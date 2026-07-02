Hooks:Register("BLTOnBuildOptions")

-- Create the menu node for BLT mods
local function add_blt_mods_node(menu)
	local new_node = {
		_meta = "node",
		name = "blt_mods",
		back_callback = "perform_blt_save close_blt_mods",
		menu_components = "blt_mods",
		scene_state = "crew_management",
		[1] = {
			["_meta"] = "default_item",
			["name"] = "back"
		}
	}
	table.insert(menu, new_node)

	return new_node
end

-- Create the menu node for BLT mod options
local function add_blt_options_node(menu)
	local new_node = {
		_meta = "node",
		name = "blt_options",
		refresh = "BLTModOptionsInitiator",
		back_callback = "perform_blt_save",
		modifier = "BLTModOptionsInitiator",
		[1] = {
			_meta = "legend",
			name = "menu_legend_select"
		},
		[2] = {
			_meta = "legend",
			name = "menu_legend_back"
		},
		[3] = {
			_meta = "default_item",
			name = "back"
		},
		[4] = {
			_meta = "item",
			name = "back",
			text_id = "menu_back",
			back = true,
			previous_node = true,
			visible_callback = "is_pc_controller"
		},
		[5] = {
			_meta = "item",
			name = "blt_settings",
			text_id = "blt_settings",
			help_id = "blt_settings_desc",
			next_node = "blt_settings",
			priority = 1
		},
		[6] = {
			_meta = "item",
			name = "blt_divider",
			type = "MenuItemDivider",
			no_text = true,
			size = 8,
			priority = 0
		}
	}
	table.insert(menu, new_node)

	return new_node
end

-- Create the menu node for BLT mod keybinds
local function add_blt_keybinds_node(menu)
	local new_node = {
		_meta = "node",
		name = "blt_keybinds",
		back_callback = "perform_blt_save",
		modifier = "BLTKeybindMenuInitiator",
		refresh = "BLTKeybindMenuInitiator",
		[1] = {
			_meta = "legend",
			name = "menu_legend_select"
		},
		[2] = {
			_meta = "legend",
			name = "menu_legend_back"
		},
		[3] = {
			_meta = "default_item",
			name = "back"
		},
		[4] = {
			_meta = "item",
			name = "back",
			text_id = "menu_back",
			back = true,
			previous_node = true,
			visible_callback = "is_pc_controller"
		}
	}
	table.insert(menu, new_node)

	return new_node
end

-- Create the menu node for the download manager
local function add_blt_downloads_node(menu)
	local new_node = {
		_meta = "node",
		name = "blt_download_manager",
		menu_components = "blt_download_manager",
		back_callback = "close_blt_download_manager",
		scene_state = "crew_management",
		[1] = {
			_meta = "default_item",
			name = "back"
		}
	}
	table.insert(menu, new_node)

	return new_node
end

-- Create the menu node for BLT settings
local function add_blt_settings_node(menu)
	local new_node = {
		_meta = "node",
		name = "blt_settings",
		refresh = "BLTSettingsInitiator",
		back_callback = "perform_blt_save",
		modifier = "BLTSettingsInitiator",
		[1] = {
			_meta = "legend",
			name = "menu_legend_select"
		},
		[2] = {
			_meta = "legend",
			name = "menu_legend_back"
		},
		[3] = {
			_meta = "default_item",
			name = "back"
		},
		[4] = {
			_meta = "item",
			name = "back",
			text_id = "menu_back",
			back = true,
			previous_node = true,
			visible_callback = "is_pc_controller"
		}
	}

	local menu_item_language = {
		_meta = "item",
		type = "MenuItemMultiChoice",
		name = "blt_localization_choose",
		text_id = "blt_language_select",
		help_id = "blt_language_select_desc",
		callback = "blt_choose_language",
		value_func = function() return BLT.Localization:get_language().language end
	}
	for _, lang in ipairs(BLT.Localization:languages()) do
		table.insert(menu_item_language, {
			_meta = "option",
			text_id = "blt_language_" .. tostring(lang.language),
			value = tostring(lang.language)
		})
	end

	local menu_item_divider = {
		_meta = "item",
		name = "blt_divider",
		type = "MenuItemDivider",
		no_text = true,
		size = 8
	}

	local menu_item_log_level = {
		_meta = "item",
		type = "MenuItemMultiChoice",
		name = "blt_log_level_choose",
		text_id = "blt_log_level_select",
		help_id = "blt_log_level_select_desc",
		callback = "blt_choose_log_level",
		value_func = function() return BLTLogs.log_level end
	}
	for i = _G.LogLevel.NONE, _G.LogLevel.ALL do
		table.insert(menu_item_log_level, {
			_meta = "option",
			text_id = "blt_log_level_" .. i,
			value = i
		})
	end

	local menu_item_log_lifetime = {
		_meta = "item",
		type = "MenuItemMultiChoice",
		name = "blt_log_lifetime_choose",
		text_id = "blt_log_lifetime_select",
		help_id = "blt_log_lifetime_select_desc",
		callback = "blt_choose_log_lifetime",
		value_func = function() return BLTLogs.lifetime end
	}
	for _, lifetime in ipairs(BLTLogs.lifetime_options) do
		table.insert(menu_item_log_lifetime, {
			_meta = "option",
			text_id = lifetime[2],
			value = lifetime[1]
		})
	end

	table.insert(new_node, menu_item_language)
	table.insert(new_node, menu_item_divider)
	table.insert(new_node, menu_item_log_level)
	table.insert(new_node, menu_item_log_lifetime)

	table.insert(menu, new_node)

	return new_node
