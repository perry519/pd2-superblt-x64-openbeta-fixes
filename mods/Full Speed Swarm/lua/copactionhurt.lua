local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function CopActionHurt:is_network_allowed(action_desc)
	if not CopActionHurt.network_allowed_hurt_types[action_desc.hurt_type] then
		return false
	end

	if action_desc.allow_network == false then
		return false
	end

	if self._unit:in_slot(managers.slot:get_mask('criminals')) then
		if not managers.groupai:state():is_enemy_converted_to_criminal(self._unit) then
			return false
		end
	end

	return true
end

local fs_original_copactionhurt_freezeragdoll = CopActionHurt._freeze_ragdoll
function CopActionHurt:_freeze_ragdoll()
	fs_original_copactionhurt_freezeragdoll(self)
	self._unit:set_extension_update_enabled(Idstring('movement'), false)
	local dmg_ext = self._unit:damage()
	if dmg_ext then
		dmg_ext.fs_ragdollizable = true
	end
end

if Network:is_server() then
	local incr = 0
	local math_randomseed = math.randomseed
	local math_random = math.random
	local math_floor = math.floor
	function CopActionHurt:_pseudorandom(a, b)
		local at = Application:time()
		local ht = managers.game_play_central:get_heist_timer()

		local mult = 10
		local t = math_floor(ht * mult + 0.5) / mult
		local uid = self._unit:id()

		local seed = (uid ^ (t / 183.62) * 100) % 100000
		math_randomseed(seed)
		local ret = a and b and math_random(a, b) or a and math_random(a) or math_random()

		math_randomseed(incr + (at - math_floor(at)) * 1000000000)
		incr = (incr + 1) % 4096

		return ret
	end
end
