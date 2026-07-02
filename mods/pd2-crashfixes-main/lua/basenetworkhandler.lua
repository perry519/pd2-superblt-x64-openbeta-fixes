--  [string "lib/network/base/handlers/basenetworkhandler.lua"]:46: attempt to index local 'rpc' (a nil value)
function BaseNetworkHandler._verify_sender(rpc)
    if managers.network:session() and type(rpc) == "userdata" and rpc.ip_at_index and rpc:ip_at_index(0) then
        if rpc:protocol_at_index(0) == SystemInfo:matchmaking_protocol() then
            return managers.network:session():peer_by_user_id(rpc:ip_at_index(0))
        else
            return managers.network:session():peer_by_ip(rpc:ip_at_index(0))
        end
    end
    return nil
end

-- Anticrash/lua/basenetworkhandler.lua:7: attempt to index local 'cd' (a number value)
-- and probably something else idk
function BaseNetworkHandler._verify_character(unit)
    if unit and type(unit) == "userdata" and alive(unit) then
        local cd = unit:character_damage()
        if cd and type(cd) == "table" and not cd:dead() then
            return true
        end
    end
    return false
end
