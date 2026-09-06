local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

_G.FullSpeedSwarm = _G.FullSpeedSwarm or {}
FullSpeedSwarm._path = ModPath
FullSpeedSwarm._data_path = SavePath .. 'full_speed_swarm.txt'
FullSpeedSwarm.in_arrest_logic = {}
FullSpeedSwarm.units_per_navseg = {}
FullSpeedSwarm.call_on_loud = {}
FullSpeedSwarm.call_on_stealth = {}
FullSpeedSwarm.custom_mutators = {}
FullSpeedSwarm.final_settings = {}
FullSpeedSwarm.settings_not_saved = {
	'real_elastic',
	'stealthroids',
	'stealth_vanilla_detection',
	'stealthroids_loud_only'
}
FullSpeedSwarm.settings = {
	task_throughput = 600,

	lod_updater = 1,
	high_violence_mode = true,
	slower_but_safer = false, -- to be enabled in mods/saves/full_speed_swarm.txt
	walking_quality = 1,

	cop_awareness = false,
	cops_disable_bag_contour = false,
	disable_stealth_changes = true,
	eyes_wide_open = false,
	fastpaced = false,
	hostage_situation = true,
	improved_tactics = true,
	iter_chase = false,
	nervous_game = false,
	spawn_delay = true,
	tie_stamina_to_lives = false,

	real_elastic = false,
	stealthroids = false,
}

function FullSpeedSwarm:update_walking_quality()
	CopBase.fs_lod_stage = CopBase['fs_lod_stage_' .. self.settings.walking_quality]
end

local streamlined
function FullSpeedSwarm:get_gameplay_options_forced_values()
	local result = {}

	if streamlined == nil then
		streamlined = _G.Iter and _G.Iter.settings.streamline_path or streamlined or false
	end
	if not streamlined then
		result.iter_chase = false
		result.improved_tactics = false
	end

	if self.settings.real_elastic then
		result.cop_awareness = true
		result.cops_disable_bag_contour = true
		result.eyes_wide_open = true
		result.fastpaced = true
		result.hostage_situation = true
		result.improved_tactics = true
		result.iter_chase = true
		result.nervous_game = true
		result.tie_stamina_to_lives = true
	end

	if self.settings.stealthroids then
		result.iter_chase = true
	end

	if self.host_settings then
		for _, opt in pairs({
			'task_throughput',
			'cop_awareness',
			'cops_disable_bag_contour',
			'disable_stealth_changes',
			'eyes_wide_open',
			'fastpaced',
			'hostage_situation',
			'improved_tactics',
			'iter_chase',
			'nervous_game',
			'spawn_delay',
			'tie_stamina_to_lives'
		}) do
			if self.host_settings[opt] ~= nil then
				result[opt] = self.host_settings[opt]
			end
		end
	end

	return result
end

function FullSpeedSwarm:is_stealth_active()
	local state = managers and managers.groupai and managers.groupai:state()
	if not state then
		return false
	end
	if state.enemy_weapons_hot and state:enemy_weapons_hot() then
		return false
	end
	return state.whisper_mode and state:whisper_mode() or false
end

function FullSpeedSwarm:allow_stealth_changes()
	return not self.final_settings.disable_stealth_changes or not self:is_stealth_active()
end

local function _safe_unit_extension(unit, method)
	local ok, result = pcall(function()
		local f = unit and unit[method]
		return f and f(unit)
	end)
	if ok then
		return result
	end
end

function FullSpeedSwarm:ensure_attention_extensions(attention_data)
	local unit = attention_data and attention_data.unit
	if not unit then
		return attention_data
	end

	attention_data.fs_ext_animdata = attention_data.fs_ext_animdata or _safe_unit_extension(unit, 'anim_data')
	attention_data.fs_ext_base = attention_data.fs_ext_base or _safe_unit_extension(unit, 'base')
	attention_data.fs_ext_brain = attention_data.fs_ext_brain or _safe_unit_extension(unit, 'brain')
	attention_data.fs_ext_movement = attention_data.fs_ext_movement or _safe_unit_extension(unit, 'movement')
	attention_data.fs_ext_cdmg = attention_data.fs_ext_cdmg or _safe_unit_extension(unit, 'character_damage')
	return attention_data
