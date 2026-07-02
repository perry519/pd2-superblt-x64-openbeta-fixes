local Hooks = Hooks

core:module("CoreMenuLogic")

Hooks:RegisterHook("LogicOnSelectNode")
Hooks:PostHook(Logic, "select_node", "BLT.Logic.select_node", function(self, node_name, queue, ...)
	Hooks:Call("LogicOnSelectNode", self, node_name, queue, ...)
end)
