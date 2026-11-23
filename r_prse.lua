-- REDUX parser. --
--[[
    Uses Pratt Parsing to generate an AST tree.
]]--

local r_error = require "r_error"

local function print_error(figs)
    local err = r_error.error(figs)

    local diagnostic = table.concat(err, "\n")
    print(diagnostic)
    os.exit(1)
end

local fix_def = {
    prefix = {
        "not",
        "-",
        "?="
    },
    
    infix = {
        -- Logical
        "and",
        "or",
        "xor",
    
        -- Comparison
        "!=",
        "==",
        "<->",
        "<=",
        ">=",
        ">",
        "<",
    
        -- Mathematical
        "+",
        "-",
        "*",
        "/",
        "%",
        "^",
    
        -- Compound assignment
        "+=",
        "-=",
        "*=",
        "/="
    }
}

local bp = {
    binding_power = {
        -- Logical
        ["or"]  = {10, 11},
        ["xor"] = {20, 21},
        ["and"] = {30, 31},
    
        -- Comparison
        ["=="]  = {40, 41},
        ["!="]  = {40, 41},
        ["<->"] = {40, 41},
        ["<="]  = {40, 41},
        [">="]  = {40, 41},
        [">"]   = {40, 41},
        ["<"]   = {40, 41},
    
        -- Mathematical
        ["+"] = {50, 51},
        ["-"] = {50, 51},
        ["*"] = {60, 61},
        ["/"] = {60, 61},
        ["%"] = {60, 61},
        ["^"] = {70, 70},
    
        -- Compound assignment
        ["+="] = {5, 5},
        ["-="] = {5, 5},
        ["*="] = {5, 5},
        ["/="] = {5, 5}
    },
    
    prefix_binding_power = {
        ["not"] = 35,
        ["-"]   = 65,
        ["ref"] = 75,
        ["?="]  = 35
    }
}

local function switch(condition)
    local self = {}

    local is_true = false

    function self:case(value, func)
        if condition == value and not is_true then
            is_true = true
            func()
        end
        return self
    end

    function self:default(func)
        if not is_true then
            is_true = true
            func()
        end
    end

    return self
end

local function create_literal(data)
    data = data or r_error.early_halt("literals require data")

    r_error.assertion(data.value ~= nil, "literal requires a value")
    r_error.assertion(data.literal_type ~= nil, "literal needs a literal type")

    return {
        node_type = data.node_type,
        literal_type = data.literal_type,
        value = data.value
    }
end

local function create_expr(data)
    data = data or r_error.early_halt("expression needs data")

    r_error.assertion(data.fix ~= nil, "expression needs a fix")
    r_error.assertion(
        data.fix == "prefix" or
        data.fix == "postfix" or
        data.fix == "infix",
        "fix needs to be prefix, postfix, or infix"
    )

    local fix_type = data.fix
    local fix_is_unary = (fix_type == "postfix" or fix_type == "prefix")

    local data_left = data.left
    local data_right = data.right

    if fix_is_unary then
        switch(fix_type)
            :case("postfix", function()
                r_error.assertion(data_left ~= nil, "postfix expression needs a left side")
                r_error.assertion(data_right == nil, "postfix expression cannot have a right side")
            end)
            :case("prefix", function()
                r_error.assertion(data_left == nil, "prefix expression cannot have a left side")
                r_error.assertion(data_right ~= nil, "prefix expression needs a right side")
            end)
    else
        r_error.assertion(data_left ~= nil and data_right ~= nil,
            "infix expression needs both sides to exist")
    end

    r_error.assertion(data.value ~= nil, "value must exist")

    return {
        node_type = "expression",
        value = data.value,

        fix = fix_type,
        left = data_left,
        right = data_right
    }
end

