LocalizationManager._custom_localizations = LocalizationManager._custom_localizations or {}

Hooks:RegisterHook("LocalizationManagerPostInit")
Hooks:PostHook(LocalizationManager, "init", "BLT.LocalizationManager.init", function(self)
	Hooks:Call("LocalizationManagerPostInit", self)
end)

local exists = LocalizationManager.exists
function LocalizationManager:exists(str, ...)
	return self._custom_localizations[str] and true or exists(self, str, ...)
end

local text = LocalizationManager.text
function LocalizationManager:text(str, macros, ...)
	local custom_loc = self._custom_localizations[str]
	if custom_loc then
		macros = type(macros) == "table" and macros or {}

		custom_loc = custom_loc:gsub("($([%w_-]+);?)", function(full_match, macro_name)
			return macros[macro_name] or self._default_macros[macro_name] or full_match
		end)

		return custom_loc
	end

	return text(self, str, macros, ...)
end

function LocalizationManager:add_localized_strings(string_table, overwrite)
	-- Should we overwrite existing localization strings
	if overwrite == nil then
		overwrite = true
	end

	if type(string_table) == "table" then
		for k, v in pairs(string_table) do
			if overwrite or not self._custom_localizations[k] then
				self._custom_localizations[k] = v
			end
		end
	end
end

function LocalizationManager:load_localization_file(file_path, overwrite)
	-- Should we overwrite existing localization strings
	if overwrite == nil then
		overwrite = true
	end

	local file = io.open(file_path, "r")
	if file then
		local file_contents = file:read("*all")
		file:close()

		local contents = json.decode(file_contents)
		self:add_localized_strings(contents, overwrite)
	end
end
