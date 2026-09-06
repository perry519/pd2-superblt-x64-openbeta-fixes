local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local cops_to_intimidate = {}
FullSpeedSwarm.cops_to_intimidate = cops_to_intimidate

function CopDamage:fs_mark_tasered_for_intimidation(result)
	if type(result) == 'table' and result.type == 'taser_tased' and result.variant == 'light' then
		if self._char_tweak.surrender and self._char_tweak.surrender ~= tweak_data.character.presets.special then
			cops_to_intimidate[self._unit:key()] = TimerManager:game():time()
		end
	end
end

local fs_original_copdamage_sendtaseattackresult = CopDamage._send_tase_attack_result
function CopDamage:_send_tase_attack_result(attack_data, ...)
	self:fs_mark_tasered_for_intimidation(attack_data and attack_data.result)
	fs_original_copdamage_sendtaseattackresult(self, attack_data, ...)
end

local fs_original_copdamage_sendsynctaseattack_result = CopDamage._send_sync_tase_attack_result
function CopDamage:_send_sync_tase_attack_result(attack_data)
	self:fs_mark_tasered_for_intimidation(attack_data and attack_data.result)
	fs_original_copdamage_sendsynctaseattack_result(self, attack_data)
end

if Network:is_server() then
	local fs_original_copdamage_die = CopDamage.die
	function CopDamage:die(attack_data)
		fs_original_copdamage_die(self, attack_data)

		local attacker_unit = attack_data.attacker_unit
		if alive(attacker_unit) and attacker_unit:in_slot(managers.slot:get_mask('criminals_no_deployables')) then
			self._unit:unit_data().fs_attacker_pos = attacker_unit:position()
		end
	end
end

local fs_original_copdamage_ondeath = CopDamage._on_death
function CopDamage:_on_death(...)
	fs_original_copdamage_ondeath(self, ...)
	self._unit:damage().fs_dont_care_about_damage = true
end
