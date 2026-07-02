-- [string "core/lib/utils/dev/editor/coreworlddefinition..."]:910: attempt to index a number value
if WorldDefinition then
    function WorldDefinition:_create_portal(data, offset)
        if not data or type(data) ~= "table" then
            return
        end

        if not Application:editor() and type(data.portals) == "table" then
            for _, portal in ipairs(data.portals) do
                local t = {}
                for _, point in ipairs(portal.points or {}) do
                    table.insert(t, (point.position or Vector3()) + (offset or Vector3()))
                end
                local top = portal.top
                local bottom = portal.bottom
                if top == 0 and bottom == 0 then
                    top, bottom = nil
                end
                managers.portal:add_portal(t, bottom, top)
            end
        end

        local unit_groups = data.unit_groups
        if type(unit_groups) ~= "table" then
            return
        end

        unit_groups._meta = nil

        for name, group_data in pairs(unit_groups) do
            if type(group_data) == "table" then
                local group = managers.portal:add_unit_group(name)
                local shapes = group_data.shapes or group_data
                if type(shapes) == "table" then
                    for _, shape in ipairs(shapes) do
                        group:add_shape(shape)
                    end
                end
                if group_data.ids then
                    group:set_ids(group_data.ids)
                end
            end
        end
    end

    -- [string "core/lib/utils/dev/editor/coreworlddefinition..."]:1301: attempt to index a number value
    local __setup_projection_light = WorldDefinition._setup_projection_light
   	function WorldDefinition:_setup_projection_light(unit, data)
		if type(data) ~= "table" then return end
    	if type(data.projection_textures) ~= "table" then
    		data.projection_textures = nil
    	end
    	__setup_projection_light(self, unit, data)
    end

end

