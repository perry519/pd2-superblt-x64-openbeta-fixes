-- [string "lib/managers/mission/elementequipment.lua"]:23: attempt to index local 'instigator' (a nil value)
function ElementEquipment:on_executed(instigator)
	if not self._values.enabled then
		return
	end

	if self._values.equipment ~= "none" then
		if instigator == managers.player:player_unit() then
			managers.player:add_special({
				name = self._values.equipment,
				amount = self._values.amount
			})
		else
			local rpc_params = {
				"give_equipment",
				self._values.equipment,
				self._values.amount,
				false
			}
			if instigator ~= nil then
				instigator:network():send_to_unit(rpc_params)
			end
		end
	end

	ElementEquipment.super.on_executed(self, instigator)
end
