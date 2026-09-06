local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local math_floor = math.floor
local math_sin = math.sin

local fs_original_timergui_init = TimerGui.init
function TimerGui:init(...)
	fs_original_timergui_init(self, ...)
	self.fs_localized_prop_timer_gui_seconds = ' ' .. managers.localization:text('prop_timer_gui_seconds')
end

function TimerGui:update(unit, t, dt)
	local gui_script = self._gui_script
	if self._jammed then
		local alpha = 0.5 + (math_sin(t * 750) + 1) / 4
		gui_script.drill_screen_background:set_alpha(alpha)
		gui_script.bg_rect:set_alpha(alpha)
		return
	end

	if not self._powered then
		return
	end

	local dt_mod = self:get_timer_multiplier()

	if self._current_jam_timer then
		self._current_jam_timer = self._current_jam_timer - dt / dt_mod
		if self._current_jam_timer <= 0 then
			self:set_jammed(true)
			self._current_jam_timer = table.remove(self._jamming_intervals, 1)
			return
		end
	end

	self._current_timer = self._current_timer - dt / dt_mod
	self._time_left = self._current_timer * dt_mod

	local value = math_floor(self._time_left)
	if value ~= self.fs_current_time then
		self.fs_current_time = value
		if self._show_seconds then
			gui_script.time_text:set_text(value .. self.fs_localized_prop_timer_gui_seconds)
		else
			gui_script.time_text:set_text(math_floor(self._time_left))
		end
	end
	gui_script.timer:set_w(self._timer_lenght * (1 - self._current_timer / self._timer))

	if self._current_timer <= 0 then
		self._unit:set_extension_update_enabled(Idstring('timer_gui'), false)
		self._update_enabled = false
		self:done()
	else
		local working_text = gui_script.working_text
		working_text:set_alpha(0.5 + (math_sin(t * 750) + 1) / 4)
	end
end
