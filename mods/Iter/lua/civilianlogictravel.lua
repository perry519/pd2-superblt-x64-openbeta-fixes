local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not Iter.settings.streamline_path then
	return
end

local mvec3_eq = mvector3.equal
local mvec3_z = mvector3.z
local math_abs = math.abs
local table_remove = table.remove

function CivilianLogicTravel._optimize_path(path, allow_out_of_graph)
	local path_nr = #path
	if path_nr <= 2 then
		return path
	end

	local function remove_duplicates(path)
		local removed_nr = 0
		for i = #path, 2, -1 do
			if mvec3_eq(path[i], path[i - 1]) then
				table_remove(path, i - 1)
				removed_nr = removed_nr + 1
			end
		end
		return removed_nr
	end

	path_nr = path_nr - remove_duplicates(path)

	local navman = managers.navigation
	local opt_path = {path[1]}
	local count = 1
	local i = 1

	local z = {}
	for i = 1, path_nr do
		local pi = path[i]
		if type(pi) ~= 'userdata' then
			return path
		end
		z[i] = mvec3_z(pi)
	end

	while i < path_nr do
		local pos_i = path[i]
		local pos_i_z = z[i]
		local next_index = i + 1

		for j = i + 1, path_nr, 1 do
			if math_abs(z[j] - pos_i_z) < 100 then
				if allow_out_of_graph then
					if not CopActionWalk._chk_shortcut_pos_to_pos(pos_i, path[j]) then
						next_index = j
					end
				else
					if not navman:raycast({
						pos_from = pos_i,
						pos_to = path[j]
					}) then
						next_index = j
					end
				end
			end
		end

		opt_path[count + 1] = path[next_index]
		count = count + 1
		i = next_index
	end

	remove_duplicates(opt_path)

	return opt_path
end
