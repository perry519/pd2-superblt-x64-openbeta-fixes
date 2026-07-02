local _carry_type_tweak = CarryData.carry_type_tweak
function CarryData:carry_type_tweak()
	if not tweak_data.carry then
		return
	end
	return _carry_type_tweak(self)
end

--[string "lib/units/props/carrydata.lua"]:807: attempt to index local 'carry_type_tweak' (a nil value)
local _set_carry_id = CarryData.set_carry_id
function CarryData:set_carry_id(carry_id, is_init)
	local carry_tweaks = tweak_data.carry
	self._carry_id = carry_id
	if carry_id then
		local carry_tweak = carry_tweaks[self._carry_id] or carry_tweaks.money
		if not carry_tweak then return nil end
		local carry_type_tweak = carry_tweaks.types[carry_tweak.type]
		if carry_type_tweak then
			return _set_carry_id(self, carry_id, is_init)
		end
	end
	return nil
end

--[string "lib/units/props/carrydata.lua"]:1072: attempt to index field 'pickup_pos' (a nil value)
local _clbk_pickup_SO_verification = CarryData.clbk_pickup_SO_verification
function CarryData:clbk_pickup_SO_verification(candidate_unit)
	if (
		type(self._steal_SO_data) == "userdata" and
		self._steal_SO_data.SO_id and
		type(self._steal_SO_data.pickup_pos) == "userdata"
	) 
	and
	(
		type(candidate_unit) == "userdata" and
		(candidate_unit.movement and candidate_unit:movement()) and 
		(candidate_unit.base and candidate_unit:base())
	) then
		return _clbk_pickup_SO_verification(self, candidate_unit)
	end
end

--[string "lib/units/props/carrydata.lua"]:1157: attempt to index local 'secure_pos' (a nil value)
local _on_secure_SO_completed = CarryData.on_secure_SO_completed
function CarryData:on_secure_SO_completed(thief)
	if thief and type(self._steal_SO_data) == "userdata" and self._steal_SO_data.secure_pos then
		return _on_secure_SO_completed(self, thief)
	end
end

