local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local alive = alive
local math_abs = math.abs
local math_clamp = math.clamp
local math_lerp = math.lerp
local math_min = math.min
local math_random = math.random
local math_UP = math.UP

local mvec3_add = mvector3.add
local mvec3_ang = mvector3.angle
local mvec3_cpy = mvector3.copy
local mvec3_crs = mvector3.cross
local mvec3_dir = mvector3.direction
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_dot = mvector3.dot
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set
local mvec3_set_len = mvector3.set_length
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_z = mvector3.z

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

local REACT_SHOOT = AIAttentionObject.REACT_SHOOT
local REACT_SUSPICIOUS = AIAttentionObject.REACT_SUSPICIOUS
local REACT_COMBAT = AIAttentionObject.REACT_COMBAT
local REACT_SCARED = AIAttentionObject.REACT_SCARED
local REACT_ARREST = AIAttentionObject.REACT_ARREST
local REACT_MIN = AIAttentionObject.REACT_MIN
local REACT_MAX = AIAttentionObject.REACT_MAX

local World = World
local CopLogicBase = CopLogicBase
local default_crouched_head_translation = tweak_data.player.stances.default.crouched.head.translation

local fs_settings = FullSpeedSwarm.final_settings
local fs_original_coplogicbase_updattentionobjdetection = CopLogicBase._upd_attention_obj_detection
local fs_original_coplogicbase_onattentionobjidentified = CopLogicBase.on_attention_obj_identified
local fs_original_coplogicbase_getlogicstatefromreaction = CopLogicBase._get_logic_state_from_reaction
local fs_original_coplogicbase_setattentionobj = CopLogicBase._set_attention_obj
local fs_original_coplogicbase_queuetask = CopLogicBase.queue_task
local fs_original_coplogicbase_cancelqueuedtasks = CopLogicBase.cancel_queued_tasks
local fs_original_coplogicbase_unqueuetask = CopLogicBase.unqueue_task
local fs_original_coplogicbase_chkunqueuetask = CopLogicBase.chk_unqueue_task
local fs_original_coplogicbase_onqueuedtask = CopLogicBase.on_queued_task
local fs_original_coplogicbase_createdetectedattentionobjectdata = CopLogicBase._create_detected_attention_object_data

local function _angle_chk(attention_pos, dis, strictness, my_pos, my_head_fwd, my_data_detection)
	mvec3_dir(tmp_vec1, my_pos, attention_pos)
	local angle = mvec3_ang(my_head_fwd, tmp_vec1)
	local angle_max = math_lerp(180, my_data_detection.angle_max, math_clamp((dis - 150) / 700, 0, 1))
	return angle_max > angle * strictness
end

local function _angle_and_dis_chk(attention_pos, settings, my_pos, my_head_fwd, my_data_detection)
	local dis = mvec3_dir(tmp_vec1, my_pos, attention_pos)

	local settings_uncover_range = settings.uncover_range
	local my_data_detection_use_uncover_range
	local under_uncover_range = settings_uncover_range and dis < settings_uncover_range
	if under_uncover_range then
		my_data_detection_use_uncover_range = my_data_detection.use_uncover_range
		if my_data_detection_use_uncover_range then
			return -1, 0
		end
	end

	local max_dis = my_data_detection.dis_max
	local max_range = settings.max_range
	if max_range and max_range < max_dis then
		max_dis = max_range
	end
	local detection = settings.detection
	if detection then
		local detection_range_mul = detection.range_mul
		if detection_range_mul then
			max_dis = max_dis * detection_range_mul
		end
	end

	if dis < max_dis then
		if settings.notice_requires_FOV then
			local angle = mvec3_ang(my_head_fwd, tmp_vec1)
			if angle < 55 and under_uncover_range and not my_data_detection_use_uncover_range then
				return -1, 0
			end
			-- local angle_max = math_lerp(180, my_data_detection.angle_max, math_clamp((dis - 150) / 700, 0, 1))
			local t = math_clamp((dis - 150) / 700, 0, 1) -- inlined math.lerp
			local angle_max = 180 * (1 - t) + my_data_detection.angle_max * t
			if angle < angle_max then
				return angle, dis / max_dis
			end
		else
			return 0, dis / max_dis
		end
	end
