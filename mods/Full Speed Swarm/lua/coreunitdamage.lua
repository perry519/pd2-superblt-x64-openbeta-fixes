local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local math_abs = math.abs
local math_clamp = math.clamp
local math_dot = math.dot

local mvec3_add = mvector3.add
local mvec3_dir = mvector3.direction
local mvec3_is_zero = mvector3.is_zero
local mvec3_len = mvector3.length
local mvec3_len_sq = mvector3.length_sq
local mvec3_mul = mvector3.multiply
local mvec3_neg = mvector3.negate
local mvec3_norm = mvector3.normalize
local mvec3_set = mvector3.set
local mvec3_set_zero = mvector3.set_zero
local mvec3_sub = mvector3.subtract

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
local tmp_vec3 = Vector3()

local vec_zero = Vector3()
local tenpi_inv = 1 / (10 * math.pi)

function CoreUnitDamage:get_collision_velocity(position, body, other_body, other_unit, collision_velocity, normal, is_mover, velocity, other_velocity)
	local damage_ext = other_unit:damage()
	if damage_ext then
		local is_other_mover = not alive(other_body)
		if is_other_mover then
			if not damage_ext:give_mover_collision_velocity() then
				other_velocity = tmp_vec1
				mvec3_set_zero(other_velocity)
			end
		elseif not damage_ext:give_body_collision_velocity() then
			other_velocity = tmp_vec1
			mvec3_set_zero(other_velocity)
		end
	end

	if is_mover then
		local other_velocity_length = mvec3_dir(tmp_vec2, vec_zero, other_velocity)
		mvec3_set(velocity, tmp_vec2 * math_clamp(math_dot(velocity, tmp_vec2), 0, other_velocity_length))
	end

	mvec3_set(collision_velocity, velocity)
	mvec3_sub(collision_velocity, other_velocity)
	if mvec3_len_sq(velocity) < mvec3_len_sq(other_velocity) then
		mvec3_neg(collision_velocity)
	end

	local direction = tmp_vec2
	mvec3_set(direction, collision_velocity)
	mvec3_norm(direction)
	if mvec3_is_zero(direction) then
		mvec3_set(direction, normal)
		mvec3_neg(direction)
	end

	return self:add_angular_velocity(position, direction, body, other_body, other_unit, collision_velocity, is_mover)
end

function CoreUnitDamage:add_angular_velocity(position, direction, body, other_body, other_unit, collision_velocity, is_mover)
	local angular_velocity_addition = tmp_vec1

	if alive(body) then
		local body_ang_vel = body:angular_velocity()
		-- angular_velocity_addition = (direction * 200 * body_ang_vel:length() * (1 + math.abs(math.dot(body_ang_vel:normalized(), direction)))) / (10 * math.pi)
		local dis = mvec3_dir(tmp_vec2, vec_zero, body_ang_vel)
		mvec3_set(angular_velocity_addition, direction)
		mvec3_mul(angular_velocity_addition, 200 * dis * (1 + math_abs(math_dot(tmp_vec2, direction))) * tenpi_inv)
	else
		mvec3_set_zero(angular_velocity_addition)
	end

	if alive(other_body) then
		local other_body_ang_vel = other_body:angular_velocity()
		-- angular_velocity_addition = angular_velocity_addition + (direction * 200 * other_body_ang_vel:length() * (1 + math.abs(math.dot(other_body_ang_vel:normalized(), direction)))) / (10 * math.pi)
		local dis = mvec3_dir(tmp_vec2, vec_zero, other_body_ang_vel)
		mvec3_set(tmp_vec3, direction)
		mvec3_mul(tmp_vec3, 200 * dis * (1 + math_abs(math_dot(tmp_vec2, direction))) * tenpi_inv)
		mvec3_add(angular_velocity_addition, tmp_vec3)

		local avalen = mvec3_len(angular_velocity_addition)
		mvec3_set(angular_velocity_addition, direction)
		mvec3_mul(angular_velocity_addition, math_clamp(avalen, 0, 200))
	end

	-- return collision_velocity + angular_velocity_addition, direction
	mvec3_add(angular_velocity_addition, collision_velocity)
	return angular_velocity_addition, direction
end

local fs_original_coreunitdamage_bodycollisioncallback = CoreUnitDamage.body_collision_callback
function CoreUnitDamage:body_collision_callback(...)
	if self.fs_dont_care_about_damage then
		return
	end

	fs_original_coreunitdamage_bodycollisioncallback(self, ...)
end

local v1 = Vector3(0, 0, 1)
local v2 = Vector3(0, 0, -1)
local v3 = Vector3(0, 0, 0)
local v4 = Vector3()
function CoreUnitDamage:run_sequence_simple3(name, endurance_type, source_unit, params)
	self._unit:m_position(v4)
	self:run_sequence(name, endurance_type, source_unit, nil, v1, v4, v2, 0, v3, params)
end

function CoreUnitDamage:get_collision_damage(tag, body, other_unit, other_body, position, normal, collision_velocity, is_mover_collision)
	return math_clamp((mvec3_len(collision_velocity) - 400) / 100, 0, 75)
end
