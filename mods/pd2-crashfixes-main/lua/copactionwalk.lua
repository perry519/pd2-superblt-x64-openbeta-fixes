--[string "lib/units/enemies/cop/actions/lower_body/copa..."]:342: bad argument #1 to 't_ins' (table expected, got nil)

local _init = CopActionWalk.init
local __init = CopActionWalk._init

function CopActionWalk:init(action_desc, common_data)
	self._nav_path = type(action_desc.nav_path) == "table" and action_desc.nav_path or {}
	return _init(self, action_desc, common_data)
end

function CopActionWalk:_init()
	self._nav_path = type(self._nav_path) == "table" and self._nav_path or {}
	return __init(self)
end
