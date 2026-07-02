-- Move the listener around to follow the player

if not blt or not blt.xaudio then
	return
end

local l = blt.xaudio.listener

local mvec_cam_fwd = Vector3()
local mvec_cam_up = Vector3()

Hooks:PostHook(PlayerMovement, "update", "XAudioUpdateListenerPosition", function(self, unit, t, dt)
	XAudio._player_unit = self._unit

	if not blt.xaudio.issetup() then
		return
	end

	local pos = self:m_stand_pos()
	l:setposition(pos.x, pos.y, pos.z)

	local state = self:current_state()
	if not state then return end

	-- TODO jumping/falling?
	local velocity = state._last_velocity_xy

	if velocity then
		l:setvelocity(velocity.x, velocity.y, velocity.z)
	else
		l:setvelocity(0, 0, 0)
	end

	if state._ext_camera then
		local rotation = state._ext_camera:rotation()
		mrotation.y(rotation, mvec_cam_fwd)
		mrotation.z(rotation, mvec_cam_up)
		l:setorientation(
			mvec_cam_fwd.x, mvec_cam_fwd.y, mvec_cam_fwd.z,
			mvec_cam_up.x, mvec_cam_up.y, mvec_cam_up.z
		)
	end
end)

Hooks:Add("GameSetupUpdate", "XAudioGameSetupUpdateCamera", function(t, dt)
	if not blt.xaudio.issetup() then
		return
	end

	if not alive(XAudio._player_unit) then
		local viewport = managers.viewport:first_active_viewport()
		if viewport then
			local cam = viewport:camera()
			if cam then
				local cam_pos = cam:position()
				l:setvelocity(0, 0, 0)
				l:setposition(cam_pos.x, cam_pos.y, cam_pos.z)
				local rotation = cam:rotation()
				mrotation.y(rotation, mvec_cam_fwd)
				mrotation.z(rotation, mvec_cam_up)
				l:setorientation(mvec_cam_fwd.x, mvec_cam_fwd.y, mvec_cam_fwd.z, mvec_cam_up.x, mvec_cam_up.y, mvec_cam_up.z)
			end
		end
	end
end)
