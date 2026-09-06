local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings

local fs_original_carrydata_init = CarryData.init
function CarryData:init(unit)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_carrydata_init(self, unit)
	end

	fs_original_carrydata_init(self, unit)
	if Network:is_client() or self._carry_id and not self:can_explode() and not self._expire_t then
		unit:set_extension_update_enabled(Idstring('carry_data'), false)
	end
end

local fs_original_carrydata_setpositionandthrow = CarryData.set_position_and_throw
function CarryData:set_position_and_throw(...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_carrydata_setpositionandthrow(self, ...)
	end

	self._unit:set_extension_update_enabled(Idstring('carry_data'), true)
	self._unit:interaction():register_collision_callbacks()
	fs_original_carrydata_setpositionandthrow(self, ...)
end

local fs_original_carrydata_linkto = CarryData.link_to
function CarryData:link_to(parent_unit, ...)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_carrydata_linkto(self, parent_unit, ...)
	end

	if fs_settings.cops_disable_bag_contour then
		local ids_contour_opacity = Idstring('contour_opacity')
		local team = alive(parent_unit) and parent_unit:movement():team()
		local is_cop = team and team.id == 'law1'
		for _, material in ipairs(self._unit:interaction()._materials) do
			material:set_variable(ids_contour_opacity, is_cop and 0 or 1)
		end

		if is_cop then
			self._unit:interaction().fs_was_decontoured = true
		end
	end

	fs_original_carrydata_linkto(self, parent_unit, ...)
end

local fs_original_carrydata_chkregisterstealso = CarryData._chk_register_steal_SO
function CarryData:_chk_register_steal_SO()
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_carrydata_chkregisterstealso(self)
	end

	fs_original_carrydata_chkregisterstealso(self)

	local objective = self._steal_SO_data and self._steal_SO_data.pickup_objective
	if objective and objective.action then
		objective.action.blocks = {
			act = -1,
			action = -1,
			aim = -1,
			heavy_hurt = -1,
			hurt = -1,
			light_hurt = -1,
			shoot = -1,
			turn = -1,
			walk = -1
		}
	end
end
