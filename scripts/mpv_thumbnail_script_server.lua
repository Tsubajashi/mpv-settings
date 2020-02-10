--[[
    Copyright (C) 2017 AMM

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--
--[[
    mpv_thumbnail_script.lua 0.4.2 - commit a2de250 (branch master)
    https://github.com/TheAMM/mpv_thumbnail_script
    Built on 2018-02-07 20:36:54
]]--
local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local opt = require 'mp.options'
local utils = require 'mp.utils'

-- Determine platform --
ON_WINDOWS = (package.config:sub(1,1) ~= '/')

-- Some helper functions needed to parse the options --
function isempty(v) return (v == false) or (v == nil) or (v == "") or (v == 0) or (type(v) == "table" and next(v) == nil) end

function divmod (a, b)
  return math.floor(a / b), a % b
end

-- Better modulo
function bmod( i, N )
  return (i % N + N) % N
end

function join_paths(...)
  local sep = ON_WINDOWS and "\\" or "/"
  local result = "";
  for i, p in pairs({...}) do
    if p ~= "" then
      if is_absolute_path(p) then
        result = p
      else
        result = (result ~= "") and (result:gsub("[\\"..sep.."]*$", "") .. sep .. p) or p
      end
    end
  end
  return result:gsub("[\\"..sep.."]*$", "")
end

-- /some/path/file.ext -> /some/path, file.ext
function split_path( path )
  local sep = ON_WINDOWS and "\\" or "/"
  local first_index, last_index = path:find('^.*' .. sep)

  if last_index == nil then
    return "", path
  else
    local dir = path:sub(0, last_index-1)
    local file = path:sub(last_index+1, -1)

    return dir, file
  end
end

function is_absolute_path( path )
  local tmp, is_win  = path:gsub("^[A-Z]:\\", "")
  local tmp, is_unix = path:gsub("^/", "")
  return (is_win > 0) or (is_unix > 0)
end

function Set(source)
  local set = {}
  for _, l in ipairs(source) do set[l] = true end
  return set
end

---------------------------
-- More helper functions --
---------------------------

-- Removes all keys from a table, without destroying the reference to it
function clear_table(target)
  for key, value in pairs(target) do
    target[key] = nil
  end
end
function shallow_copy(target)
  local copy = {}
  for k, v in pairs(target) do
    copy[k] = v
  end
  return copy
end

-- Rounds to given decimals. eg. round_dec(3.145, 0) => 3
function round_dec(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function file_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    local ok, err, code = f:read(1)
    io.close(f)
    return code == nil
  else
    return false
  end
end

function path_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function create_directories(path)
  local cmd
  if ON_WINDOWS then
    cmd = { args = {"cmd", "/c", "mkdir", path} }
  else
    cmd = { args = {"mkdir", "-p", path} }
  end
  utils.subprocess(cmd)
end

-- Find an executable in PATH or CWD with the given name
function find_executable(name)
  local delim = ON_WINDOWS and ";" or ":"

  local pwd = os.getenv("PWD") or utils.getcwd()
  local path = os.getenv("PATH")

  local env_path = pwd .. delim .. path -- Check CWD first

  local result, filename
  for path_dir in env_path:gmatch("[^"..delim.."]+") do
    filename = join_paths(path_dir, name)
    if file_exists(filename) then
      result = filename
      break
    end
  end

  return result
end

local ExecutableFinder = { path_cache = {} }
-- Searches for an executable and caches the result if any
function ExecutableFinder:get_executable_path( name, raw_name )
  name = ON_WINDOWS and not raw_name and (name .. ".exe") or name

  if self.path_cache[name] == nil then
    self.path_cache[name] = find_executable(name) or false
  end
  return self.path_cache[name]
end

-- Format seconds to HH.MM.SS.sss
function format_time(seconds, sep, decimals)
  decimals = decimals == nil and 3 or decimals
  sep = sep and sep or "."
  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  local second_format = string.format("%%0%d.%df", 2+(decimals > 0 and decimals+1 or 0), decimals)

  return string.format("%02d"..sep.."%02d"..sep..second_format, h, m, s)
end

-- Format seconds to 1h 2m 3.4s
function format_time_hms(seconds, sep, decimals, force_full)
  decimals = decimals == nil and 1 or decimals
  sep = sep ~= nil and sep or " "

  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  if force_full or h > 0 then
    return string.format("%dh"..sep.."%dm"..sep.."%." .. tostring(decimals) .. "fs", h, m, s)
  elseif m > 0 then
    return string.format("%dm"..sep.."%." .. tostring(decimals) .. "fs", m, s)
  else
    return string.format("%." .. tostring(decimals) .. "fs", s)
  end
end

-- Writes text on OSD and console
function log_info(txt, timeout)
  timeout = timeout or 1.5
  msg.info(txt)
  mp.osd_message(txt, timeout)
end

-- Join table items, ala ({"a", "b", "c"}, "=", "-", ", ") => "=a-, =b-, =c-"
function join_table(source, before, after, sep)
  before = before or ""
  after = after or ""
  sep = sep or ", "
  local result = ""
  for i, v in pairs(source) do
    if not isempty(v) then
      local part = before .. v .. after
      if i == 1 then
        result = part
      else
        result = result .. sep .. part
      end
    end
  end
  return result
end

function wrap(s, char)
  char = char or "'"
  return char .. s .. char
end
-- Wraps given string into 'string' and escapes any 's in it
function escape_and_wrap(s, char, replacement)
  char = char or "'"
  replacement = replacement or "\\" .. char
  return wrap(string.gsub(s, char, replacement), char)
end
-- Escapes single quotes in a string and wraps the input in single quotes
function escape_single_bash(s)
  return escape_and_wrap(s, "'", "'\\''")
end

-- Returns (a .. b) if b is not empty or nil
function joined_or_nil(a, b)
  return not isempty(b) and (a .. b) or nil
end

-- Put items from one table into another
function extend_table(target, source)
  for i, v in pairs(source) do
    table.insert(target, v)
  end
end

-- Creates a handle and filename for a temporary random file (in current directory)
function create_temporary_file(base, mode, suffix)
  local handle, filename
  suffix = suffix or ""
  while true do
    filename = base .. tostring(math.random(1, 5000)) .. suffix
    handle = io.open(filename, "r")
    if not handle then
      handle = io.open(filename, mode)
      break
    end
    io.close(handle)
  end
  return handle, filename
end


function get_processor_count()
  local proc_count

  if ON_WINDOWS then
    proc_count = tonumber(os.getenv("NUMBER_OF_PROCESSORS"))
  else
    local cpuinfo_handle = io.open("/proc/cpuinfo")
    if cpuinfo_handle ~= nil then
      local cpuinfo_contents = cpuinfo_handle:read("*a")
      local _, replace_count = cpuinfo_contents:gsub('processor', '')
      proc_count = replace_count
    end
  end

  if proc_count and proc_count > 0 then
      return proc_count
  else
    return nil
  end
end

function substitute_values(string, values)
  local substitutor = function(match)
    if match == "%" then
       return "%"
    else
      -- nil is discarded by gsub
      return values[match]
    end
  end

  local substituted = string:gsub('%%(.)', substitutor)
  return substituted
end

-- ASS HELPERS --
function round_rect_top( ass, x0, y0, x1, y1, r )
  local c = 0.551915024494 * r -- circle approximation
  ass:move_to(x0 + r, y0)
  ass:line_to(x1 - r, y0) -- top line
  if r > 0 then
      ass:bezier_curve(x1 - r + c, y0, x1, y0 + r - c, x1, y0 + r) -- top right corner
  end
  ass:line_to(x1, y1) -- right line
  ass:line_to(x0, y1) -- bottom line
  ass:line_to(x0, y0 + r) -- left line
  if r > 0 then
      ass:bezier_curve(x0, y0 + r - c, x0 + r - c, y0, x0 + r, y0) -- top left corner
  end
end

function round_rect(ass, x0, y0, x1, y1, rtl, rtr, rbr, rbl)
    local c = 0.551915024494
    ass:move_to(x0 + rtl, y0)
    ass:line_to(x1 - rtr, y0) -- top line
    if rtr > 0 then
        ass:bezier_curve(x1 - rtr + rtr*c, y0, x1, y0 + rtr - rtr*c, x1, y0 + rtr) -- top right corner
    end
    ass:line_to(x1, y1 - rbr) -- right line
    if rbr > 0 then
        ass:bezier_curve(x1, y1 - rbr + rbr*c, x1 - rbr + rbr*c, y1, x1 - rbr, y1) -- bottom right corner
    end
    ass:line_to(x0 + rbl, y1) -- bottom line
    if rbl > 0 then
        ass:bezier_curve(x0 + rbl - rbl*c, y1, x0, y1 - rbl + rbl*c, x0, y1 - rbl) -- bottom left corner
    end
    ass:line_to(x0, y0 + rtl) -- left line
    if rtl > 0 then
        ass:bezier_curve(x0, y0 + rtl - rtl*c, x0 + rtl - rtl*c, y0, x0 + rtl, y0) -- top left corner
    end
end
local SCRIPT_NAME = "mpv_thumbnail_script"

local default_cache_base = ON_WINDOWS and os.getenv("TEMP") or "/tmp/"

local thumbnailer_options = {
    -- The thumbnail directory
    cache_directory = join_paths(default_cache_base, "mpv_thumbs_cache"),

    ------------------------
    -- Generation options --
    ------------------------

    -- Automatically generate the thumbnails on video load, without a keypress
    autogenerate = true,

    -- Only automatically thumbnail videos shorter than this (seconds)
    autogenerate_max_duration = 3600, -- 1 hour

    -- SHA1-sum filenames over this length
    -- It's nice to know what files the thumbnails are (hence directory names)
    -- but long URLs may approach filesystem limits.
    hash_filename_length = 128,

    -- Use mpv to generate thumbnail even if ffmpeg is found in PATH
    -- ffmpeg does not handle ordered chapters (MKVs which rely on other MKVs)!
    -- mpv is a bit slower, but has better support overall (eg. subtitles in the previews)
    prefer_mpv = true,

    -- Explicitly disable subtitles on the mpv sub-calls
    mpv_no_sub = false,
    -- Add a "--no-config" to the mpv sub-call arguments
    mpv_no_config = false,
    -- Add a "--profile=<mpv_profile>" to the mpv sub-call arguments
    -- Use "" to disable
    mpv_profile = "",
    -- Output debug logs to <thumbnail_path>.log, ala <cache_directory>/<video_filename>/000000.bgra.log
    -- The logs are removed after successful encodes, unless you set mpv_keep_logs below
    mpv_logs = true,
    -- Keep all mpv logs, even the succesfull ones
    mpv_keep_logs = false,

    -- Disable the built-in keybind ("T") to add your own
    disable_keybinds = false,

    ---------------------
    -- Display options --
    ---------------------

    -- Move the thumbnail up or down
    -- For example:
    --   topbar/bottombar: 24
    --   rest: 0
    vertical_offset = 24,

    -- Adjust background padding
    -- Examples:
    --   topbar:       0, 10, 10, 10
    --   bottombar:   10,  0, 10, 10
    --   slimbox/box: 10, 10, 10, 10
    pad_top   = 10,
    pad_bot   =  0,
    pad_left  = 10,
    pad_right = 10,

    -- If true, pad values are screen-pixels. If false, video-pixels.
    pad_in_screenspace = true,
    -- Calculate pad into the offset
    offset_by_pad = true,

    -- Background color in BBGGRR
    background_color = "000000",
    -- Alpha: 0 - fully opaque, 255 - transparent
    background_alpha = 80,

    -- Keep thumbnail on the screen near left or right side
    constrain_to_screen = true,

    -- Do not display the thumbnailing progress
    hide_progress = false,

    -----------------------
    -- Thumbnail options --
    -----------------------

    -- The maximum dimensions of the thumbnails (pixels)
    thumbnail_width = 200,
    thumbnail_height = 200,

    -- The thumbnail count target
    -- (This will result in a thumbnail every ~10 seconds for a 25 minute video)
    thumbnail_count = 150,

    -- The above target count will be adjusted by the minimum and
    -- maximum time difference between thumbnails.
    -- The thumbnail_count will be used to calculate a target separation,
    -- and min/max_delta will be used to constrict it.

    -- In other words, thumbnails will be:
    --   at least min_delta seconds apart (limiting the amount)
    --   at most max_delta seconds apart (raising the amount if needed)
    min_delta = 5,
    -- 120 seconds aka 2 minutes will add more thumbnails when the video is over 5 hours!
    max_delta = 90,


    -- Overrides for remote urls (you generally want less thumbnails!)
    -- Thumbnailing network paths will be done with mpv

    -- Allow thumbnailing network paths (naive check for "://")
    thumbnail_network = false,
    -- Override thumbnail count, min/max delta
    remote_thumbnail_count = 60,
    remote_min_delta = 15,
    remote_max_delta = 120,

    -- Try to grab the raw stream and disable ytdl for the mpv subcalls
    -- Much faster than passing the url to ytdl again, but may cause problems with some sites
    remote_direct_stream = true,
}

read_options(thumbnailer_options, SCRIPT_NAME)
function skip_nil(tbl)
    local n = {}
    for k, v in pairs(tbl) do
        table.insert(n, v)
    end
    return n
end

function create_thumbnail_mpv(file_path, timestamp, size, output_path, options)
    options = options or {}

    local ytdl_disabled = not options.enable_ytdl and (mp.get_property_native("ytdl") == false
                                                       or thumbnailer_options.remote_direct_stream)

    local header_fields_arg = nil
    local header_fields = mp.get_property_native("http-header-fields")
    if #header_fields > 0 then
        -- We can't escape the headers, mpv won't parse "--http-header-fields='Name: value'" properly
        header_fields_arg = "--http-header-fields=" .. table.concat(header_fields, ",")
    end

    local profile_arg = nil
    if thumbnailer_options.mpv_profile ~= "" then
        profile_arg = "--profile=" .. thumbnailer_options.mpv_profile
    end

    local log_arg = "--log-file=" .. output_path .. ".log"

    local mpv_command = skip_nil({
        "mpv",
        -- Hide console output
        "--msg-level=all=no",

        -- Disable ytdl
        (ytdl_disabled and "--no-ytdl" or nil),
        -- Pass HTTP headers from current instance
        header_fields_arg,
        -- Pass User-Agent and Referer - should do no harm even with ytdl active
        "--user-agent=" .. mp.get_property_native("user-agent"),
        "--referrer=" .. mp.get_property_native("referrer"),
        -- Disable hardware decoding
        "--hwdec=no",

        -- Insert --no-config, --profile=... and --log-file if enabled
        (thumbnailer_options.mpv_no_config and "--no-config" or nil),
        profile_arg,
        (thumbnailer_options.mpv_logs and log_arg or nil),

        file_path,

        "--start=" .. tostring(timestamp),
        "--frames=1",
        "--hr-seek=yes",
        "--no-audio",
        -- Optionally disable subtitles
        (thumbnailer_options.mpv_no_sub and "--no-sub" or nil),

        ("--vf=scale=%d:%d"):format(size.w, size.h),
        "--vf-add=format=bgra",
        "--of=rawvideo",
        "--ovc=rawvideo",
        "--o", output_path
    })
    return utils.subprocess({args=mpv_command})
end


function create_thumbnail_ffmpeg(file_path, timestamp, size, output_path)
    local ffmpeg_command = {
        "ffmpeg",
        "-loglevel", "quiet",
        "-noaccurate_seek",
        "-ss", format_time(timestamp, ":"),
        "-i", file_path,

        "-frames:v", "1",
        "-an",

        "-vf", ("scale=%d:%d"):format(size.w, size.h),
        "-c:v", "rawvideo",
        "-pix_fmt", "bgra",
        "-f", "rawvideo",

        "-y", output_path
    }
    return utils.subprocess({args=ffmpeg_command})
end


function check_output(ret, output_path, is_mpv)
    local log_path = output_path .. ".log"
    local success = true

    if ret.killed_by_us then
        return nil
    else
        if ret.error or ret.status ~= 0 then
            msg.error("Thumbnailing command failed!")
            msg.error("mpv process error:", ret.error)
            msg.error("Process stdout:", ret.stdout)
            if is_mpv then
                msg.error("Debug log:", log_path)
            end

            success = false
        end

        if not file_exists(output_path) then
            msg.error("Output file missing!", output_path)
            success = false
        end
    end

    if is_mpv and not thumbnailer_options.mpv_keep_logs then
        -- Remove successful debug logs
        if success and file_exists(log_path) then
            os.remove(log_path)
        end
    end

    return success
end


function do_worker_job(state_json_string, frames_json_string)
    msg.debug("Handling given job")
    local thumb_state, err = utils.parse_json(state_json_string)
    if err then
        msg.error("Failed to parse state JSON")
        return
    end

    local thumbnail_indexes, err = utils.parse_json(frames_json_string)
    if err then
        msg.error("Failed to parse thumbnail frame indexes")
        return
    end

    local thumbnail_func = create_thumbnail_mpv
    if not thumbnailer_options.prefer_mpv then
        if ExecutableFinder:get_executable_path("ffmpeg") then
            thumbnail_func = create_thumbnail_ffmpeg
        else
            msg.warn("Could not find ffmpeg in PATH! Falling back on mpv.")
        end
    end

    local file_duration = mp.get_property_native("duration")
    local file_path = thumb_state.worker_input_path

    if thumb_state.is_remote then
        if (thumbnail_func == create_thumbnail_ffmpeg) then
            msg.warn("Thumbnailing remote path, falling back on mpv.")
        end
        thumbnail_func = create_thumbnail_mpv
    end

    local generate_thumbnail_for_index = function(thumbnail_index)
        -- Given a 1-based thumbnail index, generate a thumbnail for it based on the thumbnailer state
        local thumb_idx = thumbnail_index - 1
        msg.debug("Starting work on thumbnail", thumb_idx)

        local thumbnail_path = thumb_state.thumbnail_template:format(thumb_idx)
        -- Grab the "middle" of the thumbnail duration instead of the very start, and leave some margin in the end
        local timestamp = math.min(file_duration - 0.25, (thumb_idx + 0.5) * thumb_state.thumbnail_delta)

        mp.commandv("script-message", "mpv_thumbnail_script-progress", tostring(thumbnail_index))

        -- The expected size (raw BGRA image)
        local thumbnail_raw_size = (thumb_state.thumbnail_size.w * thumb_state.thumbnail_size.h * 4)

        local need_thumbnail_generation = false

        -- Check if the thumbnail already exists and is the correct size
        local thumbnail_file = io.open(thumbnail_path, "rb")
        if thumbnail_file == nil then
            need_thumbnail_generation = true
        else
            local existing_thumbnail_filesize = thumbnail_file:seek("end")
            if existing_thumbnail_filesize ~= thumbnail_raw_size then
                -- Size doesn't match, so (re)generate
                msg.warn("Thumbnail", thumb_idx, "did not match expected size, regenerating")
                need_thumbnail_generation = true
            end
            thumbnail_file:close()
        end

        if need_thumbnail_generation then
            local ret = thumbnail_func(file_path, timestamp, thumb_state.thumbnail_size, thumbnail_path, thumb_state.worker_extra)
            local success = check_output(ret, thumbnail_path, thumbnail_func == create_thumbnail_mpv)

            if success == nil then
                -- Killed by us, changing files, ignore
                msg.debug("Changing files, subprocess killed")
                return true
            elseif not success then
                -- Real failure
                mp.osd_message("Thumbnailing failed, check console for details", 3.5)
                return true
            end
        else
            msg.debug("Thumbnail", thumb_idx, "already done!")
        end

        -- Verify thumbnail size
        -- Sometimes ffmpeg will output an empty file when seeking to a "bad" section (usually the end)
        thumbnail_file = io.open(thumbnail_path, "rb")

        -- Bail if we can't read the file (it should really exist by now, we checked this in check_output!)
        if thumbnail_file == nil then
            msg.error("Thumbnail suddenly disappeared!")
            return true
        end

        -- Check the size of the generated file
        local thumbnail_file_size = thumbnail_file:seek("end")
        thumbnail_file:close()

        -- Check if the file is big enough
        local missing_bytes = math.max(0, thumbnail_raw_size - thumbnail_file_size)
        if missing_bytes > 0 then
            msg.warn(("Thumbnail missing %d bytes (expected %d, had %d), padding %s"):format(
              missing_bytes, thumbnail_raw_size, thumbnail_file_size, thumbnail_path
            ))
            -- Pad the file if it's missing content (eg. ffmpeg seek to file end)
            thumbnail_file = io.open(thumbnail_path, "ab")
            thumbnail_file:write(string.rep(string.char(0), missing_bytes))
            thumbnail_file:close()
        end

        msg.debug("Finished work on thumbnail", thumb_idx)
        mp.commandv("script-message", "mpv_thumbnail_script-ready", tostring(thumbnail_index), thumbnail_path)
    end

    msg.debug(("Generating %d thumbnails @ %dx%d for %q"):format(
        #thumbnail_indexes,
        thumb_state.thumbnail_size.w,
        thumb_state.thumbnail_size.h,
        file_path))

    for i, thumbnail_index in ipairs(thumbnail_indexes) do
        local bail = generate_thumbnail_for_index(thumbnail_index)
        if bail then return end
    end

end

-- Set up listeners and keybinds

-- Job listener
mp.register_script_message("mpv_thumbnail_script-job", do_worker_job)


-- Register this worker with the master script
local register_timer = nil
local register_timeout = mp.get_time() + 1.5

local register_function = function()
    if mp.get_time() > register_timeout and register_timer then
        msg.error("Thumbnail worker registering timed out")
        register_timer:stop()
    else
        msg.debug("Announcing self to master...")
        mp.commandv("script-message", "mpv_thumbnail_script-worker", mp.get_script_name())
    end
end

register_timer = mp.add_periodic_timer(0.1, register_function)

mp.register_script_message("mpv_thumbnail_script-slaved", function()
    msg.debug("Successfully registered with master")
    register_timer:stop()
end)
