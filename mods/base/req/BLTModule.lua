---@class BLTModule
---@field new fun(self):BLTModule
BLTModule = blt_class()
BLTModule.__type = "BLTModule"

function BLTModule:init()
	BLT:Log(LogLevel.INFO, string.format("[BLT] Loading module '%s'", self.__type))
end

function BLTModule:destroy()
end
