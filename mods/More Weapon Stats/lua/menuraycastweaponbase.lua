local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local original_raycast_weapon_base = RaycastWeaponBase
local menu_raycast_weapon_base = NewRaycastWeaponBase or class()

NewRaycastWeaponBase = menu_raycast_weapon_base
require('lib/units/weapons/CosmeticsWeaponBase')
require('lib/units/weapons/ScopeBase')

NewRaycastWeaponBase = nil
require('lib/units/weapons/RaycastWeaponBase')
require('lib/units/weapons/NewRaycastWeaponBase')

Faker.classes.RaycastWeaponBase = RaycastWeaponBase
Faker:redo_class('NewRaycastWeaponBase', 'RaycastWeaponBase')

RaycastWeaponBase = original_raycast_weapon_base
NewRaycastWeaponBase = menu_raycast_weapon_base
