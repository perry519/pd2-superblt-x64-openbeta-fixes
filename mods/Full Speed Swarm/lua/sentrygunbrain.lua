local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local math_abs = math.abs
local math_clamp = math.clamp
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local math_random = math.random
local math_sqrt = math.sqrt
local math_UP = math.UP

local mvec3_add = mvector3.add
local mvec3_cpy = mvector3.copy
local mvec3_crs = mvector3.cross
local mvec3_dir = mvector3.direction
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_dot = mvector3.dot
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set
local mvec3_set_len = mvector3.set_length
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_z = mvector3.z

local fs_settings = FullSpeedSwarm.final_settings
local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
local REACT_MIN = AIAttentionObject.REACT_MIN
local REACT_MAX = AIAttentionObject.REACT_MAX
local World = World
local fs_original_sentrygunbrain_upddetection = SentryGunBrain._upd_detection
local fs_original_sentrygunbrain_selectfocusattention = SentryGunBrain._select_focus_attention
local fs_original_sentrygunbrain_update = SentryGunBrain.update

local function _distance_chk(max_detection_range, settings, attention_pos, my_pos)
	local max_dis = math_min(max_detection_range, settings.max_range or max_detection_range)
	if settings.detection and settings.detection.range_mul then
		max_dis = max_dis * settings.detection.range_mul
	end
	local dis_sq = mvec3_dis_sq(my_pos, attention_pos)
	if dis_sq < max_dis * max_dis then
		return math_sqrt(dis_sq)
	end
end

