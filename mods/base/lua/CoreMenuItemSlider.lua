local Hooks = Hooks
local tweak_data = tweak_data

core:module("CoreMenuItemSlider")

Hooks:PostHook(ItemSlider, "setup_gui", "BLT.ItemSlider.setup_gui", function (self, node, row_item)
	row_item.gui_slider_text:set_font_size(tweak_data.menu.stats_font_size)
end)

Hooks:PreHook(ItemSlider, "reload", "BLT.ItemSlider.reload", function (self, row_item)
	if not row_item then
		return
	end

	local disabled = not self:enabled()

	row_item.gui_text:set_color(disabled and row_item.disabled_color or row_item.color)
	row_item.gui_slider_text:set_color(disabled and row_item.disabled_color or row_item.color)

	self:set_slider_color(disabled and row_item.disabled_color or tweak_data.screen_colors.button_stage_3)
	self:set_slider_highlighted_color(disabled and row_item.disabled_color or tweak_data.screen_colors.button_stage_2)
end)
