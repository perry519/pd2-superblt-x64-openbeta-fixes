--[string "lib/managers/occlusionmanager.lua"]:53: attempt to perform arithmetic on a boolean value
--[string "lib/managers/occlusionmanager.lua"]:66: attempt to index local 'obj' (a number value)
function _OcclusionManager:remove_occlusion(unit)
	local u_key = unit:key()

	if self._skip_occlusion[u_key] and type(self._skip_occlusion[u_key]) == "number" then
		self._skip_occlusion[u_key] = self._skip_occlusion[u_key] + 1
	else
		self._skip_occlusion[u_key] = 1

		if alive(unit) then
			local objects = unit:get_objects_by_type(self._model_ids)

			for _, obj in pairs(objects) do
				if type(obj) == "userdata" then
					obj:set_skip_occlusion(true)
				end
			end
		end
	end
end

function _OcclusionManager:add_occlusion(unit)
	local u_key = unit:key()

	if self._skip_occlusion[u_key] and type(self._skip_occlusion[u_key]) == "number" then
		self._skip_occlusion[u_key] = self._skip_occlusion[u_key] - 1

		if self._skip_occlusion[u_key] > 0 then
			return
		else
			self._skip_occlusion[u_key] = nil
		end
	end

	if alive(unit) then
		local objects = unit:get_objects_by_type(self._model_ids)

		for _, obj in pairs(objects) do
			if type(obj) == "userdata" then
				obj:set_skip_occlusion(false)
			end
		end
	end
end
