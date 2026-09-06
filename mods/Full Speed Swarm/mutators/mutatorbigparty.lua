_G.MutatorBigParty = _G.MutatorBigParty or class(BaseMutator)
MutatorBigParty._type = 'MutatorBigParty'
MutatorBigParty.name_id = 'fs_mutator_bigparty_name'
MutatorBigParty.desc_id = 'fs_mutator_bigparty_desc'
MutatorBigParty.has_options = true
MutatorBigParty.reductions = {money = 0, exp = 0}
MutatorBigParty.categories = {'enemies'}
MutatorBigParty.icon_coords = {6, 1}
MutatorBigParty.incompatiblities = {
	'MutatorRealElastic'
}

table.insert(FullSpeedSwarm.custom_mutators, MutatorBigParty)

function MutatorBigParty:register_values(mutator_manager)
	self:register_value('cops_nr', self:min_cops_nr(), 'cnr')
end

function MutatorBigParty:get_cops_nr()
	return self:value('cops_nr')
end

function MutatorBigParty:set_cops_nr(item)
	self:set_value('cops_nr', item:value())
end

function MutatorBigParty:min_cops_nr()
	return 100
end

function MutatorBigParty:max_cops_nr()
	return 1000
end

function MutatorBigParty:setup_options_gui(node)
	local params = {
		name = 'cops_nr_slider',
		text_id = 'fs_menu_mutator_cops_nr',
		callback = '_update_mutator_value',
		update_callback = callback(self, self, 'set_cops_nr')
	}

	local data_node = {
		type = 'CoreMenuItemSlider.ItemSlider',
		show_value = true,
		min = self:min_cops_nr(),
		max = self:max_cops_nr(),
		step = 5,
		decimal_count = 0
	}

	local new_item = node:create_item(data_node, params)
	new_item:set_value(self:get_cops_nr())
	node:add_item(new_item)
	self._node = node

	return new_item
end

function MutatorBigParty:values()
	-- ugly way to send nothing to clients
	return {}
end

function MutatorBigParty:reset_to_default()
	self:clear_values()

	if self._node then
		local slider = self._node:item('cops_nr_slider')
		if slider then
			slider:set_value(self:get_cops_nr())
		end
	end
end

function MutatorBigParty:options_fill()
	return self:_get_percentage_fill(self:min_cops_nr(), self:max_cops_nr(), self:get_cops_nr())
end

function MutatorBigParty:setup()
	local cops_nr = self:get_cops_nr()
	local group_ai = tweak_data.group_ai
	local assault = group_ai.besiege.assault

	local ratio = cops_nr / (assault.force[#assault.force] * assault.force_balance_mul[#assault.force_balance_mul])

	local processed = {}
	for id, group in pairs(group_ai.enemy_spawn_groups) do
		if id ~= 'Phalanx' then
			if group.amount and not processed[group.amount] then
				processed[group.amount] = true
				for k, v in pairs(group.amount) do
					group.amount[k] = math.ceil(v * ratio * 5)
				end
			end
			if group.spawn and not processed[group.spawn] then
				processed[group.spawn] = true
				for _, spawn in pairs(group.spawn) do
					if spawn.amount_max then
						spawn.amount_max = math.ceil(spawn.amount_max * ratio * 5)
					end
				end
			end
		end
	end

	for i = 1, #assault.force do
		assault.force[i] = cops_nr
	end

	for i = 1, #assault.force_balance_mul do
		assault.force_balance_mul[i] = 1
	end

	for i = 1, #assault.force_pool do
		assault.force_pool[i] = math.ceil(assault.force_pool[i] * assault.force_pool_balance_mul[#assault.force_pool_balance_mul] * ratio)
	end

	for i = 1, #assault.force_pool_balance_mul do
		assault.force_pool_balance_mul[i] = 1
	end

	local fs_original_groupaistatebesiege_performgroupspawning = GroupAIStateBesiege._perform_group_spawning
	function GroupAIStateBesiege:_perform_group_spawning(spawn_task, force, use_last)
		fs_original_groupaistatebesiege_performgroupspawning(self, spawn_task, true, use_last)

		local spawn_points = spawn_task.spawn_group.spawn_pts
		for _, sp_data in ipairs(spawn_points) do
			sp_data.delay_t = 0
		end
	end
end
