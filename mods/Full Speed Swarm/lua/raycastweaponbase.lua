local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function RaycastWeaponBase:fs_method_ammo_base()
	return self.fs_ammo_base
end

function RaycastWeaponBase:fs_method_weapon_tweak_data()
	return self.fs_weapon_tweak_data
end

RaycastWeaponBase.fs_original_ammo_base = RaycastWeaponBase.ammo_base
RaycastWeaponBase.fs_original_weapon_tweak_data = RaycastWeaponBase.weapon_tweak_data

function RaycastWeaponBase:fs_reset_methods()
	self.fs_ammo_base = self:fs_original_ammo_base()
	self.ammo_base = self.fs_method_ammo_base

	self.fs_weapon_tweak_data = self:fs_original_weapon_tweak_data()
	self.weapon_tweak_data = self.fs_method_weapon_tweak_data
end

local fs_original_raycastweaponbase_onenabled = RaycastWeaponBase.on_enabled
function RaycastWeaponBase:on_enabled()
	self:fs_reset_methods()
	fs_original_raycastweaponbase_onenabled(self)
end

function RaycastWeaponBase:clip_empty()
	return self.fs_ammo_base:get_ammo_remaining_in_clip() == 0
end
