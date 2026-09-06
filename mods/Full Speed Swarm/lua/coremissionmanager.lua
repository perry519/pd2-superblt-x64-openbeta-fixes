local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

core:module('CoreMissionManager')

local fs_original_missionmanager_update = MissionManager.update
function MissionManager:update(t, dt)
	self.project_instigators_cache = {}
	fs_original_missionmanager_update(self, t, dt)
end

function MissionScript:is_debug()
	return false
end

if Network:is_client() then
	_G.DelayedCalls:Add('DelayedModFSS_missionscript_load', 0, function()
		local fs_original_missionscript_load = MissionScript.load
		function MissionScript:load(data)
			fs_original_missionscript_load(self, data)
			if type(data.fs_conf) == 'table' then
				_G.FullSpeedSwarm.host_settings = data.fs_conf
				data.fs_conf = nil
			end
		end
	end)
else
	local fs_original_missionscript_save = MissionScript.save
	function MissionScript:save(data)
		fs_original_missionscript_save(self, data)
		data.fs_conf = _G.FullSpeedSwarm.final_settings
	end
end
