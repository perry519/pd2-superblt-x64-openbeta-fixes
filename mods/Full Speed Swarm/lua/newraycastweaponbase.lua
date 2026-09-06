local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_newraycastweaponbase_init = NewRaycastWeaponBase.init
function NewRaycastWeaponBase:init(...)
	fs_original_newraycastweaponbase_init(self, ...)

	self:fs_reset_methods()
end

local fs_original_newraycastweaponbase_resetcachedgadget = NewRaycastWeaponBase.reset_cached_gadget
function NewRaycastWeaponBase:reset_cached_gadget()
	fs_original_newraycastweaponbase_resetcachedgadget(self)

	self:fs_reset_methods()
end

local fs_original_newraycastweaponbase_togglefiremode = NewRaycastWeaponBase.toggle_firemode
function NewRaycastWeaponBase:toggle_firemode(...)
	local result = fs_original_newraycastweaponbase_togglefiremode(self, ...)

	self:fs_reset_methods()

	return result
end
