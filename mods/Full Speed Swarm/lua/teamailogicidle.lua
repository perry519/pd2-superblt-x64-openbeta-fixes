local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local mvec3_add = mvector3.add
local mvec3_ang = mvector3.angle
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

local REACT_COMBAT = AIAttentionObject.REACT_COMBAT
local REACT_SURPRISED = AIAttentionObject.REACT_SURPRISED

local fs_original_teamailogicidle_getpriorityattention = TeamAILogicIdle._get_priority_attention
function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func)
	if not FullSpeedSwarm:allow_stealth_changes() or attention_objects ~= data.detected_attention_objects then
		return fs_original_teamailogicidle_getpriorityattention(data, attention_objects, reaction_func)
	end

	reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
	local best_target, best_target_priority_slot, best_target_priority, best_target_reaction = nil

	local detected_obj_i = data.detected_attention_objects_i
	for i = detected_obj_i[0], 1, -1 do
		local attention_data = detected_obj_i[i]
		FullSpeedSwarm:ensure_attention_extensions(attention_data)

		if not attention_data.identified then
			-- qued

		elseif attention_data.pause_expire_t then
			if attention_data.pause_expire_t < data.t then
				attention_data.pause_expire_t = nil
			end

		elseif attention_data.stare_expire_t and attention_data.stare_expire_t < data.t then
			local pause = attention_data.settings.pause
			if pause then
				attention_data.stare_expire_t = nil
				attention_data.pause_expire_t = data.t + math.lerp(pause[1], pause[2], math.random())
			end

		else
			local distance = attention_data.dis
			local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data))
			attention_data.aimed_at = TeamAILogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)
			local reaction_too_mild

			if not reaction or best_target_reaction and reaction < best_target_reaction then
				reaction_too_mild = true
			elseif distance < 150 and reaction <= REACT_SURPRISED then
				reaction_too_mild = true
			end

			if not reaction_too_mild then
				local alert_dt = attention_data.alert_t and data.t - attention_data.alert_t or 10000
				local dmg_dt = 1
				local mark_dt = attention_data.mark_t and data.t - attention_data.mark_t or 10000

				if data.attention_obj and data.attention_obj.u_key == attention_data.u_key then
					alert_dt = alert_dt * 0.8
					dmg_dt = 0.8
					mark_dt = mark_dt * 0.8
					distance = distance * 0.8
				end

				local has_alerted = alert_dt < 5
				local been_marked = mark_dt < 8
				local target_priority = distance
				local target_priority_slot
				local is_shield = attention_data.is_shield
				local is_shielded = is_shield and TeamAILogicIdle._ignore_shield(data.unit, attention_data)

				if attention_data.verified then
					local near = distance < 800
					local dangerous_special = attention_data.is_very_dangerous
					target_priority_slot = (dangerous_special or been_marked) and distance < 1600 and 1
						or near and (
								has_alerted and (dmg_dt * (attention_data.dmg_t and data.t - attention_data.dmg_t or 10000) < 2) -- has_alerted and has_damaged
								or been_marked
								or is_shield and not is_shielded
							) and 2
						or near and has_alerted and 3
						or has_alerted and 4
						or 5

					if is_shielded then
						target_priority_slot = math.min(5, target_priority_slot + 1)
					end
				else
					target_priority_slot = has_alerted and 6 or 7
				end

				if is_shielded then
					target_priority = target_priority * 10
				end

				if reaction < REACT_COMBAT then
					target_priority_slot = 10 + target_priority_slot + math.max(0, REACT_COMBAT - reaction)
				end

				if target_priority_slot ~= 0 then
					local best = false

					if not best_target then
						best = true
					elseif target_priority_slot < best_target_priority_slot then
						best = true
					elseif target_priority_slot == best_target_priority_slot and target_priority < best_target_priority then
						best = true
					end

					if best then
						best_target = attention_data
						best_target_priority_slot = target_priority_slot
						best_target_priority = target_priority
						best_target_reaction = reaction
					end
				end
			end
		end
	end

	return best_target, best_target_priority_slot, best_target_reaction
end

