core:module("CorePortalManager")
core:import("CoreShapeManager")

-- [string "core/lib/managers/coreportalmanager.lua"]:652: attempt to index a number value
function PortalUnitGroup:_change_units_visibility(diff)
	for i = #self._units, 1, -1 do
		local unit = self._units[i]
		if type(unit) ~= "userdata" or not alive(unit) then
			table.remove(self._units, i)
		else
			self:_change_visibility(unit, diff)
		end
	end
end
local __change_visibility = PortalUnitGroup._change_visibility
function PortalUnitGroup:_change_visibility(unit, diff)
	if type(unit) ~= "userdata" or not alive(unit) then return end
	if type(unit:unit_data()) ~= "table" then return end
	if type(unit:unit_data()._visibility_counter) ~= "number" then unit:unit_data()._visibility_counter = 0 end
	__change_visibility(self, unit, diff)
end