end

local function inject_menu_options(menu, node_name, injection_point, items)
	for _, node in ipairs(menu) do
		if node.name == node_name then
			for i, item in ipairs(node) do
				-- If we get to the last node, inject it anyway - it's better for it to be in
				-- the wrong place than missing.
				if item.name == injection_point or i == #node then
					for k = #items, 1, -1 do
						table.insert(node, i + 1, items[k])
					end

					return
				end
			end
		end
	end
end

-- Add the menu nodes for various menus
Hooks:Add("CoreMenuData.LoadDataMenu", "BLT.CoreMenuData.LoadDataMenu", function(menu_id, menu)
	-- Create menu items
	local menu_item_divider = {
		_meta = "item",
		name = "blt_divider",
		type = "MenuItemDivider",
		no_text = true,
		size = 8
	}

	local menu_item_options = {
		_meta = "item",
		name = "blt_options",
		text_id = "blt_options_menu_lua_mod_options",
		help_id = "blt_options_menu_lua_mod_options_desc",
		next_node = "blt_options"
	}

	local menu_item_mods = {
		_meta = "item",
		name = "blt_mods_new",
		text_id = "blt_options_menu_blt_mods",
		help_id = "blt_options_menu_blt_mods_desc",
		next_node = "blt_mods"
	}

	local menu_item_keybinds = {
		_meta = "item",
		name = "blt_keybinds",
		text_id = "blt_options_menu_keybinds",
		help_id = "blt_options_menu_keybinds_desc",
		visible_callback = "blt_show_keybinds_item",
		next_node = "blt_keybinds"
	}

	local point = "advanced"

	-- Inject menu nodes and items
	if menu_id == "start_menu" then
		add_blt_mods_node(menu)
		local options_node = add_blt_options_node(menu)
		Hooks:Call("BLTOnBuildOptions", options_node, menu_id) -- All mods to hook into the options menu to add items
		add_blt_keybinds_node(menu)
		add_blt_downloads_node(menu)
		add_blt_settings_node(menu)
		inject_menu_options(menu, "options", point, {
			menu_item_divider,
			menu_item_mods,
			menu_item_options,
			menu_item_keybinds
		})
	elseif menu_id == "pause_menu" then
		local options_node = add_blt_options_node(menu)
		Hooks:Call("BLTOnBuildOptions", options_node, menu_id) -- All mods to hook into the options menu to add items
		add_blt_keybinds_node(menu)
		add_blt_settings_node(menu)
		inject_menu_options(menu, "options", point, {
			menu_item_divider,
			menu_item_options,
			menu_item_keybinds
		})
	end
end)

---Menu Initiator for the Mod Options
---@class BLTModOptionsInitiator
---@field new fun(self):BLTModOptionsInitiator
BLTModOptionsInitiator = BLTModOptionsInitiator or class(MenuInitiatorBase)

function BLTModOptionsInitiator:modify_node(node)
	local old_items = node:items()

	node:clean_items()

	table.sort(old_items, function(a, b)
		local a_params = a:parameters()
		local b_params = b:parameters()
		if a_params.priority and (not b_params.priority or b_params.priority < a_params.priority) then
			return true
		elseif b_params.priority and (not a_params.priority or a_params.priority < b_params.priority) then
			return false
		end
		local text_a = managers.localization:text(a_params.text_id)
		local text_b = managers.localization:text(b_params.text_id)
		return text_a < text_b
	end)

	for _, item in pairs(old_items) do
		node:add_item(item)
	end

	return node
end

function BLTModOptionsInitiator:refresh_node(node)
	self:modify_node(node)
end

---Menu Initiator for the BLT Settings
---@class BLTSettingsInitiator : BLTModOptionsInitiator
---@field new fun(self):BLTSettingsInitiator
BLTSettingsInitiator = BLTSettingsInitiator or class(BLTModOptionsInitiator)

function BLTSettingsInitiator:modify_node(node)
	for _, item in pairs(node:items()) do
		if item:parameters().value_func then
			item:set_value(item:parameters().value_func())
		end
	end
	return node
end
