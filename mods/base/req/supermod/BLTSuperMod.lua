---@class BLTSuperMod
---@field new fun(self, mod: BLTMod, xml: table):BLTSuperMod
BLTSuperMod = blt_class()

BLT:Require("req/supermod/SuperModAssetLoader")

local containers = {
	dependencies = true,
	hooks = true,
	keybinds = true,
	native_modules = true,
	updates = true,
}

local list_fields = {
	entry = "entry_scripts",
	keybind = "keybinds",
	native_module = "native_modules",
	persist = "persist_scripts",
	post = "hooks",
	pre = "pre_hooks",
	update = "updates",
}

local boolean_fields = {
	critical = true,
	desktop_disabled = true,
	disable_safe_mode = true,
	disallow_update = true,
	hash_file = true,
	is_library = true,
	library = true,
	localized = true,
	needs_restart = true,
	run_in_game = true,
	run_in_menu = true,
	show_in_menu = true,
	undisablable = true,
	vr_disabled = true,
}

local function convert(name, value)
	if boolean_fields[name] then
		return tostring(value):lower() == "true"
	elseif name == "priority" then
		return tonumber(value)
	end
	return value
end

local function scope_for(tag, parent)
	local scope = setmetatable({}, { __index = parent })
	local source = tag._doc and tag._doc.filename or "XML"
	for raw_name, raw_value in pairs(tag.params or {}) do
		local name = raw_name
		local value = raw_value:gsub("#{(%a[%w_]*)}", function(key)
			return tostring(assert(scope[key], "Missing parameter '" .. key .. "' in " .. source))
		end)

		if name:sub(1, 1) == ":" then
			name = name:sub(2)
			value = assert(scope[name], "Missing parameter '" .. name .. "' in " .. source) .. value
		end
		scope[name] = convert(name, value)
	end
	return scope
end

function BLTSuperMod.read(path)
	local handle = io.open(path)
	if not handle then
		return
	end

	local xml = blt.parsexml(handle:read("*all"))
	handle:close()
	if xml then
		xml._doc = { filename = path }
	end
	return xml
end

function BLTSuperMod.try_load(mod, file_name, xml)
	xml = xml or BLTSuperMod.read(mod:GetPath() .. (file_name or "supermod.xml"))
	return xml and BLTSuperMod:new(mod, xml)
end

function BLTSuperMod:init(mod, xml)
	self._mod = mod
	self._assets = {}
	self:_expand_includes(xml)
	self:_merge_root(xml.params or {})
	self:_walk(xml, {})
end

function BLTSuperMod:Setup()
	if #self._assets == 0 or not self._mod:IsEnabled() then
		return
	end

	self._asset_loader = self.AssetLoader:new(self)
	for _, asset in ipairs(self._assets) do
		self._asset_loader:FromXML(asset.tag, asset.scope)
	end
end

function BLTSuperMod:GetAssetLoader()
	return self._asset_loader
end

function BLTSuperMod:_merge_root(params)
	local data = self._mod.raw_data
	for name, value in pairs(params) do
		local target = name == "library" and "is_library" or name
		data[target] = convert(target, value)
	end
end

function BLTSuperMod:_append(name, value)
	local data = self._mod.raw_data
	data[name] = data[name] or {}
	table.insert(data[name], value)
end

function BLTSuperMod._recurse_xml(xml, parent_scope, callbacks)
	for _, tag in ipairs(xml) do
		local scope = scope_for(tag, parent_scope)
		local callback = callbacks[tag.name]
		if not tag.name or tag.name == "group" then
			BLTSuperMod._recurse_xml(tag, scope, callbacks)
		elseif callback then
			callback(tag, scope, callbacks)
		else
			BLT:Log(LogLevel.WARN, "Unknown tag '" .. tostring(tag.name) .. "' in " .. tag._doc.filename)
		end
	end
end

function BLTSuperMod:_walk(xml, parent_scope)
	for _, tag in ipairs(xml) do
		local scope = scope_for(tag, parent_scope)

		local name = tag.name
		if not name or name == "group" or containers[name] then
			self:_walk(tag, scope)
		elseif name == "dependency" then
			if scope.identifier then
				local dependencies = self._mod.raw_data.dependencies or {}
				self._mod.raw_data.dependencies = dependencies
				dependencies[scope.identifier] = scope
			end
		elseif list_fields[name] then
			self:_append(list_fields[name], scope)
		elseif name == "assets" then
			table.insert(self._assets, { tag = tag, scope = scope })
			self._mod.raw_data.needs_restart = self._mod.raw_data.needs_restart ~= false
		elseif name == "wren" or name == "tweak" then
			self._mod.raw_data.needs_restart = self._mod.raw_data.needs_restart ~= false
		else
			BLT:Log(LogLevel.WARN, "Unknown tag '" .. tostring(name) .. "' in " .. tag._doc.filename)
		end
	end
end

function BLTSuperMod:_expand_includes(xml)
	for index, tag in ipairs(xml) do
		tag._doc = xml._doc
		if tag.name == ":include" then
			local included = BLTSuperMod.read(self._mod:GetPath() .. tag.params.src)
			assert(included, "Could not read " .. self._mod:GetPath() .. tag.params.src)
			xml[index] = included
			tag = included
		end
		self:_expand_includes(tag)
	end
end
