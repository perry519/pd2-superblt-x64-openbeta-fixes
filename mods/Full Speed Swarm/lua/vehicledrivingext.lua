local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

local mvec3_len = mvector3.length
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

local _world_find_units = Global.game_settings.level_id == 'ranc' and World.find_units or World.find_units_quick -- TODO: solve this one, or not

local fs_original_vehicledrivingext_init = VehicleDrivingExt.init
function VehicleDrivingExt:init(...)
	fs_original_vehicledrivingext_init(self, ...)
	self.fs_flesh_slotmask = managers.slot:get_mask('flesh') - managers.slot:get_mask('all_criminals')
	self.fs_enemies_slotmask = managers.slot:get_mask('enemies')
	self.fs_slotmask1 = World:make_slot_mask(1)

	local td = tweak_data.achievement.ranc_9
	local vehicle_pass = not td.vehicle_id or self.tweak_data == td.vehicle_id
	local level_pass = td.job == (managers.job:has_active_job() and managers.job:current_level_id() or '')
	local diff_pass = not td.difficulty or table.contains(td.difficulty, Global.game_settings.difficulty)
	self.fs_eval_ranc_9 = vehicle_pass and level_pass and diff_pass
end

function VehicleDrivingExt:_wake_nearby_dynamics()
	local units = World:find_units_quick('sphere', self._vehicle:position(), 500, self.fs_slotmask1)
	for _, unit in ipairs(units) do
		local damage_ext = unit:damage()
		if damage_ext and not damage_ext.fs_car_destructed and damage_ext:has_sequence('car_destructable') then
			damage_ext:run_sequence_simple('car_destructable')
			damage_ext.fs_car_destructed = true
		end
	end
end

function VehicleDrivingExt:_detect_npc_collisions()
	local vel = self._vehicle:velocity()
	local vel_length = mvec3_len(vel)
	if vel_length < 150 then
		return
	end

	local t = TimerManager:game():time()
	local vl100 = math.clamp(vel_length / 50, 0, 100)

	local oobb = self._unit:oobb()
	local units = _world_find_units(World, 'intersect', 'obb', oobb:center(), oobb:x(), oobb:y(), oobb:z(), self.fs_flesh_slotmask)
	for _, unit in ipairs(units) do
		local movement_ext = unit:alive() and unit:movement()
		local damage_ext = movement_ext and movement_ext._ext_damage
		if damage_ext and (not damage_ext.fs_car_hit_t or t - damage_ext.fs_car_hit_t > 1) then
			damage_ext.fs_car_hit_t = t
			unit:m_position(tmp_vec2)
			self._hit_soundsource:set_position(tmp_vec2)
			self._hit_soundsource:set_rtpc('car_hit_vel', vl100)
			self._hit_soundsource:post_event('car_hit_body_01')

			if not damage_ext:dead() then
				local attack_data = {
					variant = 'explosion',
					damage = damage_ext._HEALTH_INIT or 1000
				}
				local local_player = managers.player:local_player()
				if self._seats.driver.occupant == local_player then
					attack_data.attacker_unit = local_player
				end

				if self.fs_eval_ranc_9 and unit:in_slot(self.fs_enemies_slotmask) then
					local players_inside = {}
					for _, seat in pairs(self._seats) do
						if alive(seat.occupant) and not seat.occupant:brain() then
							table.insert(players_inside, seat.occupant)
						end
					end

					attack_data.players_in_vehicle = players_inside
				end

				damage_ext:damage_mission(attack_data)

				local action = movement_ext._active_actions[1]
				if action and action:type() == 'hurt' then
					action:force_ragdoll(true)
				end

			elseif fs_settings.high_violence_mode then
				managers.enemy:fs_ragdollize(unit)
			end

			mvec3_set(tmp_vec1, vel)
			mvec3_mul(tmp_vec1, 2.5)

			local nr_u_bodies = unit:num_bodies() - 1
			for i_u_body = 0, nr_u_bodies do
				local u_body = unit:body(i_u_body)
				if u_body:enabled() and u_body:dynamic() then
					local body_mass = u_body:mass()
					u_body:push_at(body_mass / math.random(2), tmp_vec1, u_body:position())
				end
				i_u_body = i_u_body + 1
			end
		end
	end
end

local fs_original_vehicledrivingext_settweakdata = VehicleDrivingExt.set_tweak_data
function VehicleDrivingExt:set_tweak_data(...)
	fs_original_vehicledrivingext_settweakdata(self, ...)
	self.fs_loot_points = {}
	for _, loot_point in pairs(self._loot_points) do
		table.insert(self.fs_loot_points, loot_point)
	end
	self:fs_reset_ai_seats()
end

function VehicleDrivingExt:_catch_loot()
	if not self._interaction_loot or self._tweak_data and self._tweak_data.max_loot_bags <= #self._loot then
		return false
	end

	for _, loot_point in ipairs(self.fs_loot_points) do
		if loot_point.object then
			local pos = loot_point.object:position()
			local equipements = World:find_units_quick('sphere', pos, 100, 14)
			for _, unit in ipairs(equipements) do
				local carry_data = unit:carry_data()
				if carry_data and self:_loot_filter_func(carry_data) then
					self:_store_loot(unit)
					break
				end
			end
		end
	end
end

local is_server = Network:is_server()
function VehicleDrivingExt:update(unit, t, dt)
	self:_manage_position_reservation()

	if is_server then
		if self._vehicle:is_active() then
			self:drop_loot()
		end
		self:_catch_loot()
	end

	local ai_seats = self.fs_ai_seats
	for _, seat in ipairs(ai_seats) do
		if alive(seat.occupant) then
			local mov_ext = seat.occupant:movement()
			if mov_ext._ext_damage:is_downed() then
				self:_evacuate_seat(seat)
			else
				local pos = seat.third_object:position()
				mov_ext:set_position(pos)
			end
		end
	end

	self._current_state:update(t, dt)
end

function VehicleDrivingExt:fs_reset_ai_seats()
	self.fs_ai_seats = {}
	for _, seat in pairs(self._seats) do
		if alive(seat.occupant) and seat.occupant:brain() ~= nil then
			table.insert(self.fs_ai_seats, seat)
		end
	end
end

for _, fname in ipairs({
	'reserve_seat',
	'place_player_on_seat',
	'exit_vehicle',
	'_evacuate_seat',
	'on_team_ai_enter',
	'on_drive_SO_completed'
}) do
	local fs_original_vehicledrivingext_func = VehicleDrivingExt[fname]
	VehicleDrivingExt[fname] = function(self, ...)
		local result = fs_original_vehicledrivingext_func(self, ...)
		self:fs_reset_ai_seats()
		return result
	end
end
