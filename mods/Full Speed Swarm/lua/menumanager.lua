local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

Hooks:Add('LocalizationManagerPostInit', 'LocalizationManagerPostInit_FullSpeedSwarm', function(loc)
	local language_filename

	local modname_to_language = {
		['PAYDAY 2 THAI LANGUAGE Mod'] = 'thai.txt',
	}
	for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
		language_filename = mod:IsEnabled() and modname_to_language[mod:GetName()]
		if language_filename then
			break
		end
	end

	if not language_filename then
		for _, filename in pairs(file.GetFiles(FullSpeedSwarm._path .. 'loc/')) do
			local str = filename:match('^(.*).txt$')
			if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
				language_filename = filename
				break
			end
		end
	end

	if language_filename then
		loc:load_localization_file(FullSpeedSwarm._path .. 'loc/' .. language_filename)
	end
	loc:load_localization_file(FullSpeedSwarm._path .. 'loc/english.txt', false)
end)

Hooks:Add('MenuManagerInitialize', 'MenuManagerInitialize_FullSpeedSwarm', function(menu_manager)

	MenuCallbackHandler.FullSpeedSwarmMenuCheckboxClbk = function(this, item)
		FullSpeedSwarm.settings[item:name()] = item:value() == 'on'
	end

	MenuCallbackHandler.FullSpeedSwarmMenuValueClbk = function(this, item)
		FullSpeedSwarm.settings[item:name()] = item:value()
	end

	local function apply_runtime_settings()
		FullSpeedSwarm:finalize_settings()
		FullSpeedSwarm:refresh_mode_sensitive_state()
	end

	MenuCallbackHandler.FullSpeedSwarmChangedFocus = function(node, focus)
		if focus then
			local menu = MenuHelper:GetMenu('fs_options_menu')
			local options = FullSpeedSwarm:get_gameplay_options_forced_values()
			for item_id, value in pairs(options) do
				local menu_item = menu:item(item_id)
				if menu_item then
					menu_item:set_enabled(false)
					menu_item:set_value(type(value) == 'number' and value or value and 'on' or 'off')
				end
			end
		else
			apply_runtime_settings()
		end
	end

	MenuCallbackHandler.FullSpeedSwarmSetTaskThroughput = function(self, item)
		FullSpeedSwarm.settings.task_throughput = math.floor(item:value())
		FullSpeedSwarm:update_max_task_throughput()
	end

	MenuCallbackHandler.FullSpeedSwarmSave = function(this, item)
		apply_runtime_settings()
		FullSpeedSwarm:save()
	end

	if not Iter then
		FullSpeedSwarm.settings.iter_chase = false
	end

	MenuHelper:LoadFromJsonFile(FullSpeedSwarm._path .. 'menu/options.txt', FullSpeedSwarm, FullSpeedSwarm.settings)

end)

local fs_original_menucallbackhandler_updateoutfitinformation = MenuCallbackHandler._update_outfit_information
function MenuCallbackHandler:_update_outfit_information()
	fs_original_menucallbackhandler_updateoutfitinformation(self)
	managers.player:fs_refresh_body_armor_skill_multiplier()
	managers.player:fs_reset_max_health()
end
