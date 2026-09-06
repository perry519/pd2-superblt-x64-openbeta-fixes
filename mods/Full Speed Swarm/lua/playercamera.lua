local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

if _G.IS_VR then
	return
end

local math_abs = math.abs
local math_floor = math.floor
local math_clamp = math.clamp

local mrot_set = mrotation.set_yaw_pitch_roll
local mrot_x = mrotation.x
local mrot_y = mrotation.y
local mrot_z = mrotation.z
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply

local mvec1 = Vector3()
local tdnetcam = tweak_data.network and tweak_data.network.camera

local fs_original_playercamera_setrotation = PlayerCamera.set_rotation
function PlayerCamera:set_rotation(rot)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_playercamera_setrotation(self, rot)
	end

	mrot_y(rot, mvec1)
	mvec3_mul(mvec1, 100000)
	mvec3_add(mvec1, self._m_cam_pos)
	self._camera_controller:set_target(mvec1)

	mrot_z(rot, mvec1)
	self._camera_controller:set_default_up(mvec1)

	local sync_yaw = rot:yaw()
	local sync_pitch = rot:pitch()
	mrot_set(self._m_cam_rot, sync_yaw, sync_pitch, rot:roll())
	mrot_y(self._m_cam_rot, self._m_cam_fwd)
	mrot_x(self._m_cam_rot, self._m_cam_right)

	if tdnetcam then
		sync_yaw = sync_yaw + 360
		sync_yaw = sync_yaw % 360
		sync_yaw = math_floor((255 * sync_yaw) / 360)

		sync_pitch = math_clamp(sync_pitch, -85, 85) + 85
		sync_pitch = math_floor((127 * sync_pitch) / 170)
		local angle_delta = math_abs(self._sync_dir.yaw - sync_yaw) + math_abs(self._sync_dir.pitch - sync_pitch)

		local t = TimerManager:game():time()
		if angle_delta == 0 then
			self._last_sync_t = t
		elseif tdnetcam.network_sync_delta_t <= t - self._last_sync_t then
			self._unit:network():send('set_look_dir', sync_yaw, sync_pitch)
			self._sync_dir.yaw = sync_yaw
			self._sync_dir.pitch = sync_pitch
			self._last_sync_t = t
		end
	end
end
