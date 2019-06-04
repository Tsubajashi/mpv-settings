--[[

Automatically apply profiles based on runtime conditions.
At least mpv 0.21.0 is required.

This script queries the list of loaded config profiles, and checks the
"profile-desc" field of each profile. If it starts with "cond:", the script
parses the string as Lua expression, and evaluates it. If the expression
returns true, the profile is applied, if it returns false, it is ignored.

Expressions can reference properties by accessing "p". For example, "p.pause"
would return the current pause status. If the variable name contains any "_"
characters, they are turned into "-". For example, "playback_time" would
return the property "playback-time". (Although you can also just write
p["playback-time"].)

Note that if a property is not available, it will return nil, which can cause
errors if used in expressions. These are printed and ignored, and the
expression is considered to be false. You can also write e.g.
get("playback-time", 0) instead of p.playback_time to default to 0.

Whenever a property referenced by a profile condition changes, the condition
is re-evaluated. If the return value of the condition changes from false or
error to true, the profile is applied.

Note that profiles cannot be "unapplied", so you may have to define inverse
profiles with inverse conditions do undo a profile.

Using profile-desc is just a hack - maybe it will be changed later.

Supported --script-opts:

    auto-profiles: if set to "no", the script disables itself (but will still
                   listen to property notifications etc. - if you set it to
                   "yes" again, it will re-evaluate the current state)

Example profiles:

# the profile names aren't used (except for logging), but must not clash with
# other profiles
[test]
profile-desc=cond:p.playback_time>10
video-zoom=2

# you would need this to actually "unapply" the "test" profile
[test-revert]
profile-desc=cond:p.playback_time<=10
video-zoom=0

--]]

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local profiles = {}
local watched_properties = {}   -- indexed by property name (used as a set)
local cached_properties = {}    -- property name -> last known raw value
local properties_to_profiles = {} -- property name -> set of profiles using it
local have_dirty_profiles = false -- at least one profile is marked dirty

-- Used during evaluation of the profile condition, and should contain the
-- profile the condition is evaluated for.
local current_profile = nil

local function evaluate(profile)
    msg.verbose("Re-evaluate auto profile " .. profile.name)

    current_profile = profile
    local status, res = pcall(profile.cond)
    current_profile = nil

    if not status then
        -- errors can be "normal", e.g. in case properties are unavailable
        msg.info("Error evaluating: " .. res)
        res = false
    elseif type(res) ~= "boolean" then
        msg.error("Profile '" .. profile.name .. "' did not return a boolean.")
        res = false
    end
    if res ~= profile.status and res == true then
        msg.info("Applying profile " .. profile.name)
        mp.commandv("apply-profile", profile.name)
    end
    profile.status = res
    profile.dirty = false
end

local function on_property_change(name, val)
    cached_properties[name] = val
    -- Mark all profiles reading this property as dirty, so they get re-evaluated
    -- the next time the script goes back to sleep.
    local dependent_profiles = properties_to_profiles[name]
    if dependent_profiles then
        for profile, _ in pairs(dependent_profiles) do
            assert(profile.cond) -- must be a profile table
            profile.dirty = true
            have_dirty_profiles = true
        end
    end
end

local function on_idle()
    if mp.get_opt("auto-profiles") == "no" then
        return
    end

    -- When events and property notifications stop, re-evaluate all dirty profiles.
    if have_dirty_profiles then
        for _, profile in ipairs(profiles) do
            if profile.dirty then
                evaluate(profile)
            end
        end
    end
    have_dirty_profiles = false
end

mp.register_idle(on_idle)

local evil_meta_magic = {
    __index = function(table, key)
        -- interpret everything as property, unless it already exists as
        -- a non-nil global value
        local v = _G[key]
        if type(v) ~= "nil" then
            return v
        end
        -- Lua identifiers can't contain "-", so in order to match with mpv
        -- property conventions, replace "_" to "-"
        key = string.gsub(key, "_", "-")
        -- Normally, we use the cached value only (to reduce CPU usage I guess?)
        if not watched_properties[key] then
            watched_properties[key] = true
            mp.observe_property(key, "native", on_property_change)
            cached_properties[key] = mp.get_property_native(key)
        end
        -- The first time the property is read we need add it to the
        -- properties_to_profiles table, which will be used to mark the profile
        -- dirty if a property referenced by it changes.
        if current_profile then
            local map = properties_to_profiles[key]
            if not map then
                map = {}
                properties_to_profiles[key] = map
            end
            map[current_profile] = true
        end
        return cached_properties[key]
    end,
}

local evil_magic = {}
setmetatable(evil_magic, evil_meta_magic)

local function compile_cond(name, s)
    chunk, err = loadstring("return " .. s, "profile " .. name .. " condition")
    if not chunk then
        msg.error("Profile '" .. name .. "' condition: " .. err)
        return function() return false end
    end
    return chunk
end

for i, v in ipairs(mp.get_property_native("profile-list")) do
    local desc = v["profile-desc"]
    if desc and desc:sub(1, 5) == "cond:" then
        local profile = {
            name = v.name,
            cond = compile_cond(v.name, desc:sub(6)),
            properties = {},
            status = nil,
            dirty = true, -- need re-evaluate
        }
        profiles[#profiles + 1] = profile
        have_dirty_profiles = true
    end
end

-- these definitions are for use by the condition expressions

p = evil_magic

function get(property_name, default)
    local val = p[property_name]
    if val == nil then
        val = default
    end
    return val
end

-- re-evaluate all profiles immediately
on_idle()