end

local _base_delay = 0.1
local _nervous_game
local _is_loud, _eyes_wide_open
local function _set_loud()
	_is_loud = true
	_nervous_game = fs_settings.nervous_game and FullSpeedSwarm:allow_stealth_changes()
	_eyes_wide_open = fs_settings.eyes_wide_open and FullSpeedSwarm:allow_stealth_changes()
	_base_delay = _nervous_game and 0.5 or 1
end
table.insert(FullSpeedSwarm.call_on_loud, _set_loud)

local _mask_enemies
DelayedCalls:Add('DelayedModFSS_coplogicbase_maskenemies', 0, function()
	_mask_enemies = managers.slot:get_mask('enemies')
end)

function CopLogicBase._upd_attention_obj_detection(data, min_reaction, max_reaction)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_updattentionobjdetection(data, min_reaction, max_reaction)
	end

	local gstate = managers.groupai._state
	local t = data.t
	local my_unit = data.unit
	local my_mov = data.fs_ext_movement
	local my_pos = my_mov:m_head_pos()
	local my_head_fwd = my_mov:m_head_rot():z()
	local player_importance_wgt = my_unit:in_slot(_mask_enemies) and {}
	local player_importance_wgt_nr = 0
	local my_data_detection = data.internal_data.detection
	local wraycast = World.raycast

	do
	local my_key = data.key
	local detected_obj = data.detected_attention_objects
	local my_team = data.team
	local all_attention_objects = gstate:get_AI_attention_objects_by_filter_i(data.SO_access_str, my_team)
	local is_nervous = _nervous_game or my_unit:slot() == 16
	local my_access = data.SO_access
	local attention_cache_key = (min_reaction or REACT_MIN) .. my_access .. (max_reaction or REACT_MAX) .. (my_team and my_team.id or '')

		for i = #all_attention_objects, 1, -1 do
			local attention_info1 = all_attention_objects[i]
			FullSpeedSwarm:ensure_attention_extensions(attention_info1)
			local u_key = attention_info1.unit_key

		if not detected_obj[u_key] and u_key ~= my_key then
			local att_handler = attention_info1.handler
			local settings = att_handler.rel_cache[attention_cache_key]
			if settings == nil then
				settings = att_handler:get_attention_no_cache_query(attention_cache_key, my_access, min_reaction, max_reaction, my_team)
			end
			if settings then
				local acquired
				local attention_pos = att_handler:get_detection_m_pos()
				if _angle_and_dis_chk(attention_pos, settings, my_pos, my_head_fwd, my_data_detection) then
					local vis_ray = wraycast(World, 'ray', my_pos, attention_pos, 'slot_mask', data.visibility_slotmask, 'ray_type', 'ai_vision')
					acquired = not vis_ray or vis_ray.unit:key() == u_key
					if acquired then
						local att_obj = CopLogicBase._create_detected_attention_object_data(t, my_unit, u_key, attention_info1, settings)
						if is_nervous then
							att_obj.notice_progress = 1
							if att_obj.dis < 2000 then
								att_obj.next_verify_t = t
							end
						end
						detected_obj[u_key] = att_obj
					end
				end
				if not acquired then
					--_chk_record_attention_obj_importance_wgt(u_key, attention_info1)
					if player_importance_wgt then
							local ubase = attention_info1.fs_ext_base
							if ubase and attention_info1.fs_ext_movement and (ubase.is_local_player or ubase.is_husk_player) then
								local e_fwd = attention_info1.fs_ext_movement:detect_look_dir()
							if e_fwd then
								local weight = mvec3_dir(tmp_vec1, attention_pos, my_pos)
								local dot = mvec3_dot(e_fwd, tmp_vec1)
								weight = weight * weight * (1 - dot)
								player_importance_wgt_nr = player_importance_wgt_nr + 1
								player_importance_wgt[player_importance_wgt_nr] = u_key
								player_importance_wgt_nr = player_importance_wgt_nr + 1
								player_importance_wgt[player_importance_wgt_nr] = weight
							end
						end
					end
				end
			end
		end
	end
	end

	local is_detection_persistent = gstate:is_detection_persistent()

	local t2 = t + 0.1
	local delay = _base_delay
		local detected_obj_i = data.detected_attention_objects_i
		for i = detected_obj_i[0], 1, -1 do
			local attention_info2 = detected_obj_i[i]
			FullSpeedSwarm:ensure_attention_extensions(attention_info2)
			if t2 < attention_info2.next_verify_t then
				if attention_info2.reaction >= REACT_SUSPICIOUS then
				delay = math_min(attention_info2.next_verify_t - t, delay)
			end
		else
			local u_key = attention_info2.u_key
			local attention_pos = attention_info2.handler:get_detection_m_pos()
			local settings = attention_info2.settings
			local verification_interval = settings.verification_interval
			attention_info2.next_verify_t = t + (not attention_info2.verified and settings.notice_interval or verification_interval)
			delay = math_min(delay, verification_interval)
			if not attention_info2.identified then
				local noticable
				local angle, dis_multiplier = _angle_and_dis_chk(attention_pos, settings, my_pos, my_head_fwd, my_data_detection)
				if angle then
					local vis_ray = wraycast(World, 'ray', my_pos, attention_pos, 'slot_mask', data.visibility_slotmask, 'ray_type', 'ai_vision')
					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end
				local delta_prog
				local dt = t - attention_info2.prev_notice_chk_t
				if noticable then
					if angle == -1 then
						delta_prog = 1
					else
						local notice_delay_mul = settings.notice_delay_mul or 1
						if settings.detection and settings.detection.delay_mul then
							notice_delay_mul = notice_delay_mul * settings.detection.delay_mul
						end
						local angle_mul_mod = 0.25 * math_min(angle / my_data_detection.angle_max, 1)
						local dis_mul_mod = 0.75 * dis_multiplier
						local min_delay = my_data_detection.delay[1]
						local max_delay = my_data_detection.delay[2]
						local notice_delay_modified = math_lerp(min_delay * notice_delay_mul, max_delay, dis_mul_mod + angle_mul_mod)
						delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
					end
				else
					delta_prog = dt * -0.125
				end
				local new_notice_progress = attention_info2.notice_progress + delta_prog
				if new_notice_progress > 1 then
					attention_info2.notice_progress = nil
					attention_info2.prev_notice_chk_t = nil
					attention_info2.identified = true
					attention_info2.release_t = t + settings.release_delay
					attention_info2.identified_t = t
					noticable = true
					data.logic.on_attention_obj_identified(data, u_key, attention_info2)
				elseif new_notice_progress < 0 then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info2)
					noticable = false
				else
					attention_info2.notice_progress = new_notice_progress
					noticable = new_notice_progress
					attention_info2.prev_notice_chk_t = t
					if data.cool and settings.reaction >= REACT_SCARED then
						gstate:on_criminal_suspicion_progress(attention_info2.unit, my_unit, noticable)
					end
				end
				if noticable ~= false and settings.notice_clbk then
					settings.notice_clbk(my_unit, noticable)
				end
			end
			if attention_info2.identified then
				attention_info2.nearly_visible = nil
				local verified, vis_ray
				local dis = mvec3_dis(data.m_pos, attention_info2.m_pos)
				local att_unit = attention_info2.unit
				local is_enemy = data.enemy_slotmask and att_unit:in_slot(data.enemy_slotmask)
				if dis < my_data_detection.dis_max * 1.2 and (not settings.max_range or dis < settings.max_range * (settings.detection and settings.detection.range_mul or 1) * 1.2) then
					local detect_pos
					if attention_info2.is_husk_player and attention_info2.fs_ext_animdata and attention_info2.fs_ext_animdata.crouch then
						detect_pos = tmp_vec1
						mvec3_set(detect_pos, attention_info2.m_pos)
						mvec3_add(detect_pos, default_crouched_head_translation)
					else
						detect_pos = attention_pos
					end
					local in_FOV = is_enemy or not settings.notice_requires_FOV or _angle_chk(attention_pos, dis, 0.8, my_pos, my_head_fwd, my_data_detection)
					if in_FOV then
						vis_ray = wraycast(World, 'ray', my_pos, detect_pos, 'slot_mask', data.visibility_slotmask, 'ray_type', 'ai_vision')
						verified = not vis_ray or vis_ray.unit:key() == u_key
					end
					attention_info2.verified = verified
				end
				attention_info2.dis = dis
				attention_info2.vis_ray = vis_ray
				-- NB: arrested check done through player state change
				if verified then
					attention_info2.release_t = nil
					attention_info2.verified_t = t
					mvec3_set(attention_info2.verified_pos, attention_pos)
					attention_info2.last_verified_pos = mvec3_cpy(attention_pos)
					attention_info2.verified_dis = dis
					if data.group then
						data.group.fs_attention_obj_aware_t[u_key] = t
					end
				elseif is_enemy then
					if attention_info2.criminal_record and settings.reaction >= REACT_COMBAT then
						if not is_detection_persistent and mvec3_dis_sq(attention_pos, attention_info2.criminal_record.pos) > 700*700 then
							CopLogicBase._destroy_detected_attention_object_data(data, attention_info2)
						else
							delay = math_min(0.2, delay)
							attention_info2.verified_pos = mvec3_cpy(attention_info2.criminal_record.pos)
							attention_info2.verified_dis = dis
							if vis_ray and data.logic._chk_nearly_visible_chk_needed(data, attention_info2, u_key) then
								--_nearly_visible_chk(attention_info2, attention_pos)
								local near_pos = tmp_vec1
								if dis < 2000 then
									local attention_pos_z = mvec3_z(attention_pos)
									if math_abs(attention_pos_z - mvec3_z(my_pos)) < 300 then
										mvec3_set(near_pos, attention_pos)
										mvec3_set_z(near_pos, attention_pos_z + 100)
										local visibility_slotmask = data.visibility_slotmask
										local near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'slot_mask', visibility_slotmask, 'ray_type', 'ai_vision', 'report')
										if near_vis_ray then
											local side_vec = tmp_vec2
											mvec3_set(side_vec, attention_pos)
											mvec3_sub(side_vec, my_pos)
											mvec3_crs(side_vec, side_vec, math_UP)
											mvec3_set_len(side_vec, 150)
											mvec3_add(near_pos, side_vec)
											near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'slot_mask', visibility_slotmask, 'ray_type', 'ai_vision', 'report')
											if near_vis_ray then
												mvec3_mul(side_vec, -2)
												mvec3_add(near_pos, side_vec)
												near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'slot_mask', visibility_slotmask, 'ray_type', 'ai_vision', 'report')
											end
										end
										if not near_vis_ray then
											attention_info2.nearly_visible = true
											attention_info2.last_verified_pos = mvec3_cpy(near_pos)
										end
									end
								end
							end
						end
					elseif attention_info2.release_t then
						if t > attention_info2.release_t then
							CopLogicBase._destroy_detected_attention_object_data(data, attention_info2)
						end
					else
						attention_info2.release_t = t + settings.release_delay
					end
				elseif attention_info2.release_t then
					if t > attention_info2.release_t then
						CopLogicBase._destroy_detected_attention_object_data(data, attention_info2)
					end
				else
					attention_info2.release_t = t + settings.release_delay
				end
			end
		end
		--_chk_record_acquired_attention_importance_wgt(attention_info2)
			if player_importance_wgt and attention_info2.is_human_player and attention_info2.fs_ext_movement then
				local weight = mvec3_dir(tmp_vec1, attention_info2.m_head_pos, my_pos)
			local e_fwd = attention_info2.fs_ext_movement:detect_look_dir()
			local dot = mvec3_dot(e_fwd, tmp_vec1)
			weight = weight * weight * (1 - dot)
			player_importance_wgt_nr = player_importance_wgt_nr + 1
			player_importance_wgt[player_importance_wgt_nr] = attention_info2.u_key
			player_importance_wgt_nr = player_importance_wgt_nr + 1
			player_importance_wgt[player_importance_wgt_nr] = weight
		end
	end
	if player_importance_wgt_nr > 0 then
		gstate:set_importance_weight(data.key, player_importance_wgt)
	end
	return delay
