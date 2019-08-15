-- deus0ww - 2019-03-18

local mp      = require 'mp'
local msg     = require 'mp.msg'
local utils   = require 'mp.utils'

local function parse_json(json)
	local tab, err = utils.parse_json(json, true)
	if err then msg.error('Parsing JSON failed:', err) end
	if tab then return tab else return {} end
end

local filter_list = {}
local type_map    = { video = 'vf', audio = 'af' }
local defaults    = { default_on_load = false, reset_on_load = true }

local function show_status(filter, no_osd)
	mp.command_native_async({'script-message', filter.name .. (filter.enabled and '-enabled' or '-disabled')}, function()
		if not no_osd then
			local filter_string = filter.filters[filter.current_index]
			filter_string = filter_string:find('=') == nil and filter_string or filter_string:gsub('=', ' [', 1):gsub(':', ' ') .. ']'
			local index_string  = #filter.filters > 1 and (' %s'):format(filter.current_index) or ''
			mp.osd_message( ('%s %s%s:  %s'):format( (filter.enabled and '☑︎' or '☐'), filter.name, index_string, filter_string ) )
		end
	end)
end

local cmd = {
	enable  = function(filter) mp.command_native({type_map[filter.filter_type], 'add', ('@%s:%s' ):format(filter.name, filter.filters[filter.current_index])}) end,
	disable = function(filter) mp.command_native({type_map[filter.filter_type], 'add', ('@%s:!%s'):format(filter.name, filter.filters[filter.current_index])}) end,
	add     = function(filter) mp.command_native({type_map[filter.filter_type], 'add', ('@%s:!%s'):format(filter.name, filter.filters[filter.current_index])}) end,
	remove  = function(filter) mp.command_native({type_map[filter.filter_type], 'del', ('@%s'    ):format(filter.name)}) end,
	clear   = function() mp.set_property_native(type_map['audio'], {})
	                     mp.set_property_native(type_map['video'], {}) end,
}

local function apply_all()
	cmd.clear()
	filter_list.num_enabled = 0
	for i = 1, #filter_list do
		if filter_list[i].enabled then
			cmd.enable(filter_list[i])
			filter_list.num_enabled = filter_list.num_enabled + 1
		end
	end
end

local function cycle_filter_up(filter, no_osd)
	msg.debug('Filter - Up:', filter.name)
	filter.current_index = (filter.current_index % #filter.filters) + 1
	if filter.enabled then apply_all() end
	show_status(filter, no_osd)
end

local function cycle_filter_dn(filter, no_osd)
	msg.debug('Filter - Down:', filter.name)
	filter.current_index = ((filter.current_index - 2) % #filter.filters) + 1
	if filter.enabled then apply_all() end
	show_status(filter, no_osd)
end

local function toggle_filter(filter, no_osd)
	msg.debug('Filter - Toggling:', filter.name)
	if filter.current_index == 0 then filter.current_index = 1 end
	filter.enabled = not filter.enabled
	apply_all()
	show_status(filter, no_osd)
end

local function enable_filter(filter, no_osd)
	msg.debug('Filter - Enabling:', filter.name)
	filter.enabled = true
	apply_all()
	show_status(filter, no_osd)
end

local function disable_filter(filter, no_osd)
	msg.debug('Filter - Disabling:', filter.name)
	filter.enabled = false
	apply_all()
	show_status(filter, no_osd)
end

local function filter_status(filter, no_osd)
	mp.command_native_async({'script-message', filter.name .. '-state', filter.enabled and filter.filters[filter.current_index] or ''}, function() show_status(filter, no_osd) end)
end

local function register_filter(filter)
	if filter.default_on_load == nil then filter.default_on_load = defaults.default_on_load end
	if filter.reset_on_load   == nil then filter.reset_on_load   = defaults.reset_on_load   end
	filter.current_index = 1
	filter.enabled = filter.default_on_load
	table.insert(filter_list, filter)
	if filter.enabled then cmd.enable(filter) else cmd.add(filter) end
	mp.register_script_message(filter.name .. '-cycle+',  function(no_osd) cycle_filter_up(filter, no_osd == 'yes') end)
	mp.register_script_message(filter.name .. '-cycle-',  function(no_osd) cycle_filter_dn(filter, no_osd == 'yes') end)
	mp.register_script_message(filter.name .. '-toggle',  function(no_osd) toggle_filter(filter,   no_osd == 'yes') end)
	mp.register_script_message(filter.name .. '-enable',  function(no_osd) enable_filter(filter,   no_osd == 'yes') end)
	mp.register_script_message(filter.name .. '-disable', function(no_osd) disable_filter(filter,  no_osd == 'yes') end)
	mp.register_script_message(filter.name .. '-status',  function(no_osd) filter_status(filter,   no_osd == 'yes') end)
	msg.debug('Filter Registration:', filter.name)
end

mp.register_event('file-loaded', function()
	msg.debug('Setting Filters on File Load...')
	for _, filter in ipairs(filter_list) do
		if filter.reset_on_load then
			filter.enabled = filter.default_on_load
			filter.current_index = filter.default_index and filter.default_index or 1
		end
	end
	apply_all()
end)

mp.register_event('playback-restart', function()
	if filter_list.num_enabled ~= #mp.get_property_native('vf', {}) + #mp.get_property_native('af', {}) then 
		msg.debug('Playback-Restart - Number of fitlers changed. Resetting...')
		apply_all()
	else
		msg.debug('Playback-Restart - Filters are OK.')
	end
end)

mp.register_script_message('Filter_Registration', function(json)
	if not json then return end
	register_filter(parse_json(json))
end)

mp.register_script_message('Filters_Registration', function(json)
	if not json then return end
	local filters = parse_json(json)
	for _, filter in ipairs (filters) do
		register_filter(filter)
	end
end)

mp.command_native({'script-message', 'Filter_Registration_Request', mp.get_script_name()})
