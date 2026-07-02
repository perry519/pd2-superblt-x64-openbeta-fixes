---Checks if a file can be opened to read from
---@param fname string @The path (relative to payday2_win32_release.exe) and file name to check
---@return boolean @`true` if the file can be opened for reading, `false` otherwise
function io.file_is_readable(fname)
	local file = io.open(fname, "r")
	if file ~= nil then
		io.close(file)
		return true
	end

	return false
end

---Recursively deletes all files and folders from the directory specified
---@param path string @The path (relative to payday2_win32_release.exe) of the directory to delete
---@param verbose boolean? @Wether to print verbose output to the log
---@return boolean @`true` if the operation was successful, `false` otherwise
function io.remove_directory_and_files(path, verbose)
	local vlog = function(str)
		if verbose then
			BLT:Log(LogLevel.INFO, str)
		end
	end

	if not path then
		BLT:Log(LogLevel.ERROR, "Paramater #1 to io.remove_directory_and_files, string expected, recieved " .. tostring(path))
		return false
	end

	if path == "" then
		BLT:Log(LogLevel.ERROR, "Cannot delete the root directory!")
		return false
	end

	if not file.DirectoryExists(path) then
		BLT:Log(LogLevel.ERROR, string.format("Directory '%s' does not exist", path))
		return false
	end

	-- Ensure final path separator
	local path_end = path:sub(-1)
	if path_end ~= "/" and path_end ~= "\\" then
		path = path .. "/"
	end

	local files = file.GetFiles(path)
	if files then
		for _, v in pairs(files) do
			local file_path = path .. v
			vlog(string.format("Removing file '%s'", file_path))
			local r, error_str = os.remove(file_path)
			if not r then
				BLT:Log(LogLevel.ERROR, string.format("Could not remove '%s': %s", file_path, error_str))
				return false
			end
		end
	end

	local dirs = file.GetDirectories(path)
	if dirs then
		for _, v in pairs(dirs) do
			local child_path = path .. v .. "/"
			vlog(string.format("Removing directory '%s'", child_path))
			local r = io.remove_directory_and_files(child_path, verbose)
			if not r then
				BLT:Log(LogLevel.ERROR, string.format("Could not remove directory '%s'", child_path))
				return false
			end
		end
	end

	vlog(string.format("Removing directory '%s'", path))
	local r = file.RemoveDirectory(path)
	if not r then
		BLT:Log(LogLevel.ERROR, string.format("Could not remove directory '%s'", path))
		return false
	end

	return true
end

---Converts a Lua table to a JSON string and saves it to a file
---@param data table @The data to save as JSON file
---@param path string @The path (relative to payday2_win32_release.exe) and file name to save the data to
---@return boolean @`true` if the operation was successful, `false` otherwise
function io.save_as_json(data, path)
	local count = 0
	for k, v in pairs(data) do
		count = count + 1
	end

	if data and count > 0 then
		local file = io.open(path, "w+")
		if file then
			file:write(json.encode(data))
			file:close()
			return true
		else
			BLT:Log(LogLevel.ERROR, string.format("Could not save to file '%s', data may be lost", path))
			return false
		end
	else
		BLT:Log(LogLevel.WARN, string.format("Skipped saving empty data table to '%s'", path))
		return true
	end
end

---Loads a file containing JSON data and converts it into a Lua table
---@param path string @The path (relative to payday2_win32_release.exe) and file name to load the data from
---@return table? @The table containing the data, or `nil` if loading wasn't successful
function io.load_as_json(path)
	local file = io.open(path, "r")
	if file then
		local file_contents = file:read("*all")
		file:close()
		return json.decode(file_contents)
	else
		BLT:Log(LogLevel.ERROR, string.format("Could not load file '%s', no data loaded", path))
	end
end
