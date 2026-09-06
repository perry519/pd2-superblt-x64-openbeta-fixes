local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playermanager_bodyarmorvalue = PlayerManager.body_armor_value
local fs_original_playermanager_healthskilladdend = PlayerManager.health_skill_addend
local fs_original_playermanager_hascategoryupgrade = PlayerManager.has_category_upgrade
local fs_original_playermanager_gethostagebonusaddend = PlayerManager.get_hostage_bonus_addend
local fs_original_playermanager_bodyarmorskilladdend = PlayerManager.body_armor_skill_addend
local fs_original_playermanager_bodyarmorskillmultiplier = PlayerManager.body_armor_skill_multiplier
local fs_original_playermanager_getvaluefromriskupgrade = PlayerManager.get_value_from_risk_upgrade

function PlayerManager:fs_overwrite_functions()
	local mblackmarket = managers.blackmarket
	local td_armors = tweak_data.blackmarket.armors

	if self:equipment_slot('armor_kit') then
		local upgrade_default = {}
		function PlayerManager:body_armor_value(category, override_value, default)
			if not FullSpeedSwarm:allow_stealth_changes() then
				return fs_original_playermanager_bodyarmorvalue(self, category, override_value, default)
			end

			local level = override_value or td_armors[mblackmarket:equipped_armor(true, true)].upgrade_level
			return self:upgrade_value_by_level('player', 'body_armor', category, upgrade_default)[level] or default or 0
		end
	else
		local cached_body_armor_value = {}
		function PlayerManager:body_armor_value(category, override_value, default)
			if not FullSpeedSwarm:allow_stealth_changes() then
				return fs_original_playermanager_bodyarmorvalue(self, category, override_value, default)
			end

			if override_value then
				return self:upgrade_value_by_level('player', 'body_armor', category, {})[override_value] or default or 0
			else
				local result = cached_body_armor_value[category]
				if not result then
					local armor_id, cacheable = mblackmarket:equipped_armor(true, true)
					result = self:upgrade_value_by_level('player', 'body_armor', category, {})[td_armors[armor_id].upgrade_level] or default or 0
					if cacheable then
						cached_body_armor_value[category] = result
					end
				end
				return result
			end
		end
	end
end

local fs_original_playermanager_init = PlayerManager.init
function PlayerManager:init()
	fs_original_playermanager_init(self)
	self.fs_equipment_slots = {}
	self:fs_reset_max_health()
end

function PlayerManager:fs_reset_max_health()
	self.fs_current_max_health = (PlayerDamage._HEALTH_INIT + self:health_skill_addend()) * self:health_skill_multiplier()
end

local fs_original_playermanager_verifyequipmentkit = PlayerManager._verify_equipment_kit
function PlayerManager:_verify_equipment_kit(...)
	fs_original_playermanager_verifyequipmentkit(self, ...)
	self.fs_equipment_slots = table.list_to_set(self._global.kit.equipment_slots)
end

local fs_original_playermanager_setequipmentinslot = PlayerManager.set_equipment_in_slot
function PlayerManager:set_equipment_in_slot(...)
	fs_original_playermanager_setequipmentinslot(self, ...)
	self.fs_equipment_slots = table.list_to_set(self._global.kit.equipment_slots)
end

function PlayerManager:health_skill_addend()
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_healthskilladdend(self)
	end

	local addend = self:upgrade_value('team', 'crew_add_health', 0)
	if self.fs_equipment_slots.thick_skin then -- historical value ;)
		addend = addend + self:upgrade_value('player', 'thick_skin', 0)
	end
	return addend
end

if not _G.IS_VR then
	local fs_original_playermanager_exitvehicle = PlayerManager.exit_vehicle
	function PlayerManager:exit_vehicle()
		fs_original_playermanager_exitvehicle(self)
		managers.interaction.fs_reset_ordered_list()
	end
end

