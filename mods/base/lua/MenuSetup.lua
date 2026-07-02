Hooks:RegisterHook("MenuUpdate")
Hooks:PostHook(MenuSetup, "update", "BLT.MenuSetup.update", function(self, t, dt)
	Hooks:Call("MenuUpdate", t, dt)
end)

Hooks:RegisterHook("SetupOnQuit")
Hooks:PreHook(MenuSetup, "quit", "BLT.MenuSetup.quit", function(self)
	Hooks:Call("SetupOnQuit", self)
end)
