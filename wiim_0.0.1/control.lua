
local GUI = require("lib.gui")
local QueueManager = require("lib.queueSystem")

function SetupGlobals()
	QueueManager.Init()
	GUI.Init()
	
	if ( not global.factories ) then global.factories = {} end
end

function queueFinished(data)
	game.print("Queue Finished, logged queue result to factorio-current")
	log(serpent.block(data))
	
	for _,ent in pairs(data.results) do
		game.print("Found item " .. data.criteria.lookup .. " inside " .. ent.name .. " at position x=" .. ent.position.x .. " y=" .. ent.position.y)
	end
end

function queueProgressed(data)
	game.print("[" .. game.tick .. "] - Progress: " .. data.player.name .. " | " .. data.progress .. "/" .. data.total)
	GUI.SearchProgressUpdate(data.player, data.progress, data.total)
end

GUI.SearchRequestFunction = function(player, element)
	game.print("Player " .. player.name .. " requested a search for " .. element .. " - Searching against " .. (#global.factories["assembling-machine"]) .. " factories!")
	
	QueueManager.Add(player, "assembling-machine", element, global.factories["assembling-machine"], queueFinished, queueProgressed)
end

function AddFactories(overwrite)
	--todo: add everything we're searching on later, such as storage containers as well.
	local typeValue = "assembling-machine"
	
	local forceOverwrite = overwrite or false
		
	-- if it already exists, we do not want to re-create it again.
	if ( global.factories[typeValue] and not forceOverwrite ) then return end
	
	-- Create our factory list, just in case this mod was installed on an already existing save.
	global.factories[typeValue] = {}
	
	for _,surface in pairs(game.surfaces) do
		for _,ent in pairs(surface.find_entities_filtered{type=typeValue}) do
			global.factories[typeValue][#global.factories[typeValue]+1] = ent
		end
	end
end

script.on_event(defines.events.on_tick, function()
	--QueueManager.Tick()
end)

function processTick()
	QueueManager.Tick()
end

-- Define our event handlers
script.on_init(function ()
	SetupGlobals()
	AddFactories()
end)

script.on_load(function () 
	
end)

script.on_configuration_changed(function (data) 
	SetupGlobals()
	AddFactories()
end)

script.on_event(defines.events.on_player_created, function(data)
	GUI.PlayerCreatedRaisedEvent(data)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
	GUI.RaisedEvent(event)
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
	local player = game.players[event.player_index]
	if ( player ) then
		GUI.Destroy(player)
	end
end)

-- GUI Events
script.on_event(defines.events.on_gui_click, GUI.RaisedEvent)
script.on_event(defines.events.on_gui_elem_changed, GUI.RaisedEvent)
script.on_event(defines.events.on_gui_closed, GUI.RaisedEvent)