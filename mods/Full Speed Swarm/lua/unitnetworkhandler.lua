local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if Network:is_client() then
	return
end

local fs_unitnetworkhandler_unitnetworkhandler_damagebullet = UnitNetworkHandler.damage_bullet
function UnitNetworkHandler:damage_bullet(subject_unit, attacker_unit, ...)
	if alive(attacker_unit) and attacker_unit:slot() == 3 then
		-- qued
	elseif alive(subject_unit) and subject_unit:slot() == 16 then
		if managers.groupai:state():is_enemy_converted_to_criminal(subject_unit) then
			-- too bad but it can't be helped (without major desync)
		else
			return -- because that's already been accounted by host
		end
	end

	fs_unitnetworkhandler_unitnetworkhandler_damagebullet(self, subject_unit, attacker_unit, ...)
end
