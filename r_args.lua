local redux_args = {}

local compile_flags = {
    ["-compile=exe"] = true,
    ["-compile=elf"] = true,
    ["-compile=mz"] = true,
    ["-compile=asm"] = true,
    ["-compile=bin"] = true,
}

local target_flags = {
    ["-target=x86"] = true,
    ["-target=8086"] = true,
    ["-target=arm"] = true,
    ["-target=riscv"] = true,
}

-- Create an arguments object. I genuinely had
-- to make THIS instead because I didn't realize
-- lua put it's own CLI arguments into the 'require' function.
-- welp it works so
function redux_args.new(...)
    local args = {}
    args["cli"] = {...}

    function args:get_arg(n)
        return self["cli"][n]
    end

    function args:get_args()
        return self["cli"]
    end

    function args:check_arg(n)
        if compile_flags[n] then
            return true, "compile", n:sub(#"-compile=")
        elseif target_flags[n] then
            return true, "target", n:sub(#"-target=")
        end
        return false, nil, nil
    end

    function args:get_arg_count()
        return #self["cli"]
    end
    return args
end

return redux_args
