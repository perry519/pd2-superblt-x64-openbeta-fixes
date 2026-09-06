local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_playerdamage_init = PlayerDamage.init
function PlayerDamage:init(...)
	self._current_max_health = self:fs_max_health()
	fs_original_playerdamage_init(self, ...)
end

local fs_original_playerdamage_sethealth = PlayerDamage.set_health
function PlayerDamage:set_health(health)
	local result = fs_original_playerdamage_sethealth(self, health)
	self._not_full_life = self:get_real_health() < self:_max_health()
	return result
end

function PlayerDamage:fs_raw_max_health()
	local managers_player = managers.player
	local max_health_no_cs = (self._HEALTH_INIT + managers_player:health_skill_addend()) * managers_player:health_skill_multiplier()
	local max_health = max_health_no_cs * managers.modifiers:modify_value('PlayerDamage:GetMaxHealth', 1)
	return max_health, max_health_no_cs
end

function PlayerDamage:fs_max_health()
	local max_health, max_health_no_cs = self:fs_raw_max_health()

	local managers_player = managers.player
	if managers_player:has_category_upgrade('player', 'armor_to_health_conversion') then
		local max_armor = self:_raw_max_armor()
		local conversion_factor = managers_player:upgrade_value('player', 'armor_to_health_conversion') * 0.01
		max_health = max_health + max_armor * conversion_factor
	else
		self.fs_max_health = self.fs_raw_max_health
	end

	return max_health, max_health_no_cs
end

function PlayerDamage:_max_health()
	return self._current_max_health
end

function PlayerDamage:_check_update_max_health()
	local max_health, max_health_no_cs = self:fs_max_health()

	if self._current_max_health ~= max_health then
		local ratio = max_health / self._current_max_health
		local health = math.clamp(self:get_real_health() * ratio, 0, max_health)
		self._health = Application:digest_value(health, true)
		self._current_max_health = max_health
		managers.player.fs_current_max_health = max_health_no_cs -- PlayerManager:body_armor_skill_addend() ignores CS

		self:update_armor_stored_health()
	end
end

function PlayerDamage:_upd_health_regen(t, dt)
	local health_regen_update_timer = self._health_regen_update_timer
	if health_regen_update_timer then
		health_regen_update_timer = health_regen_update_timer - dt
		if health_regen_update_timer <= 0 then
			health_regen_update_timer = nil
		end
		self._health_regen_update_timer = health_regen_update_timer
	end

	if not health_regen_update_timer then
		if self._not_full_life then
			local managers_player = managers.player
			local regen_rate = managers_player:health_regen()
			if regen_rate > 0 then
				self:restore_health(regen_rate, false)
			end
			self:restore_health(managers_player:fixed_health_regen(self:health_ratio()), true)
			self._health_regen_update_timer = 5
		end
	end

	local damage_to_hot_stack = self._damage_to_hot_stack
	if damage_to_hot_stack[1] then
		local n = #damage_to_hot_stack
		for i = n, 1, -1 do
			local doh = damage_to_hot_stack[i]
			if doh.next_tick < t then
				local regen_rate = managers.player:upgrade_value('player', 'damage_to_hot', 0)
				self:restore_health(regen_rate, true)

				local ticks_left = doh.ticks_left - 1
				if ticks_left == 0 then
					if i < n then
						damage_to_hot_stack[i] = damage_to_hot_stack[n]
					end
					damage_to_hot_stack[n] = nil
					n = n - 1
				else
					doh.ticks_left = ticks_left
					doh.next_tick = doh.next_tick + (self._doh_data.tick_time or 1)
				end
			end
		end
	end
end

local math_abs = math.abs
local math_lerp = math.lerp
local math_min = math.min
function PlayerDamage:_update_armor_hud(t, dt)
	local real_armor = self:get_real_armor()
	self._current_armor_fill = math_lerp(self._current_armor_fill, real_armor, 10 * dt)
	if math_abs(self._current_armor_fill - real_armor) > 0.01 then
		local total_armor = self:_max_armor()
		managers.hud:set_player_armor({
			current = self._current_armor_fill,
			total = total_armor,
			max = total_armor
		})
	end
	if self._hurt_value then
		self._hurt_value = math_min(1, self._hurt_value + dt)
	end
end

function PlayerDamage:_raw_max_armor()
	local managers_player = managers.player
	local base_max_armor = self._ARMOR_INIT + managers_player:body_armor_value('armor') + managers_player:body_armor_skill_addend()
	local mul = managers_player:body_armor_skill_multiplier()
	mul = managers.modifiers:modify_value('PlayerDamage:GetMaxArmor', mul)
	return base_max_armor * mul
end

local fs_original_playerdamage_ondowned = PlayerDamage.on_downed
function PlayerDamage:on_downed()
	fs_original_playerdamage_ondowned(self)

	local u_mov = self._unit:movement()
	if u_mov then
		u_mov.fs_stamina_tick = 0
		u_mov:_change_stamina(0)
	end
end

-- https://steamcommunity.com/app/218620/discussions/14/2579854400739478371/
function PlayerDamage:_update_armor_grinding(t, dt)
	self._armor_grinding.elapsed = self._armor_grinding.elapsed + dt

	if self._armor_grinding.target_tick <= self._armor_grinding.elapsed then
		self._armor_grinding.elapsed = 0
		self:change_armor(self._armor_grinding.armor_value)
		self:_send_set_armor()
	end
end
