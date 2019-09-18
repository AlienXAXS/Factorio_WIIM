
local GUI = require("lib.gui")
local QueueManager = require("lib.queueSystem")
local TypeValues = {}
TypeValues["assembling-machine"] = true

function SetupGlobals()
	QueueManager.Init()
	GUI.Init()
	
	if ( not global.factories ) then global.factories = {} end
end

function queueFinished(data)
	GUI.SearchComplete(data.player, data.results)
end

function queueProgressed(data)
	GUI.SearchProgressUpdate(data.player, data.progress, data.total)
end

GUI.SearchRequestFunction = function(player, element)	
	local tmpList = {}
	for id,ent in pairs(global.factories["assembling-machine"]) do tmpList[#tmpList+1] = ent end
	
	player.print("Searching for '" .. element .. "' against " .. #tmpList .. " factories!")
	
	QueueManager.Add(player, "assembling-machine", element, tmpList, queueFinished, queueProgressed)
end

function AddFactories(overwrite)
	--todo: add everything we're searching on later, such as storage containers as well.
	local forceOverwrite = overwrite or false
		
	-- if it already exists, we do not want to re-create it again.
	if ( global.factories[typeValue] and not forceOverwrite ) then return end
	
	-- Create our factory list, just in case this mod was installed on an already existing save.
	global.factories = {}
	
	for _,surface in pairs(game.surfaces) do
		for tv,_ in pairs(TypeValues) do
			if ( not global.factories[tv] ) then global.factories[tv] = {} end
			for _,ent in pairs(surface.find_entities_filtered{type=tv}) do
				global.factories[tv][ent.unit_number] = ent
			end
		end
	end
end

-- Called when a player or bot puts an entity in the world
script.on_event(
    {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity
    },
    function(event)
		local entity = event.created_entity or event.entity or nil
		if ( entity and entity.valid ) then
			if ( entity.type == "assembling-machine" ) then
				global.factories[entity.type][entity.unit_number] = entity
			end
		end
	end
)

-- Entity death/pickup checks
script.on_event(
    {
        defines.events.on_entity_died,
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity
    },
    function(event)
		local entity = event.entity
		if ( entity.valid ) then
			if ( global.factories[entity.type] and global.factories[entity.type][entity.unit_number] ) then
				global.factories[entity.type][entity.unit_number] = nil
			end
		end
	end
)

script.on_event(defines.events.on_tick, function()
	QueueManager.Tick()
	GUI.Tick()
end)

function processTick()
	QueueManager.Tick()
end

-- Define our event handlers
script.on_init(function ()
	SetupGlobals()
	AddFactories()
	GUI.SetupPlayers()
end)

script.on_load(function () 
	
end)

script.on_configuration_changed(function (data) 
	SetupGlobals()
	AddFactories(true)
	GUI.SetupPlayers()
end)

script.on_event(defines.events.on_player_created, function(data)
	GUI.PlayerCreatedRaisedEvent(data)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
	game.print("Shortcut pressed")
	GUI.RaisedEvent(event)
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
	local player = game.players[event.player_index]
	if ( player ) then
		GUI.DestroySprites(player)
		GUI.Destroy(player)
	end
end)

-- GUI Events
script.on_event(defines.events.on_gui_click, GUI.RaisedEvent)
script.on_event(defines.events.on_gui_elem_changed, GUI.RaisedEvent)
script.on_event(defines.events.on_gui_closed, GUI.RaisedEvent)