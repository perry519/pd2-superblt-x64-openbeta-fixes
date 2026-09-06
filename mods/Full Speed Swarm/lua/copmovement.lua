local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

CopMovement.move_speed_multiplier = 1
local fs_original_copmovement_updgroundray = CopMovement.upd_ground_ray

local fs_original_copmovement_init = CopMovement.init
function CopMovement:init(unit)
	fs_original_copmovement_init(self, unit)
	self.fs_blockers_nr = 0
	self.fs_keep_groundray = 0
	self.fs_fake_ray_position = Vector3()
	self.fs_m_stand_pos = self._m_stand_pos
end

local fs_original_copmovement_chkactionforbidden = CopMovement.chk_action_forbidden
function CopMovement:chk_action_forbidden(action_type)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copmovement_chkactionforbidden(self, action_type)
	end

	return self.fs_blockers_nr > 0 and fs_original_copmovement_chkactionforbidden(self, action_type)
end

local fs_original_copmovement_actionrequest = CopMovement.action_request
function CopMovement:action_request(action_desc)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copmovement_actionrequest(self, action_desc)
	end

	local action = fs_original_copmovement_actionrequest(self, action_desc)
	if action and action.chk_block then
		self.fs_blockers_nr = self.fs_blockers_nr + 1
	end
	return action
end

local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_z = mvector3.z
local mvec3_add = mvector3.add
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local math_down = math.DOWN
local math_abs = math.abs

local _units_per_navseg = FullSpeedSwarm.units_per_navseg
-- These helpers own FSS's lazy _m_stand_pos layout, so they cannot switch to vanilla mid-heist.
function CopMovement:set_position(pos)
	mvec3_set(self._m_pos, pos)
	self._m_stand_pos = nil

	self._obj_head:m_position(self._m_head_pos)
	self._obj_spine:m_position(self._m_com)
	self._nav_tracker:move(pos)
	self._unit:set_position(pos)

	if self.fs_do_track then
		local new_seg = self._nav_tracker:nav_segment()
		local old_seg = self.fs_cur_seg
		if new_seg ~= old_seg then
			local new_list = _units_per_navseg[new_seg]
			local u_key = self._unit:key()
			if old_seg then
				_units_per_navseg[old_seg][u_key] = nil
			end
			if not new_list then
				new_list = {}
				_units_per_navseg[new_seg] = new_list
			end
			new_list[u_key] = self.fs_do_track
		end
		self.fs_cur_seg = new_seg
	end
end

function CopMovement:set_m_pos(pos)
	mvec3_set(self._m_pos, pos)
	self._m_stand_pos = nil
	self._obj_head:m_position(self._m_head_pos)
	self._nav_tracker:move(pos)
	self._obj_spine:m_position(self._m_com)
end

local vec_stand = Vector3(0, 0, 160)
function CopMovement:m_stand_pos()
	local pos = self._m_stand_pos
	if not pos then
		pos = self.fs_m_stand_pos
		mvec3_set(pos, self._m_pos)
		mvec3_add(pos, vec_stand)
		self._m_stand_pos = pos
	end
	return pos
end

function CopMovement:upd_ground_ray(from_pos)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copmovement_updgroundray(self, from_pos)
	end

	local fake_ray = self.fs_old_gnd_ray
	if fake_ray and self.fs_keep_groundray > 0 then
		if math_abs(fake_ray.field_z - self._nav_tracker:field_z()) < 2 then
			self.fs_keep_groundray = self.fs_keep_groundray - 1
		else
			self.fs_keep_groundray = 0
		end

	else
		local hit_ray
		local new_pos = from_pos or self._m_pos
		local field_z = self._nav_tracker:field_z()
		local ground_z = field_z - 22
		local fake_ray_pos = self.fs_fake_ray_position
		mvec3_set(temp_vec1, new_pos)
		mvec3_set(temp_vec2, new_pos)
		mvec3_set_z(temp_vec1, ground_z + 171)
		mvec3_set_z(temp_vec2, ground_z - 140)
		local gnd_ray = World:raycast('ray', temp_vec1, temp_vec2, 'slot_mask', self._slotmask_gnd_ray, 'ray_type', 'walk')
		if gnd_ray then
			local dubious
			local hit_pos = gnd_ray.position
			local hit_pos_z = mvec3_z(hit_pos)
			local new_pos_z = mvec3_z(new_pos)

			if new_pos_z - field_z > -40 and new_pos_z - hit_pos_z > 100 then
				mvec3_set_z(temp_vec1, ground_z + 100)
				gnd_ray = World:raycast('ray', temp_vec1, temp_vec2, 'slot_mask', self._slotmask_gnd_ray, 'ray_type', 'walk') or gnd_ray
				hit_pos = gnd_ray.position
				hit_pos_z = mvec3_z(hit_pos)
				if hit_pos_z - new_pos_z > 99 then
					dubious = true
				end
			end

			if not from_pos then
				ground_z = (new_pos_z + hit_pos_z) / 2
			elseif not dubious and math_abs(new_pos_z - hit_pos_z) < 100 then
				self.fs_keep_groundray = self.fs_dt and (self._ext_anim.run and 0.1 or 0.4) / self.fs_dt or 4
				ground_z = hit_pos_z
			else
				self.fs_keep_groundray = 0
				ground_z = fake_ray_pos.z
			end

			hit_ray = gnd_ray
		else
			self.fs_keep_groundray = 4
			if fake_ray then
				ground_z = mvec3_z(fake_ray.position) - fake_ray.field_z + ground_z
			end
		end

		mvec3_set(fake_ray_pos, new_pos)
		mvec3_set_z(fake_ray_pos, ground_z)

		if fake_ray then
			fake_ray.field_z = field_z
			fake_ray.unit = hit_ray and hit_ray.unit
		else
			fake_ray = {
				field_z = field_z,
				position = fake_ray_pos,
				ray = math_down,
				unit = hit_ray and hit_ray.unit
			}
			self.fs_old_gnd_ray = fake_ray
		end
	end

	self._action_common_data.gnd_ray = fake_ray
	self._gnd_ray = fake_ray
