local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerclean_updattention = PlayerClean._upd_attention
function PlayerClean:_upd_attention()
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playerclean_updattention(self)
	end

	self._ext_movement:set_attention_settings({
		'pl_mask_off_friend_combatant',
		'pl_mask_off_friend_non_combatant',
		'pl_mask_off_foe_combatant',
		'pl_mask_off_foe_non_combatant'
	})
end
