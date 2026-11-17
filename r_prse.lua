-- REDUX parser. --
--[[
    Responsible for generating an Abstract Syntax Tree
    and catching any possible errors that may happen.
]]--
-- NOT FINISHED YET

-- 500 errors.
local r_error = require "r_error"

local function switch(condition)
    local self = {}
    local is_true = false

    function self:case(value, func)
        if is_true then return end
        if condition == value then
            is_true = true
            func()
        end
        return self
    end

    function self:default(func)
        if is_true then return end
        is_true = true
        func()
        return self
    end

    return self
end

local max_vars = 250

local input = {
    -- 1 0
    prefix = {
        "not"
    },
    -- 0 1
    postfix = {
        "?=", "var", "type", "const", "func",
        "usable", "unusable", "while",
        "return", "else", "imports",
        "export", "if", "for",
        "ref"
    },
    -- 1 0 1
    infix = {
        "and", "or", "xor",
        "!=", "==", "<->",
        "<=", ">=", ">", "<",
        "+=", "-=", "*=", "/=",
        "+", "-", "*", "/", "%",
        "^"
    }
}

local multiple_inputs = {
    
}

-- theoretically this is more like a scanner constructor
-- but whatever
local function node(data)
    -- data check
    data = data or r_error.early_halt("need node data to scan")

    -- type check
    local type = data.node_type
    if type then
        r_error.assertion(type == "unary_left" or 
        type == "unary_right" or
        type == "binary", "not valid node type")
    else
        r_error.early_halt("node type doesn't exist")
    end

    -- directional check
    local left = data.left
    local right = data.right
    if type == "unary_left" then
        r_error.assertion(left ~= nil, "unary_left needs a left")
        r_error.assertion(right == nil, "unary_left doesn't need a right")
    elseif type == "unary_right" then
        r_error.assertion(left == nil, "unary_right doesn't need a left")
        r_error.assertion(right ~= nil, "unary_right needs a right")
    elseif type == "binary" then
        r_error.assertion(
            left ~= nil and
            right ~= nil,
            "binary requires both directions"
        )
    else
        r_error.early_halt("invalid directional node type")
    end

    data.parent = data.parent or "ast"

    return data
end

--[[
    Checks a fix from the token's value
]]--
local function check_fix_of(value, next)
    local needs_extra_context = false
    if value == '-' then
        -- ok we need the next_value
        needs_extra_context = true
    end
    local infix = input.infix
    for i=1, #infix do
        if infix[i] == value then
            return "infix"
        end
    end
    local prefix = input.prefix
    for i=1, #prefix do
        if prefix[i] == value then
            return "prefix"
        end
    end
    local postfix = input.postfix
    for i=1, #postfix do
        if postfix[i] == value then
            return "postfix"
        end
    end

    return nil
end

-- requires a table that takes tables with these:
--[[
    VALUE,
    TYPE
]]--
-- and returns an abstract syntax tree
local function redux_parser(tokens)
    local ast = node(
        {
            node_type = "unary_left",
            left = true -- temporary gets overridden eventually
        }
    )

    local parent = ast

    local token_len = #tokens
    local prev_val = nil
    for i=1, token_len do
        
    end

    return ast
end

return redux_parser
