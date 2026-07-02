---@class BLTLogs : BLTModule
---@field new fun(self):BLTLogs
BLTLogs = blt_class(BLTModule)
BLTLogs.__type = "BLTLogs"
BLTLogs.lifetime = 1
BLTLogs.log_level = _G.LogLevel.ALL
BLTLogs.logs_location = "mods/logs/"
BLTLogs.lifetime_options = {
	[1] = {1, "blt_logs_one_day"},
	[2] = {3, "blt_logs_three_days"},
	[3] = {7, "blt_logs_one_week"},
	[4] = {14, "blt_logs_two_weeks"},
	[5] = {30, "blt_logs_thirty_days"}
}
BLTLogs.day_length = 86400

function BLTLogs:init()
	local logs = BLT.save_data.logs
	if logs then
		BLTLogs.lifetime = logs.lifetime or BLTLogs.lifetime
		BLTLogs.log_level = logs.log_level or BLTLogs.log_level
	end

	BLTLogs.super.init(self)
end

function BLTLogs:LogNameToNumber(name)
	local year, month, day = name:match("^([0-9]+)_([0-9]+)_([0-9]+)_log.txt$")
	if not year or not month or not day then
		return -1
	end
	return Utils:TimestampToEpoch(year, month, day)
end

function BLTLogs:CleanLogs()
	BLT:Log(LogLevel.INFO, string.format("[BLT] Cleaning logs folder, lifetime %i day(s)", BLTLogs.lifetime))

	local current_time = os.time()
	local files = file.GetFiles(BLTLogs.logs_location)
	if files then
		for i, file_name in pairs(files) do
			local file_date = self:LogNameToNumber(file_name)
			if file_date > 0 and file_date < current_time - (BLTLogs.lifetime * BLTLogs.day_length) then
				BLT:Log(LogLevel.INFO, string.format("[BLT] Removing log: %s", file_name))
				os.remove(string.format("%s%s", BLTLogs.logs_location, file_name))
			end
		end
	end
end

Hooks:Add("BLTOnSaveData", "BLTOnSaveData.BLTLogs", function(save_data)
	save_data.logs = {
		lifetime = BLTLogs.lifetime,
		log_level = BLTLogs.log_level
	}
end)
