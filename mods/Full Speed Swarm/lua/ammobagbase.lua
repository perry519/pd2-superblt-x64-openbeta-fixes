local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not Network:is_server() then
	return
end

DelayedCalls:Add('DelayedFSS_equipments', 0, function()

for _, classe in ipairs({
	AmmoBagBase,
	BodyBagsBagBase,
	DoctorBagBase,
	FirstAidKitBase,
	GrenadeCrateBase,
}) do
	local fs_original_someequipment_setup = classe.setup
	function classe:setup(...)
		fs_original_someequipment_setup(self, ...)

		if self._attached_data and alive(self._attached_data.body) then
			self._unit:set_extension_update_enabled(Idstring('base'), false)
			local function clbk()
				if alive(self._unit) then
					self:_check_body()
				end
			end
			self._attached_data.body:unit():add_body_enabled_callback(clbk)
			self._attached_data.fs_clbk = clbk
		end
	end
end

end)
