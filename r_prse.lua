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
        declared_type = data.declared_type,
        value = data.value,
        fix = data.fix,
        left = data.left,
        right = data.right,
        statement_type = data.statement_type
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
        return create_expr({
            value = val,
            fix = "prefix",
            right = operand
        })
    end
end

parse_expr = function(min_bp)
    local lhs = parse_prefix()

    while true do
        local token = check_t(0)

        if not token then break end

        local operator = token.VALUE
        local binding = bp.binding_power[operator]

        if not binding then break end

        local leftbp,rightbp = binding[1], binding[2]

        if leftbp<min_bp then break end

        advance()

        local rhs = parse_expr(rightbp)

        lhs = create_expr({
            value = operator,
            fix = "infix",
            left = lhs,
            right = rhs
        })
    end

    return lhs
end

local keywords = {
    "var", "type", "const", "func",
    "usable", "unusable", "while",
    "return", "else", "imports",
    "export", "if", "for",
    "ref"
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
    
    if ((not check_t(0)) or check_t(0).VALUE == "<eof>") or (not item_is_in_array(check_t(0).VALUE, type_references)) then
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
            if not following then
                local data = {
                    category = "Type",
                    readable_message = "Expected type after ':'",
                    compiler_message = "malformed union"
                }
                print_error(data)
            end
        
            advance()
        else
            if not following or not item_is_in_array(following.VALUE, type_references) then
                local data = {
                    category = "Type",
                    readable_message = "Type doesn't exist",
                    compiler_message = "malformed union"
                }
                print_error(data)
            else
                break
            end
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
                    if token.TYPE == "keywords" then
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
                local condition = parse_expr(0)

                if check_t(0) and check_t(0).VALUE == "{" then
                    
                else
                    local data = {

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

        if token.TYPE == "keywords" then
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
