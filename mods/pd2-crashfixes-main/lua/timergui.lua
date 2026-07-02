-- [string "lib/units/props/timergui.lua"]:655: bad argument #1 to 'floor' (number expected, got nil)
-- [string "lib/units/props/timergui.lua"]:534: attempt to perform arithmetic on field '_current_timer' (a nil value)
function TimerGui:_set_jammed(jammed)
    self._time_left = self._time_left or 5
    self._current_timer = self._current_timer or 5

    self._jammed = jammed

    if self._jammed then
        if self._unit:damage() then
            if self._unit:damage():has_sequence("set_is_jammed") then
                self._unit:damage():run_sequence_simple("set_is_jammed")
            end

            if self._unit:damage():has_sequence("jammed_trigger") then
                self._unit:damage():run_sequence_simple("jammed_trigger")
            end
        end

        for _, child in ipairs(self._gui_script.panel:children()) do
            local theme = TimerGui.themes[self.THEME]

            if child.children then
                for _, grandchild in ipairs(child:children()) do
                    local color = self._original_colors[grandchild:key()]
                    local c = Color(color.a, 1, 0, 0)

                    grandchild:set_color(c)
                end
            else
                local color = self._original_colors[child:key()]
                local jammed_color = theme and theme.jammed and theme.jammed[child:name()] or Color.red
                local c = jammed_color:with_alpha(color.a)

                child:set_color(c)

                local blend_mode = theme and theme.jammed and theme.jammed[child:name() .. "_blend_mode"]

                if blend_mode then
                    child:set_blend_mode(blend_mode)
                end
            end
        end

        self._gui_script.working_text:set_text(managers.localization:text(self._gui_malfunction))
        self._gui_script.time_text:set_text(managers.localization:text("prop_timer_gui_error"))

        if self._unit:interaction() then
            if self._jammed_tweak_data then
                self._unit:interaction():set_tweak_data(self._jammed_tweak_data)
            end

            self._unit:interaction():set_active(true)
        end

        self:post_event(self._jam_event)
    else
        if self._unit:damage() and self._unit:damage():has_sequence("resumed_trigger") then
            self._unit:damage():run_sequence_simple("resumed_trigger")
        end

        for _, child in ipairs(self._gui_script.panel:children()) do
            if child.children then
                for _, grandchild in ipairs(child:children()) do
                    grandchild:set_color(self._original_colors[grandchild:key()])
                end
            else
                child:set_color(self._original_colors[child:key()])
            end
        end

        self._gui_script.working_text:set_text(managers.localization:text(self._gui_working))
        local time = self._time_left or self._current_timer
        if time then
            self._gui_script.time_text:set_text(math.floor(time) .. " " .. managers.localization:text("prop_timer_gui_seconds"))
        else
            self._gui_script.time_text:set_text(managers.localization:text("prop_timer_gui_error"))
        end
        self._gui_script.drill_screen_background:set_color(self._gui_script.drill_screen_background:color():with_alpha(1))
        self:post_event(self._resume_event)

        local theme = TimerGui.themes[self.THEME]

        if theme and theme.bg_rect_blend_mode then
            self._gui_script.bg_rect:set_blend_mode(theme.bg_rect_blend_mode)
        end

        if self._unit:interaction() then
            self._unit:interaction():set_active(false)
        end
    end

    self._unit:base():set_jammed(jammed)

    if self._unit:mission_door_device() then
        self._unit:mission_door_device():report_jammed_state(jammed)
    end

    if managers.gameinfo then -- fix for vanillahud+ timers 1
        managers.gameinfo:event("timer", "set_jammed", self._info_key, jammed and true or false)
    end
end

function TimerGui:update(unit, t, dt)
	local gui_script = self._gui_script
	if self._jammed then
		local alpha = 0.5 + (math.sin(t * 750) + 1) / 4
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

	self._current_timer = (self._current_timer or 5) - dt / dt_mod
	self._time_left = (self._current_timer or 5) * dt_mod
	self._timer = self._timer or 5

    if self._show_seconds then
        self._gui_script.time_text:set_text(math.floor(self._time_left or self._current_timer) .. " " .. managers.localization:text("prop_timer_gui_seconds"))
    else
        self._gui_script.time_text:set_text(math.floor(self._time_left or self._current_timer))
    end

	gui_script.timer:set_w(self._timer_lenght * (1 - self._current_timer / self._timer))

	if self._current_timer <= 0 then
		self._unit:set_extension_update_enabled(Idstring('timer_gui'), false)
		self._update_enabled = false
		self:done()
	else
		local working_text = gui_script.working_text
		working_text:set_alpha(0.5 + (math.sin(t * 750) + 1) / 4)
	end

    if managers.gameinfo then -- fix for vanillahud+ timers 1
        managers.gameinfo:event("timer", "update", self._info_key, t, self._time_left, self._current_timer / self._timer)
    end
end

