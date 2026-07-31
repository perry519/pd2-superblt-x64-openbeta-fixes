_G.DifficultyPicker = _G.DifficultyPicker or class()

DifficultyPicker.risks = {
	'risk_pd',
	'risk_swat',
	'risk_fbi',
	'risk_death_squad',
	'risk_easy_wish',
	'risk_murder_squad',
	'risk_sm_wish'
}

function DifficultyPicker:init(parent_panel)
	self.can_set_difficulty = not managers.network:session()

	self.panel = parent_panel:panel({
		y = parent_panel:h() - 30,
		x = 0,
		layer = 1,
		w = 200,
		h = 30,
		visible = not managers.crime_spree:is_active()
	})

	local risk_text = self.panel:text({
		name = 'mws_bp_risk',
		align = 'center',
		vertical = 'center',
		text = utf8.to_upper(managers.localization:text('menu_risk')),
		font_size = tweak_data.menu.pd2_small_font_size,
		font = tweak_data.menu.pd2_small_font,
		color = tweak_data.screen_colors.risk:with_alpha(self.can_set_difficulty and 1 or 0.5),
		x = 0,
		y = 0,
		w = 100,
		h = 30
	})
	local _, _, w, _ = risk_text:text_rect()
	risk_text:set_w(w)

	self.difficulty_bitmaps = {}
	for i = 2, 7 do
		local name = self.risks[i]
		local texture, rect = tweak_data.hud_icons:get_icon_data(name)
		self.difficulty_bitmaps[i] = self.panel:bitmap({
			blend_mode = 'add',
			y = 0,
			x = risk_text:right() + (i - 2) * 35,
			name = name,
			texture = texture,
			texture_rect = rect,
			alpha = 0.25,
			color = Color.white
		})
	end

	self.panel:set_w(self.difficulty_bitmaps[7]:right())
	self.panel:set_center_x(parent_panel:w() / 2)
end

function DifficultyPicker:update_difficulty(difficulty, can_switch)
	local difficulty_rank
	if not self.can_set_difficulty then
		difficulty = Global.game_settings.difficulty
		difficulty_rank = tweak_data:difficulty_to_index(difficulty)

	else
		difficulty = difficulty or MoreWeaponStats.settings.last_used_difficulty
		difficulty_rank = tweak_data:difficulty_to_index(difficulty)
		if can_switch then
			local current_id = tweak_data:difficulty_to_index(Global.game_settings.difficulty)
			if difficulty_rank == current_id then
				difficulty_rank = difficulty_rank - 1
				difficulty = tweak_data:index_to_difficulty(difficulty_rank)
			end
		end

		MoreWeaponStats.settings.last_used_difficulty = difficulty
		Global.game_settings.difficulty = difficulty
		tweak_data.character:init(tweak_data)
		tweak_data.player:init(tweak_data)
		tweak_data.player['_set_' .. difficulty](tweak_data.player)
		tweak_data.character['_set_' .. difficulty](tweak_data.character)
	end

	for i, bmp in pairs(self.difficulty_bitmaps) do
		local active = i < difficulty_rank
		bmp:set_alpha(active and (self.can_set_difficulty and 1 or 0.5) or 0.25)
		bmp:set_color(active and tweak_data.screen_colors.risk or Color.white)
	end

	return difficulty_rank
end

function DifficultyPicker:get_over_icon_index(x, y)
	if self.can_set_difficulty and self.panel:inside(x, y) then
		for i, bmp in pairs(self.difficulty_bitmaps) do
			if bmp:inside(x, y) then
				return i
			end
		end
	end
end

function DifficultyPicker:get_over_icon_difficulty_rank(x, y)
	local icon_index = self:get_over_icon_index(x, y)
	return icon_index and icon_index + 1
end
