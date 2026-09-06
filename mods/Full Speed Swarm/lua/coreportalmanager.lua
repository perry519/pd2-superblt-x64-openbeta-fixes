local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if not Global.load_level then
	return
end

core:module('CorePortalManager')

local table_remove = table.remove
local set_visible = Unit.set_visible

for _, fname in ipairs({'init', 'clear', 'clear_unit_groups'}) do
	local f = PortalManager[fname]
	PortalManager[fname] = function(self, ...)
		self.fs_unit_groups = {}
		self.fs_timer = TimerManager:wall()
		return f(self, ...)
	end
end

local fs_original_portalmanager_addunitgroup = PortalManager.add_unit_group
function PortalManager:add_unit_group(...)
	local group = fs_original_portalmanager_addunitgroup(self, ...)
	table.insert(self.fs_unit_groups, group)
	group.fs_portalmanager = self
	return group
end

local fs_original_portalmanager_removeunitgroup = PortalManager.remove_unit_group
function PortalManager:remove_unit_group(name)
	fs_original_portalmanager_removeunitgroup(self, name)

	local unit_groups = self.fs_unit_groups
	for i = #unit_groups, 1, -1 do
		if unit_groups[i]._name == name then
			table_remove(unit_groups, i)
			break
		end
	end
end

function PortalManager:render()
	local tw = self.fs_timer
	local t = tw:time()
	local dt =  tw:delta_time()

	local portal_shapes = self._portal_shapes
	for i = #portal_shapes, 1, -1 do
		portal_shapes[i]:update(t, dt)
	end

	local unit_groups = self.fs_unit_groups
	for i = #unit_groups, 1, -1 do
		unit_groups[i]:update(t, dt)
	end

	local amount = math.ceil(dt * 500)
	for _ = 1, amount do
		local unit_id, unit = next(self._hide_list)
		if unit and unit:alive() then
			set_visible(unit, false)
			self._hide_list[unit_id] = nil
		else
			break
		end
	end

	local check_positions = self._check_positions
	for i = #check_positions, 1, -1 do
		check_positions[i] = nil
	end
end

local fs_original_portalunitgroup_init = PortalUnitGroup.init
function PortalUnitGroup:init(...)
	self.fs_unit_datas = {}
	fs_original_portalunitgroup_init(self, ...)
end

function PortalUnitGroup:inside(pos)
	local shapes = self._shapes
	for i = #shapes, 1, -1 do
		if shapes[i]:is_inside(pos) then
			return true
		end
	end
	return false
end

function PortalUnitGroup:update(t, dt)
	local is_inside = false

	local positions = self.fs_portalmanager:check_positions()
	for i = #positions, 1, -1 do
		is_inside = self:inside(positions[i])
		if is_inside then
			break
		end
	end

	if self._is_inside ~= is_inside then
		self._is_inside = is_inside
		local diff = self._is_inside and 1 or -1
		self:_change_units_visibility(diff)
	end
end

local fs_original_portalunitgroup_addunit = PortalUnitGroup.add_unit
function PortalUnitGroup:add_unit(unit)
	local result = fs_original_portalunitgroup_addunit(self, unit)
	if result then
		table.insert(self.fs_unit_datas, unit:unit_data())
	end
	return result
end

function PortalUnitGroup:remove_unit_id(unit)
	local unit_id = unit:unit_data().unit_id
	self._ids[unit_id] = nil
	for i, unit_data in ipairs(self.fs_unit_datas) do
		if unit_data.unit_id == unit_id then
			table.remove(self._units, i)
			table.remove(self.fs_unit_datas, i)
			break
		end
	end
end

function PortalUnitGroup:_change_units_visibility(diff)
	local unit_datas = self.fs_unit_datas
	for i, unit in ipairs(self._units) do
		self:fs_change_visibility(unit, unit_datas[i], diff)
	end
end

function PortalUnitGroup:fs_change_visibility(unit, unit_data, diff)
	if alive(unit) then
		local vc = unit_data._visibility_counter
		if vc then
			vc = vc + diff
		else
			vc = diff > 0 and 1 or 0
		end
		unit_data._visibility_counter = vc

		if vc > 0 then
			set_visible(unit, true)
			self.fs_portalmanager._hide_list[unit_data.unit_id] = nil
		else
			self.fs_portalmanager._hide_list[unit_data.unit_id] = unit
		end
	end
end
