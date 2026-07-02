function WeaponFactoryManager:is_part_valid(part_id)
	if not part_id or type(part_id) ~= "string" then return false end
	if tweak_data and tweak_data.weapon	and tweak_data.weapon.factory and tweak_data.weapon.factory.parts then
		return tweak_data.weapon.factory.parts[part_id]
	else
		return false
	end
end
