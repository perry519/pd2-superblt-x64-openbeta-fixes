_G.SimpleChart = _G.SimpleChart or class()

function SimpleChart:init(parent_panel, x, y, w, h, bar_start_y)
	self.texts = {}

	self.panel = parent_panel:panel({
		layer = 1,
		x = x,
		y = y,
		w = w,
		h = h,
	})

	self.bars = {}
	for xb = 0, w - 1 do
		table.insert(self.bars, self.panel:rect({
			x = xb,
			y = bar_start_y or 0,
			w = 1,
			h = 1,
		}))
	end
end

function SimpleChart:visible()
	return self.panel:visible()
end

function SimpleChart:inside(x, y)
	return self.panel:inside(x, y)
end

function SimpleChart:get_text_at(world_x, world_y)
	return self.panel:inside(world_x, world_y) and self.texts[world_x - self.panel:world_x()]
end

function SimpleChart:show()
	self.panel:show()
end

function SimpleChart:hide()
	self.panel:hide()
end

function SimpleChart:update(get_text_height_colour)
	if type(get_text_height_colour) ~= 'function' then
		return
	end

	for i, bar in ipairs(self.bars) do
		local text, h, colour = get_text_height_colour(i)
		self.texts[i] = text
		if h then
			bar:set_h(h)
		end
		if colour then
			bar:set_color(colour)
		end
	end
end
