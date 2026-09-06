local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set

local temp_vec1 = Vector3()
local temp_vec2 = Vector3()

local fs_original_copbrain_converttocriminal = CopBrain.convert_to_criminal
function CopBrain:convert_to_criminal(mastermind_criminal)
	fs_original_copbrain_converttocriminal(self, mastermind_criminal)
	self._logic_data.fs_ext_movement.fs_do_track = nil
	local cur_seg = self._logic_data.fs_ext_movement.fs_cur_seg
	if cur_seg then
		FullSpeedSwarm.units_per_navseg[cur_seg][self._unit:key()] = nil
	end
end

local fs_original_copbrain_actioncompleteclbk = CopBrain.action_complete_clbk
function CopBrain:action_complete_clbk(action)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copbrain_actioncompleteclbk(self, action)
	end

	if not action.itr_fake_complete then
		if action.chk_block then
			local u_mov = self._logic_data.fs_ext_movement
			u_mov.fs_blockers_nr = u_mov.fs_blockers_nr - 1
		end

		local action_desc = action._action_desc
		if action_desc and action_desc.variant and action_desc.variant:find('e_so_sup_fumble_inplace') == 1 then
			local u_mov = self._logic_data.fs_ext_movement
			if u_mov._action_common_data.is_suppressed and action.expired and action:expired() then
				local allowed_fumbles = {'e_so_sup_fumble_inplace_3'}

				if u_mov._suppression.transition then
					local vec_from = temp_vec1
					local vec_to = temp_vec2
					local ray_params = {
						allow_entry = false,
						trace = true,
						tracker_from = u_mov:nav_tracker(),
						pos_from = vec_from,
						pos_to = vec_to
					}

					local m_pos = u_mov:m_pos()
					local m_rot = u_mov:m_rot()

					mvec3_set(vec_from, m_pos)
					mvec3_set(vec_to, m_rot:y())
					mvec3_mul(vec_to, -100)
					mvec3_add(vec_to, m_pos)
					local allow = not managers.navigation:raycast(ray_params)
					if allow then
						table.insert(allowed_fumbles, 'e_so_sup_fumble_inplace_1')
					end

					mvec3_set(vec_from, m_pos)
					mvec3_set(vec_to, m_rot:x())
					mvec3_mul(vec_to, 200)
					mvec3_add(vec_to, m_pos)
					allow = not managers.navigation:raycast(ray_params)
					if allow then
						table.insert(allowed_fumbles, 'e_so_sup_fumble_inplace_2')
					end

					mvec3_set(vec_from, m_pos)
					mvec3_set(vec_to, m_rot:x())
					mvec3_mul(vec_to, -200)
					mvec3_add(vec_to, m_pos)
					allow = not managers.navigation:raycast(ray_params)
					if allow then
						table.insert(allowed_fumbles, 'e_so_sup_fumble_inplace_4')
					end
				end

				local action_desc = {
					body_part = 1,
					type = 'act',
					variant = allowed_fumbles[math.random(#allowed_fumbles)],
					blocks = {
						action = -1,
						walk = -1
					}
				}
				u_mov:action_request(action_desc)
			end
		end
	end

	self._current_logic.action_complete_clbk(self._logic_data, action)
end

local fs_original_copbrain_resetlogicdata = CopBrain._reset_logic_data
function CopBrain:_reset_logic_data()
	fs_original_copbrain_resetlogicdata(self)
	self._logic_data.detected_attention_objects_i = FullSpeedSwarm.metaize_i(self._logic_data.detected_attention_objects)
	self._logic_data._tweak_table = self._unit:base()._tweak_table
	self._logic_data.fs_ext_movement = self._unit:movement()
	self._logic_data.fs_on_queued_task = function(id)
		if self._logic_data.internal_data.queued_tasks then
			self._logic_data.internal_data.queued_tasks[id] = nil
		end
	end
end

local fs_original_copbrain_chkenablebodybaginteraction = CopBrain._chk_enable_bodybag_interaction
function CopBrain:_chk_enable_bodybag_interaction()
	if managers.groupai:state():whisper_mode() then
		return fs_original_copbrain_chkenablebodybaginteraction(self)
	else
		self._unit:interaction():set_active(false, true)
	end
end
