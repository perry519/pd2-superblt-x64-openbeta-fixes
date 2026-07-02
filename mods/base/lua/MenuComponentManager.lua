Hooks:RegisterHook("MenuComponentManagerInitialize")
Hooks:PostHook(MenuComponentManager, "init", "BLT.MenuComponentManager.init", function(self)
	Hooks:Call("MenuComponentManagerInitialize", self)
end)

Hooks:RegisterHook("MenuComponentManagerUpdate")
Hooks:PostHook(MenuComponentManager, "update", "BLT.MenuComponentManager.update", function(self, t, dt)
	Hooks:Call("MenuComponentManagerUpdate", self, t, dt)
end)

Hooks:RegisterHook("MenuComponentManagerPreSetActiveComponents")
Hooks:PreHook(MenuComponentManager, "set_active_components", "BLT.MenuComponentManager.set_active_components", function(self, components, node)
	Hooks:Call("MenuComponentManagerPreSetActiveComponents", self, components, node)
end)

Hooks:RegisterHook("MenuComponentManagerOnMousePressed")
Hooks:PostHook(MenuComponentManager, "mouse_pressed", "BLT.MenuComponentManager.mouse_pressed", function(self, o, button, x, y)
	return Hooks:ReturnCall("MenuComponentManagerOnMousePressed", self, o, button, x, y)
end)

Hooks:RegisterHook("MenuComponentManagerOnMouseMoved")
Hooks:PostHook(MenuComponentManager, "mouse_moved", "BLT.MenuComponentManager.mouse_moved", function(self, o, x, y)
	return Hooks:ReturnCall("MenuComponentManagerOnMouseMoved", self, o, x, y)
end)
