local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local _is_loud
local fs_settings = FullSpeedSwarm.final_settings

local fs_original_groupaistatebase_onaiattentionchanged = GroupAIStateBase.on_AI_attention_changed
local fs_original_groupaistatebase_getaiattentionobjectsbyfilter = GroupAIStateBase.get_AI_attention_objects_by_filter
local fs_original_groupaistatebase_chkenemycallinginarea = GroupAIStateBase.chk_enemy_calling_in_area
local fs_original_groupaistatebase_criminalspotted = GroupAIStateBase.criminal_spotted
local fs_original_groupaistatebase_setimportanceweight = GroupAIStateBase.set_importance_weight

function GroupAIStateBase:is_ecm_jammer_active(medium)
	local jammers = self._ecm_jammers
	local cache = self.fs_ecm_jammer_cache
	-- Validate the hint against live storage, including resets and in-place settings changes.
	if cache then
		local data = jammers[cache[medium]]
		if data and data.settings[medium] then
			return true
		end
	elseif next(jammers) == nil then
		return
	end

	for unit_key, jammer in pairs(jammers) do
		if jammer.settings[medium] then
			if not cache then
				cache = {}
				self.fs_ecm_jammer_cache = cache
			end
			cache[medium] = unit_key
			return true
		end
	end
end

local fs_groupaistatebase_initmiscdata = GroupAIStateBase._init_misc_data
function GroupAIStateBase:_init_misc_data()
	self.fs_attention_objects_i = {all = {}}
	fs_groupaistatebase_initmiscdata(self)
end

local fs_groupaistatebase_setdifficulty = GroupAIStateBase.set_difficulty
function GroupAIStateBase:set_difficulty(...)
	fs_groupaistatebase_setdifficulty(self, ...)
	DelayedCalls:Add('DelayedModFSS_setdifficulty', 0, function()
		FullSpeedSwarm:update_max_task_throughput()
	end)
end

local fs_groupaistatebase_converthostagetocriminal = GroupAIStateBase.convert_hostage_to_criminal
function GroupAIStateBase:convert_hostage_to_criminal(unit, ...)
	local ret = fs_groupaistatebase_converthostagetocriminal(self, unit, ...)
	self:on_AI_attention_changed(unit:key())
	return ret
end

local fs_original_groupaistatebase_onenemyweaponshot = GroupAIStateBase.on_enemy_weapons_hot
function GroupAIStateBase:on_enemy_weapons_hot(...)
	local enemy_weapons_hot = self._enemy_weapons_hot

	fs_original_groupaistatebase_onenemyweaponshot(self, ...)
	_is_loud = true
	if not enemy_weapons_hot then
		self:fs_refresh_attention_extensions()
		self:fs_reset_attention_lists()
		for _, fct in pairs(FullSpeedSwarm.call_on_loud) do
			fct()
		end
	end
end

local fs_original_groupaistatebase_setwhispermode = GroupAIStateBase.set_whisper_mode
function GroupAIStateBase:set_whisper_mode(enabled, ...)
	local was_enabled = self._whisper_mode
	local result = fs_original_groupaistatebase_setwhispermode(self, enabled, ...)

	if enabled ~= was_enabled then
		self:fs_reset_attention_lists()
		local callbacks = enabled and FullSpeedSwarm.call_on_stealth or FullSpeedSwarm.call_on_loud
		for _, fct in pairs(callbacks) do
			fct()
		end
	end

	return result
end

function GroupAIStateBase:fs_reset_attention_lists()
	if not self._attention_objects or not self.fs_attention_objects_i then
		return
	end

	for k in pairs(self._attention_objects) do
		if k ~= 'all' then
			self._attention_objects[k] = nil
		end
	end

	for k in pairs(self.fs_attention_objects_i) do
		if k ~= 'all' then
			self.fs_attention_objects_i[k] = nil
		end
	end
end

local function _refresh_detected_attention_extensions(unit)
	local ok, brain = pcall(function()
		return alive(unit) and unit:brain()
	end)
	local logic_data = ok and brain and brain._logic_data
	local detected_attention_objects = logic_data and logic_data.detected_attention_objects
	if detected_attention_objects then
		for _, attention_data in pairs(detected_attention_objects) do
			FullSpeedSwarm:ensure_attention_extensions(attention_data)
		end
	end
end

