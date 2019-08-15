-- deus0ww - 2019-07-01

local mp      = require 'mp'
local msg     = require 'mp.msg'



-- Show Finder
mp.register_script_message('ShowFinder', function()
	mp.command_native({'run', 'open', '-a', 'Finder'})
end)



-- Show File in Finder
mp.register_script_message('ShowInFinder', function()
	local path = mp.get_property_native('path', '')
	msg.debug('Show in Finder:', path)
	if path == '' then return end
	local cmd = {'open'}
	if path:find('http://') ~= nil or path:find('https://') ~= nil then
	elseif path:find('edl://') ~= nil then
		cmd[#cmd+1] = '-R'
		path = path:gsub('edl://', ''):gsub(';/', '" /"')
	elseif path:find('file://') ~= nil then
		cmd[#cmd+1] = '-R'
		path = path:gsub('file://', '')
	else
		cmd[#cmd+1] = '-R'
	end
	cmd[#cmd+1] = path
	mp.command_native( {name='subprocess', args=cmd} )
end)



-- Move to Trash -- Requires: https://github.com/ali-rantakari/trash
mp.register_script_message('MoveToTrash', function()
	local demux_state  = mp.get_property_native('demuxer-cache-state', {})
	local demux_ranges = demux_state['seekable-ranges'] and #demux_state['seekable-ranges'] or 1
	if demux_ranges > 0 then 
		mp.osd_message('Trashing not supported.')
		return
	end
	local path = mp.get_property_native('path', ''):gsub('edl://', ''):gsub(';/', '" /"')
	msg.debug('Moving to Trash:', path)
	if path and path ~= '' then
		mp.command_native({'run', 'trash', '-F', path})
		mp.osd_message('Trashed.')
	else
		mp.osd_message('Trashing failed.')
	end
end)



-- Open From Clipboard - One URL per line
mp.register_script_message('OpenFromClipboard', function()
	local osd_msg = 'Opening From Clipboard: '
	
	local success, result = pcall(io.popen, 'pbpaste')
	if not success or not result then 
		mp.osd_message(osd_msg .. 'n/a')
		return
	end
	local lines = {}
	for line in result:lines() do lines[#lines+1] = line end
	if #lines == 0 then
		mp.osd_message(osd_msg .. 'n/a')
		return
	end

	local mode = 'replace'
	for _, line in ipairs(lines) do
		msg.debug('loadfile', line, mode)
		mp.commandv('loadfile', line, mode)
		mode = 'append'
	end

	local msg = osd_msg
	if #lines > 0 then msg = msg .. '\n' .. lines[1] end
	if #lines > 1 then msg = msg .. (' ... and %d other URL(s).'):format(#lines-1) end
	mp.osd_message(msg, 6.0)
end)