end

function CopLogicBase.on_attention_obj_identified(data, attention_u_key, attention_info)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_onattentionobjidentified(data, attention_u_key, attention_info)
	end

	local group = data.group
	if group then
		local t = group.fs_attention_obj_aware_t[attention_u_key]
		if not t or data.t - t > 1 then
			group.fs_attention_obj_aware_t[attention_u_key] = data.t
			for u_key, u_data in pairs(group.units) do
				if u_key ~= data.key and alive(u_data.unit) then
					u_data.unit:brain():clbk_group_member_attention_identified(data.unit, attention_u_key)
				end
			end
		end
	end
end

function CopLogicBase._get_logic_state_from_reaction(data, reaction)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_getlogicstatefromreaction(data, reaction)
	end

	if reaction == nil and data.attention_obj then
		reaction = data.attention_obj.reaction
	end

	local police_is_being_called = _is_loud or managers.groupai._state:chk_enemy_calling_in_area(managers.groupai._state:get_area_from_nav_seg_id(data.fs_ext_movement:nav_tracker():nav_segment()), data.key)

	if not reaction or reaction <= REACT_SCARED then
		if data.char_tweak.calls_in and managers.groupai._state:can_police_be_called() and not police_is_being_called and not managers.groupai._state:is_police_called() and not data.cool and not data.is_converted then
			return 'arrest'
		elseif data.cool then
			-- qued
		else
			return 'idle'
		end
	elseif reaction == REACT_ARREST and not data.is_converted then
		return 'arrest'
	elseif not police_is_being_called and managers.groupai._state:can_police_be_called() and (data.char_tweak.calls_in or not data.char_tweak.no_arrest) and not managers.groupai._state:is_police_called() and not data.cool and not data.is_converted and (not data.attention_obj or not data.attention_obj.verified or data.attention_obj.dis >= 1500) and not data.attention_obj.forced then
		return 'arrest'
	else
		return 'attack'
	end
