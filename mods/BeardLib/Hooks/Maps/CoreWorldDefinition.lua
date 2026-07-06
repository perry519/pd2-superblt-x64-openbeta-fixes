local BeardLib = BeardLib
local Hooks = Hooks

core:module("CoreWorldDefinition")
local FileIO = _G.FileIO
local Path = _G.Path
WorldDefinition = WorldDefinition or CoreWorldDefinition.WorldDefinition

local ASSET_IDS = {
    cooked_physics = Idstring("cooked_physics"),
    material_config = Idstring("material_config"),
    model = Idstring("model"),
    object = Idstring("object"),
    sequence_manager = Idstring("sequence_manager"),
    texture = Idstring("texture"),
    unit = Idstring("unit")
}
local ASSET_SORT = {
    texture = 1,
    cooked_physics = 2,
    model = 3,
    object = 4,
    material_config = 5,
    sequence_manager = 6,
    unit = 10
}
local function string_value(value)
    if type(value) == "string" then
        return value
    end
    if type(value) == "userdata" then
        local ok, str = pcall(function()
            return value:s()
        end)
        if ok and type(str) == "string" then
            return str
        end
    end
end

local function normalize_asset_path(path, typ)
    path = string_value(path)
    if not path or path == "" then
        return
    end

    path = path:gsub("\\", "/")
    if Path and Path.Normalize then
        path = Path:Normalize(path)
    end
    path = path:gsub("^/+", "")

    if typ then
        local suffix = "." .. typ
        if path:sub(-#suffix) == suffix then
            path = path:sub(1, #path - #suffix)
        end
    end

    return path ~= "" and path or nil
end

local function asset_file(directory, path, typ)
    return Path:Combine(directory, path) .. "." .. typ
end

local function has_registered_asset(typ, path)
    local ids_ext = ASSET_IDS[typ]
    if not ids_ext or not path then
        return false
    end

    local ids_path = Idstring(path)
    local ok, has_asset = pcall(function()
        return PackageManager:has(ids_ext, ids_path)
    end)
    if ok and has_asset then
        return true
    end

    ok, has_asset = pcall(function()
        return DB:has(ids_ext, ids_path)
    end)
    return ok and has_asset or false
end

local function find_loaded_level_module(level_id, level_tweak)
    local current_level = BeardLib.current_level
    if current_level and current_level._config and tostring(current_level._config.id) == tostring(level_id) then
        return current_level
    end

    local mod_path = level_tweak and level_tweak.mod_path
    if not mod_path then
        return current_level
    end

    local frameworks = BeardLib.Frameworks or {}
    local map_framework = frameworks.map or frameworks.Map
    local loaded_mods = map_framework and map_framework._loaded_mods or {}
    for _, mod in pairs(loaded_mods) do
        if mod.ModPath == mod_path and mod.GetModule then
            local level = mod:GetModule("level")
            if level and level._config and tostring(level._config.id) == tostring(level_id) then
                BeardLib.current_level = level
                if not level._currently_loaded and level.Load then
                    level._currently_loaded = true
                    level:Load()
                end
                return level
            end
        end
    end

    return current_level
end

local function resolver_context(self)
    local level_id = Global.level_data and Global.level_data.level_id
    local level_tweak = level_id and _G.tweak_data and _G.tweak_data.levels and _G.tweak_data.levels[level_id]
    local current_level = find_loaded_level_module(level_id, level_tweak)
    if not current_level or not level_id or not level_tweak or not level_tweak.custom then
        return
    end

    local mod = current_level._mod
    local map_root = mod and mod.ModPath
    local assets_dir = map_root and Path:CombineDir(map_root, "assets")
    if not assets_dir or not FileIO:Exists(assets_dir) then
        return
    end

    return {
        assets_dir = assets_dir,
        current_level = current_level,
        level_id = level_id,
        map_root = map_root,
        module_name = "BeardLibCustomMapAssetResolver:" .. tostring(level_id)
    }
end

local function resolver_state(self, context)
    local key = tostring(context.level_id) .. ":" .. tostring(context.assets_dir)
    local state = self._beardlib_custom_map_asset_resolver
    if not state or state.key ~= key then
        state = {
            configs = {},
            key = key,
            loaded_entries = 0,
            seen = {},
            seen_ids = {},
            units = {}
        }
        self._beardlib_custom_map_asset_resolver = state
    end
    return state
end

local function ensure_resolver_module(context, state)
    if state.module then
        return
    end

    state.module = {
        name = context.module_name,
        Unload = function()
            state.configs = {}
            state.loaded_entries = 0
            state.module = nil
            state.seen = {}
            state.seen_ids = {}
            state.units = {}
        end
    }

    context.current_level._addfiles_modules = context.current_level._addfiles_modules or {}
    table.insert(context.current_level._addfiles_modules, state.module)
end

local function read_asset_text(context, path, typ)
    local file_path = asset_file(context.assets_dir, path, typ)
    if FileIO:Exists(file_path) then
        return FileIO:ReadFrom(file_path)
    end
end

local function read_asset_script(context, path, typ)
    local file_path = asset_file(context.assets_dir, path, typ)
    if not FileIO:Exists(file_path) then
        return
    end

    local ok, data = pcall(function()
        return FileIO:ReadScriptData(file_path, "generic_xml")
    end)
    if ok and data then
        return data
    end
end

local function node_tag(node)
    return type(node) == "table" and (node._meta or node._name or node.name or node.tag)
end

local function node_attr(node, attr)
    if type(node) ~= "table" then
        return
    end

    local value = string_value(node[attr])
    if value then
        return value
    end

    local attrs = node._attr or node._attributes or node.attributes
    if type(attrs) == "table" then
        return string_value(attrs[attr])
    end
end

local function find_script_attr(node, tag, attr, depth)
    if type(node) ~= "table" or depth > 12 then
        return
    end

    if node_tag(node) == tag then
        local value = node_attr(node, attr)
        if value then
            return value
        end
    end

    for _, child in pairs(node) do
        local value = find_script_attr(child, tag, attr, depth + 1)
        if value then
            return value
        end
    end
end

local function xml_attr(raw, tag, attr)
    if not raw then
        return
    end

    local pattern = "<" .. tag .. "%s+[^>]-" .. attr .. "%s*=%s*"
    return raw:match(pattern .. "\"([^\"]+)\"") or raw:match(pattern .. "'([^']+)'")
end

local function asset_attr(context, path, typ, tag, attr)
    local script_data = read_asset_script(context, path, typ)
    local value = find_script_attr(script_data, tag, attr, 0)
    if value then
        return normalize_asset_path(value)
    end

    return normalize_asset_path(xml_attr(read_asset_text(context, path, typ), tag, attr))
end

local function collect_script_texture_attrs(node, textures, depth)
    if type(node) ~= "table" or depth > 12 then
        return
    end

    local tag = node_tag(node)
    if type(tag) == "string" and tag:find("texture", 1, true) then
        local value = normalize_asset_path(node_attr(node, "file"), "texture")
        if value then
            table.insert(textures, value)
        end
    end

    for _, child in pairs(node) do
        collect_script_texture_attrs(child, textures, depth + 1)
    end
end

local function material_texture_paths(context, material_path)
    local textures = {}
    collect_script_texture_attrs(read_asset_script(context, material_path, "material_config"), textures, 0)
    if #textures > 0 then
        return textures
    end

    local raw = read_asset_text(context, material_path, "material_config")
    if raw then
        for texture_path in raw:gmatch("<[%w_:%.-]*texture%s+[^>]-file%s*=%s*\"([^\"]+)\"") do
            table.insert(textures, normalize_asset_path(texture_path, "texture"))
        end
        for texture_path in raw:gmatch("<[%w_:%.-]*texture%s+[^>]-file%s*=%s*'([^']+)'") do
            table.insert(textures, normalize_asset_path(texture_path, "texture"))
        end
    end

    return textures
end

local function add_generated_asset(context, state, config, typ, path)
    path = normalize_asset_path(path, typ)
    if not path then
        return false
    end

    local ids_key = Idstring(path):key()
    local seen_key = typ .. ":" .. path
    local seen_ids_key = typ .. ":" .. tostring(ids_key)
    if state.seen[seen_key] or state.seen_ids[seen_ids_key] then
        return false
    end

    if has_registered_asset(typ, path) then
        state.seen[seen_key] = true
        state.seen_ids[seen_ids_key] = true
        return false
    end

    if not FileIO:Exists(asset_file(context.assets_dir, path, typ)) then
        return false
    end

    state.seen[seen_key] = true
    state.seen_ids[seen_ids_key] = true
    table.insert(config, {_meta = typ, path = path, unload = false, auto_cp = false})
    return true
end

local function resolve_unit_dependencies(context, state, config, unit_path)
    unit_path = normalize_asset_path(unit_path, "unit")
    if not unit_path then
        return
    end

    local unit_key = Idstring(unit_path):key()
    if has_registered_asset("unit", unit_path) then
        return
    end

    if not FileIO:Exists(asset_file(context.assets_dir, unit_path, "unit")) then
        return
    end

    if state.units[unit_path] or state.units[unit_key] then
        return
    end
    state.units[unit_path] = true
    state.units[unit_key] = true

    local object_path = asset_attr(context, unit_path, "unit", "object", "file") or unit_path
    local material_path = asset_attr(context, object_path, "object", "diesel", "materials") or object_path
    local sequence_path = asset_attr(context, object_path, "object", "sequence_manager", "file")

    for _, texture_path in ipairs(material_texture_paths(context, material_path)) do
        add_generated_asset(context, state, config, "texture", texture_path)
    end

    add_generated_asset(context, state, config, "cooked_physics", object_path)
    add_generated_asset(context, state, config, "model", object_path)
    add_generated_asset(context, state, config, "object", object_path)
    add_generated_asset(context, state, config, "material_config", material_path)
    add_generated_asset(context, state, config, "sequence_manager", sequence_path)
    add_generated_asset(context, state, config, "unit", unit_path)
end

local function load_generated_config(context, state, config)
    if #config == 0 then
        return
    end

    table.sort(config, function(a, b)
        return (ASSET_SORT[a._meta] or 50) < (ASSET_SORT[b._meta] or 50)
    end)

    config.auto_cp = false
    config.unload = false
    ensure_resolver_module(context, state)
    BeardLib.Managers.Package:LoadConfig(context.assets_dir, config, context.current_level._mod)
    table.insert(state.configs, config)
    state.loaded_entries = state.loaded_entries + #config
end

local function add_unit_ref(refs, value)
    local path = normalize_asset_path(value, "unit")
    if not path then
        return
    end

    local key = Idstring(path):key()
    if refs.seen[path] or refs.seen[key] then
        return
    end

    refs.seen[path] = true
    refs.seen[key] = true
    table.insert(refs, path)
end

local function add_unit_data_ref(refs, data)
    if type(data) ~= "table" then
        return
    end

    local unit_data = data.unit_data or data
    add_unit_ref(refs, unit_data and unit_data.name)
end

local function collect_unit_table(refs, values)
    if type(values) ~= "table" then
        return
    end

    for _, data in pairs(values) do
        add_unit_data_ref(refs, data)
    end
end

local function collect_massunit_refs(refs, data)
    if type(data) == "table" and type(data.preload_units) == "table" then
        for _, unit in pairs(data.preload_units) do
            add_unit_ref(refs, unit)
        end
    end
end

local function collect_runtime_unit_refs(self)
    local refs = {seen = {}}
    local definition = self._definition or {}

    collect_unit_table(refs, definition.statics)
    collect_unit_table(refs, definition.dynamics)
    collect_unit_table(refs, definition.mission)
    collect_unit_table(refs, definition.wires)
    collect_unit_table(refs, definition.ai)
    collect_massunit_refs(refs, definition.brush)

    for _, continent in pairs(self._continent_definitions or {}) do
        collect_unit_table(refs, continent.statics)
        collect_unit_table(refs, continent.dynamics)
        collect_unit_table(refs, continent.mission)
        collect_unit_table(refs, continent.wires)
        collect_unit_table(refs, continent.ai)
        collect_massunit_refs(refs, continent.brush)
    end

    for _, delayed in pairs(self._delayed_units or {}) do
        add_unit_data_ref(refs, delayed[1])
    end

    refs.seen = nil
    return refs
end

function WorldDefinition:_beardlib_resolve_custom_map_asset(name)
    local context = resolver_context(self)
    if not context then
        return
    end

    local state = resolver_state(self, context)
    local config = {}
    resolve_unit_dependencies(context, state, config, name)
    load_generated_config(context, state, config)
end

function WorldDefinition:_beardlib_resolve_custom_map_assets()
    local context = resolver_context(self)
    if not context then
        return
    end

    local refs = collect_runtime_unit_refs(self)

    local state = resolver_state(self, context)
    local config = {}
    for _, path in ipairs(refs) do
        resolve_unit_dependencies(context, state, config, path)
    end
    load_generated_config(context, state, config)
end

local WorldDefinition_init = WorldDefinition.init
function WorldDefinition:init(...)
    WorldDefinition_init(self, ...)
    if self._ignore_spawn_list then
        self._ignore_spawn_list[Idstring("units/dev_tools/level_tools/ai_coverpoint"):key()] = true
    end
end

function WorldDefinition:do_package_load(pkg)
    if PackageManager:package_exists(pkg) then
        if not PackageManager:loaded(pkg) then
            PackageManager:load(pkg)
            --BeardLib:log("Loaded package: "..pkg)
        end
        table.insert(self._custom_loaded_packages, pkg)
    end
end

local WorldDefinition_load_world_package = WorldDefinition._load_world_package
function WorldDefinition:_load_world_package(...)
    if Global.level_data then
        local level_tweak = _G.tweak_data.levels[Global.level_data.level_id]
        if level_tweak then
            self._has_package = not not level_tweak.package
            if level_tweak.custom_packages then
                self._custom_loaded_packages = self._custom_loaded_packages or {}
                for _, package in ipairs(level_tweak.custom_packages) do
                    self:do_package_load(package.."_init")
                    self:do_package_load(package)
                end
            end
        end
    end
    if not BeardLib.current_level then
        WorldDefinition_load_world_package(self, ...)
    end
end

local WorldDefinitionunload_packages = WorldDefinition.unload_packages
function WorldDefinition:unload_packages(...)
    if Global.level_data then
        if BeardLib.current_level then
            for _, module in pairs(BeardLib.current_level._addfiles_modules) do
                module:Unload()
            end
        end

        if self._custom_instances then
            for _, instance in pairs(self._custom_instances) do
                instance:Unload()
            end
        end

        if self._custom_loaded_packages then
            for _, package in pairs(self._custom_loaded_packages) do
                --BeardLib:log("Unloaded package: "..package)
                --Disabled vanilla package unloading for the time being. This will crash certain custom maps after reloading them.
                --The exact reason is unknown.
                if PackageManager:loaded(package) and BeardLib.Managers.Package:HasPackage(package) then
                    PackageManager:unload(package)
                end
            end
            self._custom_loaded_packages = {}
        end
    end
    if not BeardLib.current_level and self._continent_packages then
        WorldDefinitionunload_packages(self, ...)
    end
end

local WorldDefinition_load_continent_init_package = WorldDefinition._load_continent_init_package
function WorldDefinition:_load_continent_init_package(path, ...)
    if not PackageManager:package_exists(path) then
        return
    end

    WorldDefinition_load_continent_init_package(self, path, ...)
end

local WorldDefinition_load_continent_package =  WorldDefinition._load_continent_package
function WorldDefinition:_load_continent_package(path, ...)
    if not PackageManager:package_exists(path) then
        return
    end

    WorldDefinition_load_continent_package(self, path, ...)
end

function WorldDefinition:convert_mod_path(path)
    if Global.level_data then
        local level_tweak = _G.tweak_data.levels[Global.level_data.level_id]
        if level_tweak then
            if BeardLib.current_level and level_tweak.custom and path and string.begins(path, ".map/") then
                path = path:gsub(".map", BeardLib.current_level._inner_dir)
            end
            if not PackageManager:has(Idstring("environment"), path:id()) then
                return "core/environments/default"
            end
        end
    end
    return path
end

local WorldDefinition_create_environment = WorldDefinition._create_environment
function WorldDefinition:_create_environment(data, offset, ...)
    data.environment_values.environment = self:convert_mod_path(data.environment_values.environment)
    for _, area in pairs(data.environment_areas) do
        if type(area) == "table" and area.environment then
            area.environment = self:convert_mod_path(area.environment)
        end
    end
    local shape_data
    if data.dome_occ_shapes and data.dome_occ_shapes[1] and data.dome_occ_shapes[1].world_dir then
        shape_data = data.dome_occ_shapes[1]
        data.dome_occ_shapes = nil
    end

    WorldDefinition_create_environment(self, data, offset, ...)

	if shape_data then
		local corner = shape_data.position
		local size = Vector3(shape_data.depth, shape_data.width, shape_data.height)
		local texture_name = shape_data.world_dir .. "cube_lights/" .. "dome_occlusion"
		if not DB:has(Idstring("texture"), Idstring(texture_name)) then
			Application:error("Dome occlusion texture doesn't exists, probably needs to be generated", texture_name)
		else
			managers.environment_controller:set_dome_occ_params(corner, size, texture_name)
		end
	end
end

function WorldDefinition:try_loading_custom_instance(instance)
    local frameworks = BeardLib and BeardLib.Frameworks
    local framework = frameworks and frameworks.Base
    local loaded_instances = framework and framework._loaded_instances
    local module = loaded_instances and loaded_instances[instance]
    if module then
        self._custom_instances = self._custom_instances or {}
        if not self._custom_instances[instance] then
            module:Load()
            self._custom_instances[instance] = module
        end
    end
end

function WorldDefinition:load_custom_instances()
    for _, data in pairs(self._continent_definitions) do
        if data.instances then
            for _, instance in pairs(data.instances) do
                self:try_loading_custom_instance(instance.folder)
            end
        end
    end
end

Hooks:PreHook(WorldDefinition, "_insert_instances", "BeardLibInsertCustomInstances", function(self)
    self:load_custom_instances()
end)

local add_trigger_sequence = WorldDefinition.add_trigger_sequence
function WorldDefinition:add_trigger_sequence(unit, triggers, ...)
	if not triggers then
		return
    end

    local fixed_triggers = {}
    for _, trigger in pairs(triggers) do
        if trigger.notify_unit_id then
            table.insert(fixed_triggers, trigger)
        end
    end

    return add_trigger_sequence(self, unit, fixed_triggers, ...)
end

Hooks:PostHook(WorldDefinition, "assign_unit_data", "BeardLibAssignUnitData", function(self, unit, data)
	self:_setup_cubemaps(unit, data)

    --- This fixes custom XML thinking that "01" is a number therefore converting it to just "1" https://github.com/Luffyyy/BeardLib-Editor/issues/557
    --- In order for this fix to work, the editor will insert a space after these problematic texts and then BeardLib will remove them.

    if data.editable_gui then
        local text = unit:editable_gui():text()
        if type(text) == "string" and data.editable_gui.space_fix and text:ends(" ") then
            unit:editable_gui():set_text(text:sub(0, text:len()-1))
        end
    end
end)

function WorldDefinition:_setup_cubemaps(unit, data)
	if not data.cubemap then
		return
	end

	unit:unit_data().cubemap_resolution = data.cubemap.cubemap_resolution

	local texture_name = (self._cube_lights_path or self:world_dir()) .. "cubemaps/" .. unit:unit_data().unit_id
	if not DB:has(Idstring("texture"), Idstring(texture_name)) then
		log("Cubemap texture doesn't exist, probably needs to be generated: " .. tostring(texture_name))
		return
	end
	-- This is needed to get the cubemap texture to show up
	local light = World:create_light("omni")

	light:set_projection_texture(Idstring(texture_name), true, true)
	light:set_enable(false)

	unit:unit_data().cubemap_fake_light = light
end

local unit_ids = Idstring("unit")
local key_unit = unit_ids:key()
Hooks:PreHook(WorldDefinition, "_create_massunit", "BeardLibForceLoadMassunitUnits", function(self, data)
    self:preload_massunit_units(data)
end)

Hooks:PreHook(WorldDefinition, "create", "BeardLibResolveCustomMapAssets", function(self)
    self:_beardlib_resolve_custom_map_assets()
end)

Hooks:PreHook(WorldDefinition, "preload_unit", "BeardLibResolveCustomMapAssetFallback", function(self, name)
    self:_beardlib_resolve_custom_map_asset(name)
end)

function WorldDefinition:preload_massunit_units(data)
    -- Units inside massunits don't pass through the regular spawning function and is spawned inside the engine
    -- Unfortunately the units there don't load through dynamic resources
    -- In order to deal with this issue, we had to essentially include each unit that is used in the massunit (from the editor) in the world file.
    if data and data.preload_units then
        for _, unit in pairs(data.preload_units) do
            if Global.fm.added_files[key_unit] then
                local file = Global.fm.added_files[key_unit][unit:key()]
                if file then
                    BeardLib.Managers.File:LoadAsset(unit_ids, file.path, file.file)
                end
            end
        end
    end
end
