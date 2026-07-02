--[string "lib/units/weapons/sentrygunweapon.lua"]:296: attempt to index field '_muzzle_effect_table' (a nil value)
function SentryGunWeapon:fire(blanks, expend_ammo, shoot_player, target_unit)
	if expend_ammo then
		if self._ammo_total <= 0 then
			return
		end
		self:change_ammo(-1)
	end

	local fire_obj = self._effect_align[self._interleaving_fire]
	local from_pos = fire_obj:position()
	local direction = fire_obj:rotation():y()

	mvector3.spread(direction, tweak_data.weapon[self._name_id].SPREAD * self._spread_mul)

	if self._muzzle_effect_table then
		World:effect_manager():spawn(self._muzzle_effect_table[self._interleaving_fire])
	end

	if self._use_shell_ejection_effect then
		World:effect_manager():spawn(self._shell_ejection_effect_table)
	end

	if self._unit:damage() and self._unit:damage():has_sequence("anim_fire_seq") then
		self._unit:damage():run_sequence_simple("anim_fire_seq")
	end

	local ray_res = self:_fire_raycast(from_pos, direction, shoot_player, target_unit)

	if self._alert_events and ray_res.rays then
		RaycastWeaponBase._check_alert(self, ray_res.rays, from_pos, direction, self._unit)
	end

	self._unit:movement():give_recoil()
	self._unit:event_listener():call("on_fire")

	return ray_res
end
