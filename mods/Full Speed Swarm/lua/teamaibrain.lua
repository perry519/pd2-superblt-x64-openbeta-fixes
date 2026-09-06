local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_settings = FullSpeedSwarm.final_settings
if fs_settings.eyes_wide_open then
	-- qued
elseif fs_settings.task_throughput < 200 then
	return
end

local CopLogicBase = CopLogicBase
function TeamAIBrain:set_update_enabled_state(state)
	if not FullSpeedSwarm:allow_stealth_changes() then
		self._unit:set_extension_update_enabled(Idstring('brain'), state)
		return
	end

	self._unit:set_extension_update_enabled(Idstring('brain'), false)

	local data = self.fs_brain_data
	if not data then
		data = { internal_data = { queued_tasks = {} } }
		local qt = data.internal_data.queued_tasks
		data.fs_on_queued_task = function(id)
			qt[id] = nil
		end
		self.fs_brain_data = data
	end

	local task_key = 'TeamAIBrain.update' .. tostring(self._unit:key())
	local my_data = data.internal_data

	if state then
		local unit = self._unit
		local timer = TimerManager:game()
		local clbk
		clbk = function()
			local t = timer:time()
			data.t = t
			self:update(unit, t, timer:delta_time())
			CopLogicBase.queue_task(my_data, task_key, clbk, data, t + 0.1)
		end
		data.t = timer:time()
		CopLogicBase.queue_task(my_data, task_key, clbk, data, data.t + math.random() / 10)
	else
		CopLogicBase.unqueue_task(my_data, task_key)
	end
end
