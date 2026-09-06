local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local math = math
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_lerp = math.lerp

local mvec3_cpy = mvector3.copy
local mvec3_cross = mvector3.cross
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_dot = mvector3.dot
local mvec3_len = mvector3.length
local mvec3_lerp = mvector3.lerp
local mvec3_norm = mvector3.normalize
local mvec3_rot = mvector3.rotate_with
local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_z = mvector3.z
local mrot_lookat = mrotation.set_look_at
local mrot_slerp = mrotation.slerp

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
local tmp_vec3 = Vector3()
local temp_rot1 = Rotation()

local idstr_base = Idstring('base')

local fs_original_copactionwalk_update = CopActionWalk.update
local fs_original_copactionwalk_setupdator = CopActionWalk._set_updator
local fs_original_copactionwalk_setnewpos = CopActionWalk._set_new_pos
local fs_original_copactionwalk_getcurrentmaxwalkspeed = CopActionWalk._get_current_max_walk_speed
local fs_original_copactionwalk_navchkwalk = CopActionWalk._nav_chk_walk
local fs_original_copactionwalk_updstopanimfirstframe = CopActionWalk._upd_stop_anim_first_frame
local fs_original_copactionwalk_updstopanim = CopActionWalk._upd_stop_anim

local _move_speeds = {}
CopActionWalk.fs_move_speeds = _move_speeds
local function _build_move_speeds()
	for character, tweaks in pairs(tweak_data.character) do
		if type(tweaks) == 'table' and tweaks.move_speed and character ~= 'presets' then
			_move_speeds[character] = _move_speeds[character] or {}
			for pose, stances in pairs(tweaks.move_speed) do
				for variant, walk_dirs in pairs(stances) do
					for stance, variants in pairs(walk_dirs) do
						_move_speeds[character][stance] = _move_speeds[character][stance] or {}
						_move_speeds[character][stance][variant] = _move_speeds[character][stance][variant] or {}
						for walk_dir, value in pairs(variants) do
							_move_speeds[character][stance][variant][walk_dir] = _move_speeds[character][stance][variant][walk_dir] or {}
							_move_speeds[character][stance][variant][walk_dir][pose] = value
						end
						_move_speeds[character][stance][variant].l = _move_speeds[character][stance][variant].strafe
						_move_speeds[character][stance][variant].r = _move_speeds[character][stance][variant].strafe
					end
				end
			end
		end
	end
end
_build_move_speeds()
DelayedCalls:Add('DelayedModFSS_copactionwalk', 0, function()
	-- Do it again in case another mod added or modified a character's speed
	_build_move_speeds()

	-- safety filler
	for _, obj in pairs(_G) do
		if type(obj) == 'table' and type(obj._walk_anim_velocities) == 'table' then
			local vels = obj._walk_anim_velocities
			for pose, stances in pairs(vels) do
				if table.size(stances) == 1 then
					local def_stance = next(stances)
					local other_stances = {'cbt', 'hos', 'ntl'}
					table.delete(other_stances, def_stance)
					for _, stance in pairs(other_stances) do
						stances[stance] = stances[def_stance]
					end
				else
					stances.cbt = stances.cbt or stances.hos
					stances.ntl = stances.ntl or stances.cbt
				end
				stances.ntl.run = stances.ntl.run or stances.ntl.walk
				stances.ntl.sprint = stances.ntl.sprint or stances.ntl.run
			end
			vels.crouch = vels.crouch or vels.stand
		end
	end

	local fs_original_copactionwalk_init = CopActionWalk.init
	function CopActionWalk:init(action_desc, common_data)
		local tt = common_data.char_tweak.kpr_tweak_table or common_data.ext_base._tweak_table
		self.fs_move_speed = self.fs_move_speeds[tt][common_data.stance.name][action_desc.variant]
		self.fs_update_rot = Rotation()
		self.fs_changing = 2
		self.fs_cache_t = -1
		self.fs_ws_vec_result = Vector3()
		self.fs_move_dir_norm_tmp = Vector3()
		return fs_original_copactionwalk_init(self, action_desc, common_data)
	end
end)

local _is_loud
local function _set_loud()
	_is_loud = true
end
table.insert(FullSpeedSwarm.call_on_loud, _set_loud)

