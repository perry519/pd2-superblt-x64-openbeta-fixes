local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_characterattentionobject_setsettingsset = CharacterAttentionObject.set_settings_set
function CharacterAttentionObject:set_settings_set(settings_set)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_characterattentionobject_setsettingsset(self, settings_set)
	end

	fs_original_characterattentionobject_setsettingsset(self, settings_set)
	self.rel_cache = {}
end
