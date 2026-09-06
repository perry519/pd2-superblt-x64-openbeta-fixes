local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

local fs_groupaistatebesiege_init = GroupAIStateBesiege.init
function GroupAIStateBesiege:init(...)
	fs_groupaistatebesiege_init(self, ...)
	self.fs_clbk_is_nav_seg_safe = callback(self, self, 'is_nav_seg_safe')
end

local fs_groupaistatebesiege_createobjectivefromgroupobjective = GroupAIStateBesiege._create_objective_from_group_objective
function GroupAIStateBesiege._create_objective_from_group_objective(grp_objective, ...)
	local objective = fs_groupaistatebesiege_createobjectivefromgroupobjective(grp_objective, ...)

	if objective and fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() then
		objective.fs_patchable = false
		if grp_objective.type ~= 'assault_area' then
			-- qued
		elseif grp_objective.moving_in or grp_objective.charge then
			objective.stance = 'cbt'
		elseif objective.type == 'phalanx' then
			-- qued
		elseif objective.path_style ~= 'coarse_complete' then
			-- qued
		elseif objective.path_data and objective.path_data[2] then
			objective.fs_patchable = true
		else
			objective.path_data = nil
			objective.path_style = nil
			objective.fs_patchable = true
		end
	end

	return objective
end

local fs_groupaistatebesiege_checkphalanxgrouphasspawned = GroupAIStateBesiege._check_phalanx_group_has_spawned
function GroupAIStateBesiege:_check_phalanx_group_has_spawned()
	if self._phalanx_spawn_group and self._phalanx_spawn_group.has_spawned then
		if not self._phalanx_spawn_group.set_to_phalanx_group_obj then
			for u_key, group_unit in pairs(self._phalanx_spawn_group.units) do
				if not alive(group_unit.unit) then
					if group_unit.tweak_table == 'phalanx_vip' then
						-- because sending the captain right into a killzone is always a good idea...
						self:phalanx_damage_reduction_disable()
						self:unregister_phalanx_vip()
						self._phalanx_spawn_group.units[u_key] = nil
						break
					end
				end
			end
		end
	end

	fs_groupaistatebesiege_checkphalanxgrouphasspawned(self)
end

GroupAIStateBesiege.register_criminal = GroupAIStateBase.register_criminal

