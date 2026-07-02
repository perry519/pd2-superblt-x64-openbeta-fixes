_G.json = {}

---Converts a JSON string to a Lua table
---@param data string @String to decode
---@return table @Decoded data
function json.decode(data)
	-- Attempt to use 1.0 json module first
	local passed, value = pcall(json10.decode, data)

	if not passed then
		-- If it fails, then try using the old json module to load malformatted json files
		BLT:Log(LogLevel.WARN, string.format("Found a json error, attempting to use old json loader!"))
		passed, value = pcall(json09.decode, data)
	end

	return passed and value
end

---Converts a Lua table to a JSON string
---@param data table @Data to encode
---@return string @Encoded data
function json.encode(data)
	return json10.encode(data)
end
