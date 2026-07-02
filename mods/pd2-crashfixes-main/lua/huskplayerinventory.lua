function HuskPlayerInventory:add_unit_by_factory_name(factory_name, equip, instant, blueprint_string, cosmetics_string)
	if not factory_name or not tweak_data.weapon or not tweak_data.weapon.factory then
		return
	end

	local factory_weapon = tweak_data.weapon.factory[factory_name]
	local actual_factory_id = factory_name
	if not factory_weapon then
		if tweak_data.weapon.factory[factory_name .. "_npc"] then
			actual_factory_id = factory_name .. "_npc"
			factory_weapon = tweak_data.weapon.factory[actual_factory_id]
        else return end
	end
	if not factory_weapon.unit then return end

	local blueprint = nil
	if blueprint_string and blueprint_string ~= "" then
		blueprint = managers.weapon_factory:unpack_blueprint_from_string(actual_factory_id, blueprint_string)
	end
	if not blueprint then
		blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(actual_factory_id) or {}
	end

	self:add_unit_by_factory_blueprint(actual_factory_id, equip, instant, blueprint, nil)
end

function HuskPlayerInventory:add_unit_by_factory_blueprint(factory_name, equip, instant, blueprint, cosmetics)
	if not factory_name or not tweak_data.weapon or not tweak_data.weapon.factory then
		return
	end

	local factory_weapon = tweak_data.weapon.factory[factory_name]
	if not factory_weapon or not factory_weapon.unit then return end

	local ids_unit_name = Idstring(factory_weapon.unit)
    if not ids_unit_name then return end
	managers.dyn_resource:load(Idstring("unit"), ids_unit_name, managers.dyn_resource.DYN_RESOURCES_PACKAGE, nil)
	local new_unit
	local ok, result = pcall(function() return World:spawn_unit(ids_unit_name, Vector3(0,0,0), Rotation(0,0,0)) end)
	if ok then
		new_unit = result
	else return end

	new_unit:base():set_factory_data(factory_name)
	new_unit:base():assemble_from_blueprint(factory_name, blueprint or {})
	new_unit:base():check_npc()

	local ignore_units = { self._unit, new_unit }
	if self._ignore_units then
		for _, ig_unit in pairs(self._ignore_units) do
			table.insert(ignore_units, ig_unit)
		end
	end

	local setup_data = {
		user_unit = self._unit,
		ignore_units = ignore_units,
		expend_ammo = false,
		autoaim = false,
		alert_AI = false,
		user_sound_variant = "1"
	}
	new_unit:base():setup(setup_data)

	if new_unit:base().AKIMBO then
		local first, second = self:_align_place(equip, new_unit, "left_hand")
		new_unit:base():create_second_gun(nil, (second and second.obj3d_name) or first.obj3d_name)
	end

	self:add_unit(new_unit, equip, instant)
end
