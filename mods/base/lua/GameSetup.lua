Hooks:RegisterHook("GameSetupUpdate")
Hooks:PreHook(GameSetup, "update", "BLT.GameSetup.update", function(self, t, dt)
	Hooks:Call("GameSetupUpdate", t, dt)
end)

Hooks:RegisterHook("GameSetupPausedUpdate")
Hooks:PreHook(GameSetup, "paused_update", "BLT.GameSetup.paused_update", function(self, t, dt)
	Hooks:Call("GameSetupPausedUpdate", t, dt)
end)
