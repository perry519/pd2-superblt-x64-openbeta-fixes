-- Only run if we have the global table
if not _G then
	return
end

-- Localise globals
local _G = _G
local io = io
local file = file

-- Log levels
_G.LogLevel = {
	NONE = 0,
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	ALL = 4
}

_G.LogLevelPrefix = {
	[LogLevel.ERROR] = "[ERROR]",
	[LogLevel.WARN] = "[WARN]",
	[LogLevel.INFO] = "[INFO]"
}

-- BLT Global table
_G.BLT = { version = 2.0 }
_G.BLT.Base = {}

function BLT:InstallStringMethodCompatibility()
	if type(string) ~= "table" then
		return false
	end

	if type(debug) ~= "table" or type(debug.setmetatable) ~= "function" then
		return false
	end

	local string_meta = type(debug.getmetatable) == "function" and debug.getmetatable("") or getmetatable("")
	if type(string_meta) ~= "table" then
		string_meta = {}
	end

	string_meta.__index = string

	return pcall(debug.setmetatable, "", string_meta)
end

_G.BLTInstallStringMethodCompatibility = function()
	return BLT:InstallStringMethodCompatibility()
end

BLT:InstallStringMethodCompatibility()

-- Load modules
_G.BLT._PATH = "mods/base/"
function BLT:Require(path)
	self:InstallStringMethodCompatibility()
	dofile(string.format("%s%s", BLT._PATH, path .. ".lua"))
end

BLT:Require("req/utils/UtilsClass")
BLT:Require("req/utils/UtilsCore")
BLT:Require("req/utils/UtilsIO")
BLT:Require("req/utils/json-1.0")
BLT:Require("req/utils/json-0.9")
BLT:Require("req/utils/json")
BLT:Require("req/core/Hooks")
BLT:Require("req/core/DelayedCalls")
BLT:Require("req/BLTHttp")
BLT:Require("req/supermod/BLTSuperMod")
BLT:Require("req/BLTMod")
BLT:Require("req/BLTUpdate")
BLT:Require("req/BLTUpdateCallbacks")
BLT:Require("req/BLTModDependency")
BLT:Require("req/BLTModule")
BLT:Require("req/BLTLogs")
BLT:Require("req/BLTModManager")
BLT:Require("req/BLTDownloadManager")
BLT:Require("req/BLTLocalization")
BLT:Require("req/BLTNotificationsManager")
BLT:Require("req/BLTPersistScripts")
BLT:Require("req/BLTKeybindsManager")
BLT:Require("req/BLTAssetManager")
if blt and blt.xaudio then
	BLT:Require("req/xaudio/XAudio")
else
	if log then
		log("[WARN] Skipping XAudio Lua module because blt.xaudio is unavailable")
	end
end

---Writes a message to the log file
---Multiple arguments can be passed to the function and will be concatenated
---@param level integer @The log level of the message
---@param ... any @The message to log
function BLT:Log(level, ...)
	if level > BLTLogs.log_level then
		return
	end

	local out = {LogLevelPrefix[level] or "", ...}
	local n = select("#", ...) -- allow nil holes
	-- skip prefix, allow for n=0
	for i = 2, n+1, 1 do
		out[i] = tostring(out[i])
	end
	log(table.concat(out, " "))
end

function BLT:DeprecationWarning(name, level)
	local info = debug.getinfo(level or 3, "Sl")
	BLT:Log(LogLevel.WARN, string.format("%s is deprecated and will be removed in a future version of SuperBLT (%s:%s)", name, info.source, info.currentline))
end

-- BLT base functions
function BLT:Initialize()
	-- Create hook tables
	self.hook_tables = {
		pre = {},
		post = {},
		wildcards = {}
	}

	-- Override require and setup self
	self:OverrideRequire()

	self:Setup()
end

function BLT:IsVr()
	local system_info = _G.SystemInfo
	local system_info_meta = system_info ~= nil and getmetatable(system_info) or nil
	return type(system_info_meta) == "table" and system_info_meta.is_vr ~= nil and system_info:is_vr()
end

