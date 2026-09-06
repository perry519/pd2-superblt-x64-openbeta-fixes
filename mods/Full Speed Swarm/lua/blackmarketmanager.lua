local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_blackmarketmanager_equippedgrenade = BlackMarketManager.equipped_grenade
local fs_original_blackmarketmanager_equippedarmor = BlackMarketManager.equipped_armor

function BlackMarketManager:fs_overwrite_functions()
	local id, amount = managers.blackmarket:equipped_grenade()
	function BlackMarketManager:equipped_grenade()
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_blackmarketmanager_equippedgrenade(self)
		end

		return id, amount
	end

	local armor_id = self:equipped_armor()
	local armor = self._global.armors[armor_id]
	armor_id = armor.equipped and armor.unlocked and armor.owned and armor_id or self._defaults.armor
	local has_armor_kit = managers.player:equipment_slot('armor_kit')
	local managers_player = managers.player
	local default_armor = self._defaults.armor
	function BlackMarketManager:equipped_armor(chk_armor_kit, chk_player_state)
		if not FullSpeedSwarm:allow_stealth_changes() then
			return fs_original_blackmarketmanager_equippedarmor(self, chk_armor_kit, chk_player_state)
		end

		if armor_id == default_armor then
			return default_armor, true
		elseif chk_player_state and managers_player:current_state() == 'civilian' then
			return default_armor
		elseif chk_armor_kit and has_armor_kit then
			if managers_player:get_equipment_amount('armor_kit') > 0 or game_state_machine and game_state_machine:current_state_name() == 'ingame_waiting_for_players' then
				return default_armor
			end
		end

		return armor_id, true
	end

	local fs_original_blackmarketmanager_equippedprimary = BlackMarketManager.equipped_primary
	function BlackMarketManager:equipped_primary()
		local result = fs_original_blackmarketmanager_equippedprimary(self)
		self.equipped_primary = function()
			return result
		end
		return result
	end

	local fs_original_blackmarketmanager_equippedsecondary = BlackMarketManager.equipped_secondary
	function BlackMarketManager:equipped_secondary()
		local result = fs_original_blackmarketmanager_equippedsecondary(self)
		self.equipped_secondary = function()
			return result
		end
		return result
	end
end

function BlackMarketManager:is_weapon_modified(factory_id, blueprint)
	local weapon = tweak_data.weapon.factory[factory_id]
	if not weapon then
		return false
	end

	local default_blueprint = weapon.default_blueprint

	for _, part_id in ipairs(blueprint) do
		if not table.icontains(default_blueprint, part_id) then
			return true
		end
	end

	return false
end

local fs_original_blackmarketmanager_forcedprimary = BlackMarketManager.forced_primary
function BlackMarketManager:forced_primary()
	local result = fs_original_blackmarketmanager_forcedprimary(self)
	self.forced_primary = function()
		return result
	end
	return result
end

local fs_original_blackmarketmanager_forcedsecondary = BlackMarketManager.forced_secondary
function BlackMarketManager:forced_secondary()
	local result = fs_original_blackmarketmanager_forcedsecondary(self)
	self.forced_secondary = function()
		return result
	end
	return result
end
