local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- Quality levels
local HIGH = "High Quality"
local MID  = "Mid Quality"
local LOW  = "Low Quality"
-- Platform
local is_linux, is_osx, is_windows = false, false, false
local exec_cache = {}


local function exec(process, force_exec)
    local key = table.concat(process, " ")
    if force_exec or exec_cache[key] == nil or exec_cache[key].error then
        local p_ret = utils.subprocess({args = process})
        exec_cache[key] = p_ret
        if p_ret.error and p_ret.error == "init" then
            msg.error("executable not found: " .. key)
        end
        return p_ret
    else
        return exec_cache[key]
    end
end


local function get_platform()
    local is_linux = false
    local is_osx = false
    local is_windows = type(package) == 'table' and type(package.config) == 'string' and string.sub(package.config, 1, 1) == '\\'
    if not is_windows then
        uname = exec({"uname"})
        is_linux = uname.stdout == "Linux\n"
        is_osx = uname.stdout == "Darwin\n"
    end
    return is_linux, is_osx, is_windows
end


function on_battery()
    if is_osx then
        local bat = exec({"/usr/bin/pmset", "-g", "batt"}, true)
        return string.match(bat.stdout, "Now drawing from 'Battery Power'")
    elseif is_linux then
        local res = exec({"/bin/cat", "/sys/class/power_supply/AC/online"}, true)
        return res.stdout == "0\n"
    elseif is_windows then
        msg.warn("on_battery() not implemented on windows. PRs welcome")
        msg.warn("assuming AC power")
        return false
    end
end


-- This is a crude attempt to figure out if a (beefy) dedicated GPU is present.
-- Can't identify the actually used GPU but works when we assume that an existing
-- dedicated GPU can/will be used in case we are drawing power from AC.
function dedicated_gpu()
    if is_osx then
        local r = exec({"system_profiler", "SPDisplaysDataType"})
        return string.find(r.stdout, "Chipset Model: Radeon") ~= nil or string.find(r.stdout, "Chipset Model: NVIDIA GeForce") ~= nil
    -- Untested
    elseif is_linux then
        local r = exec({"lshw", "-C", 'display'})
        r.stdout = string.lower(r.stdout)
        return string.find(r.stdout, "amd") ~= nil or string.find(r.stdout, "nvidia") ~= nil
    elseif is_windows then
        msg.warn("dedicated_gpu() not implemented on windows. PRs welcome")
        msg.warn("assuming dedicated GPU")
        return true
    end
end


local function determine_level(width, height, fps)
    if on_battery() then
        return LOW
    end

    if dedicated_gpu() then
        if width > 4096 then
            return MID
        end
        if width > 1920 and fps > 61 then
            return MID
        end
        return HIGH
    else
        if width > 1919 then
            return LOW
        end
        if fps > 58 then
            return LOW
        end
        return MID
    end
    
    msg.error("could not determine profile")
    msg.warn("assuming HIGH")
    return HIGH
end


local function is_level(level)
    return function(width, height, fps)
        local l = determine_level(width, height, fps)
        return l == level
    end
end


is_high = is_level(HIGH)
is_mid = is_level(MID)
is_low = is_level(LOW)

is_linux, is_osx, is_windows = get_platform()
