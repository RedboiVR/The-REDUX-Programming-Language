local redux_error = {}

--[[
    The initial error diagnostic.
    Very similar to Rust's diagnostics.. But not quite.
    Provides 3 main features + an additional feature:
        Initial message
        Line + Where it errors
        Possible fix

        Website link documentation (i am not working on the website until this is done lol)
]]--
function redux_error.error(configs)
    configs = configs or {}

    -- crap ton of configurations woah
    local category = configs.category or "Unknown"
    local line = configs.line or "???"
    local readable_message = configs.readable_message or "An unexpected error occurred."
    local compiler_message = configs.compiler_message or "no compiler info"

    local spacing = configs.spacing or 2
    local spacing_char = configs.spacing_char or "*"

    local line_string = configs.line_string or ""
    local possible_fix = configs.possible_fixes

    local error_spots = configs.error_spots or {}
    local error_start = error_spots.start or 1
    local error_end = error_spots["end"] or error_start + 1
    local error_note = error_spots.note and ' <- ' .. error_spots.note or ""

    local docs = configs.documentation
    
    -- building the thing
    local diagnostic = {
        spacing_char .. ' ' .. category .. " Error (ln "
            .. tostring(line) .. "): "
            .. readable_message .. " (caught "
            .. compiler_message .. ")"
    }

    for i = 1, spacing do
        diagnostic[#diagnostic + 1] = spacing_char .. " "
    end

    -- source line
    diagnostic[#diagnostic + 1] = spacing_char .. " " .. line_string

    -- error underline
    local underline = {
        spacing_char,
        " "
    }

    for i = 1, error_start - 1 do
        underline[#underline + 1] = " "
    end

    for i = error_start, error_end - 1 do
        underline[#underline + 1] = "~"
    end

    diagnostic[#diagnostic + 1] = table.concat(underline) .. error_note

    -- possible fix
    if possible_fix then
        local fix_line = {
            spacing_char,
            " "
        }

        for _ = 1, #line_string + 1 do
            fix_line[#fix_line + 1] = " "
        end

        local fix_line = table.concat(fix_line)
        diagnostic[#diagnostic + 1] =
            fix_line .. "Possible fixes: " .. possible_fix
    end

    -- docs
    if docs then
        diagnostic[#diagnostic+1] = spacing_char .. ' see ' .. docs
    end

    return diagnostic
end

return redux_error