end

local fs_original_copmovement_update = CopMovement.update
function CopMovement:update(unit, t, dt)
	self.fs_dt = dt
	return fs_original_copmovement_update(self, unit, t, dt)
end

if Network:is_server() then
	local fs_original_copmovement_updactions = CopMovement._upd_actions
	local fs_use_optimized_updactions
	local function fs_refresh_updactions()
		fs_use_optimized_updactions = FullSpeedSwarm:allow_stealth_changes()
	end
	table.insert(FullSpeedSwarm.call_on_loud, fs_refresh_updactions)
	table.insert(FullSpeedSwarm.call_on_stealth, fs_refresh_updactions)
	fs_refresh_updactions()

	function CopMovement:_upd_actions(t)
		if not fs_use_optimized_updactions then
			return fs_original_copmovement_updactions(self, t)
		end

		local a_actions = self._active_actions
		local has_no_action = true
		local need_upd

		-- Native owns four action slots and clears them with false sentinels.
		for i_action = 1, 4 do
			local action = a_actions[i_action]
			if action then
				local action_expired = action.expired
				if action_expired and action_expired(action) then
					a_actions[i_action] = false

					local action_on_exit = action.on_exit
					if action_on_exit then
						action_on_exit(action)
					end

					self._ext_brain:action_complete_clbk(action)

					for remaining_i = 1, 4 do
						if a_actions[remaining_i] then
							has_no_action = nil
							break
						end
					end
				else
					local action_update = action.update
					if action_update then
						action_update(action, t)
					end

					local action_need_upd = action.need_upd
					need_upd = need_upd or action_need_upd and action_need_upd(action)
					has_no_action = nil
				end
			end
		end

		self._need_upd = need_upd

		if not self._queued_actions or not next(self._queued_actions) then
			if has_no_action then
				self:action_request({
					body_part = 3,
					type = 'idle'
				})

				if self._ext_anim.spawn then
					self:play_redirect('idle')
				end
			elseif a_actions[1] then
				if a_actions[1]:type() == 'idle' then
					self:action_request({
						body_part = 3,
						client_interrupt = true,
						type = 'idle'
					})
				end
			elseif a_actions[2] and a_actions[2]:type() == 'idle' then
				if not a_actions[3] or a_actions[3]:type() == 'idle' then
					self:action_request({
						body_part = 2,
						client_interrupt = true,
						non_persistent = true,
						type = 'idle'
					})

					if not a_actions[3] then
						self:action_request({
							body_part = 3,
							type = 'idle'
						})
					end
				end
			elseif a_actions[2] and not a_actions[3] then
				local action_data = {
					body_part = 3,
					type = 'idle'
				}

				if not self:chk_action_forbidden('action') then
					self:action_request(action_data)
				end
			elseif not a_actions[2] and a_actions[3] and a_actions[3]:type() ~= 'idle' then
				local action_data = {
					body_part = 2,
					type = 'idle'
				}

				if not self:chk_action_forbidden('walk') then
					self:action_request(action_data)
				end
			end
		end

		self:_upd_stance(t)

		if not self._need_upd and (self._ext_anim.base_need_upd or self._ext_anim.upper_need_upd or self._force_updating or self._stance.transition or self._suppression.transition) then
			self._need_upd = true
		end
	end

	local fs_original_copmovement_onsuppressed = CopMovement.on_suppressed
	function CopMovement:on_suppressed(state)
		fs_original_copmovement_onsuppressed(self, state)

		if not state and self._ext_anim.act and self._ext_anim.fumble then
			self:action_request({type = 'idle', body_part = 1})
		end
	end
end

local fs_original_copmovement_setcarryingbag = CopMovement.set_carrying_bag
function CopMovement:set_carrying_bag(unit)
	fs_original_copmovement_setcarryingbag(self, unit)
	if unit and not unit:carry_data():can_explode() then
		unit:set_extension_update_enabled(Idstring('carry_data'), false)
	end
end

function CopMovement:throw_bag(target_unit, reason)
	if not self:carrying_bag() then
		return
	end

	local carry_unit = self._carry_unit
	self._was_carrying = {
		unit = carry_unit,
		reason = reason
	}

	carry_unit:carry_data():unlink()

	if Network:is_server() then
		-- self:sync_throw_bag(carry_unit, target_unit)
		-- managers.network:session():send_to_peers("sync_ai_throw_bag", self._unit, carry_unit, target_unit)
		-- ^^^ no, no, NO!

		local position = carry_unit:position()
		local direction, force

		if alive(target_unit) then
			direction = target_unit:position() - self._unit:position()
			mvector3.set_z(direction, math.abs(direction.x + direction.y) * 0.5)
			local throw_distance_multiplier = tweak_data.carry.types[tweak_data.carry[carry_unit:carry_data():carry_id()].type].throw_distance_multiplier
			force = tweak_data.ai_carry.throw_force * throw_distance_multiplier
		else
			direction = Vector3()
			force = 0
		end

		carry_unit:carry_data():set_position_and_throw(position, direction, force)
	end
end