function PlayerManager:fs_max_movement_speed_multiplier()
	local armor_penalty = self:mod_movement_penalty(self:body_armor_value('movement', false, 1))
	local multiplier = 1
		+ (armor_penalty - 1)
		+ (self:upgrade_value('player', 'run_speed_multiplier', 1) - 1)
		+ (self:upgrade_value('player', 'movement_speed_multiplier', 1) - 1)
		-- no mrwi: crouch/carry no max

	if self:has_category_upgrade('player', 'minion_master_speed_multiplier') then
		multiplier = multiplier + (self:upgrade_value('player', 'minion_master_speed_multiplier', 1) - 1)
	end

	local damage_health_ratio = self:get_damage_health_ratio(0.01, 'movement_speed')
	multiplier = multiplier * (1 + self:upgrade_value('player', 'movement_speed_damage_health_ratio_multiplier', 0) * damage_health_ratio)

	if self:has_category_upgrade('temporary', 'damage_speed_multiplier') then
		local damage_speed_multiplier = self:upgrade_value('temporary', 'damage_speed_multiplier', self:upgrade_value('temporary', 'team_damage_speed_multiplier_received', 1))
		multiplier = multiplier * ((damage_speed_multiplier[1] - 1) * 0.5 + 1)
	end

	return multiplier
end

function PlayerManager:has_category_upgrade(category, upgrade)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_hascategoryupgrade(self, category, upgrade)
	end

	local upgs_ctg = self._global.upgrades[category]
	if upgs_ctg and upgs_ctg[upgrade] then
		return true
	end
	return false
end

local cached_upgrade_values = {}

local fs_original_playermanager_aquireupgrade = PlayerManager.aquire_upgrade
function PlayerManager.aquire_upgrade(...)
	cached_upgrade_values = {}
	fs_original_playermanager_aquireupgrade(...)
end

local fs_original_playermanager_aquireincrementalupgrade = PlayerManager.aquire_incremental_upgrade
function PlayerManager.aquire_incremental_upgrade(...)
	cached_upgrade_values = {}
	fs_original_playermanager_aquireincrementalupgrade(...)
end

local fs_original_playermanager_unaquireincrementalupgrade = PlayerManager.unaquire_incremental_upgrade
function PlayerManager.unaquire_incremental_upgrade(...)
	cached_upgrade_values = {}
	fs_original_playermanager_unaquireincrementalupgrade(...)
end

local fs_original_playermanager_upgradevalue = PlayerManager.upgrade_value
function PlayerManager:upgrade_value(category, upgrade, default)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_upgradevalue(self, category, upgrade, default)
	end

	local key = category .. upgrade .. tostring(default)
	local cached_value = cached_upgrade_values[key]
	if cached_value ~= nil then
		return cached_value
	end

	local result = fs_original_playermanager_upgradevalue(self, category, upgrade, default)
	cached_upgrade_values[key] = result
	return result
end

local cached_team_upgrade_values = {}

local fs_original_playermanager_aquireteamupgrade = PlayerManager.aquire_team_upgrade
function PlayerManager.aquire_team_upgrade(...)
	cached_team_upgrade_values = {}
	fs_original_playermanager_aquireteamupgrade(...)
end

local fs_original_playermanager_unaquireteamupgrade = PlayerManager.unaquire_team_upgrade
function PlayerManager.unaquire_team_upgrade(...)
	cached_team_upgrade_values = {}
	fs_original_playermanager_unaquireteamupgrade(...)
end

local fs_original_playermanager_teamupgradevalue = PlayerManager.team_upgrade_value
function PlayerManager:team_upgrade_value(category, upgrade, default)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_teamupgradevalue(self, category, upgrade, default)
	end

	local key = category .. upgrade .. tostring(default)
	local cached_value = cached_team_upgrade_values[key]
	if cached_value ~= nil then
		return cached_value
	end

	local result = fs_original_playermanager_teamupgradevalue(self, category, upgrade, default)
	cached_team_upgrade_values[key] = result
	return result
end

local cached_hostage_bonus_multiplier = {}

function PlayerManager:reset_cached_hostage_bonus_multiplier()
	cached_hostage_bonus_multiplier = {}
end

local fs_original_playermanager_gethostagebonusmultiplier = PlayerManager.get_hostage_bonus_multiplier
function PlayerManager:get_hostage_bonus_multiplier(category)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_gethostagebonusmultiplier(self, category)
	end

	local key = category .. (self._is_local_close_to_hostage and 'y' or 'n')
	local result = cached_hostage_bonus_multiplier[key]
	if not result then
		result = fs_original_playermanager_gethostagebonusmultiplier(self, category)
		cached_hostage_bonus_multiplier[key] = result
	end
	return result
end

