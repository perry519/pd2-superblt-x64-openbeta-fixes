local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerdriving_enter = PlayerDriving.enter
function PlayerDriving:enter(state_data, enter_data)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playerdriving_enter(self, state_data, enter_data)
	end

	self._was_unarmed = enter_data and enter_data.was_unarmed -- asap!

	fs_original_playerdriving_enter(self, state_data, enter_data)
end

local mvec3_add = mvector3.add
local trick_pos = Vector3(0, 0, 2)
local fs_original_playerdriving_update = PlayerDriving.update
function PlayerDriving:update(t, dt)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playerdriving_update(self, t, dt)
	end

	mvec3_add(self._m_pos, trick_pos)
	self:_upd_nav_data()

	fs_original_playerdriving_update(self, t, dt)
end

