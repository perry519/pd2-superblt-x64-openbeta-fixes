core:module("CoreCode")
core:import("CoreTable")
core:import("CoreDebug")
core:import("CoreClass")
core:import("CoreApp")

local function open_lua_source_file_safe(source)
	if DB:is_bundled() then
		return nil
	end

	local entry_type = Idstring("lua_source")
	local source_name = tostring(source)
	local entry_name = string.lower(string.match(source_name, "([^.]*)") or source_name)

	return DB:has(entry_type, Idstring(entry_name)) and DB:open(entry_type, Idstring(entry_name)) or nil
end

function get_prototype(info)
	if info.source == "=[C]" then
		return "(C++ method)"
	end

	local prototype = info.source
	local source_file = open_lua_source_file_safe(info.source)

	if source_file then
		for _ = 1, info.linedefined do
			prototype = source_file:gets()
		end

		source_file:close()
	end

	return prototype
end

function alive(obj)
	if (type(obj) == "userdata" or type(obj) == "table") and type(obj.alive) == "function" then
		return obj:alive()
	end
	return false
end

local function string_left(value, width)
	value = tostring(value)

	if string.len(value) >= width then
		return string.sub(value, 1, width)
	end

	return value .. string.rep(" ", width - string.len(value))
end

function line_representation(x, seen, raw)
	if DB:is_bundled() then
		return "[N/A in bundle]"
	end

	local w = 60

	if type(x) == "userdata" then
		return tostring(x)
	elseif type(x) == "table" then
		seen = seen or {}

		if seen[x] then
			return "..."
		end

		seen[x] = true
		local r = "{"

		for k, v in sort_iterator(x, raw) do
			r = r .. line_representation(k, seen, raw) .. "=" .. line_representation(v, seen, raw) .. ", "

			if w < string.len(r) then
				r = string.sub(r, 1, w) .. "..."

				break
			end
		end

		return r .. "}"
	elseif type(x) == "string" then
		x = string.gsub(x, "\n", "\\n")
		x = string.gsub(x, "\r", "\\r")
		x = string.gsub(x, "\t", "\\t")

		if w < string.len(x) then
			x = string.sub(x, 1, w) .. "..."
		end

		return x
	elseif type(x) == "function" then
		local info = debug.getinfo(x)

		if not info then
			return tostring(x)
		elseif info.source == "=[C]" then
			return "(C++ method)"
		else
			return line_representation(get_prototype(info), nil, raw)
		end
	else
		return tostring(x)
	end
end

function ascii_table(t, raw)
	local out = ""
	local klen = 20
	local vlen = 20

	for k, v in pairs(t) do
		klen = math.max(klen, string.len(line_representation(k, nil, raw)) + 2)
		vlen = math.max(vlen, string.len(line_representation(v, nil, raw)) + 2)
	end

	out = out .. string.rep("-", klen + vlen + 5) .. "\n"

	for k, v in sort_iterator(t, raw) do
		out = out
			.. "| "
			.. string_left(line_representation(k, nil, raw), klen)
			.. "| "
			.. string_left(line_representation(v, nil, raw), vlen)
			.. "|\n"
	end

	out = out .. string.rep("-", klen + vlen + 5) .. "\n"

	return out
end
