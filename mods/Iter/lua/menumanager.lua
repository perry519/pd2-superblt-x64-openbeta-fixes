local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

Hooks:Add('LocalizationManagerPostInit', 'LocalizationManagerPostInit_Iter', function(loc)
	local language_filename

	local modname_to_language = {
		['PAYDAY 2 THAI LANGUAGE Mod'] = 'thai.txt',
	}
	for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
		language_filename = mod:IsEnabled() and modname_to_language[mod:GetName()]
		if language_filename then
			break
		end
	end

	if not language_filename then
		for _, filename in pairs(file.GetFiles(Iter._path .. 'loc/')) do
			local str = filename:match('^(.*).txt$')
			if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
				language_filename = filename
				break
			end
		end
	end

	if language_filename then
		loc:load_localization_file(Iter._path .. 'loc/' .. language_filename)
	end
	loc:load_localization_file(Iter._path .. 'loc/english.txt', false)
end)

Hooks:Add('MenuManagerInitialize', 'MenuManagerInitialize_Iter', function(menu_manager)

	MenuCallbackHandler.IterMenuCheckboxClbk = function(this, item)
		Iter.settings[item:name()] = item:value() == 'on'
	end

	MenuCallbackHandler.IterSave = function(this, item)
		Iter:save()
	end

	MenuHelper:LoadFromJsonFile(Iter._path .. 'menu/options.txt', Iter, Iter.settings)

	Hooks:Add('MenuManagerBuildCustomMenus', 'MenuManagerBuildCustomMenus_Iter', function(menu_manager, nodes)
		nodes.itr_options_menu:parameters().modifier = {IterMenuCreator.modify_node}
	end)

end)

IterMenuCreator = IterMenuCreator or class()
function IterMenuCreator.modify_node(node)
	local old_items = node:items()
	node:clean_items()
	for i = 1, 2 do
		node:add_item(table.remove(old_items, 1))
	end
	table.sort(old_items, function(a, b)
		local a = managers.localization:text(a:parameters().text_id)
		local b = managers.localization:text(b:parameters().text_id)
		return a < b
	end)
	for _, item in pairs(old_items) do
		node:add_item(item)
	end
	return node
end
