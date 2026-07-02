---@class Buffer
---@field new fun(self, input: string):Buffer
local C = blt_class()
XAudio.Buffer = C

function C:init(input)
	local t = type(input)
	if t == "string" then
		input = blt.xaudio.loadbuffer(input)
	elseif t == "userdata" then
		-- Nothing needs to be done.
		-- TODO verify this is a buffer
	else
		error("Unknown XAudio.Buffer input type " .. type .. " for " .. tostring(input))
	end

	self._buffer = input
end

function C:close(force)
	if blt.xaudio.buffer_close then
		blt.xaudio.buffer_close(self._buffer, force and true or false)
	else
		self._buffer:close(force and true or false)
	end
end

function C:get_length()
	if blt.xaudio.buffer_getsamplecount then
		return blt.xaudio.buffer_getsamplecount(self._buffer) / blt.xaudio.buffer_getsamplerate(self._buffer)
	end

	return self._buffer:getsamplecount() / self._buffer:getsamplerate()
end