function PlayerManager:get_hostage_bonus_addend(category)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_gethostagebonusaddend(self, category)
	end

	local groupai = managers.groupai
	local hostages = groupai and groupai:state():hostage_count() or 0
	local minions = self:num_local_minions() or 0
	hostages = hostages + minions

	if hostages == 0 then
		return 0
	end

	local hostage_max_num = tweak_data:get_raw_value('upgrades', 'hostage_max_num', category)
	if hostage_max_num then
		hostages = math.min(hostages, hostage_max_num)
	end

	local addend = self:team_upgrade_value(category, 'hostage_addend', 0)
		+ self:team_upgrade_value(category, 'passive_hostage_addend', 0)
		+ self:upgrade_value('player', 'hostage_' .. category .. '_addend', 0)
		+ self:upgrade_value('player', 'passive_hostage_' .. category .. '_addend', 0)
	local local_player = self:local_player()
	if self:has_category_upgrade('player', 'close_to_hostage_boost') and self._is_local_close_to_hostage then
		addend = addend * tweak_data.upgrades.hostage_near_player_multiplier
	end
	return addend * hostages
end

function PlayerManager:body_armor_skill_addend(override_armor)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_bodyarmorskilladdend(self, override_armor)
	end

	local addend = self:upgrade_value('player', tostring(override_armor or managers.blackmarket:equipped_armor(true, true)) .. '_armor_addend', 0)
		+ self.fs_current_max_health * self:upgrade_value('player', 'armor_increase', 0)
		+ self:upgrade_value('team', 'crew_add_armor', 0)
	return addend
end

function PlayerManager:fs_body_armor_skill_multiplier(override_armor)
	local multiplier = self.fs_bas_multiplier
		+ self:team_upgrade_value('armor', 'multiplier', 1)
		+ self:get_hostage_bonus_multiplier('armor')
		+ self:upgrade_value('player', tostring(override_armor or managers.blackmarket:equipped_armor(true, true)) .. '_armor_multiplier', 1)
		+ self:upgrade_value('player', 'chico_armor_multiplier', 1)
		+ self:upgrade_value('player', 'mrwi_armor_multiplier', 1)
	return multiplier - 5
end

function PlayerManager:fs_refresh_body_armor_skill_multiplier()
	local multiplier = 1
		+ self:upgrade_value('player', 'tier_armor_multiplier', 1)
		+ self:upgrade_value('player', 'passive_armor_multiplier', 1)
		+ self:upgrade_value('player', 'armor_multiplier', 1)
		+ self:upgrade_value('player', 'perk_armor_loss_multiplier', 1)
	self.fs_bas_multiplier = multiplier - 4
end

function PlayerManager:body_armor_skill_multiplier(override_armor)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_bodyarmorskillmultiplier(self, override_armor)
	end

	self.body_armor_skill_multiplier = self.fs_body_armor_skill_multiplier

	self:fs_refresh_body_armor_skill_multiplier()
	return self:fs_body_armor_skill_multiplier(override_armor)
end

local ids_carrydata = Idstring('carry_data')
local fs_original_playermanager_synccarrydata = PlayerManager.sync_carry_data
function PlayerManager:sync_carry_data(unit, ...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_synccarrydata(self, unit, ...)
	end

	unit:set_extension_update_enabled(ids_carrydata, true)
	fs_original_playermanager_synccarrydata(self, unit, ...)
end

function PlayerManager:get_value_from_risk_upgrade(risk_upgrade, detection_risk)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playermanager_getvaluefromriskupgrade(self, risk_upgrade, detection_risk)
	end

	local risk_value = 0

	if type(risk_upgrade) == 'table' then
		if not detection_risk then
			detection_risk = managers.blackmarket:get_suspicion_offset_of_local(tweak_data.player.SUSPICION_OFFSET_LERP or 0.75)
			detection_risk = math.round(detection_risk * 100)
		end

		local value = risk_upgrade[1]
		local step = risk_upgrade[2]
		local operator = risk_upgrade[3]
		local threshold = risk_upgrade[4]
		local cap = risk_upgrade[5]
		local num_steps = 0

		if operator == 'above' then
			num_steps = math.max(math.floor((detection_risk - threshold) / step), 0)
		elseif operator == 'below' then
			num_steps = math.max(math.floor((threshold - detection_risk) / step), 0)
		end

		risk_value = num_steps * value
		if cap then
			risk_value = math.min(cap, risk_value) or risk_value
		end
	end

	return risk_value
end
