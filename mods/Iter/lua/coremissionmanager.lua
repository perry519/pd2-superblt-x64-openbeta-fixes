local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

core:module('CoreMissionManager')
core:import('CoreTable')

local itr_custom_elements = {}

local function _make_navlink(id, editor_name, so_action, from_pos, to_pos, angle, so_access, interval)
	local rotation = Rotation(angle, 0, 0)
	return {
		id = id,
		class = 'ElementSpecialObjective',
		editor_name = editor_name,
		values = {
			on_executed = {},
			align_position = true,
			ai_group = 'enemies',
			is_navigation_link = true,
			position = from_pos,
			scan = true,
			needs_pos_rsrv = true,
			enabled = true,
			execute_on_startup = true,
			rotation = rotation,
			base_delay = 0,
			action_duration_min = 0,
			search_position = to_pos or from_pos + _G.Iter:get_navlink_vector(so_action, rotation),
			use_instigator = false,
			trigger_times = 0,
			trigger_on = 'none',
			so_action = so_action,
			search_distance = 0,
			interval = interval or 1,
			path_stance = 'none',
			path_haste = 'none',
			repeatable = false,
			attitude = 'avoid',
			action_duration_max = 0,
			no_arrest = false,
			chance_inc = 0,
			pose = none,
			forced = false,
			base_chance = 1,
			interaction_voice = 'none',
			SO_access = so_access or '8388607',
			interrupt_dmg = 0,
			align_rotation = true,
			interrupt_objective = true,
			interrupt_dis = 0,
			path_style = 'destination',
			patrol_path = 'none',
		}
	}
end

local function _add_forbid_custom(data, id, navsegs)
	local element = {
		id = id,
		class = 'ElementAIGraph',
		editor_name = 'itr_navseg_forbid_custom',
		values = {
			execute_on_startup = false,
			operation = 'forbid_custom',
			filter_group = 'friendlies',
			graph_ids = navsegs,
			base_delay = 0,
			trigger_times = 0,
			on_executed = {},
			enabled = true,
		}
	}
	table.insert(data.elements, element)
	table.insert(itr_custom_elements, id)
end

if Network:is_client() then
	function MissionScript:load(data)
		local state = data[self._name]
		if data.iter then
			for id, element in pairs(data.iter) do
				state[id] = element
			end
			data.iter = nil
		end

		if self._element_groups.ElementInstancePoint then
			for _, element in ipairs(self._element_groups.ElementInstancePoint) do
				local id = element:id()
				if state[id] then
					self._elements[id]:load(state[id])
					state[id] = nil
				end
			end
		end

		for id, mission_state in pairs(state) do
			-- there can be uninitialized elements when host doesn't use Iter
			local element = self._elements[id]
			if element and type(element.load) == 'function' then
				element:load(mission_state)
			end
		end
	end
else
	local itr_original_missionscript_save = MissionScript.save
	function MissionScript:save(data)
		itr_original_missionscript_save(self, data)

		local state = data[self._name]
		local itr_state = {}
		for _, id in ipairs(itr_custom_elements) do
			itr_state[id] = state[id]
			state[id] = nil
		end
		data.iter = itr_state
	end
end

local level_id = _G.Iter:get_level_id()
local itr_original_missionmanager_addscript = MissionManager._add_script
local itr_original_missionscript_createelements = MissionScript._create_elements

if not _G.Iter.settings['map_change_' .. level_id] then
	-- qued

