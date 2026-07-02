--  [string "lib/units/enemies/cop/logics/coplogicbase.lua"]:1551: attempt to index local 'data' (a nil value)
local orig_func_inc_dodge_count = TeamAIDamage.inc_dodge_count
function TeamAIDamage:inc_dodge_count(n)
    if alive(self._unit) and self._unit:brain() and self._unit:brain()._logic_data then
        orig_func_inc_dodge_count(self, n)
    end
end
