--[string "lib/states/ingamefatalstate.lua"]:13: attempt to index local 'player' (a nil value)
local _on_local_player_dead = IngameFatalState.on_local_player_dead
function IngameFatalState.on_local_player_dead()
	if managers.player:player_unit() then
		return _on_local_player_dead(self)
	end
end
