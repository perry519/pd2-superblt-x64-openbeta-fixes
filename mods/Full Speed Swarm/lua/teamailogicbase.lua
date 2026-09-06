local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local REACT_COMBAT = AIAttentionObject.REACT_COMBAT
local REACT_SURPRISED = AIAttentionObject.REACT_SURPRISED
local REACT_SHOOT = AIAttentionObject.REACT_SHOOT
local math_min = math.min

local cops_to_intimidate = {}
local function _set_loud()
	if not BB then
		cops_to_intimidate = FullSpeedSwarm.cops_to_intimidate
	end
end
table.insert(FullSpeedSwarm.call_on_loud, _set_loud)

local fs_original_teamailogicbase_chkreactiontoattentionobject = TeamAILogicBase._chk_reaction_to_attention_object
function TeamAILogicBase._chk_reaction_to_attention_object(data, attention_data, stationary)
	if not FullSpeedSwarm:allow_stealth_changes() then
		return fs_original_teamailogicbase_chkreactiontoattentionobject(data, attention_data, stationary)
	end

	local intimidate_t = cops_to_intimidate[attention_data.unit_key]
	if intimidate_t and data.t - intimidate_t < 10 then
		return
	end

	local settings = attention_data.settings
	if settings == attention_data.previous_settings then
		return REACT_COMBAT
	end

	local reaction = settings.reaction
	if attention_data.is_person and attention_data.unit:id() ~= -1 then
		if data.cool then
			return math_min(reaction, REACT_SURPRISED)
		elseif stationary then
			return math_min(reaction, REACT_SHOOT)
		end
	end

	if reaction == REACT_COMBAT then
		attention_data.previous_settings = settings
	end

	return reaction
end
