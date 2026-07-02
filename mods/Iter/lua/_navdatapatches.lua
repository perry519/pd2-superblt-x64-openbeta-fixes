local mvec3_add = mvector3.add
local mvec3_cpy = mvector3.copy
local mvec3_set_x = mvector3.set_x
local mvec3_set_y = mvector3.set_y
local mvec3_x = mvector3.x
local mvec3_y = mvector3.y
local mvec3_z = mvector3.z

local seg2vg
local add_segment
local append_room
local transfer_room
local append_vis_group
local level_id = Iter:get_level_id()

local itr_original_navigationmanager_setloaddata = NavigationManager.set_load_data

local function _make_seg2vg(data)
	seg2vg = {}
	for i, vg in ipairs(data.vis_groups) do
		seg2vg[vg.seg] = i
	end
end

if not Iter.settings['map_change_' .. level_id] then
	-- qued

elseif level_id == 'alex_2' then

	function NavigationManager:set_load_data(data)
		local rid = append_room(119, 117, 111, 110, 74, 22.5, 74, 22.5, 55)
		append_door(Vector3(117, 110, 22.5), Vector3(119, 110, 22.5), 456, rid)

		rid = append_room(119, 117, 122, 111, 181, 74, 181, 74, 55)
		append_door(Vector3(117, 111, 74), Vector3(119, 111, 74), rid - 1, rid)

		rid = append_room(119, 117, 134, 122, 280, 181, 280, 181, 90)
		local did = append_door(Vector3(117, 122, 181), Vector3(119, 122, 181), rid - 1, rid)

		data.nav_segments[55].neighbours[90] = { did }
		data.nav_segments[90].neighbours[55] = { did }

		rid = append_room(119, 117, 135, 134, 222.5, 280, 222.5, 280, 90)
		append_door(Vector3(117, 134, 280), Vector3(119, 134, 280), rid - 1, rid)
		append_door(Vector3(117, 135, 222.5), Vector3(119, 135, 222.5), 685, rid)

		data.room_borders_y_neg[685] = 135

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'arm_fac' then

	function NavigationManager:set_load_data(data)
		-- around truck 100226
		local rid = append_room(24, 32, -130, -131, 232.389, 232.389, 232.389, 232.389, 11)
		local did = append_door(Vector3(24, -130, 232.389), Vector3(24, -131, 232.389), 108, rid)
		append_door(Vector3(32, -130, 232.389), Vector3(32, -131, 232.389), 175, rid)
		append_door(Vector3(26, -131, 232.389), Vector3(32, -131, 232.389), 164, rid)
		append_door(Vector3(24, -131, 232.389), Vector3(26, -131, 232.389), 97, rid)

		table.insert(data.nav_segments[9].neighbours[11], did)
		table.insert(data.nav_segments[11].neighbours[9], did)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'arm_for' then

	function NavigationManager:set_load_data(data)
		-- 2701 and 2703 are clones, that's a new level of fucked up
		-- 2705 and 2713 are clones, won't bother to delete that and their doors

		transfer_room(2689, 57, 56)

		transfer_room(2701, 58, 59)

		transfer_room(2704, 59, 60)
		transfer_room(2705, 59, 60)
		transfer_room(2706, 59, 60)
		transfer_room(2707, 59, 60)
		transfer_room(2708, 59, 60)
		transfer_room(2709, 59, 60)
		transfer_room(2710, 59, 60)
		transfer_room(2711, 59, 60)
		transfer_room(2712, 59, 60)

		data.nav_segments[56].neighbours[57] = {5188}
		data.nav_segments[57].neighbours[56] = {5188}

		data.nav_segments[59].neighbours[60] = {5210}
		data.nav_segments[60].neighbours[59] = {5210}

		data.nav_segments[59].neighbours[58] = {5195}
		data.nav_segments[58].neighbours[59] = {5195}

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'big' then

	function NavigationManager:set_load_data(data)
		-- so _get_pos_on_wall() can find something when using thermite
		data.nav_segments[62].pos = Vector3(-3600, -1400, -1000)

		-- prevent chars to walk into wall
		data.room_borders_x_neg[489] = 66
		mvector3.set_x(data.door_low_pos[800], 66)
		mvector3.set_x(data.door_low_pos[801], 66)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'born' then

	function NavigationManager:set_load_data(data)
		-- bar counter
		data.room_borders_y_neg[442] = -46
		append_door(Vector3(39, -46, 72.5), Vector3(39, -45, 72.5), 442, 457)

		-- near bunker
		data.room_borders_y_pos[2798] = 111

		local did = append_door(Vector3(-149, 111, 22.4998), Vector3(-146, 111, 22.4998), 2798, 3405)
		append_door(Vector3(-146, 111, 22.4998), Vector3(-140, 111, 22.4998), 2798, 3381)
		append_door(Vector3(-140, 111, 22.4998), Vector3(-138, 111, 22.4998), 2798, 3379)

		data.nav_segments[50].neighbours[51] = { did, did + 1, did + 2 }
		data.nav_segments[51].neighbours[50] = { did, did + 1, did + 2 }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'branchbank' then

	function NavigationManager:set_load_data(data)
		-- prevent chars to walk into wall
		local rid = 551
		data.room_borders_y_pos[rid] = 41
		local did = 999
		mvector3.set_y(data.door_high_pos[did], 41)

		-- Parking, grid side
		rid = append_room(-129, -130, 76, 53, 22.5, 22.5, 22.5, 22.5, 17)
		append_door(Vector3(-130, 76, 22.5), Vector3(-129, 76, 22.5), 504, rid)
		did = append_door(Vector3(-130, 53, 22.5), Vector3(-129, 53, 22.5), 553, rid)

		table.insert(data.nav_segments[17].neighbours[18], did)
		table.insert(data.nav_segments[18].neighbours[17], did)

		data.room_borders_x_pos[508] = -130
		append_door(Vector3(-130, 66, 22.5), Vector3(-130, 67, 22.5), 508, rid)

		-- Parking, other side
		rid = append_room(-110, -124, 114, 113, 22.5, 22.5, 22.5, 22.5, 15)
		append_door(Vector3(-110, 113, 22.5), Vector3(-110, 114, 22.5), 375, rid)
		append_door(Vector3(-124, 113, 22.5), Vector3(-124, 114, 22.5), 414, rid)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'chas' then

	function NavigationManager:set_load_data(data)
		-- between 2 cars in front of SF souvenirs
		local rid = append_room(93, 98, 159, 160, 503.519, 503.519, 508, 503.519, 11)
		append_door(Vector3(93, 159, 503.519), Vector3(93, 160, 508), 125, rid)
		append_door(Vector3(98, 159, 503.519), Vector3(98, 160, 503.519), 161, rid)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'crojob2' then

	function NavigationManager:set_load_data(data)
		transfer_room(414, 28, 74)
		transfer_room(417, 28, 74)
		transfer_room(418, 28, 74)
		transfer_room(424, 28, 74)

		for _, door_id in ipairs(data.nav_segments[28].neighbours[52]) do
			table.insert(data.nav_segments[74].neighbours[52], door_id)
			table.insert(data.nav_segments[52].neighbours[74], door_id)
		end
		data.nav_segments[28].neighbours[52] = nil
		data.nav_segments[52].neighbours[28] = nil

		for _, door_id in ipairs({758, 764, 772, 773}) do
			table.insert(data.nav_segments[28].neighbours[74], door_id)
			table.insert(data.nav_segments[74].neighbours[28], door_id)
		end

		for _, door_id in ipairs({1776, 1777}) do
			table.delete(data.nav_segments[28].neighbours[74], door_id)
			table.delete(data.nav_segments[74].neighbours[28], door_id)
		end

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'dinner' then

	local itr_original_navigationmanager_addobstacle = NavigationManager.add_obstacle
	function NavigationManager:add_obstacle(obstacle_unit, ...)
		if obstacle_unit:unit_data().unit_id == 102343 then
			local pos = obstacle_unit:position()
			mvector3.set_z(pos, pos.z - 10)
			obstacle_unit:set_position(pos)
		end

		itr_original_navigationmanager_addobstacle(self, obstacle_unit, ...)
	end

