local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

local fs_original_coplogictravel_tryanounce = CopLogicTravel._try_anounce
local fs_original_coplogictravel_queueupdate = CopLogicTravel.queue_update
local fs_original_coplogictravel_queuedupdate = CopLogicTravel.queued_update

local mvec3_dis_sq = mvector3.distance_sq
function CopLogicTravel._try_anounce(data, my_data)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogictravel_tryanounce(data, my_data)
	end

	local my_pos = data.m_pos
	local max_dis_sq = 250000
	local my_key = data.key
	local announce_type = data.char_tweak.announce_incomming
	local tdc = tweak_data.character
	for u_key, u_data in pairs(managers.enemy:fs_all_enemy_announcers()) do
		if u_key ~= my_key then
			if tdc[u_data.tweak_table].chatter[announce_type] then
				local unit = u_data.unit
				if max_dis_sq > mvec3_dis_sq(my_pos, u_data.m_pos) and not unit:sound():speaking(data.t) and (unit:anim_data().idle or unit:anim_data().move) then
					managers.groupai:state():chk_say_enemy_chatter(unit, u_data.m_pos, announce_type)
					my_data.announce_t = data.t + 15
				end
			end
		end
	end
end

function CopLogicTravel.queue_update(data, my_data, delay)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogictravel_queueupdate(data, my_data, delay)
	end

	if data.important or fs_settings.fastpaced and FullSpeedSwarm:allow_stealth_changes() then
		delay = 0.1
	else
		delay = delay or 0.3
	end
	CopLogicBase.queue_task(my_data, my_data.upd_task_key, CopLogicTravel.queued_update, data, data.t + delay, data.important and true)
end

function CopLogicTravel.queued_update(data)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogictravel_queuedupdate(data)
	end

	local delay
	local my_data = data.internal_data
	my_data.close_to_criminal = nil
	local t = TimerManager:game():time()
	data.t = t

	if fs_settings.fastpaced and FullSpeedSwarm:allow_stealth_changes() then
		local next_detection_t = data.fs_next_detection_t or 0
		if t >= next_detection_t then
			delay = CopLogicTravel._upd_enemy_detection(data)
			data.fs_next_detection_t = t + delay
		end
	else
		delay = CopLogicTravel._upd_enemy_detection(data)
	end

	if data.internal_data ~= my_data then
		return
	end

	CopLogicTravel.upd_advance(data)

	if data.internal_data ~= my_data then
		return
	end

	CopLogicTravel.queue_update(data, data.internal_data, delay)
end

local fs_original_coplogictravel_getexactmovepos = CopLogicTravel._get_exact_move_pos
function CopLogicTravel._get_exact_move_pos(data, nav_index)
	local my_data = data.internal_data
	if my_data.path_safely and fs_settings.improved_tactics and FullSpeedSwarm:allow_stealth_changes() then
		local coarse_path = my_data.coarse_path

		local objective = data.objective
		if objective and objective.fs_patchable and nav_index == my_data.coarse_path_index + 1 then
			local grp_objective = objective.grp_objective
			if grp_objective.type == 'retire' then
				if objective.stance == 'cbt' then
					objective.stance = nil
				end
			else
				local mov = data.fs_ext_movement
				if not mov:cool() then
					local cur_seg_is_dangerous = not managers.groupai:state():is_nav_seg_safe(mov:nav_tracker():nav_segment())
					objective.pose = cur_seg_is_dangerous and 'crouch' or 'stand'

					local next_seg = coarse_path[nav_index]
					local next_seg_is_dangerous = next_seg and next_seg[1] and not managers.groupai:state():is_nav_seg_safe(next_seg[1])

					if next_seg_is_dangerous then
						objective.fs_original_path_ahead = objective.path_ahead
						objective.path_ahead = true
						objective.stance = 'cbt'
						objective.fs_original_attitude = objective.attitude
						objective.attitude = 'engage'

						local upper_body_action = mov._active_actions[3]
						if not upper_body_action or upper_body_action:type() ~= 'shoot' then
							mov:set_stance(objective.stance, true)
						end

					else
						objective.stance = 'hos'
						if objective.fs_original_path_ahead ~= nil then
							objective.path_ahead = objective.fs_original_path_ahead
							objective.fs_original_path_ahead = nil
						end
						if objective.fs_original_attitude then
							objective.attitude = objective.fs_original_attitude
							objective.fs_original_attitude = nil
						end
					end
				end
			end
		end

		if nav_index < #coarse_path then
			if my_data.moving_to_cover then
				managers.navigation:release_cover(my_data.moving_to_cover[1])
				my_data.moving_to_cover = nil
			end

			local to_pos
			local nav_seg = coarse_path[nav_index][1]
			local area = managers.groupai:state():get_area_from_nav_seg_id(nav_seg)
			local cover = managers.navigation:find_cover_in_nav_seg_1(area.nav_segs)
			if cover then
				managers.navigation:reserve_cover(cover, data.pos_rsrv_id)
				my_data.moving_to_cover = {cover}
				to_pos = cover[1]
			else
				to_pos = CopLogicTravel._get_pos_on_wall(coarse_path[nav_index][2])
				data.brain:add_pos_rsrv('path', {
					radius = 60,
					position = mvector3.copy(to_pos)
				})
			end

			return to_pos
		end
	end

	return fs_original_coplogictravel_getexactmovepos(data, nav_index)
end
