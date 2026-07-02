-- core/lib/system/corepatchlua adds a metatable to _G that prevents creating and checking variables in _G that have not been created by the game
-- We simply remove the offending metatable functions here
local mt = getmetatable(_G)
if mt then
	mt.__newindex = nil
	mt.__index = nil
end