elseif level_id == 'escape_park' then

	function NavigationManager:set_load_data(data)
		local pos_match = function(pos)
			x = mvec3_x(low_pos)
			y = mvec3_y(low_pos)
			if x >= -57 and x <= 84 and y >= -99 and y <= -21 then
				z = mvec3_z(low_pos)
				if z < -150 then
					return true
				end
			end
			return false
		end

		local delta_i = 1000000
		local delta = Vector3(delta_i, 0, 0)

		for did = #data.door_low_pos, 1, -1 do
			low_pos = data.door_low_pos[did]
			high_pos = data.door_high_pos[did]
			if pos_match(low_pos) and pos_match(high_pos) then
				mvec3_add(low_pos, delta)
				mvec3_add(high_pos, delta)
			end
		end

		for rid = #data.room_borders_x_pos, 1, -1 do
			if data.room_borders_x_neg[rid] >= -57 and data.room_borders_x_pos[rid] <= 84 then
				if data.room_borders_y_neg[rid] >= -99 and data.room_borders_y_pos[rid] <= -21 then
					if data.room_heights_xp_yp[rid] < -150
						and data.room_heights_xp_yn[rid] < -150
						and data.room_heights_xn_yp[rid] < -150
						and data.room_heights_xn_yn[rid] < -150
					then
						data.room_borders_x_pos[rid] = data.room_borders_x_pos[rid] + delta_i
						data.room_borders_x_neg[rid] = data.room_borders_x_neg[rid] + delta_i
					end
				end
			end
		end

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'escape_street' then

	function NavigationManager:set_load_data(data)
		append_vis_group(63, Vector3(1270, -1310, 400))
		add_segment(63, Vector3(1270, -1310, 400))

		data.nav_segments[63].neighbours[48] = {}
		data.nav_segments[48].neighbours[63] = {}

		local rid = append_room(69, 12, -42, -48, 422.5, 422.5, 422.5, 422.5, 63)
		append_room(69, 45, -48, -66, 422.5, 422.5, 422.5, 422.5, 63)
		append_room(30, 12, -48, -66, 422.5, 422.5, 422.5, 422.5, 63)
		append_room(45, 30, -56, -66, 422.5, 422.5, 422.5, 422.5, 63)

		append_door(Vector3(69, -48, 422.5), Vector3(45, -48, 422.5), rid, rid + 1)
		append_door(Vector3(30, -48, 422.5), Vector3(12, -48, 422.5), rid, rid + 2)
		append_door(Vector3(45, -56, 422.5), Vector3(45, -66, 422.5), rid + 1, rid + 3)
		append_door(Vector3(30, -56, 422.5), Vector3(30, -66, 422.5), rid + 2, rid + 3)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'firestarter_1' then

	function NavigationManager:set_load_data(data)
		-- access around a truck
		data.room_borders_x_pos[576] = -12
		data.room_borders_y_neg[576] = 159

		local did = append_door(Vector3(-13, 159, 21.98), Vector3(-12, 159, 21.98), 576, 1124)
		table.insert(data.nav_segments[29].neighbours[52], did)
		table.insert(data.nav_segments[52].neighbours[29], did)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'flat' then

	local downed_obstacle_units = {}
	local itr_original_navigationmanager_addobstacle = NavigationManager.add_obstacle
	function NavigationManager:add_obstacle(obstacle_unit, ...)
		if not downed_obstacle_units[obstacle_unit] and obstacle_unit:name():key() == 'bc8566d71eae8505' then
			local pos = obstacle_unit:position()
			local z = pos.z
			downed_obstacle_units[obstacle_unit] = true
			mvector3.set_z(pos, z - 5)
			obstacle_unit:set_position(pos)
		end

		itr_original_navigationmanager_addobstacle(self, obstacle_unit, ...)
	end

