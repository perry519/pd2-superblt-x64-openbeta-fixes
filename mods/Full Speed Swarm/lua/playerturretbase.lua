local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerturretbase_init = PlayerTurretBase.init
function PlayerTurretBase:init(...)
	fs_original_playerturretbase_init(self, ...)

	self:fs_reset_methods()
end