end

function CopLogicBase._set_attention_obj(data, new_att_obj, new_reaction)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_setattentionobj(data, new_att_obj, new_reaction)
	end

	local old_att_obj = data.attention_obj
	data.attention_obj = new_att_obj
	if new_att_obj then
		new_reaction = new_reaction or new_att_obj.settings.reaction
		new_att_obj.reaction = new_reaction
		local is_same_obj, contact_chatter_time
		if old_att_obj then
			if old_att_obj.u_key == new_att_obj.u_key then
				is_same_obj = true
				contact_chatter_time = 2
			else
				if old_att_obj.criminal_record then
					managers.groupai._state:on_enemy_disengaging(data.unit, old_att_obj.u_key)
				end
				contact_chatter_time = 15
			end
		else
			contact_chatter_time = 15
		end
		local new_crim_rec = new_att_obj.criminal_record
		if not is_same_obj then
			if new_crim_rec then
				managers.groupai._state:on_enemy_engaging(data.unit, new_att_obj.u_key)
			end
			local duration = new_att_obj.settings.duration
			if duration then
				new_att_obj.stare_expire_t = data.t + math_lerp(duration[1], duration[2], math_random())
				new_att_obj.pause_expire_t = nil
			end
			new_att_obj.acquire_t = data.t
		end
		if contact_chatter_time and new_crim_rec and data.t - new_crim_rec.det_t > contact_chatter_time then
			if new_reaction >= REACT_SHOOT and new_att_obj.verified and new_att_obj.is_person and data.char_tweak.chatter.contact then
				local anim_data = data.unit:anim_data()
				if anim_data.idle or anim_data.move then
					data.unit:sound():say('c01', true)
				end
			end
		end
	elseif old_att_obj and old_att_obj.criminal_record then
		managers.groupai._state:on_enemy_disengaging(data.unit, old_att_obj.u_key)
	end
