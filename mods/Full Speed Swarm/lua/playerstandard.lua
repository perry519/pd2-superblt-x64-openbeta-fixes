local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerstandard_update = PlayerStandard.update
function PlayerStandard:update(t, dt)
	fs_original_playerstandard_update(self, t, dt)

	if self._equipped_visibility_timer and t > self._equipped_visibility_timer and alive(self._equipped_unit) then
		self._equipped_visibility_timer = nil
	end
end

local fs_original_playerstandard__enter = PlayerStandard._enter
function PlayerStandard:_enter(...)
	if alive(self._equipped_unit) then
		self._equipped_unit:base():set_visibility_state(true)
	end

	return fs_original_playerstandard__enter(self, ...)
end

local fs_original_playerstandard_updattention = PlayerStandard._upd_attention
function PlayerStandard:_upd_attention()
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playerstandard_updattention(self)
	end

	if self._seat and self._was_unarmed and managers.groupai:state():whisper_mode() then
		local preset = {
			'pl_mask_off_friend_combatant',
			'pl_mask_off_friend_non_combatant',
			'pl_mask_off_foe_combatant',
			'pl_mask_off_foe_non_combatant'
		}
		self._ext_movement:set_attention_settings(preset)
	else
		fs_original_playerstandard_updattention(self)
	end
end

local mvec3_dot = mvector3.dot
local mvec3_mul = mvector3.multiply
local mvec3_norm = mvector3.normalize
local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_set_zero = mvector3.set_zero

local hold_to_run, hold_to_duck
local function _update_hold_to_run()
	hold_to_run = managers.user:get_setting('hold_to_run')
end
local function _update_hold_to_duck()
	hold_to_duck = managers.user:get_setting('hold_to_duck')
end

local fs_original_playerstandard_calculatestandardvariables = PlayerStandard._calculate_standard_variables
function PlayerStandard:_calculate_standard_variables(t, dt)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playerstandard_calculatestandardvariables(self, t, dt)
	end

	self._gnd_ray = nil
	self._gnd_ray_chk = nil
	self._unit:m_position(self._pos)
	self._rot = self._unit:rotation()
	self._cam_fwd = self._ext_camera:forward()

	mvec3_set(self._cam_fwd_flat, self._cam_fwd)
	mvec3_set_z(self._cam_fwd_flat, 0)
	mvec3_norm(self._cam_fwd_flat)

	local last_vel_xy = self._last_velocity_xy
	local sampled_vel_dir = self._unit:sampled_velocity()
	if not self._state_data.on_ladder then
		mvec3_set_z(sampled_vel_dir, 0)
	end
	local sampled_vel_len = mvec3_norm(sampled_vel_dir)
	if sampled_vel_len == 0 then
		mvec3_set_zero(self._last_velocity_xy)
	else
		local fwd_dot = mvec3_dot(sampled_vel_dir, last_vel_xy)
		mvec3_set(self._last_velocity_xy, sampled_vel_dir)
		mvec3_mul(self._last_velocity_xy, sampled_vel_len < fwd_dot and sampled_vel_len or math.max(0, fwd_dot))
	end

	self._setting_hold_to_run = hold_to_run
	self._setting_hold_to_duck = hold_to_duck
end

PlayerStandard.fs_update_crosshair_offset = PlayerStandard._update_crosshair_offset
PlayerStandard._update_crosshair_offset = function(self, ...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return self:fs_update_crosshair_offset(...)
	end
end

local fs_original_playerstandard_startactionsteelsight = PlayerStandard._start_action_steelsight
function PlayerStandard:_start_action_steelsight(t, gadget_state)
	fs_original_playerstandard_startactionsteelsight(self, t, gadget_state)
	self:fs_update_crosshair_offset(t)
end

local fs_original_playerstandard_endactionsteelsight = PlayerStandard._end_action_steelsight
function PlayerStandard:_end_action_steelsight(t)
	fs_original_playerstandard_endactionsteelsight(self, t)
	self:fs_update_crosshair_offset(t)
end

DelayedCalls:Add('DelayedModFSS_playerstandardinit', 0, function()
	local fs_original_playerstandard_init = PlayerStandard.init
	function PlayerStandard:init(...)
		fs_original_playerstandard_init(self, ...)
		managers.user:add_setting_changed_callback('hold_to_run', _update_hold_to_run)
		_update_hold_to_run()
		managers.user:add_setting_changed_callback('hold_to_duck', _update_hold_to_duck)
		_update_hold_to_duck()

		local clbk_crosshair = function()
			if self._equipped_unit then
				self:fs_update_crosshair_offset(TimerManager:game():time())
			end
		end
		managers.user:add_setting_changed_callback('accessibility_dot', clbk_crosshair)
		managers.user:add_setting_changed_callback('accessibility_dot_size', clbk_crosshair)
		managers.user:add_setting_changed_callback('accessibility_dot_hide_ads', clbk_crosshair)
	end
end)
