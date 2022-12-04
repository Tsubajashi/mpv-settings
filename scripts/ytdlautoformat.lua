--[[

A simple mpv script to automatically change ytdl-format (for yt-dlp, youtube-dl)
specifically if the URL is Youtube or Twitch.

Options:
- To add more domains, simply add them to the StreamSource set.
- To adjust quality, edit changedQuality value.
- To enable VP9 codec, change enableVP9 to true.
- To change frame rate, adjust FPSLimit, default is 30.

For more details:
https://github.com/Samillion/mpv-ytdlautoformat

--]]

local function Set (t)
	local set = {}
	for _, v in pairs(t) do set[v] = true end
	return set
end

-- Domains list for custom quality
local StreamSource = Set {
	'youtu.be', 'youtube.com', 'www.youtube.com', 
	'twitch.tv', 'www.twitch.tv'
}

-- Accepts: 240, 360, 480, 720, 1080, 1440, 2160
local changedQuality = 2160

-- Affects matched and non-matched domains
local enableVP9 = true
local FPSLimit = 60

-- Do not edit from here on
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local VP9value = ""

if enableVP9 == false then
	VP9value = "[vcodec!=?vp9]"
end

local ytdlChange = "bestvideo[height<=?"..changedQuality.."][fps<=?"..FPSLimit.."]"..VP9value.."+bestaudio/best[height<="..changedQuality.."]"
local ytdlDefault = "bestvideo[fps<=?"..FPSLimit.."]"..VP9value.."+bestaudio/best"

local function getStreamSource(path)
	local hostname = path:match '^%a+://([^/]+)/' or ''
	return hostname:match '([%w%.]+%w+)$'
end

local function ytdlAutoChange(name, value)
	local path = value

	if StreamSource[getStreamSource(string.lower(path))] then
		mp.set_property("ytdl-format", ytdlChange)
		msg.info("Domain match found, ytdl-format has been changed.")
		msg.info("Changed ytdl-format: "..mp.get_property("ytdl-format"))
	else
		msg.info("No domain match, ytdl-format unchanged.")
	end

	mp.unobserve_property(ytdlAutoChange)
	msg.info("Finished check, script no longer running.")
end

local function ytdlCheck()
	local path = mp.get_property("path", "")
	
	if string.match(string.lower(path), "^(%a+://)") then
		mp.set_property("ytdl-format", ytdlDefault)
		msg.info("Current ytdl-format: "..mp.get_property("ytdl-format"))
		
		mp.observe_property("path", "string", ytdlAutoChange)
		msg.info("Observing path to determine ytdlAutoChange status...")
	else
		msg.info("Not a URL/Stream, script did not run.")
	end
end

mp.register_event("start-file", ytdlCheck)
