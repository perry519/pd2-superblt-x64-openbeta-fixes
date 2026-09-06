local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_copactioncrouch_needupd = CopActionCrouch.need_upd
local fs_original_copactioncrouch_update = CopActionCrouch.update

function CopActionCrouch:need_upd()
	if not FullSpeedSwarm:allow_stealth_changes() and fs_original_copactioncrouch_needupd then
		return fs_original_copactioncrouch_needupd(self)
	end

	return true
end

function CopActionCrouch:update(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_copactioncrouch_update(self, t)
	end

	if not self._ext_anim.upper_need_upd then
		self._expired = true
	else
		self._ext_movement:upd_m_head_pos()
	end
end
