local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

function MessageSystem:_notify()
	local msgs = self._messages
	local i = 1
	local msg = msgs[i]
	if msg then
		self._messages = {}
		repeat
			local listeners = self._listeners[msg.message]
			if listeners then
				if msg.uid then
					listeners[msg.uid](unpack(msg.arg))
				else
					for _, listener in pairs(listeners) do
						listener(unpack(msg.arg))
					end
				end
			end

			i = i + 1
			msg = msgs[i]
		until not msg
	end
end