local function create_statement(data)
    data = data or r_error.early_halt("statement requires data")

    r_error.assertion(
        data.statement_type ~= nil,
        "statement needs a statement type"
    )

    r_error.assertion(
        data.value ~= nil,
        "statement needs value"
    )

    r_error.assertion(
        data.fix == "unary" or data.fix == "binary",
        "statement fix needs to be unary or binary"
    )
    if data.fix == "unary" then
        r_error.assertion(
            (data.left ~= nil) ~= (data.right ~= nil),
            "unary statement needs exactly one side"
        )
    elseif data.fix == "binary" then
        r_error.assertion(
            data.left ~= nil and data.right ~= nil,
            "binary statement needs both sides"
        )
    else
        r_error.early_halt("not valid statement type")
    end

    return {
        node_type = "statement",
        else_body = data.else_body,
        declared_type = data.declared_type,
        value = data.value,
        fix = data.fix,
        left = data.left,
        right = data.right,
        statement_type = data.statement_type,
        parameters = data.parameters
    }
end

local function create_type(data)
    data = data or r_error.early_halt("type requires data")

    r_error.assertion(
        data.value ~= nil, "type needs a value"
    )

    return {
        node_type = "type",
        value = data.value
    }
end

local position = 1

local tokens

local function r_p_init(t)
    position = 1
    tokens = t
end

local function check_t(i)
    if tokens ~= nil then
       return tokens[position+(i or 1)] 
    end
end

local function advance()
    local token = check_t(0)
    position = position + 1
    return token
end

local function get_number_kind(value)
    local num = tonumber(value)

    if num == nil then return end

    if value:find("%.") then
        return "Float"
    end

    if num < 0 then
        return "Integer"
    else
        return "Unsigned"
    end
end

local function account_for_esc(text)
    local chars_accounted = 0
    local text_len = #text

    local is_escape = false

    local i = 1
    while i <= text_len do
        local b = text:byte(i)
        if b == nil then break end
        local c = string.char(b)
        if is_escape == false then
            if c == '\\' then
                chars_accounted = chars_accounted + 1
                is_escape = true
            end
        else
            chars_accounted = chars_accounted + 1
            is_escape = false
        end
        i = i + 1
    end

    return chars_accounted
end

local function get_type_of(value)
    if type(value) ~= "string" then return end
    -- string checking
    local first, last = value:sub(1,1), value:sub(-1)
    if first == '"' and last == '"' then
        return "String"
    -- char checking
    elseif first == "'" and last == "'" then
        if account_for_esc(value) == 3 then
            return "Char"
        end
    end

    local val_type
    switch(value)
        :case("true", function()
            val_type = "Bool"
        end)
        :case("false", function()
            val_type = "Bool"
        end)
        :case("Nil", function()
            val_type = "Nil"
        end)

    local num = get_number_kind(value)
    if num then return num end

    return val_type
end

local parse_expr

local function parse_prefix()
    if tokens == nil then r_error.early_halt("tokens doesn't exist yet") end

    local token = advance()

    local previous = token and token.VALUE == "<eof>"
    and check_t(-2)
    or check_t(-1)
    print("token:", token and token.VALUE)
    print("previous:", previous and previous.VALUE)
    print("position:", position)
    print("current:", check_t(0) and check_t(0).VALUE)

    if not token and (not previous or previous.VALUE ~= "return") then
        local configs = {
            category = "Syntax",
            readable_message = "Caught unexpected end of expression",
            compiler_message = "unexpected ending",
            possible_fix = "Provide an expression."
        }
        print_error(configs)
    end

    local val = token.VALUE
    local token_type = token.TYPE

    if val == "(" then
        local expr = parse_expr(0)

        local closing = check_t(0)

        if not closing or closing.VALUE ~= ")" then
            local data = {
                category = "Syntax",
                readable_message = "Expected closing parenthesis",
                compiler_message = "unclosed expression"
            }
            print_error(data)
        end

        advance()
        return expr
    end

    if token_type == "value" or token_type == "literals" then
        local lit_type = get_type_of(val)

        if lit_type then
            return create_literal({
                node_type = "literal",
                literal_type = lit_type,
                value = val
            })
        end
    end
    if token_type == "identifier" then
        return create_literal({
            node_type = "identifier",
            literal_type = "identifier",
            value = val
        })
    end
    if bp.prefix_binding_power[val] then
        local operand = parse_expr(bp.prefix_binding_power[val])
        if val == "ref" then
            if not operand then
                local data = {
                    category = "Syntax",
                    readable_message = "Reference does not have identifier",
                    compiler_message = "nonexistant reference"
                }
                print_error(data)
            end
            if operand.node_type ~= "identifier" then
                local data = {
                    category = "Syntax",
                    readable_message = "Reference is not identifier",
                    compiler_message = "reference not identifier"
                }
                print_error(data)
            end
        end
        return create_expr({
            value = val,
            fix = "prefix",
            right = operand
        })
    end
