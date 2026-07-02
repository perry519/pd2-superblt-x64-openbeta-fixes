local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

core:module('CoreWorldDefinition')

local level_id = _G.Iter:get_level_id()

local itr_original_worlddefinition_create = WorldDefinition.create
local itr_original_worlddefinition_createstaticsunit = WorldDefinition._create_statics_unit

if not _G.Iter.settings['map_change_' .. level_id] then
	-- qued

elseif level_id == 'arm_fac' then

	function WorldDefinition:_create_statics_unit(data, offset)
		local unit_id = data.unit_data.unit_id
		if unit_id == 100101 then
			data.unit_data.position = Vector3(1767, -3664, 207.39)
		elseif unit_id == 100226 then
			data.unit_data.position = Vector3(577, -3475, 207.39)
		elseif unit_id == 100227 then
			data.unit_data.position = Vector3(-800, -3600, 207.39)
		end

		return itr_original_worlddefinition_createstaticsunit(self, data, offset)
	end

elseif level_id == 'cage' then

	function WorldDefinition:_create_statics_unit(data, offset)
		local unit_id = data.unit_data.unit_id
		if unit_id == 104218 or unit_id == 104264 or unit_id == 104273 or unit_id == 104303 or unit_id == 105068 or unit_id == 105143 then
			return
		end

		return itr_original_worlddefinition_createstaticsunit(self, data, offset)
	end

elseif level_id == 'dah' then

	if Network:is_server() then
		function WorldDefinition:_create_statics_unit(data, ...)
			if data.unit_data.unit_id == 105182 then
				data.unit_data.position = Vector3(-2080, -4925, 775.001)
			end

			return itr_original_worlddefinition_createstaticsunit(self, data, ...)
		end
	end

elseif level_id == 'mad' then

	function WorldDefinition:_create_statics_unit(data, offset)
		local unit_id = data.unit_data.unit_id
		if unit_id == 136936 or unit_id == 136937 then
			mvector3.add(data.unit_data.position, Vector3(40, 0, 0))
		end

		return itr_original_worlddefinition_createstaticsunit(self, data, offset)
	end

elseif level_id == 'mex' then

	function WorldDefinition:_create_statics_unit(data, offset)
		if data.unit_data.unit_id == 147353 then
			mvector3.add(data.unit_data.position, Vector3(20, 0, 0))
		end

		return itr_original_worlddefinition_createstaticsunit(self, data, offset)
	end

elseif level_id == 'mia_1' then

	function WorldDefinition:_create_statics_unit(data, offset)
		local unit_id = data.unit_data.unit_id
		if unit_id == 101331 then -- room 104
			mvector3.add(data.unit_data.position, Vector3(0, 20, 0))
		elseif unit_id == 101333 then -- room 105
			mvector3.add(data.unit_data.position, Vector3(0, 20, 0))
		elseif unit_id == 101334 then -- room 106
			mvector3.add(data.unit_data.position, Vector3(0, 20, 0))
		end

		return itr_original_worlddefinition_createstaticsunit(self, data, offset)
	end

elseif level_id == 'skm_mallcrasher' then

	function WorldDefinition:create(layer, offset)
		if layer == 'all' then
			local vase_blocker = {
				unit_data = {
					   rotation = Rotation(0, 0, 0),
					   position = Vector3(-2490, -1200, 0),
					   name_id = 'door_blocker_itr_vase',
					   continent = 'mission_turf_war',
					   name = 'units/dev_tools/level_tools/door_blocker/door_blocker',
					   unit_id = 600000,
				},
			}
			table.insert(self._continent_definitions.mission_turf_war.statics, vase_blocker)
		end

		return itr_original_worlddefinition_create(self, layer, offset)
	end

elseif level_id == 'wwh' then

	function WorldDefinition:_create_statics_unit(data, offset)
		local unit = itr_original_worlddefinition_createstaticsunit(self, data, offset)
		if unit then
			if data.unit_data.unit_id == 100139 or data.unit_data.unit_id == 100142 then
				unit:body(0):set_fixed(true)
			end
		end
		return unit
	end

end
