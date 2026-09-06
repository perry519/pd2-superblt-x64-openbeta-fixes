local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_teamaimovement_switchtonotcool = HuskTeamAIMovement._switch_to_not_cool
function HuskTeamAIMovement:_switch_to_not_cool(...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_teamaimovement_switchtonotcool(self, ...)
	end

	fs_original_teamaimovement_switchtonotcool(self, ...)
	if alive(self._unit) and alive(self._unit:inventory():equipped_unit()) then
		self._unit:inventory():_ensure_weapon_visibility()
	end
end
