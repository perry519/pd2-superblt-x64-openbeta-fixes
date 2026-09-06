local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not Iter.settings.streamline_path then
	return
end

function TeamAIBrain:clbk_pathing_results(search_id, path)
	if path then
		local objective = self._logic_data.objective
		if objective and objective.type == 'revive' or managers.groupai:state():whisper_mode() then
			path = CivilianLogicTravel._optimize_path(path, true)
		end
	end

	TeamAIBrain.super.clbk_pathing_results(self, search_id, path)
end