elseif level_id == 'alex_1' or level_id == 'rat' then

	function MissionManager:_add_script(data)
		local navlink = _make_navlink(102659, 'itr_SO_teammate_navlink_roof_down', 'e_nl_dwn_3_75m',
			Vector3(2235, 973, 2097),
			Vector3(2395, 595, 1718),
			-90, '261600', 1.5)
		table.insert(data.elements, navlink)
		table.insert(itr_custom_elements, 102659)

		navlink = _make_navlink(102660, 'itr_SO_teammate_navlink_roof_up', 'e_nl_ladder_up_3m',
			Vector3(2455, 800, 1726),
			Vector3(2200, 800, 2100.55),
			90, '261600', 1)
		table.insert(data.elements, navlink)
		table.insert(itr_custom_elements, 102660)

		for _, element in pairs(data.elements) do
			if element.editor_name == 'playersEnteredSniperPosition' then
				table.insert(element.values.on_executed, { delay = 0, id = 102659 })
				table.insert(element.values.on_executed, { delay = 0, id = 102660 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'arena' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 102016 or element.id == 102090 then
				element.values.enabled = false
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'arm_fac' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 104631 then
				table.insert(element.values.on_executed, { delay = 0, id = 105003 })
				table.insert(element.values.on_executed, { delay = 0, id = 105008 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'arm_for' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.values.is_navigation_link and element.values.interval == 6 then
				element.values.interval = 1
			elseif element.id == 102457 then
				table.insert(element.values.on_executed, { delay = 5, id = 100004 })
			elseif element.id == 102456 then
				table.insert(element.values.on_executed, { delay = 5, id = 100005 })
			elseif element.id == 102455 then
				table.insert(element.values.on_executed, { delay = 5, id = 100009 })
			elseif element.id == 102454 then
				table.insert(element.values.on_executed, { delay = 5, id = 100205 })
			elseif element.id == 102450 then
				table.insert(element.values.on_executed, { delay = 5, id = 100206 })
			elseif element.id == 102444 then
				table.insert(element.values.on_executed, { delay = 5, id = 100252 })
			elseif element.id == 105584 or element.id == 105587 then
				local new_seq = CoreTable.deep_clone(element.values.sequence_list[1])
				new_seq.sequence = 'int_seq_saw_in'
				table.insert(element.values.sequence_list, new_seq)

				new_seq = CoreTable.deep_clone(new_seq)
				new_seq.sequence = 'int_seq_explosion_in'
				table.insert(element.values.sequence_list, new_seq)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'big' then

	function MissionManager:_add_script(data)
		local outer = {
			[100535] = true,
			[100538] = true,
			[100540] = true,
			[100542] = true,
			[100544] = true,
			[100546] = true,
			[100548] = true,
			[100550] = true,
			[100552] = true,
			[100554] = true
		}
		for _, element in pairs(data.elements) do
			if outer[element.id] then
				element.values.on_executed[1] = { id = 102476, delay = 0 }
			elseif element.id == 106214 then
				local bus_id = 110000
				table.insert(data.elements, {
					id = bus_id,
					editor_name = 'itr_patch_bus',
					class = 'ElementChangeBodyProperty',
					values = {
						enabled = true,
						on_executed = {},
						things = {
							{ 105181, 2, 'set_fixed', true },
						},
						execute_on_startup = false,
						trigger_times = 1,
						toggle = 'on',
						base_delay = 0
					}
				})
				table.insert(itr_custom_elements, bus_id)
				table.insert(element.values.on_executed, {id = bus_id, delay = 0})

			elseif element.id == 103101 then
				table.insert(element.values.on_executed, { id = 103619, delay = 0 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'born' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 100780 then
				element.values.needs_pos_rsrv = false
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'brb' then

	function MissionManager:_add_script(data)
		table.insert(itr_custom_elements, 103000)

		for _, element in pairs(data.elements) do
			if element.id == 100228 then
				table.insert(element.values.on_executed, { delay = 0, id = 103000 })
			elseif element.id == 100469 then
				table.remove(element.values.graph_ids, 3)

				local ai_graph = CoreTable.deep_clone(element)
				ai_graph.id = 103000
				ai_graph.values.graph_ids = { 44 }
				table.insert(data.elements, ai_graph)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'cane' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 136356 then
				element.values.on_executed[1].id = 136446
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'chew' then

	function MissionScript:_create_elements(elements)
		local ladder_nl = {
			[132229] = 154303,
			[132230] = 154304,
			[134229] = 154603,
			[134230] = 154604,
			[136229] = 154903,
			[136230] = 154904,
			[138229] = 155203,
			[138230] = 155204,
			[140229] = 155503,
			[140230] = 155504,
		}

		for _, element in pairs(elements) do
			if element.values.is_navigation_link and element.values.interval then
				element.values.interval = math.max(1, element.values.interval - 3)
				if element.editor_name:find('ladder_nl00') == 1 then
					mvector3.set_x(element.values.position, -1)
				end
			end

			if ladder_nl[element.id] then
				table.insert(element.values.on_executed, { delay = 0, id = ladder_nl[element.id]})
			end

			if element.values.is_navigation_link then
				element.values.SO_access = '262140'
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'chill_combat' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.class == 'ElementPlayerCharacterTrigger' then
				if element.values.trigger_on_left then
					element.values.enabled = false
				end
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'dah' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 135140 then
				local obst = CoreTable.deep_clone(element.values.obstacle_list[1])
				obst.unit_id = 105182
				table.insert(element.values.obstacle_list, obst)
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'dinner' then

	function MissionManager:_add_script(data)
		local elm2door = {
			[101896] = 100920,
			[103186] = 101060,
			[103346] = 102431,
			[103355] = 102474,
			[100082] = 101275,
			[100216] = 102122,
			[100227] = 101871,
		}
		for _, element in pairs(data.elements) do
			if elm2door[element.id] then
				if not element.values.sequence_list or not element.values.sequence_list[1] then
					element.values.sequence_list = {{sequence = 'done_opened', guis_id = 1}}
				end
				element.values.sequence_list[1].unit_id = elm2door[element.id]
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'escape_garage' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 101654 or element.id == 103854 then
				local new_seq = CoreTable.deep_clone(element.values.sequence_list[1])
				new_seq.sequence = 'int_seq_saw_in'
				table.insert(element.values.sequence_list, new_seq)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'escape_street' then

	function MissionManager:_add_script(data)
		local so_action = 'e_nl_under_0_7m'

		local navlink = _make_navlink(103000, 'itr_navlink_reachextension_seg_48', so_action, Vector3(1286, -847, 400), nil, 180)
		table.insert(itr_custom_elements, 103000)
		table.insert(data.elements, navlink)

		local navlink2 = _make_navlink(103001, 'itr_navlink_reachextension_seg_48', so_action, Vector3(1286, -1074, 400), nil, 0)
		table.insert(itr_custom_elements, 103001)
		table.insert(data.elements, navlink2)

		local navlink3 = _make_navlink(103002, 'itr_navlink_reachextension_seg_48', so_action, Vector3(1556, -847, 400), nil, 180)
		table.insert(itr_custom_elements, 103002)
		table.insert(data.elements, navlink3)

		local navlink4 = _make_navlink(103003, 'itr_navlink_reachextension_seg_48', so_action, Vector3(1556, -1074, 400), nil, 0)
		table.insert(itr_custom_elements, 103003)
		table.insert(data.elements, navlink4)

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'family' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 104059 then
				element.values.elements[1] = 101527
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'fex' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 100022 then
				table.insert(element.values.on_executed, { id = 152892, delay = 0 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'firestarter_1' then

	function MissionManager:_add_script(data)
		table.insert(itr_custom_elements, 105000)

		for _, element in pairs(data.elements) do
			if element.id == 100411 then
				local ai_graph = CoreTable.deep_clone(element)
				ai_graph.id = 105000
				ai_graph.values.graph_ids[1] = 24
				table.insert(data.elements, ai_graph)
			elseif element.id == 100409 then
				table.insert(element.values.on_executed, { delay = 0, id = 105000 })
			elseif element.id == 104355 or element.id == 104356 then
				local new_seq = CoreTable.deep_clone(element.values.sequence_list[1])
				new_seq.sequence = 'int_seq_bullet_hit'
				table.insert(element.values.sequence_list, new_seq)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'firestarter_3' or level_id == 'branchbank' then

	function MissionManager:_add_script(data)
		table.insert(itr_custom_elements, 106000)
		table.insert(itr_custom_elements, 106001)

		local element106000 = {
			id = 106000,
			class = 'ElementAINavSeg',
			editor_name = 'itr_add_link1',
			values = {
				enabled = true,
				operation = 'add_nav_seg_neighbours',
				base_delay = 0,
				on_executed = {},
				execute_on_startup = false,
				trigger_times = 0,
				segment_ids = { 92, 55, 55, 92 }
			}
		}
		table.insert(data.elements, element106000)

		local element106001 = CoreTable.deep_clone(element106000)
		element106001.id = 106001
		element106001.values.segment_ids = { 93, 56, 56, 93 }
		element106001.editor_name = 'itr_add_link2'
		table.insert(data.elements, element106001)

		for _, element in pairs(data.elements) do
			if element.id == 102160 then
				table.insert(element.values.on_executed, { delay = 0, id = 106000 })
			elseif element.id == 100311 then
				table.insert(element.values.on_executed, { delay = 0, id = 106001 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'flat' then

	local function itr_mk_toggle(id, ...)
		table.insert(itr_custom_elements, id)

		local element = {
			id = id,
			module = 'CoreElementToggle',
			editor_name = 'itr_toggle_window_trigger_area_' .. id,
			class = 'ElementToggle',
			values = {
				enabled = true,
				on_executed = {},
				elements = { ... },
				execute_on_startup = false,
				trigger_times = 1,
				toggle = 'on',
				base_delay = 0
			}
		}
		return element
	end

	local function itr_mk_trigger(id, so_id, toggle_id, pos)
		table.insert(itr_custom_elements, id)

		local element = {
			id = id,
			editor_name = 'itr_SO_trigger_window_toggle_' .. id,
			class = 'ElementSpecialObjectiveTrigger',
			values = {
				enabled = true,
				on_executed = {
					{ delay = 0, id = toggle_id }
				},
				elements = { so_id },
				event = 'anim_act_04',
				execute_on_startup = false,
				trigger_times = 1,
				base_delay = 0,
				position = pos,
				rotation = Rotation(0, 0, -0)
			}
		}
		return element
	end

	local window_to_SO = {
		[100031] = 101063,
		[100047] = 101257,
		-- [100063] = ?,
		-- [102237] = ?,
		[102326] = 102141,
		[102327] = 100352,
		[102609] = 103253,
		[103282] = 102200,
		-- [103399] = ?,
		-- [103420] = ?,
	}
	function MissionManager:_add_script(data)
		local insert_id = 105000
		local SOs = {}
		for _, element in pairs(data.elements) do
			if element.id == 104122 then
				table.insert(element.values.elements, 104832)

			elseif element.id == 104150 then
				table.insert(element.values.elements, 104833)

			elseif element.editor_name:find('check enemy touch window') then
				element.values.enabled = false
				local so_id = window_to_SO[element.id]
				if so_id then
					SOs[so_id] = true
					table.insert(data.elements, itr_mk_toggle(insert_id, element.id))
					table.insert(data.elements, itr_mk_trigger(insert_id + 1, window_to_SO[element.id], insert_id, element.values.position))
					insert_id = insert_id + 2
				end
			end
		end
		for _, element in pairs(data.elements) do
			if SOs[element.id] then
				element.values.scan = true
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif _G.Iter:should_skip_navigation_hooks() then

	function MissionManager:_add_script(data)
		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'friend' then

	function MissionManager:_add_script(data)
		table.insert(itr_custom_elements, 105000)
		table.insert(itr_custom_elements, 105001)

		for _, element in pairs(data.elements) do
			if element.id == 103880 then
				table.insert(element.values.on_executed, { delay = 0, id = 105000 })
			elseif element.id == 103877 then
				table.insert(element.values.on_executed, { delay = 0, id = 105001 })
				local element105000 = {
					id = 105000,
					class = 'ElementAINavSeg',
					values = {
						enabled = true,
						operation = 'remove_nav_seg_neighbours',
						base_delay = 0,
						on_executed = {},
						execute_on_startup = false,
						trigger_times = 0,
						segment_ids = { 106, 55, 55, 106 }
					},
					editor_name = 'itr_remove_link1'
				}
				table.insert(data.elements, element105000)

				local element105001 = CoreTable.deep_clone(element105000)
				element105001.id = 105001
				element105001.values.segment_ids = { 71, 55, 55, 71 }
				element105001.editor_name = 'itr_remove_link2'
				table.insert(data.elements, element105001)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'glace' then

	function MissionManager:_add_script(data)
		local e102392, e102243
		for _, element in pairs(data.elements) do
			if element.id == 102392 then
				e102392 = element
			elseif element.id == 102243 then
				e102243 = element
			end
		end
		if e102392 and e102243 then
			e102243.values.trigger_list = CoreTable.deep_clone(e102392.values.trigger_list)
			e102243.values.trigger_list[1].notify_unit_id = 102519
			e102243.values.trigger_list[1].notify_unit_sequence = 'set_type_gold'
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'hox_1' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 101627 then
				_add_forbid_custom(data, 104000, {3, 9, 93, 32, 73, 31})
				table.insert(element.values.on_executed, { id = 104000, delay = 0 })
			elseif element.id == 101628 then
				_add_forbid_custom(data, 104001, {14, 16, 19, 20, 1})
				table.insert(element.values.on_executed, { id = 104001, delay = 0 })
			elseif element.id == 101630 then
				_add_forbid_custom(data, 104002, {69, 98, 99, 84, 29, 30})
				table.insert(element.values.on_executed, { id = 104002, delay = 0 })
			elseif element.id == 101631 then
				_add_forbid_custom(data, 104003, {25, 26, 78, 106, 107})
				table.insert(element.values.on_executed, { id = 104003, delay = 0 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'hox_2' then


	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 100018 then
				_add_forbid_custom(data, 103000, {45, 47, 50, 51, 60, 62})
				table.insert(element.values.on_executed, { id = 103000, delay = 0 })
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'jolly' then

	function MissionManager:_add_script(data)
		local base_element_id = 101785
		table.insert(itr_custom_elements, base_element_id)
		table.insert(itr_custom_elements, base_element_id + 1)
		table.insert(itr_custom_elements, base_element_id + 2)
		table.insert(itr_custom_elements, base_element_id + 3)

		for _, element in pairs(data.elements) do
			if element.id == 100760 or element.id == 100761 or element.id == 100762 or element.id == 100763
			or element.id == 100766 or element.id == 100767 or element.id == 100768 or element.id == 100769
			then
				element.values.SO_access = '16383'

			elseif element.id == 100406 then
				table.remove(element.values.on_executed, 305)
				table.insert(element.values.on_executed, { delay = 0, id = base_element_id })
				table.insert(element.values.on_executed, { delay = 0, id = base_element_id + 1 })
				table.insert(element.values.on_executed, { delay = 0, id = base_element_id + 2 })
				table.insert(element.values.on_executed, { delay = 0, id = base_element_id + 3 })

			elseif element.id == 101124 then
				element.values.repeatable = true
				element.values.so_action = 'e_nl_down_1m'
				element.values.align_position = false
				element.values.rotation = Rotation(103, 0, 0)
				element.values.position = Vector3(4686, 2490, 92)
				element.values.search_position = Vector3(4553, 2456, -1)
			elseif element.id == 100544 then
				local ladder1 = CoreTable.deep_clone(element)
				ladder1.editor_name = 'itr_SO_AI_ladder1'
				ladder1.id = base_element_id
				ladder1.values.align_position = true
				ladder1.values.attitude = 'avoid'
				ladder1.values.interval = 1.5
				ladder1.values.repeatable = true
				ladder1.values.so_action = 'e_nl_up_6m_var3'
				ladder1.values.path_style = 'destination'
				ladder1.values.rotation = Rotation(-150, 0, 0)
				ladder1.values.position = Vector3(-1533, 6530, 607)
				ladder1.values.search_position = Vector3(-1547, 6260, 1212)
				table.insert(data.elements, ladder1)

				local ladder2 = CoreTable.deep_clone(ladder1)
				ladder2.editor_name = 'itr_SO_AI_ladder2'
				ladder2.id = base_element_id + 1
				ladder2.values.rotation = Rotation(0, 0, 0)
				ladder2.values.position = Vector3(-1583, -325, 607)
				ladder2.values.search_position = Vector3(-1538, -80, 1212)
				table.insert(data.elements, ladder2)

				local ladder3 = CoreTable.deep_clone(ladder1)
				ladder3.editor_name = 'itr_SO_AI_ladder3'
				ladder3.id = base_element_id + 2
				ladder3.values.so_action = 'e_nl_cs_up_8m_ladder'
				ladder3.values.rotation = Rotation(180, 0, 0)
				ladder3.values.position = Vector3(2353, 6485, 300)
				ladder3.values.search_position = Vector3(2352, 6262, 1213)
				table.insert(data.elements, ladder3)

				local ladder4 = CoreTable.deep_clone(ladder3)
				ladder4.editor_name = 'itr_SO_AI_ladder4'
				ladder4.id = base_element_id + 3
				ladder4.values.rotation = Rotation(0, 0, 0)
				ladder4.values.position = Vector3(2364, -315, 300)
				ladder4.values.search_position = Vector3(2360, -118, 1217)
				table.insert(data.elements, ladder4)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'kenaz' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 196574 then
				table.insert(element.values.on_executed, { delay = 0, id = 102887 })
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'kosugi' then

	function MissionScript:_create_elements(elements)
		table.insert(itr_custom_elements, 105000)

		for _, element in pairs(elements) do
			if element.id == 102617 then
				table.insert(element.values.on_executed, { delay = 0, id = 105000 })
			elseif element.id == 102626 then
				table.insert(element.values.on_executed, { delay = 0, id = 105000 })
				local element105000 = {
					id = 105000,
					module = 'CoreElementToggle',
					editor_name = 'itr_toggle_SO',
					class = 'ElementToggle',
					values = {
						enabled = true,
						on_executed = {},
						elements = {
							103543,
							103545
						},
						set_trigger_times = -1,
						execute_on_startup = false,
						trigger_times = 0,
						toggle = 'on',
						base_delay = 0
					}
				}
				table.insert(elements, element105000)
			elseif element.id == 103543 or element.id == 103545 then
				element.values.enabled = false
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'mex' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 138008 or element.id == 138308 or element.id == 138608 then
				if element.values.so_action == 'e_so_disarm_bomb' then
					element.values.path_style = 'destination'
					element.values.align_position = true
					element.values.align_rotation = true
				end
			elseif element.id == 102412 then
				local id_disable_area_kill = 150400
				table.insert(element.values.on_executed, { delay = 10, id = id_disable_area_kill })

				local element2 = CoreTable.deep_clone(element)
				element2.id = id_disable_area_kill
				element2.editor_name = 'disable_triggers_in_arizona'
				element2.values.toggle = 'off'
				element2.values.on_executed = {}

				table.insert(elements, element2)
				table.insert(itr_custom_elements, id_disable_area_kill)
			elseif element.id == 100215 then
				element.values.path_style = 'destination'
				element.values.patrol_path = 'none'
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'mia_1' then

	function MissionScript:_create_elements(elements)
		local unusable_navlinks = {
			[131950] = true,
			[131951] = true,
			[132650] = true,
			[132651] = true,
			[133450] = true,
			[133451] = true,
			[133850] = true,
			[133851] = true,
			[134250] = true,
			[134251] = true,
			[135850] = true,
			[135851] = true,
			[135851] = true,
			[136250] = true,
			[136251] = true,
			[137450] = true,
			[137451] = true,
		}
		for _, element in pairs(elements) do
			if unusable_navlinks[element.id] then
				element.values.enabled = false
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'moon' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 104665 then
				for i = 1, 5 do
					table.remove(element.values.on_executed, 1)
				end
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'mus' then

	function MissionManager:_add_script(data)
		table.insert(itr_custom_elements, 105000)

		local entrance_trigger = {
			id = 105000,
			class = 'ElementUnitSequenceTrigger',
			module = 'CoreElementUnitSequenceTrigger',
			editor_name = 'itr_entrance_trigger',
			values = {
				base_delay = 0,
				enabled = true,
				execute_on_startup = false,
				trigger_times = 1,
				sequence_list = {
					{ unit_id = 300022, guis_id = 1, sequence = 'done_opened' },
				},
				on_executed = {
					{ delay = 0, id = 101225 },
					{ delay = 0, id = 100796 },
					{ delay = 0, id = 100797 },
				},
			}
		}
		table.insert(data.elements, entrance_trigger)

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'pbr2' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 100063 then
				table.remove(element.values.on_executed, 2)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'peta' then

	function MissionManager:_add_script(data)

		for _, element in pairs(data.elements) do
			if element.id == 100479 then
				table.remove(element.values.obstacle_list, 7)
			elseif element.id == 100245 then
				local ramp_id = 105000
				table.insert(data.elements, {
					id = ramp_id,
					editor_name = 'itr_patch_ramp',
					class = 'ElementChangeBodyProperty',
					values = {
						enabled = true,
						on_executed = {},
						things = {
							{ 100212, 14, 'set_fixed', true },
							{ 101390, 14, 'set_fixed', true },
							{ 101834, 14, 'set_fixed', true },
						},
						execute_on_startup = false,
						trigger_times = 1,
						toggle = 'on',
						base_delay = 0
					}
				})
				table.insert(itr_custom_elements, ramp_id)
				table.insert(element.values.on_executed, {id = ramp_id, delay = 5})
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'pex' then

	function MissionScript:_create_elements(elements)
		for _, element in pairs(elements) do
			if element.id == 100636 then
				table.insert(element.values.on_executed, {id = 100875, delay = 0})
			elseif element.id == 153486 then
				element.values.position = Vector3(-1225, 820, 950)
				element.values.search_position = Vector3(-1225, 1020, 500)
			elseif element.id == 153586 then
				element.values.position = Vector3(-1400, 820, 950)
				element.values.search_position = Vector3(-1400, 1020, 500)
			elseif element.id == 153686 then
				element.values.position = Vector3(-375, 820, 950)
				element.values.search_position = Vector3(-375, 1020, 500)
			elseif element.id == 153786 then
				element.values.position = Vector3(-200, 820, 950)
				element.values.search_position = Vector3(-200, 1020, 500)
			end
		end

		return itr_original_missionscript_createelements(self, elements)
	end

elseif level_id == 'red2' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 102449 then
				element.values.position = Vector3(-55, 1905, -25)

			elseif element.id == 103160 then
				table.delete(element.values.graph_ids, 97)

			elseif element.id == 106565 then
				element.values.position = Vector3(300, 1675, -24.9478)
				element.values.rotation = Rotation(-45, 0, -0)
				element.values.so_action = 'none'
			elseif element.id == 106566 then
				element.values.position = Vector3(750, -1425, -10.009)
				element.values.rotation = Rotation(-110, 0, 0)
				element.values.so_action = 'none'
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'rvd1' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 101436 then
				table.insert(element.values.sequence_list, { unit_id = 100072, guis_id = 1, sequence = 'int_seq_break' } )
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'skm_big2' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 102241 then
				table.delete(element.values.graph_ids, 20)
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'skm_mallcrasher' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 301584 then
				table.insert(element.values.obstacle_list, {
					obj_name = Idstring('rp_navigation_splitter'),
					guis_id = #element.values.obstacle_list + 1,
					unit_id = 600000,
				})
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'vit' then

	function MissionManager:_add_script(data)
		local element1

		for _, element in pairs(data.elements) do
			if element.id == 104080 then
				element.class = 'ElementDeleteVehicle'
				element.values.unit_ids = {101268}

			elseif element.id == 101444 then
				element1 = CoreTable.deep_clone(element)
			elseif element.id == 103172 then
				table.insert(element.values.on_executed, {id = 105000, delay = 0})
			elseif element.id == 103171 then
				table.insert(element.values.on_executed, {id = 105001, delay = 0})
			elseif element.id == 103170 then
				table.insert(element.values.on_executed, {id = 105002, delay = 0})
			end
		end

		element1.id = 105000
		element1.editor_name = 'itr_patch_oval_office_door'
		element1.values.operation = 'remove'
		element1.values.obstacle_list = { element1.values.obstacle_list[13] }
		element1.values.obstacle_list[1].guis_id = 1
		table.insert(data.elements, element1)
		table.insert(itr_custom_elements, 105000)

		local element2 = CoreTable.deep_clone(element1)
		element2.id = 105001
		element2.values.obstacle_list[1].unit_id = 102555
		table.insert(data.elements, element2)
		table.insert(itr_custom_elements, 105001)

		local element3 = CoreTable.deep_clone(element1)
		element3.id = 105002
		element3.values.obstacle_list[1].unit_id = 102556
		table.insert(data.elements, element3)
		table.insert(itr_custom_elements, 105002)

		itr_original_missionmanager_addscript(self, data)
	end

elseif level_id == 'welcome_to_the_jungle_2' then

	function MissionManager:_add_script(data)
		for _, element in pairs(data.elements) do
			if element.id == 102507 then
				element.values.sequence_list[1].sequence = 'done_opened'
			end
		end

		itr_original_missionmanager_addscript(self, data)
	end

end