end

function CopLogicBase.queue_task(internal_data, id, func, data, exec_t, asap)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_queuetask(internal_data, id, func, data, exec_t, asap)
	end

	if _eyes_wide_open then
		local t = data.t
		if t and exec_t and exec_t - t < 2 then -- not taser tasing
			exec_t = math_min(exec_t, t + 0.1)
		end
	end

	local qd_tasks = internal_data.queued_tasks
	if qd_tasks then
		if qd_tasks[id] then
			managers.enemy:update_queue_task(id, func, data, exec_t, data.fs_on_queued_task)
			return
		end
		qd_tasks[id] = true
	else
		internal_data.queued_tasks = {
			[id] = true
		}
	end

	managers.enemy:queue_task(id, func, data, exec_t, data.fs_on_queued_task, asap)
end

function CopLogicBase.cancel_queued_tasks(internal_data)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_cancelqueuedtasks(internal_data)
	end

	local qd_tasks = internal_data.queued_tasks
	if qd_tasks then
		local e_manager = managers.enemy
		for id in pairs(qd_tasks) do
			e_manager:unqueue_task(id)
			qd_tasks[id] = nil
		end
	end
end

function CopLogicBase.unqueue_task(internal_data, id)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_unqueuetask(internal_data, id)
	end

	managers.enemy:unqueue_task(id)
	internal_data.queued_tasks[id] = nil