if Network:is_client() then
	function CopActionWalk:_get_current_max_walk_speed(move_dir)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_copactionwalk_getcurrentmaxwalkspeed(self, move_dir)
		end

		local client_multiplier
		if _is_loud then
			client_multiplier = 1 + (Unit.occluded(self._unit) and 1 or CopActionWalk.lod_multipliers[self._ext_base._lod_stage] or 1)
		else
			client_multiplier = tweak_data.network.stealth_speed_boost
		end
		return self.fs_move_speed[move_dir][self._ext_anim.pose] * self._ext_movement.move_speed_multiplier * client_multiplier
	end
else
	function CopActionWalk:_get_current_max_walk_speed(move_dir)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_copactionwalk_getcurrentmaxwalkspeed(self, move_dir)
		end

		return self.fs_move_speed[move_dir][self._ext_anim.pose] * self._ext_movement.move_speed_multiplier
	end
end

function CopActionWalk:_set_updator(name)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_setupdator(self, name)
	end

	self.fs_changing = 1
	self.fs_cache_t = -1
	self.fs_ws_vec1 = false
	self.fs_curve_path_dis = {}
	self.update = self[name]
	if not name then
		self._last_upd_t = TimerManager:game():time() - 0.001
	end
end

function CopActionWalk:update_ik(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_update(self, t)
	end

	if self._ik_update then
		self._ik_update(t)
	end
	self:update_no_ik(t)
end

function CopActionWalk:update_no_ik(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_update(self, t)
	end

	local vis_state = self._ext_base:fs_lod_stage()
	if not vis_state then
		if t - self._last_upd_t < 0.15 then
			return
		else
			self._skipped_frames = 1
			vis_state = 2
		end
	elseif vis_state == 1 then
		-- qued
	elseif vis_state > self._skipped_frames then
		self._skipped_frames = self._skipped_frames + 1
		return
	else
		self._skipped_frames = 1
	end

	local dt = t - self._last_upd_t
	self._last_upd_t = t

	local pos_new
	local anim_data = self._ext_anim
	if self._end_of_path and (not anim_data.act or not anim_data.walk) then
		if self._next_is_nav_link then
			self:_set_updator('_upd_nav_link_first_frame')
			self:update(t)
			return
		elseif self._persistent then
			self:_set_updator('_upd_wait')
		elseif self._last_vel_z == 0 then
			self._expired = true
			if self._end_rot then
				self._ext_movement:set_rotation(self._end_rot)
			end
		end
	else
		self:_nav_chk_walk(t, dt, vis_state)
	end

	if self._cur_vel < 0.1 or anim_data.act and anim_data.walk then
		-- nothing
	elseif not self._expired then
		local wanted_walk_dir, move_dir_norm, move_dir_norm_changed
		local need_update = self.fs_changing > 0 or t - self.fs_cache_t > 0.25
		if need_update then
			self.fs_changing = self.fs_changing - 1
			self.fs_max_vel_cached = false
			self.fs_cache_t = t
		else
			wanted_walk_dir = self.fs_wanted_walk_dir_cached
			move_dir_norm = self.fs_move_dir_norm_cached
		end

		if not move_dir_norm then
			move_dir_norm = self.fs_move_dir_norm_tmp
			mvec3_set(move_dir_norm, self._last_pos)
			mvec3_sub(move_dir_norm, self._common_data.pos)
			mvec3_set_z(move_dir_norm, 0)
			mvec3_norm(move_dir_norm)
			self.fs_move_dir_norm_cached = move_dir_norm
			move_dir_norm_changed = true
		end

		if not wanted_walk_dir then
			local face_fwd = tmp_vec1
			if self._no_strafe or self._walk_turn then
				wanted_walk_dir = 'fwd'
			else
				if self._curve_path_end_rot and mvec3_dis_sq(self._last_pos, self._footstep_pos) < 19600 then
					mvec3_set(face_fwd, self._common_data.fwd)
				elseif self._attention_pos then
					mvec3_set(face_fwd, self._attention_pos)
					mvec3_sub(face_fwd, self._common_data.pos)
				elseif self._footstep_pos then
					mvec3_set(face_fwd, self._footstep_pos)
					mvec3_sub(face_fwd, self._common_data.pos)
				else
					mvec3_set(face_fwd, self._common_data.fwd)
				end
				mvec3_set_z(face_fwd, 0)
				mvec3_norm(face_fwd)
				local face_right = tmp_vec2
				mvec3_cross(face_right, face_fwd, math.UP)
				local right_dot = mvec3_dot(move_dir_norm, face_right)
				local fwd_dot = mvec3_dot(move_dir_norm, face_fwd)
				if math_abs(fwd_dot) > math_abs(right_dot) then
					if (anim_data.move_l and right_dot < 0 or anim_data.move_r and right_dot > 0) and math_abs(fwd_dot) < 0.73 then
						wanted_walk_dir = anim_data.move_side
					else
						wanted_walk_dir = fwd_dot > 0 and 'fwd' or 'bwd'
					end
				elseif (anim_data.move_fwd and fwd_dot > 0 or anim_data.move_bwd and fwd_dot < 0) and math_abs(right_dot) < 0.73 then
					wanted_walk_dir = anim_data.move_side
				else
					wanted_walk_dir = right_dot > 0 and 'r' or 'l'
				end
			end
			self.fs_wanted_walk_dir_cached = wanted_walk_dir
		end

		local rot_new = temp_rot1
		if self._curve_path_end_rot then
			local dis_lerp = 1 - math_min(1, mvec3_dis(self._last_pos, self._footstep_pos) / 140)
			mrot_slerp(rot_new, self._curve_path_end_rot, self._nav_link_rot or self._end_rot, dis_lerp)
		else
			if move_dir_norm_changed then
				local wanted_u_fwd = tmp_vec1
				mvec3_set(wanted_u_fwd, move_dir_norm)
				mvec3_rot(wanted_u_fwd, self._walk_side_rot[wanted_walk_dir])
				mrot_lookat(self.fs_update_rot, wanted_u_fwd, math.UP)
			end
			mrot_slerp(rot_new, self._common_data.rot, self.fs_update_rot, math_min(1, dt * 5))
		end
		self._ext_movement:set_rotation(rot_new)

		if self._chk_stop_dis and not self._common_data.char_tweak.no_run_stop then
			local end_dis = mvec3_dis(self._nav_point_pos(self._simplified_path[#self._simplified_path]), self._last_pos)
			if end_dis < self._chk_stop_dis then
				local move_dir_norm_copy = tmp_vec1
				mvec3_set(move_dir_norm_copy, move_dir_norm)
				local stop_anim_fwd = not self._nav_link_rot and self._end_rot and self._end_rot:y() or move_dir_norm_copy:rotate_with(self._walk_side_rot[wanted_walk_dir])
				local fwd_dot = mvec3_dot(stop_anim_fwd, move_dir_norm_copy)
				local move_dir_r_norm = tmp_vec3
				mvec3_cross(move_dir_r_norm, move_dir_norm_copy, math.UP)
				local fwd_dot = mvec3_dot(stop_anim_fwd, move_dir_norm_copy)
				local r_dot = mvec3_dot(stop_anim_fwd, move_dir_r_norm)
				local stop_anim_side
				if math_abs(fwd_dot) > math_abs(r_dot) then
					stop_anim_side = fwd_dot > 0 and 'fwd' or 'bwd'
				else
					stop_anim_side = r_dot > 0 and 'l' or 'r'
				end
				local stop_pose = self._action_desc.end_pose or anim_data.pose
				if stop_pose ~= anim_data.pose then
					self._ext_movement:play_redirect(stop_pose)
				end
				local stop_dis = self._anim_movement[stop_pose]['run_stop_' .. stop_anim_side]
				if stop_dis and end_dis < stop_dis then
					self._stop_anim_side = stop_anim_side
					self._stop_anim_fwd = stop_anim_fwd
					self._stop_dis = stop_dis
					self:_set_updator('_upd_stop_anim_first_frame')
				end
			end
		elseif self._walk_turn and not self._chk_stop_dis then
			local end_dis = mvec3_dis_sq(self._curve_path[self._curve_path_index + 1], self._last_pos)
			if end_dis < 45*45 then
				self:_set_updator('_upd_walk_turn_first_frame')
			end
		end

		local pose = self._stance.values[4] > 0 and 'wounded' or anim_data.pose or 'stand'
		local real_velocity = self._cur_vel
		local variant = self._haste
		local walkanimvelocities_pose_stance = self._walk_anim_velocities[pose][self._stance.name]
		if not walkanimvelocities_pose_stance then
			return
		end
		if variant == 'run' and not self._no_walk then
			if anim_data.sprint then
				if real_velocity > 480 and anim_data.pose == 'stand' then
					variant = 'sprint'
				elseif real_velocity > 250 then
					variant = 'run'
				else
					variant = 'walk'
				end
			elseif anim_data.run then
				if real_velocity > 530 and walkanimvelocities_pose_stance.sprint and anim_data.pose == 'stand' then
					variant = 'sprint'
				elseif real_velocity > 250 then
					variant = 'run'
				else
					variant = 'walk'
				end
			elseif real_velocity > 530 and walkanimvelocities_pose_stance.sprint and anim_data.pose == 'stand' then
				variant = 'sprint'
			elseif real_velocity > 300 then
				variant = 'run'
			else
				variant = 'walk'
			end
		end

		self:_adjust_move_anim(wanted_walk_dir, variant)
		local anim_walk_speed = walkanimvelocities_pose_stance[variant][wanted_walk_dir]
		local wanted_walk_anim_speed = real_velocity / anim_walk_speed
		self:_adjust_walk_anim_speed(dt, wanted_walk_anim_speed)
	end

	self:_set_new_pos(dt)
end

CopActionWalk.update = Global.game_settings.level_id == 'chill' and CopActionWalk.update_ik or CopActionWalk.update_no_ik

function CopActionWalk:_nav_chk_walk(t, dt, vis_state)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_navchkwalk(self, t, dt, vis_state)
	end

	local s_path = self._simplified_path
	local c_path = self._curve_path
	local c_index = self._curve_path_index

	local vel
	local ext_anim = self._ext_anim
	if ext_anim.act and ext_anim.walk then
		local new_anim_pos = self._unit:get_animation_delta_position()
		local anim_displacement = mvec3_len(new_anim_pos)
		vel = anim_displacement / dt
		if vel == 0 then
			return
		end
	else
		vel = self.fs_max_vel_cached
		if not vel then
			vel = self:_get_current_max_walk_speed(ext_anim.move_side or 'fwd')
			self.fs_max_vel_cached = vel
		end
		if not self._sync and not self._start_run and self:_husk_needs_speedup() then
			vel = 1.25 * vel
		end
	end

	local walk_dis = vel * dt
	local footstep_length = 200
	local nav_advanced
	local common_data = self._common_data
	local cur_pos = common_data.pos
	local new_pos, new_c_index, complete, upd_footstep

	while not self._end_of_curved_path do
		new_pos, new_c_index, complete = self:fs_walk_spline(c_path, c_index, walk_dis + footstep_length)
		upd_footstep = true
		if complete then
			if #s_path == 2 then
				self._end_of_curved_path = true
				if self._end_rot and not self._persistent then
					self._curve_path_end_rot = Rotation(mrotation.yaw(common_data.rot), 0, 0)
				end
				nav_advanced = true
				break
			elseif self._next_is_nav_link then
				self._end_of_curved_path = true
				self._nav_link_rot = Rotation(self._next_is_nav_link.element:value('rotation'), 0, 0)
				self._curve_path_end_rot = Rotation(mrotation.yaw(common_data.rot), 0, 0)
				break
			else
				self.fs_ws_vec1 = false
				self:_advance_simplified_path()
				local next_pos = self._nav_point_pos(s_path[2])
				local c_path_len = #c_path
				if self._sync and not self._action_desc.path_simplified and not self._next_is_nav_link and s_path[3] then
					self:_reserve_nav_pos(next_pos, self._nav_point_pos(s_path[3]), self._nav_point_pos(c_path[c_path_len]), vel)
				end
				local s_path_first_pos = s_path[1]
				if not s_path_first_pos.x then
					s_path_first_pos = self._nav_point_pos(s_path_first_pos)
					s_path[1] = s_path_first_pos
				end
				local new_c_path
				if vis_state == 1 and not self._action_desc.path_simplified and mvec3_dis_sq(s_path_first_pos, next_pos) > 490000 then
					new_c_path = self:_calculate_curved_path(s_path, 1, 1)
				else
					new_c_path = {
						s_path_first_pos,
						next_pos
					}
				end
				local i = c_path_len - 1
				while c_index <= i do
					table.insert(new_c_path, 1, c_path[i])
					i = i - 1
				end
				self._curve_path = new_c_path
				self._curve_path_index = 1
				c_path = self._curve_path
				c_index = 1
				if self._sync then
					self:_send_nav_point(next_pos)
				end
				nav_advanced = true
			end
		else
			break
		end
	end

	if upd_footstep then
		self._footstep_pos = new_pos:with_z(cur_pos.z)
	end

	local wanted_vel
	if vis_state == 1 and self._turn_vel then
		mvec3_set(tmp_vec1, c_path[c_index + 1])
		mvec3_set_z(tmp_vec1, mvec3_z(cur_pos))
		local dis = mvec3_dis_sq(tmp_vec1, cur_pos)
		if dis < 4900 then
			wanted_vel = math.lerp(self._turn_vel, vel, dis / 4900)
		end
	end
	wanted_vel = wanted_vel or vel
	if self._start_run then
		local delta_pos = common_data.unit:get_animation_delta_position()
		walk_dis = mvec3_len(delta_pos)
		local max_vel = self.fs_max_vel_cached or self:_get_current_max_walk_speed(ext_anim.move_side or 'fwd')
		self._cur_vel = math_min(max_vel, math_max(walk_dis / dt, self._start_max_vel))
		if self._cur_vel < self._start_max_vel then
			self._cur_vel = self._start_max_vel
			walk_dis = self._cur_vel * dt
		else
			self._start_max_vel = self._cur_vel
		end
	else
		local c_vel = self._cur_vel
		if c_vel ~= wanted_vel then
			local adj = vel * (wanted_vel > c_vel and 1.5 or 4) * dt
			c_vel = math.step(c_vel, wanted_vel, adj)
			self._cur_vel = c_vel
		end
		walk_dis = c_vel * dt
	end

	new_pos, new_c_index, complete = self:fs_walk_spline(c_path, c_index, walk_dis)
	if complete then
		local next_nav_link = self._next_is_nav_link
		if next_nav_link then
			self._end_of_path = true
			if self._sync and alive(next_nav_link.c_class) then
				local link_delay = next_nav_link.element:nav_link_delay()
				if link_delay and link_delay > 0 then
					next_nav_link.c_class:set_delay_time(t + link_delay)
				end
			end
		elseif #s_path == 2 then
			self._end_of_path = true
		end
	elseif new_c_index ~= self._curve_path_index or nav_advanced then
		self.fs_changing = 2
		local future_pos = c_path[new_c_index + 2]
		if future_pos then
			local next_pos = c_path[new_c_index + 1]
			local back_pos = c_path[new_c_index]
			local cur_vec = tmp_vec2
			mvec3_set(cur_vec, next_pos)
			mvec3_sub(cur_vec, back_pos)
			mvec3_set_z(cur_vec, 0)
			mvec3_norm(cur_vec)
			local next_vec = tmp_vec1
			mvec3_set(next_vec, future_pos)
			mvec3_sub(next_vec, next_pos)
			mvec3_set_z(next_vec, 0)
			local future_dis_flat = mvec3_norm(next_vec)
			local turn_dot = mvec3_dot(cur_vec, next_vec)
			if self._haste ~= 'run' and turn_dot > -0.7 and turn_dot < 0.7 and not self._attention_pos and future_dis_flat > 80 and common_data.stance.name == 'ntl' and mvec3_dot(common_data.fwd, cur_vec) > 0.97 then
				self._walk_turn = true
			else
				turn_dot = turn_dot * turn_dot
				local dot_lerp = math_max(0, turn_dot)
				local turn_vel = math.lerp(math_min(vel, 100), self:_get_current_max_walk_speed(ext_anim.move_side or 'fwd'), dot_lerp)
				self._turn_vel = turn_vel
				self._walk_turn = nil
			end
		else
			if vis_state < 3 and self._end_of_curved_path and ext_anim.run and not self._was_interrupted and not self._NO_RUN_STOP and not self._no_walk and not (mvec3_dis(c_path[new_c_index + 1], new_pos) < 120) then
				self._chk_stop_dis = 210
			elseif self._chk_stop_dis then
				self._chk_stop_dis = nil
			end
			self._walk_turn = nil
		end
	end
	self._curve_path_index = new_c_index
	self._last_pos = mvec3_cpy(new_pos)
end

function CopActionWalk:fs_walk_spline(path, index, walk_dis)
	if self._curve_path ~= self.fs_curve_path then
		self.fs_curve_path = self._curve_path
		self.fs_curve_path_dis = {}
	end
	local fs_curve_path_dis = self.fs_curve_path_dis

	if walk_dis >= 0 then
		local my_walk_dis = walk_dis + mvec3_dis(self._last_pos, path[index]) -- oubli du z setté à 0
		while true do
			local dis = fs_curve_path_dis[index]
			if not dis then
				dis = mvec3_dis(path[index], path[index + 1])
				fs_curve_path_dis[index] = dis
			end
			if dis == 0 or my_walk_dis >= dis then
				if index == #path - 1 then
					return path[index + 1], index, true
				else
					my_walk_dis = my_walk_dis - dis
					index = index + 1
				end
			else
				local return_vec = self.fs_ws_vec_result
				mvec3_lerp(return_vec, path[index], path[index + 1], my_walk_dis / dis)
				return return_vec, index
			end
		end

	else -- not sure this actually happens and even less sure the original code would handle it correctly
		local my_walk_dis = mvec3_dis(self._last_pos, path[index + 1]) - walk_dis -- like "+ abs(walk_dis)"
		while true do
			local dis = fs_curve_path_dis[index]
			if not dis then
				dis = mvec3_dis(path[index], path[index + 1])
				fs_curve_path_dis[index] = dis
			end
			if my_walk_dis >= 0 then
				if index == 1 then
					return path[index], index, true
				else
					my_walk_dis = my_walk_dis - dis
					index = index - 1
				end
			else
				local return_vec = self.fs_ws_vec_result
				mvec3_lerp(return_vec, path[index], path[index + 1], 1 - (my_walk_dis / dis))
				return return_vec, index
			end
		end
	end
end

function CopActionWalk:_upd_stop_anim(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_updstopanim(self, t)
	end

	local dt = TimerManager:game():delta_time()
	local rot_new = self._common_data.rot:slerp(Rotation(self._stop_anim_fwd, math.UP), math_min(1, dt * 5))

	self._ext_movement:set_rotation(rot_new)

	if self._ext_anim.run_stop then
		local seg_rel_t = self._machine:segment_relative_time(idstr_base)
		self._last_pos = self._stop_anim_displacement_f(self._stop_anim_init_pos, self._stop_anim_end_pos, seg_rel_t)
	elseif self._last_vel_z ~= 0 then
		-- qued
	else
		if #self._simplified_path > 2 or self._next_is_nav_link then
			self:_set_updator(nil)
		elseif self._persistent then
			self:_set_updator('_upd_wait')
		else
			self._expired = true
			if self._end_rot then
				self._ext_movement:set_rotation(self._end_rot)
			end
		end

		self._last_pos = mvec3_cpy(self._stop_anim_end_pos)
		self._stop_anim_displacement_f = nil
		self._stop_anim_end_pos = nil
		self._stop_anim_fwd = nil
		self._stop_anim_init_pos = nil
		self._stop_anim_side = nil
		self._stop_dis = nil
	end

	self:_set_new_pos(dt)
end

local fs_original_copactionwalk_chkcorrectpose = CopActionWalk._chk_correct_pose
function CopActionWalk:_chk_correct_pose()
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_chkcorrectpose(self)
	end

	fs_original_copactionwalk_chkcorrectpose(self)
	self._ext_movement.fs_keep_groundray = 0
end

function CopActionWalk:_set_new_pos(dt)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_setnewpos(self, dt)
	end

	local last_pos = self._last_pos
	local last_z = mvec3_z(last_pos)
	self._ext_movement:upd_ground_ray(last_pos, true)
	local gnd_z = mvec3_z(self._common_data.gnd_ray.position)
	gnd_z = math_clamp(gnd_z, last_z - 80, last_z + 80)
	local pos_z = mvec3_z(self._common_data.pos)
	local pos_new = tmp_vec1
	mvec3_set(pos_new, last_pos)
	mvec3_set_z(pos_new, pos_z)
	if gnd_z < pos_z then
		self._last_vel_z = self._apply_freefall(pos_new, self._last_vel_z, gnd_z, dt)
	else
		if gnd_z > pos_z then
			mvec3_set_z(pos_new, gnd_z)
		end
		self._last_vel_z = 0
	end
	self._ext_movement:set_position(pos_new)
end

function CopActionWalk:fs_haste()
	return (self._cur_vel > 450 or self._ext_anim.sprint) and 'run' or 'walk'
end

if Network:is_server() then
	local fs_original_copactionwalk_onexit = CopActionWalk.on_exit
	function CopActionWalk:on_exit()
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_copactionwalk_onexit(self)
		end

		if self._nav_link and self._common_data.ext_damage:dead() then
			self._ext_movement.fs_death_navseg = self._nav_link.element._values.itr_from_navseg
		end
		fs_original_copactionwalk_onexit(self)
	end
end

function CopActionWalk._nav_point_pos(nav_point)
	return nav_point.x and nav_point or nav_point.element:value('position')
end

local function fs_stop_anim_displacement_stand_fwd(p1, p2, t)
	local t_clamp = (math_clamp(t, 0, 0.6) / 0.6) ^ 0.8
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_stand_bwd(p1, p2, t)
	local low = 0.97
	local p_1_5 = 0.9
	local t_clamp = math_clamp(t, 0, 0.8) / 0.8
	if t_clamp < p_1_5 then
		t_clamp = low * (1 - (p_1_5 - t_clamp) / p_1_5)
	else
		t_clamp = low + ((1 - low) * (t_clamp - p_1_5)) / (1 - p_1_5)
	end
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_stand_l(p1, p2, t)
	local p_1_5 = 0.6
	local low = 0.8
	local t_clamp = math_clamp(t, 0, 0.75) / 0.75
	if t_clamp < p_1_5 then
		t_clamp = (low * t_clamp) / p_1_5 
	else
		t_clamp = low + ((1 - low) * (t_clamp - p_1_5)) / (1 - p_1_5)
	end
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_stand_r(p1, p2, t)
	local low = 0.9
	local p_1_5 = 0.85
	local t_clamp = math_clamp(t, 0, 0.8) / 0.8
	if t_clamp < p_1_5 then
		t_clamp = low * (1 - (p_1_5 - t_clamp) / p_1_5)
	else
		t_clamp = low + ((1 - low) * (t_clamp - p_1_5)) / (1 - p_1_5)
	end
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_crouch(p1, p2, t)
	local t_clamp = math_clamp(t, 0, 0.4) / 0.4
	t_clamp = t_clamp ^ 0.85
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_crouch_l(p1, p2, t)
	local t_clamp = math_clamp(t, 0, 0.3) / 0.3
	t_clamp = t_clamp ^ 0.85
	return math_lerp(p1, p2, t_clamp)
end

local function fs_stop_anim_displacement_crouch_r(p1, p2, t)
	local t_clamp = math_clamp(t, 0, 0.6) / 0.6
	t_clamp = t_clamp ^ 0.85
	return math_lerp(p1, p2, t_clamp)
end

function CopActionWalk:_upd_stop_anim_first_frame(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactionwalk_updstopanimfirstframe(self, t)
	end

	local enter_t
	local stop_anim_side = self._stop_anim_side
	local redir_name = 'run_stop_' .. stop_anim_side
	local redir_res = self._ext_movement:play_redirect(redir_name, enter_t)
	if not redir_res then
		return
	end

	local pose = self._ext_anim.pose or self._fallback_pose
	local speed_mul = self:_get_current_max_walk_speed(stop_anim_side) / self._walk_anim_velocities[pose][self._stance.name][self._haste][stop_anim_side]

	self._machine:set_speed(redir_res, speed_mul)

	self._stop_anim_init_pos = mvec3_cpy(self._last_pos)
	self._stop_anim_end_pos = mvec3_cpy(self._nav_point_pos(self._simplified_path[#self._simplified_path]))
	self._chk_stop_dis = nil

	self:_set_updator('_upd_stop_anim')

	if pose ~= 'crouch' then
		if stop_anim_side == 'fwd' then
			self._stop_anim_displacement_f = fs_stop_anim_displacement_stand_fwd
		elseif stop_anim_side == 'bwd' then
			self._stop_anim_displacement_f = fs_stop_anim_displacement_stand_bwd
		elseif stop_anim_side == 'l' then
			self._stop_anim_displacement_f = fs_stop_anim_displacement_stand_l
		else
			self._stop_anim_displacement_f = fs_stop_anim_displacement_stand_r
		end
	elseif stop_anim_side == 'fwd' or stop_anim_side == 'bwd' then
		self._stop_anim_displacement_f = fs_stop_anim_displacement_crouch
	elseif stop_anim_side == 'l' then
		self._stop_anim_displacement_f = fs_stop_anim_displacement_crouch_l
	else
		self._stop_anim_displacement_f = fs_stop_anim_displacement_crouch_r
	end

	self._ext_base:chk_freeze_anims()
	self:update(t)
end
