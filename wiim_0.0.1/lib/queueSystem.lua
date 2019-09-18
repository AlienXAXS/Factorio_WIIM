local Queue = {}

-- Configuration, can be overwritten
-- todo: move this to map settings
Queue.MaxSearchesPerTick = settings.global["wiim-max-searches-per-tick"].value or 5

function processFinishedCallback(queue)
	if ( queue.player.valid ) then
		if ( queue.finishedCallback ) then
			queue.finishedCallback(queue)
		end
	end
	
	-- Clear the queue from the table
	global.queueManager.queues[queue.id] = nil
end

function Queue.Init()
	if ( not global.queueManager ) then global.queueManager = {} end
	if ( not global.queueManager.queues ) then global.queueManager.queues = {} end
end

function Queue.Tick()
	if ( not global.queueManager ) then return end

	local maxSearches = Queue.MaxSearchesPerTick
	if ( #global.queueManager.queues > 1 ) then
		-- If we have multiple queues going at once, only perform the max searches that all queues together would perform.
		maxSearches = math.floor(Queue.MaxSearchesPerTick / #global.queueManager.queues)
	end
	for _,queue in pairs(global.queueManager.queues) do		
		if ( queue ) then
			if ( not queue.criteria or
				 not queue.enumerables or
				 not queue.finishedCallback or
				 not queue.criteria.against) then
				global.queueManager.queues[queue.id] = nil
				
				game.print("queue invalid params")
				game.print(serpent.block(queue))
				
				return
			end
			
			-- Sometimes, people will request a queue against no factories at all.
			if ( #queue.enumerables == 0 ) then
				-- This queue is finished, remove it
				processFinishedCallback(queue)
				global.queueManager.queues[queue.id] = nil
			else
				local tickResult = false
				if ( queue.criteria.against == "assembling-machine" ) then
					tickResult = tickRecipe(queue, maxSearches)
				end
				
				if ( queue.criteria.against == "item" ) then
					tickStorage(queue, maxSearches)
				end
				
				if ( queue.progressedCallback and tickResult ) then
					-- call the progress optional
					queue.progressedCallback({player = queue.player, progress=queue.progress, total=#queue.enumerables})
				end
			end
		else
			game.print("queue is invalid")
		end
	end
end

function tickRecipe(queueEntry, maxSearches)
	-- If we have a next entry, but it's not in the queue, then we've gone done goofed.
	if ( queueEntry.nextEntry and not queueEntry.enumerables[queueEntry.nextEntry] ) then
		game.print("Attempted to evaluate a queue entry that does not exist in the inner enumerables table.")
		queueEntry = nil
		return
	end

	for _=1, maxSearches do
		local queueEnumEntry
		queueEntry.nextEnumEntry, queueEnumEntry = next(queueEntry.enumerables, queueEntry.nextEnumEntry)
				
		if ( queueEntry.nextEnumEntry == nil or queueEnumEntry == nil ) then
			processFinishedCallback(queueEntry)
			return false
		end
		
		if ( queueEnumEntry ) then
			queueEntry.progress = queueEntry.progress + 1
			if ( queueEnumEntry.valid and queueEnumEntry.type == "assembling-machine" ) then
				local criteria = queueEntry.criteria
				local lookup = queueEntry.criteria.lookup
				
				if ( lookup ) then
					local recipe = queueEnumEntry.get_recipe()
					if ( recipe ) then
						for _,product in pairs(recipe.products) do
							if ( product.name == lookup ) then
								table.insert(queueEntry.results, queueEnumEntry)
							end
						end
					end
				end
			end
		end
	end
	
	return true
end

function tickStorage(queueEntry, maxSearches)
	--Not implemented yet.
end

function tickFurnace(queueEntry, maxSearches)
	--Not yet
end

function Queue.Add(player, buildingType, searchFor, searchItems, queueFinished, queueProgressed)
	local queueMakeup = {
		id = #global.queueManager.queues+1,
		player = player,
		criteria = {against = buildingType, lookup = searchFor},
		enumerables = searchItems,
		finishedCallback = queueFinished,
		progressedCallback = queueProgressed,
		progress = 0,
		nextEnumEntry = nil,
		results = {}
	}
	
	-- add this request to the queue
	global.queueManager.queues[queueMakeup.id] = queueMakeup
end

return Queue