end

function CopLogicBase.chk_unqueue_task(internal_data, id)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_chkunqueuetask(internal_data, id)
	end

	if internal_data.queued_tasks and internal_data.queued_tasks[id] then
		managers.enemy:unqueue_task(id)
		internal_data.queued_tasks[id] = nil
	end
end

function CopLogicBase.on_queued_task(ignore_this, internal_data, id)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_onqueuedtask(ignore_this, internal_data, id)
	end

	internal_data.queued_tasks[id] = nil
end

function CopLogicBase._create_detected_attention_object_data(time, my_unit, u_key, attention_info, settings, forced)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_coplogicbase_createdetectedattentionobjectdata(time, my_unit, u_key, attention_info, settings, forced)
	end

	FullSpeedSwarm:ensure_attention_extensions(attention_info)

	local ext_brain = my_unit:brain()
	local listener_id = 'detect_' .. tostring(my_unit:key())
	attention_info.handler:add_listener(listener_id, callback(ext_brain, ext_brain, 'on_detected_attention_obj_modified'))

	local att_unit = attention_info.unit
	local m_pos = attention_info.handler:get_ground_m_pos()
	local m_head_pos = attention_info.handler:get_detection_m_pos()
	local is_local_player, is_husk_player, is_deployable, is_person, is_very_dangerous, nav_tracker, char_tweak, m_rot, is_shield = nil
	local is_alive = true

	local att_base = attention_info.fs_ext_base
	if att_base then
		is_local_player = att_base.is_local_player
		is_husk_player = att_base.is_husk_player
		is_deployable = att_base.sentry_gun
		is_person = att_unit:in_slot(managers.slot:get_mask('persons'))
		if att_base.char_tweak then
			char_tweak = att_base:char_tweak()
			if att_base.add_tweak_data_changed_listener then
				att_base:add_tweak_data_changed_listener(listener_id, callback(ext_brain, ext_brain, 'on_detected_attention_obj_tweak_data_changed', u_key))
			end
		end
		is_very_dangerous = att_base._tweak_table == 'taser' or att_base._tweak_table == 'spooc'
		is_shield = att_base._tweak_table == 'shield' or att_base._tweak_table == 'phalanx_minion'
	end

	local att_movement = attention_info.fs_ext_movement
	if att_movement and att_movement.m_rot then
		m_rot = att_movement:m_rot()
	end

	local att_cdmg = attention_info.fs_ext_cdmg
	if att_cdmg and att_cdmg.dead then
		is_alive = not att_cdmg:dead()
	end

	local dis = mvec3_dis(my_unit:movement():m_head_pos(), m_head_pos)
	local new_entry = {
		fs_ext_animdata = attention_info.fs_ext_animdata,
		fs_ext_base = att_base,
		fs_ext_brain = attention_info.fs_ext_brain,
		fs_ext_cdmg = att_cdmg,
		fs_ext_movement = att_movement,
		verified = false,
		verified_t = false,
		notice_progress = 0,
		settings = settings,
		unit = attention_info.unit,
		u_key = u_key,
		handler = attention_info.handler,
		next_verify_t = time + (settings.notice_interval or settings.verification_interval),
		prev_notice_chk_t = time,
		m_rot = m_rot,
		m_pos = m_pos,
		m_head_pos = m_head_pos,
		nav_tracker = attention_info.nav_tracker,
		is_local_player = is_local_player,
		is_husk_player = is_husk_player,
		is_human_player = is_local_player or is_husk_player,
		is_deployable = is_deployable,
		is_person = is_person,
		is_very_dangerous = is_very_dangerous,
		is_shield = is_shield,
		is_alive = is_alive,
		reaction = settings.reaction,
		criminal_record = managers.groupai:state():criminal_record(u_key),
		char_tweak = char_tweak,
		verified_pos = mvec3_cpy(m_head_pos),
		verified_dis = dis,
		dis = dis,
		has_team = att_movement and att_movement.team,
		health_ratio = att_cdmg and att_cdmg.health_ratio,
		objective = attention_info.fs_ext_brain and attention_info.fs_ext_brain.objective,
		forced = forced
	}

	return new_entry
