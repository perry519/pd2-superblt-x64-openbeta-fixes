local _is_server_ok = NetworkMatchMakingEPIC.is_server_ok
function NetworkMatchMakingEPIC:is_server_ok(friends_only, room, attributes_list, is_invite)
	if type(room) ~= "table" then 
		return false 
	end

	if type(attributes_list) ~= "table" then
		return false
	end

	if type(friends_only) ~= "boolean" then
		friends_only = false
	end
	
	for z, v in pairs(attributes_list.numbers) do
		if type(v) ~= "number" then
			attributes_list.numbers[z] = 0
		end
	end

	if attributes_list.numbers[2] == 0 then
		attributes_list.numbers[2] = 2
	end

	if attributes_list.numbers[5] == 0 or attributes_list.numbers[5] == 4 then
		return false
	end

	if type(attributes_list.mods) ~= "string" or attributes_list.mods == "empty" then
		attributes_list.mods = "7d66a433be3a1fe2"
	end
	
	return _is_server_ok(self, friends_only, room, attributes_list, is_invite)
end