function GroupAIStateBase:fs_refresh_attention_extensions()
	local all_attention_objects = self._attention_objects and self._attention_objects.all
	if all_attention_objects then
		for _, attention_info in pairs(all_attention_objects) do
			FullSpeedSwarm:ensure_attention_extensions(attention_info)
		end
	end

	for _, data in pairs(self._police or {}) do
		_refresh_detected_attention_extensions(data.unit)
	end

	for _, record in pairs(self._criminals or {}) do
		_refresh_detected_attention_extensions(record.unit)
	end
end

local _cop_ctgs = {}
local function _build_cop_ctgs()
	for name, data in pairs(tweak_data.character) do
		if type(data) == 'table' and type(data.tags) == 'table' then
			if table.contains(data.tags, 'law') then
				_cop_ctgs[name] = true
			end
		end
	end
end
_build_cop_ctgs()
DelayedCalls:Add('DelayedModFSS_buildcopctgs', 0, function()
	-- Do it again in case another mod added new cop types
	_build_cop_ctgs()
end)

local function _requires_attention(cat_filter, att_info)
	if not att_info then
		return false
	end

	local u_base = att_info.fs_ext_base
	if not u_base then
		return not _is_loud
	end

	if _is_loud then
		if not att_info.nav_tracker then
			return false

		else
			local slot = att_info.unit:slot()
			if slot == 17 or slot == 0 then -- cold meat
				return false
			end
			if cat_filter == 'teamAI1' then
				if slot == 12 or slot == 33 then -- enemies
					return true
				elseif slot == 21 or slot == 22 then -- civilians 21, hostages 22
					return false
				elseif slot == 2 then -- local player
					local cdmg = att_info.fs_ext_cdmg
					return cdmg and cdmg.need_revive and cdmg:need_revive() or false
				elseif slot == 3 then -- husk player
					local movement = att_info.fs_ext_movement
					return movement and movement.need_revive and movement:need_revive() or false
				elseif u_base._type == 'swat_turret' then
					return true
				end

			elseif _cop_ctgs[cat_filter] then
				if slot ~= 16 and _cop_ctgs[u_base._tweak_table] then -- cops minus jokers
					return false
				elseif slot == 21 or slot == 22 then
					return false
				end

			elseif cat_filter == 'gangster' then
				if slot == 21 or slot == 22 then
					return false
				end

			elseif cat_filter:sub(1, 3) == 'civ' then
				return slot == 2 or slot == 3 or slot == 16
			end
		end

	elseif cat_filter == 'teamAI1' then
		local u_mov = att_info.fs_ext_movement
		if u_mov and u_mov._cool then
			if CopDamage.is_civilian(u_base._tweak_table) then
				return false
			end
			return CrewAbilitySpotter and managers.player:has_category_upgrade('team', CrewAbilitySpotter.ability_name)
		end
	elseif u_base.is_local_player or u_base.is_husk_player then
		return true
	elseif u_base.security_camera then
		return u_base._destroyed
	elseif att_info.fs_ext_cdmg and att_info.fs_ext_cdmg:dead() then
		return true
	elseif att_info.fs_ext_movement then
		return not att_info.fs_ext_movement._cool
	end

	return true
end

function GroupAIStateBase:register_AI_attention_object(unit, handler, nav_tracker, team, SO_access)
	local unit_key = unit:key()
	self._attention_objects.all[unit_key] = {
		fs_ext_animdata = unit:anim_data(),
		fs_ext_base = unit:base(),
		fs_ext_brain = unit:brain(),
		fs_ext_movement = unit:movement(),
		fs_ext_cdmg = unit:character_damage(),
		unit_key = unit_key,
		unit = unit,
		handler = handler,
		nav_tracker = nav_tracker,
		team = team,
		SO_access = SO_access
	}
	self:on_AI_attention_changed(unit_key)
end

local function _remove_attinfo_from_list_i(list, unit_key)
	local nr = #list
	for i = nr, 1, -1 do
		local att_info = list[i]
		if att_info.unit_key == unit_key then
			local last = table.remove(list)
			if i < nr then
				list[i] = last
			end
			return
		end
	end
end

