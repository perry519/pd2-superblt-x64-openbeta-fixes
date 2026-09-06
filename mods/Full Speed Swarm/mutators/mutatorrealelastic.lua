_G.MutatorRealElastic = _G.MutatorRealElastic or class(BaseMutator)
MutatorRealElastic._type = 'MutatorRealElastic'
MutatorRealElastic.name_id = 'fs_mutator_realelastic_name'
MutatorRealElastic.desc_id = 'fs_mutator_realelastic_desc'
MutatorRealElastic.has_options = false
MutatorRealElastic.reductions = {money = 0.5, exp = 0.5}
MutatorRealElastic.categories = {'gameplay'}
MutatorRealElastic.icon_coords = {8, 2}
MutatorRealElastic.incompatiblities = {
	'MutatorBigParty'
}

table.insert(FullSpeedSwarm.custom_mutators, MutatorRealElastic)

function MutatorRealElastic:setup()
	FullSpeedSwarm.settings.real_elastic = true
	FullSpeedSwarm:finalize_settings()

	local assault = tweak_data.group_ai.besiege.assault

	local diff = tweak_data:difficulty_to_index(Global.game_settings and Global.game_settings.difficulty or 'normal') - 1
	for i = 1, #assault.force do
		assault.force[i] = assault.force[i] + diff
	end

	for i = 1, #assault.force_pool do
		assault.force_pool[i] = math.ceil(assault.force_pool[i] / 3)
	end

	assault.force_balance_mul = { 1, 1.05, 1.1, 1.15 }
	assault.force_pool_balance_mul = { 1, 1.2, 1.4, 1.6 }

	local original_detection_angles = {}
	local function _set_detection_angles(enabled)
		for name, preset in pairs(tweak_data.character.presets.detection) do
			if name ~= 'blind' then
				original_detection_angles[name] = original_detection_angles[name] or {}
				for stance, data in pairs(preset) do
					if original_detection_angles[name][stance] == nil then
						original_detection_angles[name][stance] = data.angle_max
					end
					local original_angle = original_detection_angles[name][stance]
					data.angle_max = enabled and math.max(original_angle, 160) or original_angle
				end
			end
		end
	end
	_set_detection_angles(FullSpeedSwarm:allow_stealth_changes())
	table.insert(FullSpeedSwarm.call_on_loud, function()
		_set_detection_angles(FullSpeedSwarm:allow_stealth_changes())
	end)
	table.insert(FullSpeedSwarm.call_on_stealth, function()
		_set_detection_angles(FullSpeedSwarm:allow_stealth_changes())
	end)

	if not Keepers or not Keepers.settings.teamais_can_interact then
		local gang_member_damage = tweak_data.character.presets.gang_member_damage
		gang_member_damage.MIN_DAMAGE_INTERVAL = 0.05
		gang_member_damage.REGENERATE_TIME = gang_member_damage.REGENERATE_TIME * 3
		gang_member_damage.REGENERATE_TIME_AWAY = gang_member_damage.REGENERATE_TIME_AWAY * 3
		gang_member_damage.HEALTH_INIT = math.ceil(gang_member_damage.HEALTH_INIT / 3)
	end

	local fs_original_playerdamage_chkdmgtoosoon = PlayerDamage._chk_dmg_too_soon
	PlayerDamage._chk_dmg_too_soon = function(self, damage)
		if self._char_dmg_tweak then
			return fs_original_playerdamage_chkdmgtoosoon(self, damage)
		end
	end

	local fs_original_groupaistatebesiege_performgroupspawning = GroupAIStateBesiege._perform_group_spawning
	function GroupAIStateBesiege:_perform_group_spawning(spawn_task, force, ...)
		fs_original_groupaistatebesiege_performgroupspawning(self, spawn_task, true, ...)

		local spawn_points = spawn_task.spawn_group.spawn_pts
		for _, sp_data in ipairs(spawn_points) do
			sp_data.delay_t = 0
		end
	end
end