elseif Iter:should_skip_navigation_hooks() then

	function NavigationManager:set_load_data(data)
		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'jewelry_store' then

	function NavigationManager:set_load_data(data)
		local rid = append_room(-8, -12, 87, 86, 27.5, 27.5, 27.5, 27.5, 5)

		local did = append_door(Vector3(-12, 86, 27.5), Vector3(-11, 86, 27.5), 882, rid)
		table.insert(data.nav_segments[5].neighbours[96], did)
		table.insert(data.nav_segments[96].neighbours[5], did)

		append_door(Vector3(-8, 86, 27.5), Vector3(-8, 87, 27.5), 826, rid)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'jolly' then

	function NavigationManager:set_load_data(data)
		data.room_borders_x_pos[2420] = data.room_borders_x_pos[2420] + 2
		data.room_borders_y_neg[2420] = data.room_borders_y_neg[2420] - 1
		data.room_borders_y_pos[3445] = data.room_borders_y_pos[3445] + 1

		local pos = mvec3_cpy(data.door_high_pos[4547])
		mvec3_set_x(data.door_high_pos[4547], pos.x + 1)

		mvec3_set_x(pos, data.room_borders_x_neg[3445])
		mvec3_set_y(pos, data.room_borders_y_pos[3445])
		local pos1 = mvec3_cpy(pos)
		mvec3_set_y(pos1, pos1.y - 1)

		local did = append_door(pos, pos1, 2420, 3445)
		data.nav_segments[141].neighbours[87] = { did }
		data.nav_segments[87].neighbours = { [141] = { did } }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'kenaz' then

	function NavigationManager:set_load_data(data)
		local rid = append_room(27, 23, -83, -84, -877.5, -877.5, -877.5, -877.5, 189)

		local did = append_door(Vector3(23, -84, -877.5), Vector3(23, -83, -877.5), 1683, rid)
		data.nav_segments[57].neighbours[189] = { did }
		data.nav_segments[189].neighbours[57] = { did }

		append_door(Vector3(27, -84, -877.5), Vector3(27, -83, -877.5), 3468, rid)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'kosugi' then

	function NavigationManager:set_load_data(data)
		transfer_room(1744, 2, 3)
		transfer_room(1747, 2, 3)
		transfer_room(1751, 2, 3)
		transfer_room(1752, 2, 3)
		transfer_room(1753, 2, 3)
		transfer_room(1755, 2, 3)
		transfer_room(1756, 2, 3)
		transfer_room(1758, 2, 3)
		transfer_room(1759, 2, 3)
		transfer_room(1766, 2, 3)
		transfer_room(1767, 2, 3)
		transfer_room(1772, 2, 3)

		for _, door_id in ipairs(data.nav_segments[123].neighbours[2]) do
			table.insert(data.nav_segments[123].neighbours[3], door_id)
			table.insert(data.nav_segments[3].neighbours[123], door_id)
		end
		data.nav_segments[2].neighbours[123] = nil
		data.nav_segments[123].neighbours[2] = nil

		data.nav_segments[2].neighbours[3] = { 3028 }
		data.nav_segments[3].neighbours[2] = { 3028 }

		-- for dock access
		local navseg = 150
		append_vis_group(navseg, Vector3(4901.0, -2921.7, 975.9))
		add_segment(navseg, Vector3(4901.0, -2921.7, 975.9))

		local rid = append_room(204, 188, -77, -157, 982.69, 1000.94, 982.69, 1000.94, navseg)

		local did = append_door(Vector3(188, -77, 982.69), Vector3(204, -77, 982.69), 1651, rid)
		data.nav_segments[navseg].neighbours[65] = { did }
		data.nav_segments[65].neighbours[navseg] = { did }

		did = append_door(Vector3(188, -157, 1000.94), Vector3(199, -157, 1000.94), 31, rid)
		data.nav_segments[navseg].neighbours[69] = { did }
		data.nav_segments[69].neighbours[navseg] = { did }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'mex' then

	function NavigationManager:set_load_data(data)
		transfer_room(3908, 235, 192)
		transfer_room(3916, 235, 192)
		transfer_room(3907, 235, 192)
		transfer_room(3896, 235, 192)
		transfer_room(3906, 235, 192)
		transfer_room(3899, 235, 192)
		transfer_room(3889, 235, 192)
		transfer_room(3898, 235, 192)
		data.nav_segments[235].neighbours[192] = { 6866, 6867, 6868, 6833, 6834, 6835 }
		data.nav_segments[192].neighbours[235] = { 6866, 6867, 6868, 6833, 6834, 6835 }

		transfer_room(2627, 214, 192)
		data.nav_segments[214].neighbours[192] = { 4662, 4663, 4664 }
		data.nav_segments[192].neighbours[214] = { 4662, 4663, 4664 }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'mia_1' then

	function NavigationManager:set_load_data(data)
		-- room 101
		append_room(222, 221, -84, -85, 47.5, 47.5, 47.5, 47.5, 3)
		append_room(222, 221, -55, -56, 47.5, 47.5, 47.5, 47.5, 3)

		-- room 102
		append_room(222, 221, -138, -141, 47.5, 47.5, 47.5, 47.5, 20)
		append_room(222, 221, -111, -118, 47.5, 47.5, 47.5, 47.5, 20)

		-- room 103
		append_room(190, 189, -148, -153, 47.5, 47.5, 47.5, 47.5, 22)
		append_room(222, 221, -150, -154, 47.5, 47.5, 47.5, 47.5, 22)
		append_room(222, 220, -173, -181, 47.5, 47.5, 47.5, 47.5, 22)

		-- room 104
		append_room(142, 138, -175, -176, 47.5, 47.5, 47.5, 47.5, 9)
		append_room(168, 160, -174, -176, 47.5, 47.5, 47.5, 47.5, 9)

		-- room 105
		append_room(131, 130, -143, -176, 47.5, 47.5, 47.5, 47.5, 26)
		append_room(102, 98, -143, -147, 47.5, 47.5, 47.5, 47.5, 26)
		append_room(105, 98, -174, -176, 47.5, 47.5, 47.5, 47.5, 26)

		-- room 106
		append_room(44, 40, -175, -176, 47.5, 47.5, 47.5, 47.5, 12)
		append_room(70, 63, -174, -176, 47.5, 47.5, 47.5, 47.5, 12)

		-- room 107
		append_room(30, 26, -175, -176, 47.5, 47.5, 47.5, 47.5, 48)
		append_room(7, 0, -174, -176, 47.5, 47.5, 47.5, 47.5, 48)
		append_room(4, 0, -143, -147, 47.5, 47.5, 47.5, 47.5, 48)

		-- room 108
		append_room(-23, -24, -92, -96, 47.5, 47.5, 47.5, 47.5, 6)

		-- room 202
		append_room(204, 189, -111, -113, 447.5, 447.5, 447.5, 447.5, 5)
		append_room(195, 189, -142, -144, 447.5, 447.5, 447.5, 447.5, 5)

		-- room 203
		append_room(190, 189, -148, -154, 447.5, 447.5, 447.5, 447.5, 7)
		append_room(192, 189, -177, -181, 447.5, 447.5, 447.5, 447.5, 7)
		append_room(210, 204, -148, -149, 447.5, 447.5, 447.5, 447.5, 7)

		-- room 204
		append_room(136, 135, -143, -144, 447.5, 447.5, 447.5, 447.5, 8)
		append_room(152, 151, -143, -144, 447.5, 447.5, 447.5, 447.5, 8)
		append_room(168, 167, -143, -144, 447.5, 447.5, 447.5, 447.5, 8)
		append_room(168, 167, -175, -176, 447.5, 447.5, 447.5, 447.5, 8)

		-- room 205
		append_room(101, 98, -143, -144, 447.5, 447.5, 447.5, 447.5, 14)
		append_room(131, 123, -143, -144, 447.5, 447.5, 447.5, 447.5, 14)
		append_room(131, 130, -158, -164, 447.5, 447.5, 447.5, 447.5, 14)

		-- room 206
		append_room(39, 37, -143, -149, 447.5, 447.5, 447.5, 447.5, 13)
		append_room(58, 52, -143, -144, 447.5, 447.5, 447.5, 447.5, 13)
		append_room(70, 67, -143, -152, 447.5, 447.5, 447.5, 447.5, 13)

		-- room 207
		append_room(4, 0, -143, -146, 447.5, 447.5, 447.5, 447.5, 80)
		append_room(33, 27, -143, -144, 447.5, 447.5, 447.5, 447.5, 80)
		append_room(33, 32, -158, -164, 447.5, 447.5, 447.5, 447.5, 80)

		transfer_room(1901, 20, 113) -- room 102 / underground
		transfer_room(1902, 20, 113)
		transfer_room(1903, 20, 113)
		transfer_room(1904, 20, 113)
		transfer_room(1905, 20, 113)
		transfer_room(1906, 20, 113)
		transfer_room(1907, 20, 113)
		transfer_room(1910, 20, 113)
		data.nav_segments[20].neighbours[113] = {3207}
		data.nav_segments[113].neighbours[20] = {3207}

		transfer_room(1945, 119, 22) -- room 103 / underground
		transfer_room(1946, 119, 22)
		data.nav_segments[22].neighbours[119] = {3276,3277,3281}
		data.nav_segments[119].neighbours[22] = {3276,3277,3281}

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'moon' then

	function NavigationManager:set_load_data(data)
		data.room_borders_x_neg[2777] = data.room_borders_x_neg[2777] - 1
		data.room_borders_y_neg[2777] = data.room_borders_y_neg[2777] - 1

		local pos = mvec3_cpy(data.door_high_pos[4981])
		mvec3_set_x(pos, pos.x - 2)
		mvec3_set_y(pos, pos.y - 2)
		local pos1 = mvec3_cpy(pos)
		mvec3_set_x(pos1, pos1.x + 1)
		append_door(pos, pos1, 2777, 2758)

		data.nav_segments[22].neighbours[23] = { #data.door_low_pos }
		data.nav_segments[23].neighbours = { [22] = { #data.door_low_pos } }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'pbr' then

	function NavigationManager:set_load_data(data)
		data.room_borders_y_pos[1222] = -286

		local did = append_door(Vector3(38, -287, -58), Vector3(38, -286, -82), 1147, 1222)
		data.nav_segments[39].neighbours[40] = { did }
		data.nav_segments[40].neighbours[39] = { did }

		data.room_borders_x_pos[5714] = -30
		data.room_borders_y_pos[5714] = -96

		did = append_door(Vector3(-30, -97, -160.145), Vector3(-30, -96, -160.145), 990, 5714)
		data.nav_segments[30].neighbours[52] = { did }
		data.nav_segments[52].neighbours[30] = { did }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'peta' then

	function NavigationManager:set_load_data(data)
		transfer_room(121, 53, 47) -- Weathers hat shop
		data.nav_segments[53].neighbours[47] = {201}
		data.nav_segments[47].neighbours[53] = {201}

		local pos = mvec3_cpy(data.door_high_pos[11860])
		mvector3.set_y(pos, pos.y + 4)
		local pos1 = mvec3_cpy(pos)
		mvector3.set_y(pos1, pos1.y + 9)

		local did = append_door(pos, pos1, 97, 5959)
		data.nav_segments[47].neighbours[91] = { did }
		data.nav_segments[91].neighbours = { [47] = { did } }

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'roberts' then

	function NavigationManager:set_load_data(data)
		-- Jimbo's in
		append_room(-30, -34, 101, 84, -18.14, -18.14, -18.14, -18.14, 218)

		-- Jimbo's out
		append_room(7, -10, 103, 95, -68.21, -68.21, -68.21, -68.21, 3)

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'skm_mallcrasher' then

	function NavigationManager:set_load_data(data)
		-- prevent cops going through banditbarrier of vase store
		data.nav_segments[8].neighbours[11] = {}
		data.nav_segments[11].neighbours[8] = {}

		itr_original_navigationmanager_setloaddata(self, data)
	end

elseif level_id == 'watchdogs_1' then

	function NavigationManager:set_load_data(data)
		transfer_room(896, 134, 52)
		transfer_room(897, 134, 52)
		transfer_room(898, 134, 52)
		transfer_room(899, 134, 52)

		local d134t52 = data.nav_segments[134].neighbours[52]
		local d52t134 = data.nav_segments[52].neighbours[134]

		local old_doors = {
			1852,
			1855,
			1943,
			1944,
			1949,
			1953,
			1959,
			1960,
		}
		for _, door_id in ipairs(old_doors) do
			table.delete(d134t52, door_id)
			table.delete(d52t134, door_id)
		end

		local new_doors = {
			1564,
			1565,
			1566,
			1573,
		}
		for _, door_id in ipairs(new_doors) do
			table.insert(d134t52, door_id)
			table.insert(d52t134, door_id)
		end

		itr_original_navigationmanager_setloaddata(self, data)
	end

end

if NavigationManager.set_load_data == itr_original_navigationmanager_setloaddata then
	return
end

-- https://web.mit.edu/freebsd/head/sys/libkern/crc32.c

local crc32_tab = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
	0xe963a535, 0x9e6495a3,	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
	0xf3b97148, 0x84be41de,	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
	0xfa0f3d63, 0x8d080df5,	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
	0xdbbbc9d6, 0xacbcf940,	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
	0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
	0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
	0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
	0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
	0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
	0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
	0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
	0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
	0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
	0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
	0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
	0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
	0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
	0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
	0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
	0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
	0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
}
local xor = bit.bxor
local rshift = bit.rshift
local band = bit.band
local function feed_byte(crc, b)
	return xor(crc32_tab[band(xor(crc, b), 0xFF) + 1], rshift(crc, 8))
end
local function feed_int(crc, i)
	for _ = 1, 4 do
		local b = band(i, 0xFF)
		i = rshift(i, 8)
		crc = feed_byte(crc, b)
	end
	return crc
end

local nav_data_sigs = {
	alex_2 = 1319370361,
	arm_fac = -1355303262,
	arm_for = -1033523562,
	big = 1250090475,
	born = -752015988,
	branchbank = -115776117,
	chas = 1118766387,
	crojob2 = 1676845123,
	escape_park = 466880952,
	escape_street = 1470878858,
	firestarter_1 = 952805177,
	gallery = 1380658305,
	jewelry_store = 1306078024,
	jolly = 617794335,
	kenaz = 1079949878,
	kosugi = 373270794,
	mex = -415457450,
	mia_1 = 710528854,
	moon = -814267024,
	pbr = 1972593354,
	peta = -1335047208,
	roberts = 1306211660,
	watchdogs_1 = -136945692,
	skm_mallcrasher = 598935744,
}
nav_data_sigs.framing_frame_1 = nav_data_sigs.gallery

local function _is_expected_data(data, a, b)
	local tbls = {
		'door_high_rooms',
		'door_low_rooms',
		'room_borders_x_neg',
		'room_borders_x_pos',
		'room_borders_x_pos',
		'room_borders_y_neg',
		'room_borders_y_pos',
		'room_heights_xn_yn',
		'room_heights_xn_yp',
		'room_heights_xp_yn',
		'room_heights_xp_yp',
		'room_vis_groups',
	}
	local sig = 0
	for _, tblname in ipairs(tbls) do
		for _, n in ipairs(data[tblname]) do
			sig = feed_int(sig, n)
		end
	end

	local is_ok = sig == nav_data_sigs[level_id]
	if not is_ok then
		log()
		log(('[Iter] outdated navigation patch! (%i)'):format(sig))
		log()
	end

	return is_ok
end

local second_itr_original_navigationmanager_setloaddata = NavigationManager.set_load_data
function NavigationManager:set_load_data(data)
	if _is_expected_data(data) then
		_make_seg2vg(data)

		transfer_room = function(id, from, to)
			data.vis_groups[seg2vg[from]].rooms[id] = nil
			data.vis_groups[seg2vg[to]].rooms[id] = true
			data.room_vis_groups[id] = seg2vg[to]
		end

		local rid = #data.room_borders_x_neg
		append_room = function(borders_x_pos, borders_x_neg, borders_y_pos, borders_y_neg, heights_xp_yp, heights_xp_yn, heights_xn_yp, heights_xn_yn, segment_id)
			rid = rid + 1
			borders_x_neg, borders_x_pos = math.min_max(borders_x_pos, borders_x_neg)
			borders_y_neg, borders_y_pos = math.min_max(borders_y_pos, borders_y_neg)
			data.room_borders_x_pos[rid] = borders_x_pos
			data.room_borders_x_neg[rid] = borders_x_neg
			data.room_borders_y_pos[rid] = borders_y_pos
			data.room_borders_y_neg[rid] = borders_y_neg
			data.room_heights_xp_yp[rid] = heights_xp_yp
			data.room_heights_xp_yn[rid] = heights_xp_yn
			data.room_heights_xn_yp[rid] = heights_xn_yp
			data.room_heights_xn_yn[rid] = heights_xn_yn
			data.room_vis_groups[rid] = seg2vg[segment_id]
			data.vis_groups[seg2vg[segment_id]].rooms[rid] = true
			return rid
		end

		local did = #data.door_high_pos
		append_door = function(low_pos, high_pos, low_room_id, high_room_id)
			did = did + 1
			data.door_low_pos[did] = low_pos
			data.door_high_pos[did] = high_pos
			data.door_low_rooms[did] = low_room_id
			data.door_high_rooms[did] = high_room_id
			return did
		end

		append_vis_group = function(navseg_id, pos)
			local vg = {
				rooms = {},
				pos = pos,
				seg = navseg_id,
				vis_groups = {}
			}
			for k, v in pairs(data.vis_groups) do
				v.vis_groups[navseg_id] = true
				vg.vis_groups[k] = true
			end
			table.insert(data.vis_groups, vg)

			_make_seg2vg(data)

			return vg
		end

		add_segment = function(navseg_id, pos)
			data.nav_segments[navseg_id] = {
				location_id = 'location_unknown',
				pos = pos,
				vis_groups = { seg2vg[navseg_id] },
				neighbours = {},
			}
		end

		second_itr_original_navigationmanager_setloaddata(self, data)
	else
		itr_original_navigationmanager_setloaddata(self, data)
	end
end