end

local fs_original_coplogicbase_destroydetectedattentionobjectdata = CopLogicBase._destroy_detected_attention_object_data
function CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
	fs_original_coplogicbase_destroydetectedattentionobjectdata(data, attention_info)

	local a_key = attention_info.u_key
	local daoi = data.detected_attention_objects_i
	local n = daoi[0]
	for i = 1, n do
		if daoi[i].u_key == a_key then
			daoi[i] = daoi[n]
			daoi[n] = nil
			daoi[0] = n - 1
			break
		end
	end
end

local fs_original_coplogicbase_destroyalldetectedattentionobjectdata = CopLogicBase._destroy_all_detected_attention_object_data
function CopLogicBase._destroy_all_detected_attention_object_data(data)
	fs_original_coplogicbase_destroyalldetectedattentionobjectdata(data)
	data.detected_attention_objects_i = FullSpeedSwarm.metaize_i(data.detected_attention_objects)
end

local _nervous_focus_delays = {}
local _cop_awareness_face_enemy = {}
local _cop_awareness_face_enemy_seen = {}

local function _set_nervous_game_tweaks(enabled)
	if fs_settings.nervous_game then
		for name, character in pairs(tweak_data.character) do
			if name ~= 'presets' and type(character) == 'table' and type(character.weapon) == 'table' then
				for _, weapon in pairs(character.weapon) do
					if weapon.focus_delay then
						if _nervous_focus_delays[weapon] == nil then
							_nervous_focus_delays[weapon] = weapon.focus_delay
						end
						weapon.focus_delay = enabled and math.min(1, _nervous_focus_delays[weapon]) or _nervous_focus_delays[weapon]
					end
				end
			end
		end
		for level, presets in pairs(tweak_data.character.presets.weapon) do
			for _, preset in pairs(presets) do
				if preset.focus_delay then
					if _nervous_focus_delays[preset] == nil then
						_nervous_focus_delays[preset] = preset.focus_delay
					end
					preset.focus_delay = enabled and math.max(0.5, _nervous_focus_delays[preset] / 3) or _nervous_focus_delays[preset]
				end
			end
		end
	end
end

local function _set_cop_awareness_tweaks(enabled)
	if fs_settings.cop_awareness then
		for name, character in pairs(tweak_data.character) do
			if name == 'presets' then
				-- qued
			elseif name == 'cop_scared' then
				-- qued
			elseif type(character) == 'table' and type(character.tags) == 'table' then
				if table.contains(character.tags, 'law') then
					if not table.contains(character.tags, 'special') then
						if not _cop_awareness_face_enemy_seen[character] then
							_cop_awareness_face_enemy_seen[character] = true
							_cop_awareness_face_enemy[character] = character.always_face_enemy
						end
						character.always_face_enemy = enabled and true or _cop_awareness_face_enemy[character]
					end
				end
			end
		end
	end
end

local function _refresh_stealth_sensitive_tweaks()
	local enabled = FullSpeedSwarm:allow_stealth_changes()
	_set_nervous_game_tweaks(enabled)
	_set_cop_awareness_tweaks(enabled)
end

table.insert(FullSpeedSwarm.call_on_loud, _refresh_stealth_sensitive_tweaks)
table.insert(FullSpeedSwarm.call_on_stealth, _refresh_stealth_sensitive_tweaks)

DelayedCalls:Add('DelayedModFSS_tweaktweak', 0, function()
	_refresh_stealth_sensitive_tweaks()
end)