function TeamAILogicIdle.fs_find_intimidateable_civilians(data, use_default_shout_shape, max_angle, max_dis)
	local my_movement = data.fs_ext_movement
	local action_common_data = my_movement and my_movement._action_common_data
	if not action_common_data or not action_common_data.fwd then
		return nil, 1, {}
	end

	local head_pos = my_movement:m_head_pos()
	local look_vec = action_common_data.fwd
	local close_dis = 400
	local intimidateable_civilians = {}
	local best_civ
	local best_civ_wgt = false
	local highest_wgt = 1

	for _, key in ipairs(managers.enemy._civilian_data.fs_unit_data) do
		local attention_data = data.detected_attention_objects[key]
		local char_tweak, unit_data
		if attention_data then
			FullSpeedSwarm:ensure_attention_extensions(attention_data)
			local unit = attention_data.unit
			local base = attention_data.fs_ext_base
			char_tweak = base and tweak_data.character[base._tweak_table]
			unit_data = alive(unit) and unit:unit_data()
		end
		if attention_data
		and attention_data.fs_ext_animdata
		and attention_data.fs_ext_brain
		and attention_data.fs_ext_base
		and attention_data.fs_ext_movement
		and not attention_data.fs_ext_animdata.drop
		and not attention_data.fs_ext_animdata.unintimidateable
		and not attention_data.fs_ext_brain:is_tied()
		and not attention_data.fs_ext_base.unintimidateable
		and char_tweak
		and char_tweak.intimidateable
		and unit_data
		and not unit_data.disable_shout
		then
			local u_head_pos = tmp_vec1
			mvec3_set(u_head_pos, math.UP)
			mvec3_mul(u_head_pos, 30)
			mvec3_add(u_head_pos, attention_data.fs_ext_movement:m_head_pos())
			local vec = tmp_vec2
			local dis = mvec3_dir(vec, head_pos, u_head_pos)
			local angle = mvec3_ang(vec, look_vec)

			if use_default_shout_shape then
				max_angle = math.max(8, math.lerp(90, 30, dis / 1200))
				max_dis = 1200
			end

			if dis < close_dis or dis < max_dis and angle < max_angle then
				local slotmask = managers.slot:get_mask('AI_visibility')
				local ray = World:raycast('ray', head_pos, u_head_pos, 'slot_mask', slotmask, 'ray_type', 'ai_vision')
				if not ray then
					local inv_wgt = dis * dis * (1 - mvec3_dot(vec, look_vec))
					table.insert(intimidateable_civilians, {
						unit = attention_data.unit,
						key = key,
						inv_wgt = inv_wgt,
						brain = attention_data.fs_ext_brain
					})
					if not best_civ_wgt or inv_wgt < best_civ_wgt then
						best_civ_wgt = inv_wgt
						best_civ = attention_data.unit
					end
					if highest_wgt < inv_wgt then
						highest_wgt = inv_wgt
					end
				end
			end
		end
	end

	return best_civ, highest_wgt, intimidateable_civilians
end

local fs_original_teamailogicidle_intimidatecivilians = TeamAILogicIdle.intimidate_civilians
function TeamAILogicIdle.intimidate_civilians(data, criminal, play_sound, play_action, primary_target)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_teamailogicidle_intimidatecivilians(data, criminal, play_sound, play_action, primary_target)
	end

	if alive(primary_target) and primary_target:unit_data().disable_shout then
		return false
	end

	if primary_target then
		if not alive(primary_target) or not managers.groupai:state():fleeing_civilians()[primary_target:key()] then
			primary_target = nil
		end
	end

	local best_civ, highest_wgt, intimidateable_civilians = TeamAILogicIdle.fs_find_intimidateable_civilians(data, true)
	local plural = false

	local intimidateable_civilians_nr = #intimidateable_civilians
	if intimidateable_civilians_nr > 1 then
		plural = true
	elseif intimidateable_civilians_nr <= 0 then
		return false
	end

	local act_name, sound_name
	local sound_suffix = plural and 'plu' or 'sin'

	if best_civ:anim_data().move then
		act_name = 'gesture_stop'
		sound_name = 'f02x_' .. sound_suffix
	else
		act_name = 'arrest'
		sound_name = 'f02x_' .. sound_suffix
	end

	if play_sound then
		criminal:sound():say(sound_name, true)
	end

	if play_action and data.fs_ext_movement and not data.fs_ext_movement:chk_action_forbidden('action') then
		local new_action = {
			align_sync = true,
			body_part = 3,
			type = 'act',
			variant = act_name
		}
		if data.brain:action_request(new_action) then
			data.internal_data.gesture_arrest = true
		end
	end

	local intimidated_primary_target = false
	for i = 1, intimidateable_civilians_nr do
		local civ = intimidateable_civilians[i]
		local amount = civ.inv_wgt / highest_wgt
		if best_civ == civ.unit then
			amount = 1
		end
		if primary_target == civ.unit then
			intimidated_primary_target = true
			amount = 1
		end
		civ.brain:on_intimidated(amount, criminal)
	end
	if not intimidated_primary_target and primary_target then
		primary_target:brain():on_intimidated(1, criminal)
	end

	if not managers.groupai:state():enemy_weapons_hot() then
		local alert = {
			'vo_intimidate',
			data.m_pos,
			800,
			data.SO_access,
			data.unit
		}
		managers.groupai:state():propagate_alert(alert)
	end

	if not primary_target and best_civ and best_civ:unit_data().disable_shout then
		return false
	end

	return primary_target or best_civ
end
