-- [string "lib/network/matchmaking/networkvoicechatsteam..."]:113: attempt to perform arithmetic on field 'time' (a nil value)
local orig_func_NetworkVoiceChatSTEAM_update = NetworkVoiceChatSTEAM.update
function NetworkVoiceChatSTEAM:update()
	local playing = self.handler:get_voice_receivers_playing()
	for id, pl in pairs(playing) do
		if pl and self._users_talking[id] and self._users_talking[id].time then
        	orig_func_NetworkVoiceChatSTEAM_update(self)
    	end
	end
end