end

local function apply_implicit_comparison(node, operator, value)
    if node.node_type == "expression" and
    (node.value == "and" or node.value == "or" or node.value == "xor") then
        node.left = apply_implicit_comparison(node.left, operator, value)
        node.right = apply_implicit_comparison(node.right, operator, value)
    
        return node
    end

    return create_expr({
        value = operator,
        fix = "infix",
        left = node,
        right = value
    })
end

parse_expr = function(min_bp, implicit_comparison)
    local lhs = parse_prefix()

    while true do
        local token = check_t(0)

        if not token then break end

        local operator = token.VALUE

        local closing = check_t(0)

        if operator == "(" then
            if not closing or closing.VALUE ~= ")" then
                local data = {
                    category = "Syntax",
                    readable_message = "Function calls currently cannot have arguments rn :(",
                    compiler_message = "no function calls rn haha"
                }
                print_error(data)
            end
    
            advance()
    
            lhs = create_expr({
                value = "func_call",
                fix = "postfix",
                left = lhs
            })

            goto continue
        end

        local binding = bp.binding_power[operator]

        if not binding then break end

        local leftbp,rightbp = binding[1], binding[2]

        if leftbp<min_bp then break end

        advance()

        local rhs = parse_expr(rightbp, implicit_comparison)

        if implicit_comparison and (operator == "and" or operator == "or" or operator == "xor") then
            if rhs and bp.binding_power[rhs.value] and bp.binding_power[rhs.value][1] == 40 then
                lhs = apply_implicit_comparison(lhs, rhs.value, rhs.right)
            end
        end

        lhs = create_expr({
            value = operator,
            fix = "infix",
            left = lhs,
            right = rhs
        })
        ::continue::
    end

    return lhs
end

local keywords = {
    "var", "type", "const", "func",
    "usable", "unusable", "while",
    "return", "else", "imports",
    "export", "if", "for"
}

local type_references = {
    "I64", "U64", "F64",
    "I32", "U32", "F32",
    "Byte", "Char", "String",
    "Nil", "Any", "Bool", "Unused"
}

local function item_is_in_array(needle, haystack)
    for _, v in ipairs(haystack) do
        if v == needle then
            return true
        end
    end
    return false
end

