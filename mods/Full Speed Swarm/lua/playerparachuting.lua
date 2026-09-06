local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if _G.IS_VR then
	return
end

local fs_original_playerparachuting_exit = PlayerParachuting.exit
function PlayerParachuting.exit(...)
	managers.interaction.fs_reset_ordered_list()
	fs_original_playerparachuting_exit(...)
end
