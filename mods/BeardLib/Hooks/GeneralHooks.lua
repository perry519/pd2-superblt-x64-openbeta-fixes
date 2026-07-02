local F = table.remove(RequiredScript:split("/"))
local Hooks = Hooks

if F == "gamesetup" then
	Hooks:PreHook(GameSetup, "paused_update", "GameSetupPausedUpdateBase", function(self, t, dt)
        Hooks:Call("GameSetupPrePausedUpdate", t, dt)
	end)
	Hooks:PostHook(GameSetup, "paused_update", "GameSetupPausedUpdateBase", function(self, t, dt)
        Hooks:Call("GameSetupPauseUpdate", t, dt)
	end)
	Hooks:PostHook(GameSetup, "init_managers", "BeardLibAddMissingDLCPackagesGameSetup", function(self)
		if managers.dlc.give_missing_package then
			managers.dlc:give_missing_package()
		end
		Hooks:Call("GameSetupInitManagers", self)
	end)
elseif F == "menusetup" then
	Hooks:PostHook(MenuSetup, "init_managers", "BeardLibAddMissingDLCPackagesMenuSetup", function(self)
		if managers.dlc.give_missing_package then
			managers.dlc:give_missing_package()
		end
		Hooks:Call("MenuSetupInitManagers", self)
	end)
elseif F == "setup" then
	Hooks:PreHook(Setup, "update", "BeardLibSetupPreUpdate", function(self, t, dt)
        Hooks:Call("SetupPreUpdate", t, dt)
	end)

	Hooks:PostHook(Setup, "init_managers", "BeardLibAddMissingDLCPackages", function(self)
		Hooks:Call("SetupInitManagers", self)
	end)

	Hooks:PostHook(Setup, "init_finalize", "BeardLibInitFinalize", function(self)
		BeardLib.Managers.Sound:Open()
		Hooks:Call("BeardLibSetupInitFinalize", self)
	end)

	Hooks:PostHook(Setup, "unload_packages", "BeardLibUnloadPackages", function(self)
		BeardLib.Managers.Sound:Close()
		BeardLib.Managers.Package:Unload()
		Hooks:Call("BeardLibSetupUnloadPackages", self)
	end)
elseif F == "localizationmanager" then
	if type(BeardLibInstallStringMethodCompatibility) == "function" then
		BeardLibInstallStringMethodCompatibility()
	end

	local text = LocalizationManager.text
	local unpack_result = unpack or table.unpack
	local function beardlib_safe_localization_text(self, str, macros, ...)
		local custom_loc = self._custom_localizations and self._custom_localizations[str]
		local result
		if custom_loc then
			macros = type(macros) == "table" and macros or {}

			result = string.gsub(tostring(custom_loc), "($([%w_-]+);?)", function(full_match, macro_name)
				local replacement = macros[macro_name] or self._default_macros and self._default_macros[macro_name]
				return replacement ~= nil and replacement or full_match
			end)
		else
			result = text(self, str, macros, ...)
		end

		if self._custom_localizations and self._custom_localizations[str] then
			local recursive_macros = {}
			for macro_name in string.gmatch(result, "%$([%w_-]+)") do
				if self._custom_localizations[macro_name] or Localizer and Localizer.exists and Localizer:exists(Idstring(macro_name)) then
					table.insert(recursive_macros, macro_name)
				end
			end

			table.sort(recursive_macros, function(a, b)
				return string.len(a) > string.len(b)
			end)

			for _, macro_name in ipairs(recursive_macros) do
				result = string.gsub(result, "$" .. macro_name, self:text(macro_name))
			end
		end

		return result
	end

	local function install_safe_localization_text()
		LocalizationManager.text = beardlib_safe_localization_text
	end

	install_safe_localization_text()

	if DelayedCalls and DelayedCalls.Add then
		if not DelayedCalls._beardlib_safe_localization_add then
			DelayedCalls._beardlib_safe_localization_add = DelayedCalls.Add

			function DelayedCalls:Add(id, time, func)
				if id == "DelayedMod_LocalizationManager_recur_text" and type(func) == "function" then
					local wrapped_func = function(...)
						local result = {pcall(func, ...)}
						install_safe_localization_text()

						if not result[1] then
							error(result[2], 2)
						end

						return unpack_result(result, 2)
					end

					return self:_beardlib_safe_localization_add(id, time, wrapped_func)
				end

				return self:_beardlib_safe_localization_add(id, time, func)
			end
		end

		DelayedCalls:Add("BeardLibSafeLocalizationText", 0.05, function()
			install_safe_localization_text()
		end)
	end

	-- Don't you love when you crash just for asking if this shit exist?
	function LocalizationManager:modded_exists(str)
		return self._custom_localizations[str] ~= nil
	end
elseif F == "networkpeer" then
	local NetworkPeerSend = NetworkPeer.send

	function NetworkPeer:send(func_name, ...)
		if not self._ip_verified then
			return
		end
		local params = table.pack(...)
		Hooks:Call("NetworkPeerSend", self, func_name, params)
		NetworkPeerSend(self, func_name, unpack(params, 1, params.n))
	end
elseif F == "tweakdata" then
	TweakDataHelper:Apply()
elseif F == "networktweakdata" then
	if BeardLib:GetGame() ~= "pd2" then
		for _, framework in pairs(BeardLib.Frameworks) do framework:RegisterHooks() end
	end
	--Makes sure that rect can be returned as a null if it's a custom icon
	local get_icon = HudIconsTweakData.get_icon_data
	function HudIconsTweakData:get_icon_data(id, rect, ...)
		local icon, texture_rect = get_icon(self, id, rect, ...)
		local data = self[id]
		if not rect and data and data.custom and not data.texture_rect then
			texture_rect = nil
		end
		return icon, texture_rect
	end
end
