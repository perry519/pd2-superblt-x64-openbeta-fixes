local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

for character, tweaks in pairs(tweak_data.character) do
	if type(tweaks) == "table" and tweaks.move_speed and character ~= "presets" then
		tweaks.hostage_move_speed = tweaks.surrender and tweaks.surrender ~= tweak_data.character.presets.surrender.special and tweak_data.character.civilian.hostage_move_speed or 1
	end
end

HuskCopBrain._ENABLE_LASER_TIME = 0.1
HuskCopBrain._NET_EVENTS.hostage_on = 7
HuskCopBrain._NET_EVENTS.hostage_off = 8

local fs_original_huskcopbrain_syncnetevent = HuskCopBrain.sync_net_event
function HuskCopBrain:sync_net_event(event_id)
	local movement = self._unit:movement()
	if event_id == self._NET_EVENTS.hostage_on then
		local base = self._unit:base()
		local char_tweak = base and tweak_data.character[base._tweak_table]
		if movement then
			movement.move_speed_multiplier = char_tweak and char_tweak.hostage_move_speed or 1
		end
	elseif event_id == self._NET_EVENTS.hostage_off then
		if movement then
			movement.move_speed_multiplier = 1
		end
	else
		fs_original_huskcopbrain_syncnetevent(self, event_id)
	end
end
