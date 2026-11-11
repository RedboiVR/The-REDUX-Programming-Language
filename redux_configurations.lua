local using_windows = package.config:sub(1,1) == '\\' -- Boolean that decides whether windows is allowed or not.

local redux_configurations = {}
local self = redux_configurations -- ... OOP ftw?

redux_configurations.license = "GPL 3.0"
redux_configurations.dev_contributors = {
    "RedboiVR" -- if you want put your own name in here
}

redux_configurations.rel_max = 1
redux_configurations.rel_min = 0
redux_configurations.rel_fix = 0
-- redux's release = 1.0.0
redux_configurations.release = tostring(self.rel_max) .. '.' .. tostring(self.rel_min) .. '.' .. tostring(self.rel_fix)

--[[
    Unless this is explicitly defined, REDUX can use GCC if you have it.
    Downside is that without it being so, it resorts to it's own version
    of compilation. Downside being is that it really sucks.
]]--
redux_configurations.rdx_uses_gcc = true -- SWITCH AT YOUR OWN RISK.

-- checks for path as well just important to know that
-- This checks if you can use gcc.
-- If not, or GCC is not allowed, it will resort to violence and use it's own compiler.
redux_configurations.can_use_gcc = false
if self.rdx_uses_gcc then
    local success, exit_type, exit_code
    if using_windows then
        success, exit_type, exit_code = os.execute "gcc --version >NUL 2>&1"
    else
        success, exit_type, exit_code = os.execute "gcc --version >/dev/null 2>&1"
    end
    if success then
        redux_configurations.can_use_gcc = true
    else
        redux_configurations.can_use_gcc = false
    end
    redux_configurations.gcc_exit_type = exit_type
    redux_configurations.gcc_exit_code = exit_code
end

return redux_configurations
