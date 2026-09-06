local fs_original_hooks_addhook = Hooks.AddHook
function Hooks:AddHook(key, id, func)
	if not key or not id or type(func) ~= 'function' then
		log('[FSS] Hooks:AddHook() received crap:')
		log('[FSS]   key: ' .. tostring(key))
		log('[FSS]   id: ' .. tostring(id))
		log('[FSS]   func: ' .. tostring(func))
		log('[FSS] ' .. debug.traceback())
		return
	end

	fs_original_hooks_addhook(self, key, id, func)
end

function Hooks:Call(key, ...)
	local hooks = self._registered_hooks[key]
	if not hooks then
		return
	end

	for _, hook in pairs(hooks) do
		if type(hook) == 'table' then
			local func = hook.func
			if type(func) == 'function' then
				func(...)
			end
		end
	end
end

function Hooks:Remove(id)
	for _, hooks in pairs(self._registered_hooks) do
		if type(hooks) == 'table' then
			for k, v in ipairs(hooks) do
				if v.id == id then
					table.remove(hooks, k)
					break
				end
			end
		end
	end
end
