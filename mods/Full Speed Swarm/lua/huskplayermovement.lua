local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local mvec3_len = mvector3.length
local mvec3_norm = mvector3.normalize
local mvec3_set = mvector3.set
local mvec3_sub = mvector3.subtract

local fs_original_huskplayermovement_syncstartautofiresound = HuskPlayerMovement.sync_start_auto_fire_sound
function HuskPlayerMovement:sync_start_auto_fire_sound(...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_huskplayermovement_syncstartautofiresound(self, ...)
	end

	if alive(self._unit:inventory():equipped_unit()) then
		fs_original_huskplayermovement_syncstartautofiresound(self, ...)
	end
end

local fs_original_huskplayermovement_update = HuskPlayerMovement.update
function HuskPlayerMovement:update(unit, t, dt)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_huskplayermovement_update(self, unit, t, dt)
	end

	if not self:_has_finished_loading() then
		return
	end

	self:_calculate_m_pose()

	if self._updator_movement then
		self:_updator_movement(t, dt)
	else
		self:_upd_move_standard(t, dt)
	end

	if self._updator_attention then
		self:_updator_attention(t, dt)
	else
		self:_upd_attention_standard(t, dt)
	end

	self:_upd_stance(t)

	if alive(self._unit) then
		if not self.fs_char_data then
			self.fs_char_data = managers.criminals:character_data_by_unit(self._unit)
		end

		local panel_id = self.fs_char_data and self.fs_char_data.panel_id
		if panel_id then
			if self._state == 'civilian' then
				managers.hud:hide_player_gear(panel_id)
			else
				managers.hud:show_player_gear(panel_id)
			end
		end

		if not self._peer_weapon_spawned then
			local inventory = self._unit:inventory()
			if inventory and inventory.check_peer_weapon_spawn then
				self._peer_weapon_spawned = inventory:check_peer_weapon_spawn()
			else
				self._peer_weapon_spawned = true
			end
		end
	end

	if self._auto_firing >= 2 and not self._ext_anim.reload then
		local equipped_weapon = self._unit:inventory():equipped_unit()
		if alive(equipped_weapon) and equipped_weapon:base().auto_trigger_held then
			equipped_weapon:base():auto_trigger_held(self._look_dir, true, self._firing, self:_use_weapon_fire_dir())
			self._aim_up_expire_t = t + 2
		end
	end

	if self._ext_anim and self._ext_anim.reload then
		if not alive(self._left_hand_obj) then
			self._left_hand_obj = self._unit:get_object(Idstring('LeftHandMiddle1'))
		end

		if alive(self._left_hand_obj) then
			if self._left_hand_pos then
				self._left_hand_direction = self._left_hand_direction or Vector3()
				mvec3_set(self._left_hand_direction, self._left_hand_pos)
				mvec3_sub(self._left_hand_direction, self._left_hand_obj:position())
				self._left_hand_velocity = mvec3_len(self._left_hand_direction)
				mvec3_norm(self._left_hand_direction)
			end
			self._left_hand_pos = self._left_hand_pos or Vector3()
			mvec3_set(self._left_hand_pos, self._left_hand_obj:position())
		end
	end

	if self._delayed_redirects then
		for i, redirect in ipairs(self._delayed_redirects) do
			redirect.t = redirect.t - dt
			if redirect.t <= 0 then
				self:play_redirect(unpack(redirect.args))
				table.remove(self._delayed_redirects, i)
			end
		end
	end

	if self._retry_sync_movement_state_driving then
		self._retry_sync_movement_state_driving = nil
		if self._state == 'driving' then
			self:_sync_movement_state_driving()
		end
	end

	if self._retry_sync_movement_state_player_turret then
		self._retry_sync_movement_state_player_turret = nil
		if self._state == 'player_turret' then
			self:_sync_movement_state_player_turret()
		end
	end

	self._arm_animator:update(t, dt)
end

if Network:is_server() then
	local fs_original_huskplayermovement_syncmovementstate = HuskPlayerMovement.sync_movement_state
	function HuskPlayerMovement:sync_movement_state(state, ...)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_huskplayermovement_syncmovementstate(self, state, ...)
		end

		if state == 'arrested' then
			managers.groupai:state():fs_destroy_attention_object(self._unit:key())
		end

		fs_original_huskplayermovement_syncmovementstate(self, state, ...)
	end
end
