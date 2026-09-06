local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_elementlasertrigger_setdummiesvisible = ElementLaserTrigger._set_dummies_visible
function ElementLaserTrigger:_set_dummies_visible(...)
	local dummy_units = self._dummy_units
	if type(dummy_units) == 'table' then
		for i = #dummy_units, 1, -1 do
			if not alive(dummy_units[i]) then
				table.remove(dummy_units, i)
			end
		end
	end

	fs_original_elementlasertrigger_setdummiesvisible(self, ...)
end
