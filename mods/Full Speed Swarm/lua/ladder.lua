local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

for obj_name, ext_name in pairs({
	CopSound = 'sound',
	GageAssignmentBase = 'base',
	NetworkBaseExtension = 'network',
	Pickup = 'pickup',
	PlayerAnimationData = 'anim_data',
	PlayerEquipment = 'equipment',
	PlayerInventory = 'inventory',
	PlayerSound = 'sound',
	ScriptUnitData = 'unit_data',
	TeamAISound = 'sound',
}) do
	local fs_original_object_init = _G[obj_name].init
	_G[obj_name].init = function(self, unit)
		fs_original_object_init(self, unit)
		if type(unit) == 'userdata' then
			unit:set_extension_update_enabled(Idstring(ext_name), false)
		end
	end
end
