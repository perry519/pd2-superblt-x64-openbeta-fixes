local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local itr_groupaistatebase_onnavsegneighbourstate = GroupAIStateBase.on_nav_seg_neighbour_state
function GroupAIStateBase:on_nav_seg_neighbour_state(start_seg_id, end_seg_id, state)
	itr_groupaistatebase_onnavsegneighbourstate(self, start_seg_id, end_seg_id, state)

	managers.navigation:itr_make_neighbours_list(start_seg_id)
	managers.navigation:itr_make_neighbours_list(end_seg_id)
end