local _cf = {}
function GroupAIStateBase:on_AI_attention_changed(unit_key)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_groupaistatebase_onaiattentionchanged(self, unit_key)
	end

	local attention_objects = self._attention_objects
	local attention_objects_i = self.fs_attention_objects_i
	local att_info = attention_objects.all[unit_key]
	local att_handler
	if att_info then
		att_handler = att_info.handler
		att_handler.rel_cache = {}
	end

	local navigation = managers.navigation
	for cat_filter, list in pairs(attention_objects) do
		if cat_filter ~= 'all' then
			local list_i = attention_objects_i[cat_filter]
			if not list_i then
				list_i = {}
				for _, existing_att_info in pairs(list) do
					table.insert(list_i, existing_att_info)
				end
				attention_objects_i[cat_filter] = list_i
			end

			_cf[1] = cat_filter
			if att_handler and _requires_attention(cat_filter, att_info) and att_handler:get_attention(navigation:convert_access_filter_to_number(_cf)) then
				if not list[unit_key] then
					table.insert(list_i, att_info)
					list[unit_key] = att_info
				end
			else
				list[unit_key] = nil
				if list_i then
					_remove_attinfo_from_list_i(list_i, unit_key)
				end
			end
		end
	end
end

function GroupAIStateBase:unregister_AI_attention_object(unit_key)
	local attention_objects_i = self.fs_attention_objects_i
	for cat_filter, list in pairs(self._attention_objects) do
		if list[unit_key] then
			local list_i = attention_objects_i[cat_filter]
			if list_i then
				_remove_attinfo_from_list_i(list_i, unit_key)
			end
			list[unit_key] = nil
		end
	end
end

function GroupAIStateBase:fs_create_AI_attention_objects_by_filter(filter)
	_cf[1] = filter
	local filter_num = managers.navigation:convert_access_filter_to_number(_cf)
	local result = {}
	local result_i = {}
	for u_key, attention_info in pairs(self._attention_objects.all) do
		if attention_info.handler:get_attention(filter_num) then
			if _requires_attention(filter, attention_info) then
				result[u_key] = attention_info
				table.insert(result_i, attention_info)
			end
		end
	end
	return result, result_i
end

function GroupAIStateBase:get_AI_attention_objects_by_filter(filter, team)
	if not FullSpeedSwarm:allow_stealth_changes() then
		if self.fs_attention_objects_i and self.fs_attention_objects_i[filter] then
			self._attention_objects[filter] = nil
			self.fs_attention_objects_i[filter] = nil
		end
		return fs_original_groupaistatebase_getaiattentionobjectsbyfilter(self, filter)
	end

	local real_filter = team and team.id == 'converted_enemy' and 'teamAI1' or filter

	local result = self._attention_objects[real_filter]
	if not result then
		local list, list_i = self:fs_create_AI_attention_objects_by_filter(real_filter)
		self._attention_objects[real_filter] = list
		self.fs_attention_objects_i[real_filter] = list_i
		result = list
	end

	return result
end

function GroupAIStateBase:get_AI_attention_objects_by_filter_i(filter, team)
	if not FullSpeedSwarm:allow_stealth_changes() then
		if self.fs_attention_objects_i and self.fs_attention_objects_i[filter] then
			self._attention_objects[filter] = nil
			self.fs_attention_objects_i[filter] = nil
		end
		local result = {}
		for _, attention_info in pairs(fs_original_groupaistatebase_getaiattentionobjectsbyfilter(self, filter)) do
			table.insert(result, attention_info)
		end
		return result
	end

	local real_filter = team and team.id == 'converted_enemy' and 'teamAI1' or filter

	local result = self.fs_attention_objects_i[real_filter]
	if not result then
		local list, list_i = self:fs_create_AI_attention_objects_by_filter(real_filter)
		self._attention_objects[real_filter] = list
		self.fs_attention_objects_i[real_filter] = list_i
		result = list_i
	end

	return result
end

function GroupAIStateBase:fs_destroy_attention_object(unit_key)
	for _, data in pairs(self._police) do
		local logic_data = data.unit:brain()._logic_data
		local attention_info2 = logic_data.detected_attention_objects[unit_key]
		if attention_info2 then
			CopLogicBase._destroy_detected_attention_object_data(logic_data, attention_info2)
			if logic_data.attention_obj and logic_data.attention_obj.u_key == unit_key then
				CopLogicBase._set_attention_obj(logic_data, nil, nil)
			end
		end
	end
end

function GroupAIStateBase.on_unit_detection_updated()
	-- qued
end

function GroupAIStateBase:chk_enemy_calling_in_area(area, except_key)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_groupaistatebase_chkenemycallinginarea(self, area, except_key)
	end

	local area_nav_segs = area.nav_segs
	for _, unit_key in ipairs(FullSpeedSwarm.in_arrest_logic) do
		if unit_key ~= except_key then
			local u_data = self._police[unit_key]
			if u_data and area_nav_segs[u_data.tracker:nav_segment()] then
				return true
			end
		end
	end
end

