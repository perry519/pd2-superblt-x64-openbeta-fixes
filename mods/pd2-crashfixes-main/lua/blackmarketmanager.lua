--[string "lib/managers/blackmarketmanager.lua"]:1388: attempt to index local 'equipped' (a nil value)
local __outfit_string_mask = BlackMarketManager._outfit_string_mask
function BlackMarketManager:_outfit_string_mask()
	local bm = managers.blackmarket or nil
	if bm and type(bm.equipped_mask) == "function" and
		(
			type(bm:equipped_mask()) == "string" or type(bm:equipped_mask()) == "table"
		)
		then
		return __outfit_string_mask(self)
	end
	return "character_locked nothing no_color_no_material plastic"
end

--[string "lib/managers/blackmarketmanager.lua"]:1572: attempt to index local 'weapon' (a nil value)
local _get_silencer_concealment_modifiers = BlackMarketManager.get_silencer_concealment_modifiers
function BlackMarketManager:get_silencer_concealment_modifiers(weapon)
	if 
		type(weapon) == "table" and
		type(weapon.factory_id) == "string" and
		type(weapon.blueprint) == "table"
	then
		return _get_silencer_concealment_modifiers(self, weapon)
	end
	return 0
end

--[string "lib/managers/blackmarketmanager.lua"]:3026: attempt to index local 'weapon' (a nil value)
local __calculate_weapon_concealment = BlackMarketManager._calculate_weapon_concealment
function BlackMarketManager:_calculate_weapon_concealment(weapon)
	if 
		type(weapon) == "table" and
		type(weapon.factory_id) == "string" and
		type(weapon.blueprint) == "table"
	then
		return __calculate_weapon_concealment(self, weapon)
	end
	return 0
end

function BlackMarketManager:set_equipped_armor_skin(skin_id, loading)
	if not skin_id then
		return
	end

	local skin_data = tweak_data and tweak_data.economy and tweak_data.economy.armor_skins and tweak_data.economy.armor_skins[skin_id] or nil

	if not skin_data then
		return
	end

	Global.blackmarket_manager.equipped_armor_skin = skin_id

	if not loading then
		if managers.menu_scene and alive(managers.menu_scene._character_unit) then
			local skin = tweak_data.economy:get_armor_skin_id(skin_id)

			managers.menu_scene._character_unit:base():set_cosmetics_data(skin)
		end

		MenuCallbackHandler:_update_outfit_information()
	end
end
function BlackMarketManager:get_weapon_icon_path(weapon_id, cosmetics)
    local akimbo_gui_data = tweak_data.weapon[weapon_id] and tweak_data.weapon[weapon_id].akimbo_gui_data
    local use_cosmetics = cosmetics and cosmetics.id and cosmetics.id ~= "nil" and true or false
    local data = use_cosmetics and tweak_data.blackmarket.weapon_skins or tweak_data.weapon
    local id = use_cosmetics and cosmetics.id or akimbo_gui_data and akimbo_gui_data.weapon_id or weapon_id
    local path = use_cosmetics and "weapon_skins/" or "textures/pd2/blackmarket/icons/weapons/"
    local weapon_tweak = data and id and data[id]
    local texture_path, rarity_path = nil

    if weapon_tweak then
        local guis_catalog = "guis/"
        local bundle_folder = weapon_tweak.texture_bundle_folder

        local is_tam_skin = use_cosmetics
            and weapon_tweak.global_value == "tam"
            and not weapon_tweak.is_a_color_skin
            and string.match(cosmetics.id, "tam")

        if is_tam_skin then
            if bundle_folder then
                guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
            end
            local texture_name = weapon_tweak.texture_name or tostring(id)
            texture_path = guis_catalog .. path .. texture_name
            if use_cosmetics then
                if weapon_tweak.color then
                    rarity_path = "guis/dlcs/wcs/textures/pd2/blackmarket/icons/rarity_color"
                    texture_path = self:get_weapon_icon_path(weapon_id, nil)
                else
                    local rarity = weapon_tweak.rarity or "common"
                    rarity_path = tweak_data.economy.rarities[rarity] and tweak_data.economy.rarities[rarity].bg_texture
                end
            end
        else
            if bundle_folder then
                guis_catalog = guis_catalog .. "dlcs/"
                if use_cosmetics and weapon_tweak.texture_bundle_folder_is_short then
                    guis_catalog = guis_catalog .. "cash/safes/"
                end
                guis_catalog = guis_catalog .. tostring(bundle_folder) .. "/"
            end
            local texture_name = nil
            if use_cosmetics then
                local skin_data = tweak_data.blackmarket.weapon_skins[cosmetics.id]
				local is_there_even_fucking_data = skin_data
                local is_cosmetic_base_weapon_id = is_there_even_fucking_data and skin_data.weapon_id == weapon_id or false
                if is_cosmetic_base_weapon_id and is_there_even_fucking_data then
                    texture_name = cosmetics.id
				elseif is_there_even_fucking_data then
                    texture_name = cosmetics.id .. "_" .. weapon_id
                else
					texture_name = nil
				end
            else
                texture_name = weapon_tweak.texture_name or tostring(id)
            end
			if not texture_name then
				texture_path = nil
			else
				texture_path = guis_catalog .. path .. texture_name
			end
            if use_cosmetics then
                if weapon_tweak.color then
                    rarity_path = "guis/dlcs/wcs/textures/pd2/blackmarket/icons/rarity_color"
                    texture_path = self:get_weapon_icon_path(weapon_id, nil)
                else
                    local rarity = weapon_tweak.rarity or "common"
                    rarity_path = tweak_data.economy.rarities[rarity] and tweak_data.economy.rarities[rarity].bg_texture
                end
            end
        end
    end

    return texture_path, rarity_path
end

function BlackMarketManager:_on_load_update_crafted_items()
	local crafted = self._global.crafted_items

	if not crafted then
		return
	end

	for category, category_crafts in pairs(crafted) do
		for i, crafted in ipairs(category_crafts) do
			if crafted.customize_locked and type(crafted.customize_locked) == "boolean" then

				if crafted.cosmetics and crafted.cosmetics.id then
					local skin_data = tweak_data.blackmarket.weapon_skins[crafted.cosmetics.id]
					if skin_data then
						crafted.customize_locked = skin_data.locked
					end
				end
			end
		end
	end
end
