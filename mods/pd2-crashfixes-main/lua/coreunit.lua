core:module("CoreUnit")
core:import("CoreEngineAccess")
core:import("CoreCode")

--[string "core/lib/utils/coreunit.lua"]:111: attempt to index local 'ext' (a number value)
function detach_unit_from_network(unit)
	if type(unit) ~= "userdata" then return end

	local ext = nil
	local extensions = nil
	
	if unit.extensions then
		extensions = unit:extensions()
	end
	
	if type(extensions) ~= "table" then return end

	for idx, ext_name in ipairs(extensions) do
		ext = unit[ext_name](unit)
		if type(ext) == "table" and ext.on_pre_detached_from_network then
			ext:on_pre_detached_from_network()
		end
	end

	Network:detach_unit(unit)

	for idx, ext_name in ipairs(extensions) do
		ext = unit[ext_name](unit)
		if type(ext) == "table" and ext.on_post_detached_from_network then
			ext:on_post_detached_from_network()
		end
	end
end