function GroupAIStateBase:criminal_spotted(unit)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_groupaistatebase_criminalspotted(self, unit)
	end

	local u_key = unit:key()
	local u_sighting = self._criminals[u_key]
	if u_sighting.det_t == self._t then
		return
	end

	local prev_area = u_sighting.area
	local seg = u_sighting.tracker:nav_segment()
	u_sighting.undetected = nil
	u_sighting.seg = seg
	u_sighting.tracker:m_position(u_sighting.pos)
	u_sighting.det_t = self._t

	local area
	if prev_area and prev_area.nav_segs[seg] then
		area = prev_area
	else
		area = self:get_area_from_nav_seg_id(seg)
	end

	if prev_area ~= area then
		u_sighting.area = area
		if prev_area then
			prev_area.criminal.units[u_key] = nil
		end
		area.criminal.units[u_key] = u_sighting
	end

	if area.is_safe then
		area.is_safe = nil
		self:_on_area_safety_status(area, {reason = 'criminal', record = u_sighting})
	end
end

local fs_original_groupaistatebase_creategroup = GroupAIStateBase._create_group
function GroupAIStateBase:_create_group(...)
	local result = fs_original_groupaistatebase_creategroup(self, ...)
	result.fs_attention_obj_aware_t = {}
	return result
end

function GroupAIStateBase:fs_recent_target_activity(group, threshold_t)
	local t = self._t - threshold_t
	for _, ti in pairs(group.fs_attention_obj_aware_t) do
		if ti > t then
			return true
		end
	end
	return false
end

local table_insert = table.insert
function GroupAIStateBase:set_importance_weight(u_key, wgt_report)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_groupaistatebase_setimportanceweight(self, u_key, wgt_report)
	end

	local max_nr_imp = self._nr_important_cops
	local imp_adj = 0
	local criminals = self._player_criminals

	for i_dis_rep = #wgt_report - 1, 1, -2 do
		local c_record = criminals[wgt_report[i_dis_rep]]
		local c_dis = wgt_report[i_dis_rep + 1]
		local imp_enemies = c_record.important_enemies
		local imp_dis = c_record.important_dis
		-- original function sorts the tables by distance but it does not seem to be useful anywhere
		local max_dis = -1
		local max_i = 1

		local imp_enemies_nr = #imp_enemies
		for i = 1, imp_enemies_nr do
			if imp_enemies[i] == u_key then
				imp_dis[i] = c_dis
				max_i = nil
				break
			else
				local imp_dis_i = imp_dis[i]
				if imp_dis_i > max_dis then
					max_dis = imp_dis_i
					max_i = i
				end
			end
		end

		if max_i then
			if imp_enemies_nr < max_nr_imp then
				table_insert(imp_enemies, u_key)
				table_insert(imp_dis, c_dis)
				imp_adj = imp_adj + 1
			elseif max_dis > c_dis then
				self:_adjust_cop_importance(imp_enemies[max_i], -1)
				imp_enemies[max_i] = u_key
				imp_dis[max_i] = c_dis
				imp_adj = imp_adj + 1
			end
		end
	end

	if imp_adj ~= 0 then
		self:_adjust_cop_importance(u_key, imp_adj)
	end
end

local _fs_cache_areas_from_nav_seg_id = {}

local fs_original_groupaistatebase_addarea = GroupAIStateBase.add_area
function GroupAIStateBase:add_area(...)
	_fs_cache_areas_from_nav_seg_id = {}
	return fs_original_groupaistatebase_addarea(self, ...)
end

local fs_original_groupaistatebase_createareadata = GroupAIStateBase._create_area_data
function GroupAIStateBase:_create_area_data()
	_fs_cache_areas_from_nav_seg_id = {}
	fs_original_groupaistatebase_createareadata(self)
end

local fs_original_groupaistatebase_onnavsegmentstatechange = GroupAIStateBase.on_nav_segment_state_change
function GroupAIStateBase:on_nav_segment_state_change(...)
	_fs_cache_areas_from_nav_seg_id = {}
	fs_original_groupaistatebase_onnavsegmentstatechange(self, ...)
end

local fs_original_groupaistatebase_getareasfromnavsegid = GroupAIStateBase.get_areas_from_nav_seg_id
function GroupAIStateBase:get_areas_from_nav_seg_id(nav_seg_id)
	local areas = _fs_cache_areas_from_nav_seg_id[nav_seg_id]

	if not areas then
		areas = fs_original_groupaistatebase_getareasfromnavsegid(self, nav_seg_id)
		_fs_cache_areas_from_nav_seg_id[nav_seg_id] = areas
	end

	return areas
