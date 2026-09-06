local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

local fs_original_explosionmanager_unitstopush = ExplosionManager.units_to_push
function ExplosionManager:units_to_push(units_to_push, ...)
	if fs_settings.high_violence_mode then
		for u_key, unit in pairs(units_to_push) do
			if unit:alive() and unit:slot() == 17 then
				local dmg_ext = unit:character_damage()
				if dmg_ext and dmg_ext.damage_explosion then
					managers.enemy:fs_ragdollize(unit)
				end
			end
		end
	end

	fs_original_explosionmanager_unitstopush(self, units_to_push, ...)
end