function BLT:Setup()
	-- Load saved data
	if BLT:IsVr() then
		local save_file = BLTModManager.Constants:ModManagerSaveFile(true)
		self.save_data = io.file_is_readable(save_file) and io.load_as_json(save_file)
	end

	if not self.save_data then
		local save_file = BLTModManager.Constants:ModManagerSaveFile(false)
		self.save_data = io.file_is_readable(save_file) and io.load_as_json(save_file) or {}
	end

	-- Setup modules
	self.Logs = BLTLogs:new()
	self.Mods = BLTModManager:new()
	self.Downloads = BLTDownloadManager:new()
	self.Keybinds = BLTKeybindsManager:new()
	self.PersistScripts = BLTPersistScripts:new()
	self.Localization = BLTLocalization:new()
	self.Notifications = BLTNotificationsManager:new()
	self.AssetManager = BLTAssetManager:new()

	-- Create the required base directories, if necessary
	self:CheckDirectory(BLTModManager.Constants:DownloadsDirectory())
	self:CheckDirectory(BLTModManager.Constants:LogsDirectory())
	self:CheckDirectory(BLTModManager.Constants:SavesDirectory())

	-- Initialization functions
	self.Logs:CleanLogs()
	local found_mods = self:FindMods()
	self.Mods:SetModsList(self:ProcessModsList(found_mods))

	-- Some backwards compatibility for v1 mods
	local C = self.Mods.Constants
	local legacy_mod_manager = {}
	rawset(_G, "LuaModManager", legacy_mod_manager)
	legacy_mod_manager.Constants = C
	legacy_mod_manager.Mods = {} -- No mods are available via old api
	rawset(_G, C.logs_path_global, C.mods_directory .. C.logs_directory)
	rawset(_G, C.save_path_global, C.mods_directory .. C.saves_directory)
end

---Returns the version of BLT
---@return string @The version of BLT
function BLT:GetVersion()
	return self.version
end

---Returns the operating system that the game is running on
---@return '"windows"'|'"linux"' @The operating system
function BLT:GetOS()
	local info = blt.blt_info()
	if not info then
		return "windows"
	end
	return info.platform == "mswindows" and "windows" or "linux"
end

function BLT:RunHookTable(hooks_table, path)
	if not hooks_table or not hooks_table[path] then
		return false
	end
	for i, hook_data in pairs(hooks_table[path]) do
		self:RunHookFile(path, hook_data)
	end
end

function BLT:SetModGlobals(mod)
	rawset(_G, BLTModManager.Constants.mod_path_global, mod and mod:GetPath() or false)
	rawset(_G, BLTModManager.Constants.mod_instance_global, mod or false)
end

function BLT:RunHookFile(path, hook_data)
	self:InstallStringMethodCompatibility()
	rawset(_G, BLTModManager.Constants.required_script_global, path or false)
	self:SetModGlobals(hook_data.mod)
	local mod_path = hook_data.mod:GetPath()
	local hook_file = mod_path .. hook_data.script
	dofile(hook_file)
end

function BLT:OverrideRequire()
	if _G.require == self.require_wrapper then
		return false
	end

	if type(_G.require) ~= "function" then
		return false
	end

	-- Cache original require function
	self.require = _G.require

	-- Override require function to run hooks
	self.require_wrapper = function(...)
		self:InstallStringMethodCompatibility()
		local args = { ... }
		local path = args[1]
		if type(path) ~= "string" then
			return self.require(...)
		end

		local path_lower = path:lower()
		local require_result = nil

		self:RunHookTable(self.hook_tables.pre, path_lower)
		require_result = self.require(...)
		self:RunHookTable(self.hook_tables.post, path_lower)

		for k, v in ipairs(self.hook_tables.wildcards) do
			self:RunHookFile(path, v)
		end

		return require_result
	end
	_G.require = self.require_wrapper
	return true
end

function BLT:FindMods()
	-- Get all folders in mods directory
	local mods_list = {}
	local mods_directory = BLTModManager.Constants.mods_directory
	local folders = file.GetDirectories(mods_directory)

	-- If we didn't get any folders then return an empty mods list
	if not folders then
		return {}
	end

	for index, directory in pairs(folders) do
		-- Check if this directory is excluded from being checked for mods (logs, saves, etc.)
		if not self.Mods:IsExcludedDirectory(directory) then
			local mod_path = mods_directory .. directory .. "/"

			-- Attempt to read the mod defintion file
			local file = io.open(mod_path .. "mod.txt")
			if file then
				-- Read the file contents
				local file_contents = file:read("*all")
				file:close()

				-- Create a BLT mod from the loaded data
				local mod_content = json.decode(file_contents)
				if mod_content then
					local new_mod, valid = BLTMod:new(directory, mod_content, mod_path)
					if valid then
						table.insert(mods_list, new_mod)
					end
				else
					self:Log(LogLevel.ERROR, "[BLT] An error occured while loading mod.txt from: " .. tostring(mod_path))
				end
			else
				self:Log(LogLevel.WARN, "[BLT] Could not read or find mod.txt in " .. tostring(mod_path))
			end
		end
	end

	return mods_list
end

function BLT:ProcessModsList(mods_list)
	-- Prioritize mod load order
	table.sort(mods_list, function(a, b)
		return a:GetPriority() > b:GetPriority()
	end)

	return mods_list
end

function BLT:CheckDirectory(path)
	path = path:sub(1, #path - 1)
	if not file.DirectoryExists(path) then
		self:Log(LogLevel.INFO, "[BLT] Creating missing directory " .. path)
		file.CreateDirectory(path)
	end
end

-- Perform startup
BLT:Initialize()
