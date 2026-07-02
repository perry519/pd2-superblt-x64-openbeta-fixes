--[string "lib/network/matchmaking/networkvoicechatsteam..."]:30: attempt to index global 'Steam' (a nil value)
local _init = NetworkManager.init
function NetworkManager:init()
	_init(self)
	if SystemInfo:distribution() == Idstring("EPIC") then
		self.voice_chat = NetworkVoiceChatDisabled:new()
	end
end
