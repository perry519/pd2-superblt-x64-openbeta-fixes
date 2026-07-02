---@class BLTModItem
---@field new fun(self, panel, index, mod, show_icon):BLTModItem
BLTModItem = BLTModItem or blt_class()

local padding = 10

local medium_font = tweak_data.menu.pd2_medium_font
local small_font = tweak_data.menu.pd2_small_font

local medium_font_size = tweak_data.menu.pd2_medium_font_size
local small_font_size = tweak_data.menu.pd2_small_font_size

BLTModItem.layout = {
	x = 4,
	y = 2
}
BLTModItem.image_size = 108

function BLTModItem:init(panel, index, mod, show_icon)
	local w = (panel:w() - (self.layout.x + 1) * padding) / self.layout.x
	local h = ((panel:h() - (self.layout.y + 1) * padding) / self.layout.y) * (show_icon and 1 or 0.5) - (show_icon and 0 or padding * 0.5)
	local column, row = self:_get_col_row(index)
	local icon_size = 32

	self._mod = mod

	local bg_color = mod:GetColor()
	local text_color = Color.white
	if mod:LastError() then
		bg_color = tweak_data.screen_colors.important_1
		text_color = tweak_data.screen_colors.important_1
	elseif not mod:IsUndisablable() and mod:IsEnabled() and not mod:WasEnabledAtStart() then
		bg_color = Color.yellow
		text_color = Color.yellow
	elseif not mod:IsEnabled() then
		bg_color = Color(0.15, 0.15, 0.15)
		text_color = Color(0.25, 0.25, 0.25)
	end

	-- Main panel
	self._panel = panel:panel({
		x = (w + padding) * (column - 1),
		y = (h + padding) * (row - 1),
		w = w,
		h = h,
		layer = 10
	})

	-- Background
	self._background = self._panel:rect({
		color = bg_color,
		alpha = 0.2,
		blend_mode = "add",
		layer = -1
	})
	BoxGuiObject:new(self._panel, {sides = {1, 1, 1, 1}})

	self._panel:bitmap({
		texture = "guis/textures/test_blur_df",
		w = self._panel:w(),
		h = self._panel:h(),
		render_template = "VertexColorTexturedBlur3D",
		layer = -1,
		halign = "scale",
		valign = "scale"
	})

	-- Mod name
	local mod_name = self._panel:text({
		name = "mod_name",
		font_size = medium_font_size,
		font = medium_font,
		layer = 10,
		blend_mode = "add",
		color = text_color,
		text = mod:GetName(),
		align = "center",
		vertical = "top",
		wrap = true,
		word_wrap = true
	})
	local name_padding = show_icon and padding or (icon_size + 4 + padding)
	mod_name:set_x(name_padding)
	mod_name:set_width(self._panel:w() - mod_name:x() - name_padding)
	mod_name:set_top(math.round(self._panel:h() * (show_icon and 0.5 or 0.1)))
	local _, _, _, th = mod_name:text_rect()
	mod_name:set_h(th)

	-- Mod description
	local mod_desc = self._panel:text({
		name = "mod_desc",
		font_size = small_font_size,
		font = small_font,
		layer = 10,
		blend_mode = "add",
		color = text_color,
		text = string.sub(mod:GetDescription(), 1, 120),
		align = "left",
		vertical = "top",
		wrap = true,
		word_wrap = true,
		w = self._panel:w() - padding * 2
	})
	mod_desc:set_top(math.round(mod_name:bottom()) + 5)
	local _, _, tw, th = mod_desc:text_rect()
	mod_desc:set_size(tw, math.min(th, self._panel:h() - mod_desc:y() - padding))
	mod_desc:set_center_x(math.round(self._panel:w() * 0.5))

	-- Mod image
	local image_path
	if show_icon and mod:HasModImage() then
		image_path = mod:GetModImage()
	end

	if image_path then
		local image = self._panel:bitmap({
			name = "image",
			texture = image_path,
			color = Color.white,
			alpha = mod:IsEnabled() and 1 or 0.25,
			layer = 10,
			w = BLTModItem.image_size,
			h = BLTModItem.image_size
		})
		image:set_center_x(self._panel:w() * 0.5)
		image:set_top(padding)
	elseif show_icon then
		local no_image_panel = self._panel:panel({
			name = "no_image_panel",
			w = BLTModItem.image_size,
			h = BLTModItem.image_size,
			alpha = mod:IsEnabled() and 1 or 0.5,
			layer = 10
		})
		no_image_panel:set_center_x(self._panel:w() * 0.5)
		no_image_panel:set_top(padding)

		BoxGuiObject:new(no_image_panel, {sides = {1, 1, 1, 1}})

		no_image_panel:text({
			name = "no_image_text",
			font_size = small_font_size,
			font = small_font,
			layer = 10,
			blend_mode = "add",
			text = managers.localization:to_upper_text("blt_no_image"),
			align = "center",
			vertical = "center",
			w = no_image_panel:w(),
			h = no_image_panel:h()
		})
	end

	-- Mod settings
	local icon_y = padding

	if mod:HasUpdates() then
		local icon, rect = tweak_data.hud_icons:get_icon_data("csb_pagers")
		local icon_updates = self._panel:bitmap({
			texture = icon,
			texture_rect = rect,
			alpha = mod:AreUpdatesEnabled() and 1 or 0.2,
			layer = 10,
			w = icon_size,
			h = icon_size
		})
		icon_updates:set_left(padding)
		icon_updates:set_top(icon_y)

		-- Animate the icon. When the update is done, the animation ends and
		-- sets the icon to the appropriate colour
		icon_updates:animate(callback(self, self, "_clbk_animate_update_icon"))
	end
end

function BLTModItem:_clbk_animate_update_icon(icon)
	-- While the update is still in progress, fade the icon
	local time = 0
	while self._mod:IsCheckingForUpdates() do
		local dt = coroutine.yield()
		time = time + dt

		-- Fade colour from 0 to 1 to 0 over the course of two seconds
		local colour = time % 2 -- From 0-2

		if colour > 1 then
			-- If the colour has gone past half way, subtract it from two. This
			-- causes it to decrease starting from 1 (as 2-1=1) to 0 (as 2-2=0).
			colour = 2 - colour
		end

		-- Lerb between white and blue to make it fade in and out
		icon:set_color(math.lerp(Color.white, Color.blue, colour))
	end

	-- Check for corrupted downloads, and set the colour accordingly
	if self._mod:GetUpdateError() then
		icon:set_color(Color.red)
		return
	end

	-- Check if the update is resolved
	if BLT.Downloads:get_pending_downloads_for(self._mod) then
		icon:set_color(Color.yellow)
		return
	end

	-- Update check finished and no updates are due, colour it white
	icon:set_color(Color.white)
end

function BLTModItem:_get_col_row(index)
	local column = 1
	local row = 1
	for i = 1, index - 1 do
		column = column + 1
		if column > self.layout.x then
			row = row + 1
			column = 1
		end
	end
	return column, row
end

function BLTModItem:inside(x, y)
	return self._panel:inside(x, y)
end

function BLTModItem:mod()
	return self._mod
end

function BLTModItem:set_highlight(enabled, no_sound)
	if self._enabled ~= enabled then
		self._enabled = enabled
		self._background:set_alpha(enabled and 0.4 or 0.2)
		if enabled and not no_sound then
			managers.menu_component:post_event("highlight")
		end
	end
end
