-- requires subliminal, version 1.0 or newer
-- default keybinding: b
-- add the following to your input.conf to change the default keybinding:
-- keyname script_binding auto_load_subs

local utils = require 'mp.utils'
function load_sub_fn()
    subl = "/usr/local/bin/subliminal" -- use 'which subliminal' to find the path
    mp.msg.info("Searching subtitle")
    mp.osd_message("Searching subtitle")
    t = {}
    t.args = {subl, "download", "-l", "en", "-l", "eng", "-p", "podnapisi", "-p", "addic7ed", "-p", "subscenter", "-p", "thesubdb", "-p", "tvsubtitles", mp.get_property("path")}
    res = utils.subprocess(t)
    print(res)
    if res.status == 0 then
        mp.commandv("rescan_external_files", "reselect")
        mp.msg.info("Subtitle download succeeded")
        mp.osd_message("Subtitle download succeeded")
    else
        mp.msg.warn("Subtitle download failed")
        mp.osd_message("Subtitle download failed")
    end
end

mp.add_key_binding("Alt+S", "auto_load_subs", load_sub_fn)
