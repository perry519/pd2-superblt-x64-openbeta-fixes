--	_set_dummies_visible()  lib/managers/mission/elementlasertrigger.lua:513    
local orig_ElementLaserTrigger_set_dummies_visible = ElementLaserTrigger._set_dummies_visible
function ElementLaserTrigger:_set_dummies_visible(...)
  local dummy_units = self._dummy_units
  if type(dummy_units) == 'table' then
	  for i = #dummy_units, 1, -1 do
		  if not alive(dummy_units[i]) then
			  table.remove(dummy_units, i)
		  end
	  end
  end
  orig_ElementLaserTrigger_set_dummies_visible(self, ...)
end