end

local fs_original_groupaistatebase_onhostagestate = GroupAIStateBase.on_hostage_state
function GroupAIStateBase:on_hostage_state(state, key, ...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_groupaistatebase_onhostagestate(self, state, key, ...)
	end

	fs_original_groupaistatebase_onhostagestate(self, state, key, ...)

	local attention_data = self._attention_objects.all[key]
	local unit = attention_data and attention_data.unit
	if alive(unit) then
		local base = unit:base()
		local movement = unit:movement()
		local char_tweak = base and tweak_data.character[base._tweak_table]
		if movement then
			movement.move_speed_multiplier = state and char_tweak and char_tweak.hostage_move_speed or 1
			local net_events = HuskCopBrain._NET_EVENTS
			managers.network:session():send_to_peers_synched('sync_unit_event_id_16', unit, 'brain', state and net_events.hostage_on or net_events.hostage_off)
		end
	end
end

local fs_original_groupaistatebase_synchostageheadcount = GroupAIStateBase.sync_hostage_headcount
function GroupAIStateBase:sync_hostage_headcount(...)
	managers.player:reset_cached_hostage_bonus_multiplier()
	fs_original_groupaistatebase_synchostageheadcount(self, ...)
end

if Network:is_server() then
	local fs_original_groupaistatebase_oncriminaldisabled = GroupAIStateBase.on_criminal_disabled
	function GroupAIStateBase:on_criminal_disabled(unit, ...)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_groupaistatebase_oncriminaldisabled(self, unit, ...)
		end

		self:on_AI_attention_changed(unit:key())
		fs_original_groupaistatebase_oncriminaldisabled(self, unit, ...)
	end

	local fs_original_groupaistatebase_oncriminalneutralized = GroupAIStateBase.on_criminal_neutralized
	function GroupAIStateBase:on_criminal_neutralized(unit)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_groupaistatebase_oncriminalneutralized(self, unit)
		end

		self:on_AI_attention_changed(unit:key())
		fs_original_groupaistatebase_oncriminalneutralized(self, unit)
	end

	local fs_original_groupaistatebase_oncriminalrecovered = GroupAIStateBase.on_criminal_recovered
	function GroupAIStateBase:on_criminal_recovered(criminal_unit)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_groupaistatebase_oncriminalrecovered(self, criminal_unit)
		end

		self:on_AI_attention_changed(criminal_unit:key())
		fs_original_groupaistatebase_oncriminalrecovered(self, criminal_unit)
	end

	local fs_original_groupaistatebase_checkgameoverconditions = GroupAIStateBase.check_gameover_conditions
	function GroupAIStateBase:check_gameover_conditions()
		local result = fs_original_groupaistatebase_checkgameoverconditions(self)
		self.fs_has_crim_status = false
		for _, u_data in pairs(self._char_criminals) do
			if u_data.status then
				self.fs_has_crim_status = true
				break
			end
		end
		return result
	end
end

if Network:is_server() then
	FullSpeedSwarm.delayed_spawn_groups = {}
	local delayed_spawn_groups = FullSpeedSwarm.delayed_spawn_groups

	local fs_original_groupaistatebase_oncriminalnavsegchange = GroupAIStateBase.on_criminal_nav_seg_change
	function GroupAIStateBase:on_criminal_nav_seg_change(unit, nav_seg_id)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_groupaistatebase_oncriminalnavsegchange(self, unit, nav_seg_id)
		end

		fs_original_groupaistatebase_oncriminalnavsegchange(self, unit, nav_seg_id)

		local to_remove = {}
		for sg_data in pairs(delayed_spawn_groups) do
			local area = self._area_data[sg_data.fs_attacker_area_id]
			if area and table.size(area.criminal.units) == 0 then
				if sg_data.fs_no_delay_t and sg_data.delay_t > self._t then
					sg_data.delay_t = sg_data.fs_no_delay_t
				end
				sg_data.fs_no_delay_t = nil
				table.insert(to_remove, sg_data)
			end
		end
		for _, sg_data in ipairs(to_remove) do
			delayed_spawn_groups[sg_data] = nil
		end
	end

	local fs_original_groupaistatebase_isareasafe = GroupAIStateBase.is_area_safe
	function GroupAIStateBase:is_area_safe(area)
		if _is_loud and fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() then
			if area.fs_unsafe_till_t and self._t < area.fs_unsafe_till_t then
				return
			end
			for _, record in pairs(self._criminals) do
				if not record.undetected and area.nav_segs[record.tracker:nav_segment()] then
					return
				end
			end
			return true
		end
		return fs_original_groupaistatebase_isareasafe(self, area)
	end

	local fs_original_groupaistatebase_onenemyunregistered = GroupAIStateBase.on_enemy_unregistered
	function GroupAIStateBase:on_enemy_unregistered(unit)
		fs_original_groupaistatebase_onenemyunregistered(self, unit)

		if fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() and unit:character_damage():dead() then
			local mov = unit:movement()
			local nav_seg = mov.fs_death_navseg or mov:nav_tracker():nav_segment()
			local area = self:get_area_from_nav_seg_id(nav_seg)
			local tda = self._tweak_data.assault
			local force = 80 / (self:_get_difficulty_dependent_value(tda.force) * self:_get_balancing_multiplier(tda.force_balance_mul))
			if not area.fs_unsafe_till_t or self._t > area.fs_unsafe_till_t then
				area.fs_unsafe_till_t = self._t + 5 * force
			else
				area.fs_unsafe_till_t = math.min(area.fs_unsafe_till_t + 7 * force, self._t + 60)
			end
			managers.navigation._nav_segments[nav_seg].fs_unsafe_till_t = area.fs_unsafe_till_t
		end

		if fs_settings.spawn_delay and FullSpeedSwarm:allow_stealth_changes() then
			local e_data = self._police[unit:key()]
			if e_data.assigned_area and unit:character_damage():dead() then
				local u_data = unit:unit_data()
				local spawn_point = u_data.mission_element
				if spawn_point then
					local spawn_pos = spawn_point:value('position')
					local u_pos = e_data.m_pos
					if u_data.fs_attacker_pos and mvector3.distance(u_data.fs_attacker_pos, u_pos) < 1000 then
						if mvector3.distance(spawn_pos, u_pos) < 700 and math.abs(spawn_pos.z - u_pos.z) < 300 then
							for _, area_data in pairs(self._area_data) do
								local area_spawn_groups = area_data.spawn_groups
								if area_spawn_groups then
									for _, sg_data in ipairs(area_spawn_groups) do
										if sg_data.spawn_pts then
											local spawn_point_id = spawn_point._id
											for _, sp in ipairs(sg_data.spawn_pts) do
												if sp.mission_element._id == spawn_point_id then
													local delay = math.random(10, 20)
													local delay_t = self._t + delay
													if delay_t > sg_data.delay_t then
														local seg_id = managers.navigation:get_nav_seg_from_pos(u_data.fs_attacker_pos, true)
														local area = managers.groupai:state():get_area_from_nav_seg_id(seg_id)
														sg_data.fs_attacker_area_id = area.id
														sg_data.fs_no_delay_t = sg_data.delay_t
														sg_data.delay_t = delay_t
														delayed_spawn_groups[sg_data] = true
													end
													return
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local fs_original_groupaistatebase_spawnoneteamai = GroupAIStateBase.spawn_one_teamAI
	function GroupAIStateBase:spawn_one_teamAI(...)
		FullSpeedSwarm.tmp_spawn_one_teamAI = self:whisper_mode()
		local result = fs_original_groupaistatebase_spawnoneteamai(self, ...)
		FullSpeedSwarm.tmp_spawn_one_teamAI = nil
		return result
	end
end

function GroupAIStateBase:fs_update_group_grenade_ability(group)
	local has_grenade = false
	for _, u_data in pairs(group.units) do
		local tactics_map = u_data.tactics_map
		if tactics_map then
			if tactics_map.flash_grenade or tactics_map.smoke_grenade then
				has_grenade = true
				break
			end
		end
	end
	group.fs_has_grenade = has_grenade
end

fs_original_groupaistatebase_addgroupmember = fs_original_groupaistatebase_addgroupmember or GroupAIStateBase._add_group_member
function GroupAIStateBase:_add_group_member(group, ...)
	fs_original_groupaistatebase_addgroupmember(self, group, ...)
	self:fs_update_group_grenade_ability(group)
end

fs_original_groupaistatebase_removegroupmember = fs_original_groupaistatebase_removegroupmember or GroupAIStateBase._remove_group_member
function GroupAIStateBase:_remove_group_member(group, ...)
	local result = fs_original_groupaistatebase_removegroupmember(self, group, ...)
	if not result then
		self:fs_update_group_grenade_ability(group)
	end
	return result
end