function SentryGunBrain:_upd_detection(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_sentrygunbrain_upddetection(self, t)
	end

	if self._next_detection_upd_t > t then
		return
	end

	if self._ext_movement:is_activating() or self._ext_movement:is_inactivating() then
		return
	end

	local delay = 1
	local my_SO_access_str = self._SO_access_str
	local my_SO_access = self._SO_access
	local detected_objects = self._detected_attention_objects
	local my_key = self._unit:key()
	local my_team = self._ext_movement:team()
	local my_pos = self._ext_movement:m_head_pos()
	local max_detection_range = self._tweak_data.DETECTION_RANGE
	local all_attention_objects = managers.groupai:state():get_AI_attention_objects_by_filter_i(my_SO_access_str, my_team)
	local wraycast = World.raycast

	local ignore_units = {self._unit}

	local attention_cache_key = REACT_MIN .. my_SO_access .. REACT_MAX .. (my_team and my_team.id or '')

	for i = #all_attention_objects, 1, -1 do
		local attention_info1 = all_attention_objects[i]
		local u_key = attention_info1.unit_key
		if u_key ~= my_key and not detected_objects[u_key] then
			local att_handler = attention_info1.handler
			local settings = att_handler.rel_cache[attention_cache_key]
			if settings == nil then
				settings = att_handler:get_attention_no_cache_query(attention_cache_key, my_SO_access, REACT_MIN, REACT_MAX, my_team)
			end
			if settings then
				local attention_pos = att_handler:get_detection_m_pos()
				if _distance_chk(max_detection_range, settings, attention_pos, my_pos) then
					ignore_units[2] = attention_info1.unit or nil
					local vis_ray = wraycast(World, 'ray', my_pos, attention_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision')
					if not vis_ray or vis_ray.unit:key() == u_key then
						detected_objects[u_key] = CopLogicBase._create_detected_attention_object_data(t, self._unit, u_key, attention_info1, settings)
					end
				end
			end
		end
	end

	local t2 = t + 0.1
	local update_delay = 2
		local detected_obj_i = self._detected_attention_objects_i
		for i = detected_obj_i[0], 1, -1 do
			local attention_info2 = detected_obj_i[i]
			FullSpeedSwarm:ensure_attention_extensions(attention_info2)
			if t2 < attention_info2.next_verify_t then
				update_delay = math_min(attention_info2.next_verify_t - t, update_delay)
		else
			local u_key = attention_info2.u_key
			local settings = attention_info2.settings
			ignore_units[2] = attention_info2.unit or nil
			attention_info2.next_verify_t = t + (attention_info2.identified and attention_info2.verified and settings.verification_interval or settings.notice_interval or settings.verification_interval)
			update_delay = math_min(update_delay, settings.verification_interval)

			if not attention_info2.identified then
				local health_ratio = self:_attention_health_ratio(attention_info2)
				local objective = self:_attention_objective(attention_info2)
				local noticable = nil
				local attention_pos = attention_info2.handler:get_detection_m_pos()
				local distance = _distance_chk(max_detection_range, settings, attention_pos, my_pos)
				local skip = objective == 'surrender' or health_ratio <= 0

				if distance then
					local vis_ray = wraycast(World, 'ray', my_pos, attention_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision', 'report')
					if not vis_ray then
						noticable = true
					end
				end

				local delta_prog = nil
				local dt = t - attention_info2.prev_notice_chk_t

				if noticable and not skip then
					local detect_delay = self._tweak_data.DETECTION_DELAY
					local min_delay = detect_delay[1][2]
					local max_delay = detect_delay[2][2]
					local dis_ratio = (distance - detect_delay[1][1]) / (detect_delay[2][1] - detect_delay[1][1])
					local dis_mul_mod = math_lerp(min_delay, max_delay, dis_ratio)
					local notice_delay_mul = settings.notice_delay_mul or 1

					if settings.detection and settings.detection.delay_mul then
						notice_delay_mul = notice_delay_mul * settings.detection.delay_mul
					end

					local notice_delay_modified = math_lerp(min_delay * notice_delay_mul, max_delay, dis_mul_mod)
					delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
				else
					delta_prog = dt * -0.125
				end

				attention_info2.notice_progress = attention_info2.notice_progress + delta_prog
				if attention_info2.notice_progress > 1 and not skip then
					attention_info2.notice_progress = nil
					attention_info2.prev_notice_chk_t = nil
					attention_info2.identified = true
					attention_info2.release_t = t + settings.release_delay
					attention_info2.identified_t = t
					noticable = true
				elseif attention_info2.notice_progress < 0 or skip then
					self:_destroy_detected_attention_object_data(attention_info2)
					noticable = false
				else
					noticable = attention_info2.notice_progress
					attention_info2.prev_notice_chk_t = t
				end

				if noticable ~= false and settings.notice_clbk then
					settings.notice_clbk(self._unit, noticable)
				end
			end

			if attention_info2.identified then
				update_delay = math_min(update_delay, settings.verification_interval)
				attention_info2.nearly_visible = nil
				local verified, vis_ray
				local attention_pos = attention_info2.handler:get_detection_m_pos()
				local dis = mvec3_dis(my_pos, attention_info2.m_head_pos)

				if dis < max_detection_range * 1.2 and (not settings.max_range or dis < settings.max_range * (settings.detection and settings.detection.range_mul or 1) * 1.2) then
					local detect_pos
					if attention_info2.is_husk_player and attention_info2.fs_ext_animdata and attention_info2.fs_ext_animdata.crouch then
						detect_pos = tmp_vec1
						mvec3_set(detect_pos, attention_info2.m_pos)
						mvec3_add(detect_pos, tweak_data.player.stances.default.crouched.head.translation)
					else
						detect_pos = attention_pos
					end

					vis_ray = wraycast(World, 'ray', my_pos, detect_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision')
					if not vis_ray then
						verified = true
					end

					attention_info2.verified = verified
				end

				attention_info2.dis = dis
				attention_info2.vis_ray = vis_ray and vis_ray.dis or nil

				local is_downed = false
				local u_mov = attention_info2.fs_ext_movement
				if u_mov and u_mov.downed then
					is_downed = u_mov:downed()
				end
				local u_team = u_mov and u_mov:team()

				local is_ignored_target = self:_attention_health_ratio(attention_info2) <= 0 or self:_attention_objective(attention_info2) == 'surrender' or is_downed
				if is_ignored_target then
					self:_destroy_detected_attention_object_data(attention_info2)
				elseif verified and dis < self._tweak_data.FIRE_RANGE then
					attention_info2.release_t = nil
					attention_info2.verified_t = t

					mvec3_set(attention_info2.verified_pos, attention_pos)

					attention_info2.last_verified_pos = mvec3_cpy(attention_pos)
					attention_info2.verified_dis = dis
				elseif attention_info2.has_team and my_team and my_team.foes and u_team and my_team.foes[u_team.id] then
					if attention_info2.criminal_record and settings.reaction >= AIAttentionObject.REACT_COMBAT then
						if dis > 1000 and mvec3_dis(attention_pos, attention_info2.last_verified_pos or attention_info2.criminal_record.pos) > 700 or max_detection_range < dis then
							self:_destroy_detected_attention_object_data(attention_info2)
						else
							update_delay = math_min(0.2, update_delay)
							attention_info2.verified_pos = mvec3_cpy(attention_info2.criminal_record.pos)
							attention_info2.verified_dis = dis

							if vis_ray then
								-- _nearly_visible_chk(attention_info2, attention_pos)
								local near_pos = tmp_vec1

								if attention_info2.verified_dis < 2000 and math_abs(mvec3_z(attention_pos) - mvec3_z(my_pos)) < 300 then
									mvec3_set(near_pos, attention_pos)
									mvec3_set_z(near_pos, near_pos.z + 100)

									local near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision', 'report')
									if near_vis_ray then
										local side_vec = tmp_vec1
										mvec3_set(side_vec, attention_pos)
										mvec3_sub(side_vec, my_pos)
										mvec3_crs(side_vec, side_vec, math_UP)
										mvec3_set_len(side_vec, 150)
										mvec3_set(near_pos, attention_pos)
										mvec3_add(near_pos, side_vec)

										near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision', 'report')
										if near_vis_ray then
											mvec3_mul(side_vec, -2)
											mvec3_add(near_pos, side_vec)
											near_vis_ray = wraycast(World, 'ray', my_pos, near_pos, 'ignore_unit', ignore_units, 'slot_mask', self._visibility_slotmask, 'ray_type', 'ai_vision', 'report')
										end
									end

									if not near_vis_ray then
										attention_info2.nearly_visible = true
										attention_info2.last_verified_pos = mvec3_cpy(near_pos)
									end
								end
							end
						end
					elseif attention_info2.release_t and attention_info2.release_t < t then
						self:_destroy_detected_attention_object_data(attention_info2)
					else
						attention_info2.release_t = attention_info2.release_t or t + settings.release_delay
					end
				elseif attention_info2.release_t and attention_info2.release_t < t then
					self:_destroy_detected_attention_object_data(attention_info2)
				else
					attention_info2.release_t = attention_info2.release_t or t + settings.release_delay
				end
			end
		end
	end

	self._next_detection_upd_t = t + update_delay
end

function SentryGunBrain:_select_focus_attention(t)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_sentrygunbrain_selectfocusattention(self, t)
	end

	local current_focus = self._attention_obj
	local current_pos = self._ext_movement:m_head_pos()
	local current_fwd

	if current_focus then
		current_fwd = tmp_vec2
		mvec3_dir(current_fwd, self._ext_movement:m_head_pos(), current_focus.m_head_pos)
	else
		current_fwd = self._ext_movement:m_head_fwd()
	end

	local max_dis = self._tweak_data.DETECTION_RANGE
	local best_focus_attention
	local best_focus_weight = -1
	local best_focus_reaction = 0

		local detected_obj_i = self._detected_attention_objects_i
		for i = detected_obj_i[0], 1, -1 do
			local attention_info = detected_obj_i[i]
			FullSpeedSwarm:ensure_attention_extensions(attention_info)
			if attention_info.identified then
				local weight

				if attention_info.health_ratio and attention_info.fs_ext_cdmg and attention_info.fs_ext_cdmg:health_ratio() <= 0 then
					weight = 0
			elseif attention_info.verified_t and t - attention_info.verified_t < 3 then
				local max_duration = 3
				local elapsed_t = t - attention_info.verified_t
				weight = math_lerp(1, 0.6, elapsed_t / max_duration)

				if attention_info.settings.weight_mul then
					weight = weight * attention_info.settings.weight_mul
				end

				local dis = mvec3_dir(tmp_vec1, current_pos, attention_info.m_head_pos)
				local dis_weight = math_max(0, (max_dis - dis) / max_dis)
				weight = weight * dis_weight
				local dot_weight = 1 + mvec3_dot(tmp_vec1, current_fwd)
				dot_weight = dot_weight * dot_weight * dot_weight
				weight = weight * dot_weight

				if self:_ignore_shield({self._unit}, current_pos, attention_info) then
					weight = weight * 0.01
				end
			else
				weight = 0
			end

			local hostage_weight = weight == 0 and 0 or self:fs_hostage_weight_around_target(attention_info)
			if hostage_weight > 0 then
				weight = hostage_weight >= 3 and 0 or weight * (1 - hostage_weight/10)
			end

			if attention_info.reaction > best_focus_reaction or attention_info.reaction == best_focus_reaction and weight > best_focus_weight then
				best_focus_weight = weight
				best_focus_attention = attention_info
				best_focus_reaction = attention_info.reaction
			end
		end
	end

	if current_focus ~= best_focus_attention then
		if best_focus_attention then
			local attention_data = {
				unit = best_focus_attention.unit,
				u_key = best_focus_attention.u_key,
				handler = best_focus_attention.handler,
				reaction = best_focus_attention.reaction
			}
			self._ext_movement:set_attention(attention_data)
		else
			self._ext_movement:set_attention()
		end

		self._attention_obj = best_focus_attention
	end
end

local fs_original_sentrygunbrain_init = SentryGunBrain.init
function SentryGunBrain:init(unit)
	self.fs_hostage_mask = World:make_slot_mask(21, 22)
	fs_original_sentrygunbrain_init(self, unit)
	self._detected_attention_objects_i = FullSpeedSwarm.metaize_i(self._detected_attention_objects)
end

local fs_original_sentrygunbrain_destroydetectedattentionobjectdata = SentryGunBrain._destroy_detected_attention_object_data
function SentryGunBrain:_destroy_detected_attention_object_data(attention_info)
	fs_original_sentrygunbrain_destroydetectedattentionobjectdata(self, attention_info)

	local daoi = self._detected_attention_objects_i
	for i = daoi[0], 1, -1 do
		if daoi[i].u_key == attention_info.u_key then
			daoi[i] = daoi[daoi[0]]
			daoi[daoi[0]] = nil
			daoi[0] = daoi[0] - 1
			return
		end
	end
end

local is_server = Network:is_server()
function SentryGunBrain:update(unit, t, dt)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_sentrygunbrain_update(self, unit, t, dt)
	end

	if is_server and self._next_detection_upd_t < t then
		self:_upd_detection(t)
		self:fs_update_fire_mode(t)
		self:_select_focus_attention(t)
		self:_upd_flash_grenade(t)
		self:_upd_go_idle(t)
	end

	self:_upd_fire(t)
end

function SentryGunBrain:fs_is_cop()
	local team = self._ext_movement:team()
	return team and team.id == 'law1'
end

function SentryGunBrain:fs_hostage_weight_around_target(attention_info)
	if not attention_info
	or not fs_settings.hostage_situation
	or not attention_info.criminal_record
	or attention_info.criminal_record.ai
	or not self:fs_is_cop()
	then
		return 0
	end

	local weight = 0
	local nearby_chars = World:find_units_quick('sphere', attention_info.m_pos, 210, self.fs_hostage_mask)
	for _, unit in ipairs(nearby_chars) do
		local anim_data = unit:anim_data()
		if anim_data.tied then
			weight = weight + 2
		elseif anim_data.hands_tied then
			weight = weight + 1
		end
	end
	return weight
end

function SentryGunBrain:fs_update_fire_mode(t)
	if not self:fs_is_cop() then
		return
	end

	local attention_obj = self._attention_obj
	if attention_obj and fs_settings.hostage_situation and self._active and alive(attention_obj.unit) then
		local weapon = self._unit:weapon()
		local old_use_armor_piercing = weapon._use_armor_piercing
		local hw = self:fs_hostage_weight_around_target(attention_obj)

		local old_reaction = self._ext_movement._attention and self._ext_movement._attention.reaction or AIAttentionObject.REACT_AIM
		local new_reaction
		if hw == 0 then
			self.fs_clarity_t = nil
			self.fs_confusion_t = nil
			new_reaction = AIAttentionObject.REACT_SHOOT
		else
			hw = math.min(hw, 4)
			if self.fs_clarity_t then
				if t < self.fs_clarity_t then
					new_reaction = AIAttentionObject.REACT_SHOOT
				else
					new_reaction = AIAttentionObject.REACT_AIM
					local amount = hw * 0.4
					self.fs_confusion_t = t + amount
					self.fs_clarity_t = nil
				end
			elseif self.fs_confusion_t then
				if t < self.fs_confusion_t then
					new_reaction = AIAttentionObject.REACT_AIM
				else
					local amount = math.random() < 0.5 and 2 or 3
					self.fs_clarity_t = t + amount
					self.fs_confusion_t = nil
				end
			else
				new_reaction = AIAttentionObject.REACT_SHOOT
				self.fs_clarity_t = t + 0.5
			end
		end

		if new_reaction ~= old_reaction then
			local attention_data = {
				unit = attention_obj.unit,
				u_key = attention_obj.u_key,
				handler = attention_obj.handler,
				reaction = new_reaction
			}
			self._ext_movement:set_attention(attention_data)
		end
	end
end
