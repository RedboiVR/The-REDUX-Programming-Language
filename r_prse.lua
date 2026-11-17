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
    local token = check_t()
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

    if not token then
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

-- REDUX parser! --
--[[
    Takes freshly made lexer tokens and turns them into
    AST trees
]]--
local function redux_parser(tokens)
    r_p_init(tokens)

end

return redux_parser
