Hooks:Register("DynamicResourceManagerCreated")
Hooks:PostHook(DynamicResourceManager, "init", "BLT.DynamicResourceManager.init", function(self)
	Hooks:Call("DynamicResourceManagerCreated", self)
end)
