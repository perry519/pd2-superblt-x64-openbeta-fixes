if core then
	core:module("CoreEvent")
end

--[string "core/lib/utils/coreevent.lua"]:134: attempt to perform arithmetic on local 'interval' (a nil value)
local _add = CallbackHandler.add
function CallbackHandler:add(f, interval, times)
	if type(interval) ~= "number" then
		interval = 5
	end
	return _add(self, f, interval, times)
end

