_G.MutatorStealthroids = _G.MutatorStealthroids or class(BaseMutator)
MutatorStealthroids._type = 'MutatorStealthroids'
MutatorStealthroids.name_id = 'fs_mutator_stealthroids_name'
MutatorStealthroids.desc_id = 'fs_mutator_stealthroids_desc'
MutatorStealthroids.has_options = false
MutatorStealthroids.reductions = {money = 0, exp = 0}
MutatorStealthroids.categories = {'gameplay'}
MutatorStealthroids.icon_coords = {8, 2}

table.insert(FullSpeedSwarm.custom_mutators, MutatorStealthroids)

local function _can_force_run()
	return FullSpeedSwarm:allow_stealth_changes()
end

function MutatorStealthroids:values()
	-- ugly way to send nothing to clients
	return {}
end

function MutatorStealthroids:setup()
	FullSpeedSwarm.settings.stealthroids = true
	FullSpeedSwarm:finalize_settings()

	if Network:is_client() then
		return
	end

	if FullSpeedSwarm.stealthroids_action_request_hooked then
		return
	end
	FullSpeedSwarm.stealthroids_action_request_hooked = true

	local fs_copmovement_actionrequest = CopMovement.action_request
	function CopMovement:action_request(action_desc)
		if not action_desc then
			-- qued
		elseif action_desc.type ~= 'walk' then
			-- qued
		elseif not _can_force_run() then
			-- qued
		elseif self._unit:slot() == 24 then -- bots
			-- qued
		elseif not self._unit:brain()._logic_data or self._unit:brain()._logic_data.is_tied then
			-- qued
		else
			action_desc.variant = 'run'
			action_desc.no_walk = true
		end
		return fs_copmovement_actionrequest(self, action_desc)
	end
end
