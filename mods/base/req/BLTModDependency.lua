---@class BLTModDependency
---@field new fun(self, parent_mod: BLTMod, id: string, download_data: table):BLTModDependency, boolean
BLTModDependency = BLTModDependency or blt_class()

function BLTModDependency:init(parent_mod, id, download_data)
	if not parent_mod or not id or not download_data or not download_data.meta and not download_data.download_url then
		return false
	end

	self._id = id
	self._parent_mod = parent_mod
	self._download_data = download_data

	return true
end

function BLTModDependency:GetId()
	return self._id
end

function BLTModDependency:GetParentMod()
	return self._parent_mod
end

function BLTModDependency:GetServerData()
	return self._server_data
end

function BLTModDependency:GetServerName()
	return self._server_data and self._server_data.name or self._download_data.name or self._id
end

function BLTModDependency:GetName()
	local macros = {
		dependency = self:GetServerName(),
		mod = self:GetParentMod():GetName()
	}
	return managers.localization:text("blt_download_dependency", macros)
end

function BLTModDependency:DisallowsUpdate()
	return false
end

function BLTModDependency:GetInstallDirectory()
	return self._server_data and self._server_data.install_dir or self._download_data.install_dir or BLTModManager.Constants.mods_directory
end

function BLTModDependency:Retrieve(clbk)
	if self._retrieving then
		return
	end

	-- If a download url is provided use it, otherwise get the url from a meta file
	if self._download_data.download_url then
		-- Need to wrap this in a coroutine to prevent crashing when called from main thread
		local co = coroutine.create(function()
			clbk(self, true)
		end)
		coroutine.resume(co)
	else
		self._retrieving = true
		BLT:HttpGet(self._download_data.meta, function(json_data, http_id, request_info)
			self:clbk_got_data(clbk, json_data, http_id, request_info)
		end)
	end
end

function BLTModDependency:GetDownloadURL()
	return self._server_data and self._server_data.download_url or self._download_data.download_url
end

function BLTModDependency:clbk_got_data(clbk, json_data, http_id, request_info)
	self._retrieving = false

	if not request_info.querySucceeded or string.is_nil_or_empty(json_data) then
		BLT:Log(LogLevel.ERROR, string.format("[Dependencies] Could not retrieve update data for '%s'", self:GetId()))
		return self:_run_update_callback(clbk, false, "Could not retrieve update data.")
	end

	local server_data = json.decode(json_data)
	if server_data then
		for _, data in pairs(server_data) do
			if data.ident == self:GetId() then
				BLT:Log(LogLevel.INFO, string.format("[Dependencies] Received update data for '%s'", self:GetId()))
				self._server_data = data
				break
			end
		end
	end

	if not self._server_data then
		BLT:Log(LogLevel.ERROR, string.format("[Dependencies] No matching update data found for '%s'", self:GetId()))
		return self:_run_update_callback(clbk, false, "Could not find dependency data.")
	end

	clbk(self, self._server_data and self._server_data.download_url)
end

function BLTModDependency:GetPatchNotes()
	return self._server_data and self._server_data.patchnotes
end

function BLTModDependency:ViewPatchNotes()
	BLTUpdate.ViewPatchNotes(self)
end

function BLTModDependency:IsCritical()
	return true
end

function BLTModDependency:GetInstallFolder()
	return self:GetServerName()
end

function BLTModDependency:GetServerHash()
	return self._server_data and self._server_data.hash
end

function BLTModDependency:GetServerVersion()
	return self._server_data and self._server_data.version
end

function BLTModDependency:IsInstall()
	return true
end

function BLTModDependency:UsesHash()
	return self._server_data and self._server_data.hash and true
end
