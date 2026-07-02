BeardLibModPath = ModPath

local original_core = _G.core
local original_global = _G.Global
local original_application = _G.Application
local original_idstring = _G.Idstring
local original_string_meta = debug and debug.getmetatable and debug.getmetatable("") or getmetatable("")
local original_string_index = type(original_string_meta) == "table" and original_string_meta.__index or nil
local original_string_id = string.id

local function restore_string_state()
	local string_meta = debug and debug.getmetatable and debug.getmetatable("") or getmetatable("")
	if type(string_meta) ~= "table" then
		string_meta = {}
	end

	string_meta.__index = original_string_index or string

	if debug and debug.setmetatable then
		pcall(debug.setmetatable, "", string_meta)
	end

	string.id = original_string_id
end

local function restore_globals()
	_G.core = original_core
	_G.Global = original_global
	_G.Application = original_application
	_G.Idstring = original_idstring
	restore_string_state()
end

_G.Global = {}
_G.Application = {}
_G.Application.ews_enabled = function()
	return false
end
setmetatable(_G.Application, _G.Application)

require("core/lib/system/CoreModule")
core:register_module("core/lib/utils/CoreSerialize")
core:register_module("core/lib/utils/CoreCode")
core:register_module("core/lib/utils/CoreClass")
core:register_module("core/lib/utils/CoreDebug")
core:register_module("core/lib/utils/CoreTable")
core:register_module("core/lib/utils/CoreString")
core:register_module("core/lib/utils/CoreApp")
core:_copy_module_to_global("CoreCode")
core:_copy_module_to_global("CoreClass")
core:_copy_module_to_global("CoreDebug")
core:_copy_module_to_global("CoreTable")
core:_copy_module_to_global("CoreString")
core:_copy_module_to_global("CoreApp")

function Idstring(str)
	return str
end

function string:id()
	return Idstring(self)
end

local ok, err = pcall(dofile, BeardLibModPath .. "Core.lua")
restore_globals()

if not ok then
	error(err)
end
