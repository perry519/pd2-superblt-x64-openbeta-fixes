local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local fs_original_coresoundenvironmentmanager_init = CoreSoundEnvironmentManager.init
function CoreSoundEnvironmentManager:init(...)
	self.fs_max_check_objects_id = 0
	fs_original_coresoundenvironmentmanager_init(self, ...)
end

local fs_original_coresoundenvironmentmanager_addcheckobject = CoreSoundEnvironmentManager.add_check_object
function CoreSoundEnvironmentManager:add_check_object(data)
	local i = 1
	while self._check_objects[i] do
		i = i + 1
	end
	self.fs_max_check_objects_id = math.max(self.fs_max_check_objects_id, i)
	self._check_object_id = i - 1

	return fs_original_coresoundenvironmentmanager_addcheckobject(self, data)
end

function CoreSoundEnvironmentManager:update(t, dt)
	local nr = self.fs_max_check_objects_id
	local check_objects = self._check_objects
	for id = 1, nr do
		local data = check_objects[id]
		if data and data.active then
			self:_update_object(t, dt, id, data)
		end
	end
end
