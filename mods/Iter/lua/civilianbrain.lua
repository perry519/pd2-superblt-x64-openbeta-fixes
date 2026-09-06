local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not Iter.settings.streamline_path then
	return
end

if not Global.game_settings or Global.game_settings.level_id ~= 'pal' then
	return
end

function CivilianBrain:clbk_pathing_results(search_id, path)
	if path and self._logic_data.cool then
		local objective = self:objective()
		if objective and objective.path_style == 'destination' then
			path = CivilianLogicTravel._optimize_path(path)
		end
	end

	CivilianBrain.super.clbk_pathing_results(self, search_id, path)
end
