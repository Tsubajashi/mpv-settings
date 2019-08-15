-- deus0ww - 2019-07-06

local mp      = require 'mp'
local utils   = require 'mp.utils'

local filter_list = {}
local function add(filter) filter_list[#filter_list+1] = filter end

add({
	name = 'Format',
	filter_type = 'audio',
	default_on_load = true,
	reset_on_load = true,
	filters = {
		'format=doublep:srate=96000',
	},
})

add({
	name = 'DenoiseAudio',
	filter_type = 'audio',
	reset_on_load = true,
	filters = {
		'afftdn=nr=12:nf=-48',
		'afftdn=nr=18:nf=-42',
		'afftdn=nr=24:nf=-36',
		'afftdn=nr=30:nf=-36',
		'afftdn=nr=36:nf=-36',
	},
})

add({
	name = 'HighPass',
	filter_type = 'audio',
	reset_on_load = true,
	filters = {
		'highpass=frequency=100',
		'highpass=frequency=150',
		'highpass=frequency=200',
	},
})

add({
	name = 'LowPass',
	filter_type = 'audio',
	reset_on_load = true,
	filters = {
		'lowpass=frequency=7500',
		'lowpass=frequency=5000',
		'lowpass=frequency=2500',
	},
})

add({
	name = 'Compressor',
	filter_type = 'audio',
	reset_on_load = false,
	filters = {
		'compand=attacks=0.050:decays=0.300:soft-knee=8:points=-80/-80|-20/-20|020/0', --  2:1
		'compand=attacks=0.050:decays=0.300:soft-knee=8:points=-80/-80|-20/-20|060/0', --  4:1
		'compand=attacks=0.050:decays=0.300:soft-knee=8:points=-80/-80|-20/-20|140/0', --  8:1
		'compand=attacks=0.050:decays=0.300:soft-knee=8:points=-80/-80|-20/-20|300/0', -- 16:1
	},
})

add({
	name = 'Downmix',
	filter_type = 'audio',
	default_on_load = true,
	reset_on_load = false,
	filters = { -- -3dB=0.707, -6dB=0.500, -9dB=0.353, -12dB=0.250, -15dB=0.177
		'pan="stereo| FL < 0.707*FC + 1.000*FL + 0.500*SL + 0.500*BL + 0.500*LFE | FR < 0.707*FC + 1.000*FR + 0.500*SR + 0.500*BR + 0.500*LFE"',
		'pan="stereo| FL < 0.707*FC + 1.000*FL + 0.707*SL + 0.707*BL + 0.500*LFE | FR < 0.707*FC + 1.000*FR + 0.707*SR + 0.707*BR + 0.500*LFE"', -- ATSC + LFE
		'pan="stereo| FL < 0.707*FC + 1.000*FL + 0.707*SL + 0.707*BL + 0.000*LFE | FR < 0.707*FC + 1.000*FR + 0.707*SR + 0.707*BR + 0.000*LFE"', -- ATSC
		'pan="stereo| FL < 1.000*FC + 0.707*FL + 0.500*SL + 0.500*BL + 0.000*LFE | FR < 1.000*FC + 0.707*FR + 0.500*SR + 0.500*BR + 0.000*LFE"', -- Nightmode
		'sofalizer=sofa=/Users/Shared/Library/mpv/sofa/ClubFritz7.sofa:gain=12:type=freq:interpolate=yes',
	},
})

add({
	name = 'Normalize',
	filter_type = 'audio',
	filters = {
		-- 'dynaudnorm=f=250:g=11:m=12:p=0.8:r=0.8',
		'dynaudnorm=framelen=250:gausssize=11:maxgain=12:peak=0.8:targetrms=0.8'
	},
})

add({
	name = 'ExtraStereo',
	filter_type = 'audio',
	default_on_load = true,
	reset_on_load = true,
	filters = {
		'extrastereo=m=1.25',
		'extrastereo=m=1.50',
		'extrastereo=m=1.75',
		'extrastereo=m=2.00',
	},
})

add({
	name = 'ScaleTempo',
	filter_type = 'audio',
	filters = {
		'scaletempo=stride=9:overlap=0.9:search=28',
		'rubberband=pitch=quality:transients=crisp',
		'rubberband=pitch=quality:transients=smooth',
	},
})

mp.register_script_message('Filter_Registration_Request', function(origin)
	local filter_json, _ = utils.format_json(filter_list)
	mp.command_native({'script-message-to', origin, 'Filters_Registration', filter_json and filter_json or ''})
end)