end

function FullSpeedSwarm:refresh_mode_sensitive_state()
	local state = managers and managers.groupai and managers.groupai:state()
	if not state then
		self:update_max_task_throughput()
		return
	end

	if state.fs_refresh_attention_extensions then
		state:fs_refresh_attention_extensions()
	end
	if state.fs_reset_attention_lists then
		state:fs_reset_attention_lists()
	end

	local callbacks = self:is_stealth_active() and self.call_on_stealth or self.call_on_loud
	for _, fct in pairs(callbacks) do
		fct()
	end
end

function FullSpeedSwarm:calc_max_task_throughput()
	local gstate = managers and managers.groupai and managers.groupai:state()
	if not gstate or not gstate._tweak_data then
		return 600
	end

	local force = gstate:_get_difficulty_dependent_value(gstate._tweak_data.assault.force)
	local force_balance_mul = gstate._tweak_data.assault.force_balance_mul[4]
	local mul = self.final_settings.eyes_wide_open and self:allow_stealth_changes() and 10 or 7
	return math.ceil(force * force_balance_mul) * mul
end

function FullSpeedSwarm:update_max_task_throughput()
	local new_value = self.settings.task_throughput
	if self.final_settings.eyes_wide_open and self:allow_stealth_changes() or new_value < math.floor(1 / tweak_data.group_ai.ai_tick_rate) then
		new_value = self:calc_max_task_throughput()
	end
	if type(self.apply_max_task_throughput) == 'function' then
		self:apply_max_task_throughput(new_value)
	end
end

table.insert(FullSpeedSwarm.call_on_loud, function()
	FullSpeedSwarm:update_max_task_throughput()
end)
table.insert(FullSpeedSwarm.call_on_stealth, function()
	FullSpeedSwarm:update_max_task_throughput()
end)

function FullSpeedSwarm:finalize_settings()
	for k in pairs(self.final_settings) do
		self.final_settings[k] = nil
	end

	for k, v in pairs(self.settings) do
		self.final_settings[k] = v
	end

	for k, v in pairs(self:get_gameplay_options_forced_values()) do
		self.final_settings[k] = v
	end
end

function FullSpeedSwarm:load()
	local file = io.open(self._data_path, 'r')
	if file then
		for k, v in pairs(json.decode(file:read('*all')) or {}) do
			self.settings[k] = v
		end
		file:close()
	end

	for _, v in pairs(self.settings_not_saved) do
		self.settings[v] = nil
	end

	self:finalize_settings()
end

function FullSpeedSwarm:save()
	local settings = clone(self.settings)

	for _, v in pairs(self.settings_not_saved) do
		settings[v] = nil
	end

	local file = io.open(self._data_path, 'w+')
	if file then
		file:write(json.encode(settings))
		file:close()
	end
end

FullSpeedSwarm:load()
if Global.load_level and BLT:GetOS() == 'windows' then
	DelayedCalls:Add('DelayedFSS_jitune', 0, function()
		local jit = rawget(_G, 'jit')
		if jit and jit.opt and type(jit.opt.start) == 'function' then
			jit.opt.start('maxtrace=16384', 'maxrecord=32768', 'maxmcode=65536')
		end
	end)
end

function FullSpeedSwarm.metaize_i(tbl)
	local _i = { [0] = 0 }
	local mt = {
		__newindex = function (t, k, v)
			_i[0] = _i[0] + 1
			_i[_i[0]] = v
			rawset(t, k, v)
		end
	}
	setmetatable(tbl, mt)
	return _i
end

core:module('CoreCode')

if _G.FullSpeedSwarm.settings.slower_but_safer then
	function alive(obj)
		local tp = type(obj)
		if tp == 'userdata' or tp == 'table' and type(obj.alive) == 'function' then
			return obj:alive()
		end
		return false
	end
else
	function alive(obj)
		return obj and obj:alive()
	end
end
