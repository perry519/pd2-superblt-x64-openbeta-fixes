function server_verify(data)
	if type(data) ~= "table" then return nil end
	if not data.id then return nil end
	if not data.room_id then return nil end

	if type(data.num_plrs) ~= "number" then 
		return nil
	end

	if data.num_plrs >= 4 or data.num_plrs < 1 then
		return nil
	end

  	if type(data.host_name) ~= "string" or string.is_nil_or_empty(data.host_name) then 
  		data.host_name = "Error: bad lobby name" 
  	end

  	if data.mutators and type(data.mutators) == "table" and table.empty(data.mutators) then
		data.mutators = false
	end
	
	if not SystemInfo:matchmaking() == Idstring("MM_STEAM") then
	
		local lobby = EpicMM:lobby(data.room_id)
		if type(lobby) ~= "userdata" then return nil end
		if type(lobby.key_value) ~= "function" then return nil end

		if (lobby:key_value("owner_account_type") == "STEAM" or lobby:key_value("owner_account_type") == "EPIC") then else return nil end

	end
	
	return data
end

local _add_server_job = CrimeNetGui.add_server_job
function CrimeNetGui:add_server_job(data)
	local data_checked = server_verify(data)
	if not data_checked then return end
	_add_server_job(self, data_checked)
end

local _update_server_job = CrimeNetGui.update_server_job
function CrimeNetGui:update_server_job(data, i)
	local data_checked = server_verify(data)
	if not data_checked then return end
	_update_server_job(self, data_checked, i)
end
