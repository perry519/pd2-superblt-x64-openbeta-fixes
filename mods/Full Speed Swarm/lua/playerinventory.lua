local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerinventory_placeselection = PlayerInventory._place_selection
function PlayerInventory:_place_selection(selection_index, is_equip)
	if is_equip then
		local selection = self._available_selections[selection_index]
		local unit = selection.unit
		if alive(unit) then
			local ubase = unit:base()
			if ubase and ubase.fs_reset_methods then
				ubase:fs_reset_methods() -- due to delayed on_enabled() / crash client dropin
			end
		end
	end

	fs_original_playerinventory_placeselection(self, selection_index, is_equip)
end
