Hooks:Register("NetworkManagerOnPeerAdded")
Hooks:PostHook(NetworkManager, "on_peer_added", "BLT.NetworkManager.on_peer_added", function(self, peer, peer_id)
	Hooks:Call("NetworkManagerOnPeerAdded", peer, peer_id)
end)