local function check_union()
    local union = {}

    if ((not check_t(0)) or check_t(0).VALUE == "<eof>") or
        (not item_is_in_array(check_t(0).VALUE, type_references)) then

        local data = {
            category = "Type",
            readable_message = "First token isn't a valid type",
            compiler_message = "malformed union"
        }
        print_error(data)
    end

    while check_t(0) do
        local token = check_t(0)
        local following = check_t(1)

        if item_is_in_array(token.VALUE, type_references) then
            union[#union+1] = token
            advance()

        elseif token.VALUE == ":" then
            if not following or not item_is_in_array(following.VALUE, type_references) then
                local data = {
                    category = "Type",
                    readable_message = "Expected a valid type after ':'",
                    compiler_message = "malformed union"
                }
                print_error(data)
            end

            advance()
        else
            break
        end
    end

    return union
end

local function parse_type()
    local union = check_union()

    return create_type({
        value = union
    })
end

local function parse_statement()
    local token = check_t(0)

    local function check_decl(ident, decl_type)
        if ident.node_type ~= "identifier" then
            local data = {
                category = "Syntax",
                readable_message = "Couldn't apply identifier to declaration",
                compiler_message = "invalid name"
            }
            print_error(data)
        end

        local declared_type

        local token = check_t(0)

        if token and token.VALUE == ":" then
            advance()
            declared_type = parse_type()
        end
        
        token = check_t(0) -- Get the new current token

        if token and token.VALUE == "=" then
            advance()

            local initializer = parse_expr(0)

            return create_statement({
                statement_type = decl_type,
                declared_type = declared_type,
                fix = "binary",
                left = ident,
                right = initializer,
                value = decl_type
            })
        end

        return create_statement({
            statement_type = decl_type,
            declared_type = declared_type,
            fix = "unary",
            right = ident,
            value = decl_type
        })
    end

    local is_key = false
    for _, v in ipairs(keywords) do
        if token.VALUE == v then
            is_key = true
            break
        end
    end
    local statement
    if is_key then
        switch(token.VALUE)
            :case("var", function()
                advance()
                local ident = parse_prefix()
                statement = check_decl(ident, "var")
            end)
            :case("type", function()
                advance()

                local ident = parse_prefix()

                if ident.node_type ~= "identifier" then
                    local data = {
                        category = "Syntax",
                        readable_message = "Couldn't apply identifier to declaration",
                        compiler_message = "invalid name"
                    }
                    print_error(data)
                end

                local sign = check_t(0)
                if sign == nil or sign.VALUE ~= "=" then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected '=' after declaration",
                        compiler_message = "bad assignment"
                    }
                    print_error(data)
                end

                advance()

                local type_value = parse_type()

                if not type_value then
                    print_error({
                        category = "Syntax",
                        readable_message = "Expected a type after '='",
                        compiler_message = "missing type expression"
                    })
                end
                statement = create_statement({
                    statement_type = "type",
                    fix = "binary",
                    left = ident,
                    right = type_value,
                    value = "type"
                })
            end)
            :case("return", function()
                advance()

                local value = parse_expr(0)

                statement = create_statement({
                    statement_type = "return",
                    fix = "unary",
                    right = value,
                    value = "return"
                })
            end)
            :case("func", function()
                advance()
                local ident = parse_prefix()

                local parameters = {}
                if check_t(0) and check_t(0).VALUE == "(" then
                    advance()
                    while check_t(0) and check_t(0).VALUE ~= ")" do
                        local param_ident = parse_prefix()

                        if not param_ident or param_ident.node_type ~= "identifier" then
                            local data = {
                                category = "Syntax",
                                readable_message = "Expected a parameter identifier",
                                compiler_message = "invalid parameter"
                            }
                            print_error(data)
                        end

                        local param_type

                        if check_t(0) and check_t(0).VALUE == ":" then
                            advance()
                            param_type = parse_type()
                        end
                        parameters[#parameters + 1] = create_expr({
                            value = "parameter",
                            fix = "infix",
                            left = param_ident,
                            right = {
                                literal = param_type and create_literal({
                                    node_type = "literal",
                                    literal_type = "type",
                                    value = param_type
                                }) or nil,
                                value = param_ident.value,
                                type = param_type
                            },
                            parameters = parameters
                        })
                    end
                    if not check_t(0) or check_t(0).VALUE ~= ")" then
                        local data = {
                            category = "Syntax",
                            readable_message = "Expected ')' after parameters",
                            compiler_message = "nonexistant param closer"
                        }
                        print_error(data)
                    end
                    advance()
                end

                if not ident then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected a function name",
                        compiler_message = "invalid function name"
                    }
                    print_error(data)
                end

                -- Return type
                local returntype

                if check_t(0) and check_t(0).VALUE == ":" then
                    advance()
                    returntype = parse_type()
                    if not returntype then
                        local data = {
                            category = "Syntax",
                            readable_message = "Return value suggested but not provided",
                            compiler_message = "no return value"
                        }
                        print_error(data)
                    end
                end

                -- Function body
                local opening = check_t(0)
                if not opening or opening.VALUE ~= "{" then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected a function body",
                        compiler_message = "no body"
                    }
                    print_error(data)
                end
                advance()
                local body = {}
                while check_t(0) and check_t(0).VALUE ~= "}" and check_t(0).VALUE ~= "<eof>" do
                    local token = check_t(0)
                    if token.TYPE == "keywords" and token.VALUE ~= "ref" then
                        local stmt = parse_statement()
                        if stmt then
                            body[#body+1] = stmt
                        end
                    else
                        local expr = parse_expr(0)
                        body[#body+1] = expr
                    end
                end
                if not check_t(0) then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected closing '}' for function body",
                        compiler_message = "unclosed function body"
                    }
                    print_error(data)
                end
                statement = create_statement({
                    statement_type = "func",
                    fix = "binary",
                    left = ident,
                    declared_type = returntype or "Any",
                    right = body,
                    value = "func"
                })
                advance()
            end)
            :case("if", function()
                advance()
                local condition = parse_expr(0, true)
                if not condition then
                    local data = {
                        category = "Syntax",
                        readable_message = "'if' statement needs a condition",
                        compiler_message = "no condition"
                    }
                    print_error(data)
                end

                if check_t(0) and check_t(0).VALUE == "{" then
                    advance()
                    local body = {}
                    while check_t(0) and check_t(0).VALUE ~= "}" and check_t(0).VALUE ~= "<eof>" do
                        local token = check_t(0)

                        if token.TYPE == "keywords" and token.VALUE ~= "ref" then
                            local stmt = parse_statement()
                            if stmt then
                                body[#body+1] = stmt
                            end
                        else
                            local expr = parse_expr(0)
                            if expr then
                                body[#body+1] = expr
                            end
                        end
                    end
                    if not check_t(0) or check_t(0).VALUE ~= "}" then
                        local data = {
                            category = "Syntax",
                            readable_message = "Expected closing '}' for if body",
                            compiler_message = "unfinished body"
                        }
                        print_error(data)
                    end
                    advance()

                    local else_body
                    local next_token = check_t(0)
                    
                    if next_token and next_token.VALUE == "else" then
                        advance()
                    
                        local next_branch = check_t(0)
                    
                        if next_branch and next_branch.VALUE == "if" then
                            -- else if: recursively parse another if statement
                            else_body = {parse_statement()}
                        else
                            -- else: parse a normal block
                            local opening = check_t(0)
                    
                            if not opening or opening.VALUE ~= "{" then
                                print_error({
                                    category = "Syntax",
                                    readable_message = "Expected '{' or 'if' after 'else'",
                                    compiler_message = "missing else body"
                                })
                            end
                    
                            advance()
                            else_body = {}
                    
                            while check_t(0) and check_t(0).VALUE ~= "}" and check_t(0).VALUE ~= "<eof>" do
                                local token = check_t(0)
                    
                                if token.TYPE == "keywords" and token.VALUE ~= "ref" then
                                    local stmt = parse_statement()
                                    if stmt then
                                        else_body[#else_body+1] = stmt
                                    end
                                else
                                    local expr = parse_expr(0)
                                    if expr then
                                        else_body[#else_body+1] = expr
                                    end
                                end
                            end
                    
                            if not check_t(0) or check_t(0).VALUE ~= "}" then
                                print_error({
                                    category = "Syntax",
                                    readable_message = "Expected closing '}' for else body",
                                    compiler_message = "unfinished else body"
                                })
                            end
                    
                            advance()
                        end
                    end
                    
                    statement = create_statement({
                        statement_type = "if_cond",
                        fix = "binary",
                        else_body = else_body,
                        left = condition,
                        right = body,
                        declared_type = "Bool",
                        value = "if"
                    })
                else
                    local data = {
                        category = "Syntax",
                        readable_message = "'if' statement needs a body if the condition is true",
                        compiler_message = "no body"
                    }
                    print_error(data)
                end
            end)
            :case("while", function()
                advance()
                local condition = parse_expr(0, true)
                if not condition then
                    local data = {
                        category = "Syntax",
                        readable_message = "'while' statement needs a condition",
                        compiler_message = "no condition"
                    }
                    print_error(data)
                end

                if check_t(0) and check_t(0).VALUE == "{" then
                    advance()
                    local body = {}
                    while check_t(0) and check_t(0).VALUE ~= "}" do
                        local token = check_t(0)
                        if token.TYPE == "keywords" and token.VALUE ~= "ref" then
                            local stmt = parse_statement()
                            if stmt then
                                body[#body+1] = stmt
                            end
                        else
                            local expr = parse_expr(0)
                            if expr then
                                body[#body+1] = expr
                            end
                        end
                    end
                    if not check_t(0) or check_t(0).VALUE ~= "}" then
                        local data = {
                            category = "Syntax",
                            readable_message = "Expected closing '}' for while body",
                            compiler_message = "unfinished body"
                        }
                        print_error(data)
                    end
                    advance()
                    statement = create_statement({
                        statement_type = "while_cond",
                        fix = "binary",
                        left = condition,
                        right = body,
                        declared_type = "Bool",
                        value = "while"
                    })
                end
            end)
            :case("export", function()
                advance()

                local decl = parse_statement()

                if decl == nil then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected a declaration of export",
                        compiler_message = "unexpected closure"
                    }
                    print_error(data)
                end

                local is_decl = (
                    decl.statement_type == "var" or
                    decl.statement_type == "const" or
                    decl.statement_type == "func" or
                    decl.statement_type == "type"
                )

                if is_decl then
                    statement = create_expr({
                        value = "export",
                        fix = "prefix",
                        right = decl
                    })
                else
                    if decl.value == "export" then
                        local data = {
                            category = "Semantic",
                            readable_message = "Cannot assign an export statement to an export",
                            compiler_message = "export recursion"
                        }
                        print_error(data)
                    end
                    local data = {
                        category = "Syntax",
                        readable_message = "Not a valid exportation",
                        compiler_message = "missing export declaration"
                    }
                    print_error(data)
                end
            end)
            :case("imports", function()
                advance()

                local token = check_t(0)

                switch(token.TYPE)
                    :case("value", function()
                        statement = create_statement({
                            statement_type = "imports",
                            value = "imports_mod",
                            fix = "unary",
                            right = create_literal({
                                node_type = "literal",
                                literal_type = "String",
                                value = token.VALUE
                            })
                        })
                    end)
                    :case("identifier", function()
                        statement = create_statement({
                            statement_type = "imports",
                            value = "imports_lib",
                            fix = "unary",
                            right = create_literal({
                                node_type = "literal",
                                literal_type = "identifier",
                                value = token.VALUE
                            })
                        })
                    end)
                    :default(function()
                        local data = {
                            category = "Syntax",
                            readable_message = "Expected a string or module identifier after 'imports'",
                            compiler_message = "invalid import target"
                        }
                        print_error(data)
                    end)
            end)
            :case("for", function()
                advance()

                local arguments = {parse_expr(0)}
                
                while check_t(0) and check_t(0).VALUE == "," do
                    advance()

                    local argument = parse_expr(0)
                    if not argument then
                        local data = {
                            category = "Syntax",
                            readable_message = "Expected an argument after ','",
                            compiler_message = "missing for argument"
                        }
                        print_error(data)
                    end
                    arguments[#arguments+1] = argument
                end

                local index = arguments[1]
                if not index or index.node_type ~= "identifier" then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected an index identifier after 'for'",
                        compiler_message = "invalid for index"
                    }
                    print_error(data)
                end
                local iterator = arguments[#arguments]
                if not iterator or arguments[1] == iterator then
                    local data = {
                        category = "Syntax",
                        readable_message = "Expected an iterator identifier",
                        compiler_message = "invalid for iterator"
                    }
                    print_error(data)
                end
            end)

    end
    return statement
end

-- REDUX parser! --
--[[
    Takes freshly made lexer tokens and turns them into
    AST trees
]]--
local function redux_parser(tokens)
    r_p_init(tokens)
    local AST = {}
    while check_t(0) and check_t(0).VALUE ~= "<eof>" do
        local token = check_t(0)

        if token.TYPE == "keywords" and token.VALUE ~= "ref" then
            print("PARSING: ", token.VALUE)
            local statement = parse_statement()
            if statement then
                AST[#AST+1] = statement
            end
        else
            local expr = parse_expr(0)
            AST[#AST+1] = expr
        end
    end

    return AST
end

return redux_parser
