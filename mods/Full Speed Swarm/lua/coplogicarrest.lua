local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_coplogicarrest_enter = CopLogicArrest.enter
function CopLogicArrest.enter(data, new_logic_name, enter_params)
	fs_original_coplogicarrest_enter(data, new_logic_name, enter_params)
	table.insert(FullSpeedSwarm.in_arrest_logic, data.key)
end

local fs_original_coplogicarrest_exit = CopLogicArrest.exit
function CopLogicArrest.exit(data, new_logic_name, enter_params)
	table.delete(FullSpeedSwarm.in_arrest_logic, data.key)
	fs_original_coplogicarrest_exit(data, new_logic_name, enter_params)
end