local fs_groupaistatebesiege_setassaultobjectivetogroup = GroupAIStateBesiege._set_assault_objective_to_group
function GroupAIStateBesiege:_set_assault_objective_to_group(group, phase)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_groupaistatebesiege_setassaultobjectivetogroup(self, group, phase)
	end

	if not group.has_spawned then
		return
	end

	local phase_is_anticipation = phase == 'anticipation'
	local current_objective = group.objective
	local approach, open_fire, push, pull_back, charge
	local group_leader_u_key, group_leader_u_data = self._determine_group_leader(group.units)
	local tactics_map = group_leader_u_data and group_leader_u_data.tactics_map

	if tactics_map then
		if current_objective.tactic and not tactics_map[current_objective.tactic] then
			current_objective.tactic = nil
		end

		if tactics_map.deathguard and not phase_is_anticipation then
			if self.fs_has_crim_status then
				if current_objective.tactic == 'deathguard' then
					for u_key, u_data in pairs(self._char_criminals) do
						if u_data.status and current_objective.follow_unit == u_data.unit then
							local crim_nav_seg = u_data.tracker:nav_segment()
							if current_objective.area.nav_segs[crim_nav_seg] then
								return
							end
						end
					end
				end

				local closest_crim_u_data, closest_crim_dis_sq
				for u_key, u_data in pairs(self._char_criminals) do
					if u_data.status then
						local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)
						if closest_u_dis_sq and (not closest_crim_dis_sq or closest_u_dis_sq < closest_crim_dis_sq) then
							closest_crim_u_data = u_data
							closest_crim_dis_sq = closest_u_dis_sq
						end
					end
				end

				if closest_crim_u_data then
					local search_params = {
						id = 'GroupAI_deathguard',
						from_tracker = group_leader_u_data.unit:movement():nav_tracker(),
						to_tracker = closest_crim_u_data.tracker,
						access_pos = self._get_group_acces_mask(group)
					}
					local coarse_path = managers.navigation:search_coarse(search_params)
					if coarse_path then
						local grp_objective = {
							distance = 800,
							type = 'assault_area',
							attitude = 'engage',
							tactic = 'deathguard',
							moving_in = true,
							follow_unit = closest_crim_u_data.unit,
							area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
							coarse_path = coarse_path
						}
						group.is_chasing = true
						self:_set_objective_to_enemy_group(group, grp_objective)
						self:_voice_deathguard_start(group)
						return
					end
				end
			end
		elseif tactics_map.charge
			and not current_objective.moving_out
			and group.in_place_t
			and group.is_chasing
			and not current_objective.charge
			and (self._t - group.in_place_t > 15 or self._t - group.in_place_t > 4 and self._drama_data.amount <= tweak_data.drama.low)
			and next(current_objective.area.criminal.units)
		then
			charge = true
		end
	end

	local objective_area

	local obstructed_area = self:_chk_group_areas_tresspassed(group, phase ~= 'fade' and phase ~= 'break')
	if obstructed_area then
		if current_objective.moving_out then
			if not current_objective.open_fire then
				open_fire = true
			end
		elseif not current_objective.pushed or charge and not current_objective.charge then
			push = true
		end

	else
		local obstructed_path_index = self:_chk_coarse_path_obstructed(group)
		if obstructed_path_index then
			objective_area = self:get_area_from_nav_seg_id(current_objective.coarse_path[math.max(obstructed_path_index - 1, 1)][1])
			pull_back = true

		elseif not current_objective.moving_out then
			local has_criminals_close
			local group_in_place_t = group.in_place_t
			if group_in_place_t then -- if false, no need to eval has_criminals_close
				for area_id, neighbour_area in pairs(current_objective.area.neighbours) do
					if next(neighbour_area.criminal.units) then
						has_criminals_close = true
						break
					end
				end
			end

			if charge then
				push = true
			elseif not phase_is_anticipation and group_in_place_t and tactics_map and tactics_map.ranged_fire and fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() and self:fs_recent_target_activity(group, 10) then
				open_fire = true
			elseif not has_criminals_close or not group_in_place_t then
				approach = true
			elseif not phase_is_anticipation and not current_objective.open_fire then
				open_fire = true
			elseif not phase_is_anticipation and group_in_place_t and (group.is_chasing or not tactics_map or not tactics_map.ranged_fire or self._t - group_in_place_t > 15) then
				push = true
			elseif phase_is_anticipation and current_objective.open_fire then
				pull_back = true
			end
		end
	end

	objective_area = objective_area or current_objective.area

	if open_fire then
		local grp_objective = {
			attitude = 'engage',
			pose = 'stand',
			type = 'assault_area',
			stance = 'hos',
			open_fire = true,
			tactic = current_objective.tactic,
			area = obstructed_area or current_objective.area,
		}
		grp_objective.coarse_path = {{ grp_objective.area.pos_nav_seg, mvector3.copy(grp_objective.area.pos) }}
		self:_set_objective_to_enemy_group(group, grp_objective)
		self:_voice_open_fire_start(group)

	elseif approach or push then
		local go_ok = not push or group.in_place_t and self._t - group.in_place_t > 30
		if go_ok or group.fs_has_grenade then
			local assault_area, alternate_assault_area, alternate_assault_area_from, assault_path, alternate_assault_path
			local to_search_areas = {objective_area}
			local found_areas = {[objective_area] = 'init'}
			local group_access_pos = self._get_group_acces_mask(group)

			local verif_clbk = self.fs_clbk_is_nav_seg_safe
			if fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() then
				if tactics_map and tactics_map.shield then
					verif_clbk = nil
				end
			end

			repeat
				local search_area = table.remove(to_search_areas, 1)
				if next(search_area.criminal.units) then
					local assault_from_here = true
					if not push and tactics_map and tactics_map.flank and search_area ~= objective_area then
						local assault_from_area = found_areas[search_area]
						local cop_units = assault_from_area.police.units
						for u_key, u_data in pairs(cop_units) do
							local u_data_group = u_data.group
							if u_data_group and u_data_group ~= group and u_data_group.objective.type == 'assault_area' then
								assault_from_here = false
								if not alternate_assault_area or math.random() < 0.5 then
									local search_params = {
										id = 'GroupAI_assault',
										from_seg = current_objective.area.pos_nav_seg,
										to_seg = search_area.pos_nav_seg,
										access_pos = group_access_pos,
										verify_clbk = verif_clbk
									}
									alternate_assault_path = managers.navigation:search_coarse(search_params)
									if alternate_assault_path then
										self:_merge_coarse_path_by_area(alternate_assault_path)
										alternate_assault_area = search_area
										alternate_assault_area_from = assault_from_area
									end
								end
								found_areas[search_area] = nil
								break
							end
						end
					end

					if assault_from_here then
						local search_params = {
							id = 'GroupAI_assault',
							from_seg = current_objective.area.pos_nav_seg,
							to_seg = search_area.pos_nav_seg,
							access_pos = group_access_pos,
							verify_clbk = verif_clbk
						}
						assault_path = managers.navigation:search_coarse(search_params)
						if assault_path then
							self:_merge_coarse_path_by_area(assault_path)
							assault_area = search_area
							break
						end
					end

				else
					for other_area_id, other_area in pairs(search_area.neighbours) do
						if not found_areas[other_area] then
							table.insert(to_search_areas, other_area)
							found_areas[other_area] = search_area
						end
					end
				end
			until not to_search_areas[1]

			if not assault_area and alternate_assault_area then
				assault_area = alternate_assault_area
				found_areas[assault_area] = alternate_assault_area_from
				assault_path = alternate_assault_path
			end

			if assault_area and assault_path then
				local assault_area = push and assault_area or found_areas[assault_area] == 'init' and objective_area or found_areas[assault_area]
				local steps = #assault_path
				if steps > 2 and assault_area.nav_segs[assault_path[steps - 1][1]] then
					table.remove(assault_path)
				end

				local used_grenade
				if push then
					local detonate_pos
					if charge then
						for c_key, c_data in pairs(assault_area.criminal.units) do
							detonate_pos = c_data.unit:movement():m_pos()
							break
						end
					end

					local first_chk = math.random() < 0.5 and self._chk_group_use_flash_grenade or self._chk_group_use_smoke_grenade
					local second_chk = first_chk == self._chk_group_use_flash_grenade and self._chk_group_use_smoke_grenade or self._chk_group_use_flash_grenade
					used_grenade = first_chk(self, group, self._task_data.assault, detonate_pos)
					used_grenade = used_grenade or second_chk(self, group, self._task_data.assault, detonate_pos)
					if go_ok or used_grenade then
						self:_voice_move_in_start(group)
					end
				end

				if go_ok or used_grenade then
					local grp_objective = {
						type = 'assault_area',
						stance = 'hos',
						area = assault_area,
						coarse_path = assault_path,
						pose = push and 'crouch' or 'stand',
						attitude = push and 'engage' or 'avoid',
						moving_in = push and true or nil,
						open_fire = push or nil,
						pushed = push or nil,
						charge = charge,
						interrupt_dis = charge and 0 or nil
					}
					group.is_chasing = group.is_chasing or push
					self:_set_objective_to_enemy_group(group, grp_objective)
				end
			end
		end

	elseif pull_back then
		local retreat_area, do_not_retreat = nil
		for u_key, u_data in pairs(group.units) do
			local nav_seg_id = u_data.tracker:nav_segment()
			if current_objective.area.nav_segs[nav_seg_id] then
				retreat_area = current_objective.area
				break
			end

			if self:is_nav_seg_safe(nav_seg_id) then
				retreat_area = self:get_area_from_nav_seg_id(nav_seg_id)
				break
			end
		end

		if not retreat_area and not do_not_retreat and current_objective.coarse_path then
			local forwardmost_i_nav_point = self:_get_group_forwardmost_coarse_path_index(group)
			if forwardmost_i_nav_point then
				local nearest_safe_nav_seg_id = current_objective.coarse_path[forwardmost_i_nav_point][1]
				retreat_area = self:get_area_from_nav_seg_id(nearest_safe_nav_seg_id)
			end
		end

		if retreat_area then
			local new_grp_objective = {
				attitude = 'avoid',
				stance = 'hos',
				pose = 'crouch',
				type = 'assault_area',
				area = retreat_area,
				coarse_path = {{
					retreat_area.pos_nav_seg,
					mvector3.copy(retreat_area.pos)
				}}
			}
			group.is_chasing = nil
			self:_set_objective_to_enemy_group(group, new_grp_objective)
			return
		end
	end
end

local fs_groupaistatebesiege_chkgroupareastresspassed = GroupAIStateBesiege._chk_group_areas_tresspassed
function GroupAIStateBesiege:_chk_group_areas_tresspassed(group, all)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_groupaistatebesiege_chkgroupareastresspassed(self, group, all)
	end

	local processed_nav_segs = {}
	for _, u_data in pairs(group.units) do
		local nav_seg = u_data.tracker:nav_segment()
		if not processed_nav_segs[nav_seg] then
			local areas = self:get_areas_from_nav_seg_id(nav_seg)
			for _, area in ipairs(areas) do
				if all then
					if not self:is_area_safe(area) then
						return area
					end
				elseif next(area.criminal.units) then
					return area
				end
			end
		end
		processed_nav_segs[nav_seg] = true
	end
end
