local r_error = require "r_error"

-- DO NOT CHANGE UNLESS COMPLETELY NECESSARY
-- ORDER RESERVED
local RDX_TOKENS = {
    -- RESERVED KEYWORDS
    keywords = {
        "var", "type", "const", "func",
        "usable", "unusable", "while",
        "return", "else", "imports",
        "export", "if", "for",
        "ref"
    },

    -- STRUCTURAL TOKENS
    structural = {
        ':', '(', ')', '{', '}', '[', ']',
        '=', '.', ','
    },

    -- LOGICAL OPERATORS
    logical = {
        "and", "or", "not", "xor"
    },

    -- LITERALS
    literals = {
        "...", "true", "false", "Nil"
    },

    -- PRIMITIVE TYPES
    types = {
        "U64", "I64", "U32", "I32", "F64", "F32",
        "Byte", "Bool", "String", "Char", "Unused"
    },

    -- SPECIAL TOKENS
    end_of_file = {
        '<eof>'
    },

    -- COMPARISON OPERATORS
    comparison = {
        "!=", "==", "<->", "?=",
        "<=", ">=", ">", "<"
    },

    -- STRING DELIMITERS
    string_delimiters = {
        '"', "'"
    }
}

-- is c a new line character
local function is_new_line(c)
    return (
        c == '\r' or c == '\n' or c == '\r\n'
    )
end

-- is c a white space character
local function is_white_space(c)
    return (
        is_new_line(c) or
        c == '\t' or c == '\\w' or c == ' '
    )
end

local source = ""

local saved_characters = {}
local c_limiter = 30 -- how many chars can appear in there
local c_index = 1 -- character_index

local function save(c)
    if #saved_characters >= c_limiter then
        r_error.early_halt("lexical element too long")
    else
        table.insert(saved_characters, c)
    end
end

local function next()
    c_index = c_index + 1
end

-- Resolves nil cases by replacing the char with "<eof>"
-- when theres no more characters
local function save_and_next()
    local b = source:byte(c_index)
    local c = (b ~= nil) and string.char(b) or "<eof>"
    save(c); next()
end

-- LEXICAL
-- ANALYSIS

local function check(i)
    local b = string.byte(source, (c_index + i))
    local c = (b ~= nil) and string.char(b) or "<eof>"
    return c
end

local function is_alpha(c)
    return (
        (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c == '_')
    )
end

local function is_alpha_numeric(c)
    return (
        is_alpha(c) or
        (c >= '0' and c <= '9')
    )
end

--[[
    Checks if a token is an alpha based
    token. Returns true if so, else returns false.
    Immediately returns false if there's nothing inside.
]]--
local function token_is_alpha(s)
    local initial_alpha_char = false
    local encountered_char = false
    for i=1, #s do
        local b = s:byte(i)
        local c = string.char(b)
        if is_alpha(c) then
            initial_alpha_char = true
            encountered_char = true
        elseif is_alpha_numeric(c) then
            if not initial_alpha_char then
                return false
            end
            encountered_char = true
        else
            return false
        end
    end
    return encountered_char
end

--[[
    Gets the token type of a string, s
    First scans through the sections in RDX_TOKENS.
    if it doesn't work in there, then checks if s is
    a valid identifier.
    If that doesn't work, fall back and assume s is a value.
]]--
local function get_token_type(s)
    if s == "<eof>" then return "end_of_file" end

    for section_name, section in pairs(RDX_TOKENS) do
        -- ANOTHER ONE???
        for i=1, #section do
            local item = section[i]
            if s == item then
                return section_name
            end
        end
    end
    if token_is_alpha(s) then
        return "identifier"
    end
    return "value"
end

local function r_l_init(s, i)
    saved_characters = {}
    c_index = 1
    c_limiter = i
    source = s 
    -- ^ needed cause save_and_next doesn't use a parameter
end

local function new_tkn(val, typ)
    return {
        VALUE = val,
        TYPE = typ
    }
end

local function next_is_separator()
    local next = check(0)
    local structural = RDX_TOKENS.structural
    local string_delimiters = RDX_TOKENS.string_delimiters
    for i=1, #structural do
        if structural[i] == next then
            return true
        end
    end
    for i=1, #string_delimiters do
        if string_delimiters[i] == next then
            return true
        end
    end
    return is_white_space(next)
end

local function is_structural(c)
    local structural = RDX_TOKENS.structural
    for i=1, #structural do
        local item = structural[i]
        if c == item then
            return true
        end
    end
    return false
end

local function rid_of_whitespace(tokens)
    local trace = 1

    while trace <= #tokens do
        local token = tokens[trace]

        if token.VALUE == '' or is_white_space(token.VALUE) then
            table.remove(tokens, trace)
        else
            trace = trace + 1
        end
    end

    return tokens
end

local function match_comparison()
    for i = 1, #RDX_TOKENS.comparison do
        local operator = RDX_TOKENS.comparison[i]

        if source:sub(c_index, c_index + #operator - 1) == operator then
            return operator
        end
    end

    return nil
end

local function redux_lexer(s)
    local limiter = 30
    r_l_init(s, limiter)

    local tokens = {}

    local function emit(token)
        tokens[#tokens + 1] = token
        saved_characters = {}
    end

    local in_string = false
    local string_delimiter

    local line = 1

    while check(0) ~= "<eof>" do
        local current_char = check(0)

        if is_white_space(current_char) and not in_string then
            if #saved_characters > 0 then
                local data = table.concat(saved_characters)
                emit(new_tkn(data, get_token_type(data)))
            end
        
            if current_char == '\n' then
                line = line + 1
            end
        
            next()
            goto continue
        end

        if current_char == "'" or current_char == '"' then
            if not in_string then
                in_string = true
                string_delimiter = current_char
                save_and_next()
                goto continue
            elseif current_char == string_delimiter then
                save_and_next()
        
                local data = table.concat(saved_characters)
                emit(new_tkn(data, "value"))
        
                in_string = false
                string_delimiter = nil
                goto continue
            end
        end

        local comparison = not in_string and match_comparison()

        if comparison then
            if #saved_characters > 0 then
                local data = table.concat(saved_characters)
                emit(new_tkn(data, get_token_type(data)))
            end

            for i=1, #comparison do
                next()
            end

            emit(new_tkn(comparison, "comparison"))
        elseif is_structural(check(0)) and not in_string then
            if #saved_characters > 0 then
                local data = table.concat(saved_characters)
                local token_type = get_token_type(data)
                emit(new_tkn(data, token_type))
            end
        
            save_and_next()
        
            if #saved_characters > 0 then
                local data = table.concat(saved_characters)
                local token_type = get_token_type(data)
                emit(new_tkn(data, token_type))
            end
        elseif next_is_separator() and not in_string then
            local token_value = table.concat(saved_characters)

            if #saved_characters > 0 then
                local token_type = get_token_type(token_value)
                emit(new_tkn(token_value, token_type))
            end
        
            save_and_next()
        
            while is_white_space(check(0)) do
                if check(0) == '\n' then
                    line = line + 1
                end
        
                next()
            end
        else
            if current_char == '\n' then
                line = line + 1
            end

            save_and_next()
        end
        ::continue::
    end

    if in_string then
        r_error.early_halt("unclosed string literal")
    end

    if #saved_characters > 0 then
        local token_value = table.concat(saved_characters)
        local token_type = get_token_type(token_value)
        emit(new_tkn(token_value, token_type))
    end

    return rid_of_whitespace(tokens)
end

return redux_lexer
