local mod_gui = require '__core__/lualib/mod-gui'
local GUI = {}

-- Callback for GUI Search Resusts
GUI.SearchRequestFunction = nil
GUI.LocateFunction = nil

local GUIFuntionality = {
	search = function(event)
		local innerEvent = event.event
		local player = event.player
		local guiElement = event.guiElement
		
		log(serpent.block(event))

		if ( guiElement and guiElement.valid ) then
			if ( guiElement.elem_value ) then -- do we have a selected item?
				local playerGUIData = global.guiData[player.index]
				if ( playerGUIData ) then
					if ( playerGUIData.lastItemSelected ) then
						-- detect if the player is clicking the item box again, while there is already something there.
						if ( playerGUIData.lastItemSelected == guiElement.elem_value ) then
							return
						end
					end
					playerGUIData.lastItemSelected = guiElement.elem_value
					if ( GUI.SearchRequestFunction ) then
						GUI.SearchRequestFunction(player, guiElement.elem_value)
					end
				end
			end
		end
	end,
		
	locate_button = function(event)
		local innerEvent = event.event
		local player = event.player
		local playerGUIData = global.guiData[player.index]
		local result = event.action.result
		
		if ( not result ) then return end
		
		if ( playerGUIData ) then
			local pResolution = player.display_resolution
			local globalYOffset = -2.5
			
			if ( playerGUIData.directionalSprite ) then
				-- clean up old sprites here
				if ( rendering.is_valid(playerGUIData.directionalSprite.label) ) then
					rendering.destroy(playerGUIData.directionalSprite.label)
				end
				
				if ( rendering.is_valid(playerGUIData.directionalSprite.arrow) ) then
					rendering.destroy(playerGUIData.directionalSprite.arrow)
				end
			end
			
			playerGUIData.directionalSprite = {
				label = rendering.draw_text { 
					text				=	{"wiim.distance", "?"},
					surface				=	player.surface,
					target				=	player.character,
					surface				=	player.surface,
					target_offset		=	{x=0, y=(globalYOffset - 3.75)},
					players				=	{player},
					color				=	{1,0,0,0.5},
					alignment 			=	"center",
					scale				=	2.25,
					scale_with_zoom		=	true
				},
				destination = result
			}
			
			--[[
			playerGUIData.directionalSprite.background = rendering.draw_rectangle {
					color				=	{1,1,1,0.15},
					filled 				=	true,
					left_top			=	player.character,
					right_bottom		=	player.character,
					left_top_offset		=	{-1, -2.5},
					right_bottom_offset =	{1, -2.5},
					surface				= 	player.surface,
					players				= 	{player},
					draw_on_ground 		=	true
				}
			]]
			
			playerGUIData.directionalSprite.arrow = rendering.draw_sprite {
					sprite				=	"wiim_arrow",
					target				=	player.character,
					surface				=	player.surface,
					orientation_target	=	result,
					x_scale				=	2.5,
					y_scale				=	2.5,
					target_offset		=	{x=0, y=(globalYOffset - 5)},
					players				=	{player},
					scale_with_zoom		=	true
				}
			
			GUI.Destroy(player)
		end
	end
}

function GUI.Tick()
	if ( not global.guiData ) then return end
	
	for id,pData in pairs(global.guiData) do
		local player = game.get_player(id)
		if ( player and player.character and player.character.valid ) then
			if ( pData.directionalSprite ) then
				local label = pData.directionalSprite.label
				local destination = pData.directionalSprite.destination
				if ( rendering.is_valid(label) ) then
					local dx = player.position.x - destination.position.x    
					local dy = player.position.y - destination.position.y
					local dist = math.sqrt( dx*dx + dy*dy )
				
					rendering.set_text(label, {"wiim.distance", string.format("%.2f", dist)})
				end
			end
		end
	end
end

function GUI.Init()
	if not global.guiData then global.guiData = {} end
end

function addGUIAction(guiElement, playerGUIData, actionData)
	local playerAction = playerGUIData.actions
	if ( not playerAction ) then
		playerGUIData.actions = {}
		playerAction = playerGUIData.actions
	end
	
	actionData.guiElement = guiElement
	
	playerAction[guiElement.index] = actionData
end

function GUI.PlayerCreatedRaisedEvent(eventData)
	local playerIndex = eventData.player_index
	local playerData = global.guiData[playerIndex] or {}
	
	global.guiData[playerIndex] = {
		guiElements = playerData.guiElements or {},
		actions = playerData.actions or {},
		updateLabel = playerData.updateLabel or {},
		previousSearchResults = playerData.previousSearchResults or {}
	}
end

function GUI.SetupPlayers()
	for _,player in pairs(game.players) do
		GUI.PlayerCreatedRaisedEvent({player_index = player.index})
	end
end

function GUI.RaisedEvent(event)
	local player = game.players[event.player_index]
	local guiElementName = event.prototype_name or nil
	local guiElement = event.element or nil
		
	if ( DoesPlayerHaveGUIOpen(player) and event.name == defines.events.on_gui_closed ) then
		GUI.Destroy(player)
		return
	end
	
	if ( guiElementName == "wiim-shortcut" ) then
		GUI.Create(player)
	end
	
	-- No need to go any further here
	if ( not guiElement ) then return end
	
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData and playerGUIData.actions ) then
		game.print("player " .. player.name .. " pressed a button with an ID of " .. guiElement.index)
		local playerActionableEvent = playerGUIData.actions[guiElement.index] or nil
		if ( playerActionableEvent and GUIFuntionality[playerActionableEvent.actionName] ) then
			-- We have an actionable player, let's process it
			local x = {event = event, player = player, guiElement = playerActionableEvent.guiElement or nil, action = playerActionableEvent}
			GUIFuntionality[playerActionableEvent.actionName](x)
		end
	end
end

function GUI.SearchProgressUpdate(player, progress, total)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end
	
	if ( playerGUIData.guiElements.updateLabel and playerGUIData.guiElements.updateLabel.valid ) then
		playerGUIData.guiElements.updateLabel.caption = {"", {"wiim.statuscaption"}, ": Searching: " .. progress .. "/" .. total}
	end
end

function GUI.SearchComplete(player, results)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end

	if ( playerGUIData.guiElements.scrollPane and playerGUIData.guiElements.scrollPane.valid ) then
		local mainPane = playerGUIData.guiElements.scrollPane
		mainPane.clear() -- clear the items in the list that already exist.
		for _,result in pairs(results) do
			local resultPane = mainPane.add{
				type = "frame",
				name = "",
				direction = "horizontal"
			}
			resultPane.style.horizontally_stretchable = true
			
			if ( player.gui.is_valid_sprite_path("entity/" .. result.name) ) then
				local entityIcon = resultPane.add{
					type = "sprite",
					sprite = "entity/" .. result.name
				}
			else
				local entityName = resultPane.add{
					type = "label",
					caption = result.name
				}
			end
			
			local entityPositionLabel = resultPane.add{
				type = "label",
				caption = {"", {"wiim.position"}, " x=" .. result.position.x .. " y=" .. result.position.y}
			}
			
			local pusher = resultPane.add{type = "empty-widget", direction = "horizontal", style = "draggable_space_header"}
			pusher.style.horizontally_stretchable = true
			pusher.style.vertically_stretchable = true
			
			local entityFind = resultPane.add{
				type = "button",
				caption = "Locate"
			}
			
			addGUIAction(entityFind, playerGUIData, {actionName = "locate_button", guiElement = entityFind, result = result})
		end
		
		if ( playerGUIData.guiElements.updateLabel and playerGUIData.guiElements.updateLabel.valid ) then
			playerGUIData.guiElements.updateLabel.caption = {"", {"wiim.statuscaption"}, ": Found " .. #results .. " results."}
		end
		
		if ( playerGUIData.guiElements.mainFrame and playerGUIData.guiElements.mainFrame.valid and #results ~= 0 ) then
			playerGUIData.guiElements.mainFrame.force_auto_center()
		end
	end
end

function GUI.Create(player)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end
	
	if DoesPlayerHaveGUIOpen(player) then
		GUI.Destroy(player)
		return
	end
	
	local screen = player.gui.screen --mod_gui.get_frame_flow(player)
    local frame = screen.add{
        type = "frame",
        name = "",
        caption = {"wiim_main_frame"},
        direction = "vertical"
    }
	frame.auto_center = true
	frame.style.natural_width = 5000
	frame.style.maximal_height = 500
	playerGUIData.guiElements.mainFrame = frame
	
	
	--[[
		OUTER BORDER FRAME, USED FOR INFO LABEL
	]]--
	local bordered_frame = frame.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical",
    }
	bordered_frame.style.width = 500
   
	local choose_button_label = bordered_frame.add{
		type = "label",
		caption={"wiim_choose_button_label"}
	}
	
	--[[
		INNER BORDER FRAME, USED FOR ITEM PICKER AND SEARCH BUTTON
	]]--
	local innerFrameScrollPane = bordered_frame.add{
        type = "scroll-pane",
    }
	innerFrameScrollPane.style.horizontally_stretchable = true
	local searchAreaFlow = innerFrameScrollPane.add {
		type = "flow",
		direction = "horizontal"
	}
	innerFrameScrollPane.style.horizontally_stretchable = true
	innerFrameScrollPane.style.vertically_stretchable = true
	innerFrameScrollPane.style.minimal_height = 50
	
	--[[
		RECIPIE SELECTOR BOX
	]]--
	local choose_button = searchAreaFlow.add{
        type = "choose-elem-button",
        name = "assembler",
        style = "slot_button",
        elem_type = "item",
        tooltip = "Add an item to see where it's being made."
    }
	addGUIAction(choose_button, playerGUIData, {actionName = "search", guiElement = choose_button})
	
	
	local results_pane = bordered_frame.add{
		type = "frame",
        style = "bordered_frame",
        direction = "vertical"
	}
	results_pane.style.horizontally_stretchable = true
	local results_label = results_pane.add{
		type = "label",
		caption={"", {"wiim.statuscaption"}, ": Waiting for input"}
	}
	playerGUIData.guiElements.updateLabel = results_label
	
	local scroll_pane = results_pane.add{
        type = "scroll-pane",
    }
	playerGUIData.guiElements.scrollPane = scroll_pane
	
	-- Set the players current opened dialog, this allows for esc key to close the gui
	player.opened = frame
	
end

function GUI.Destroy(player)
	local playerGUIData = global.guiData[player.index]
	
	if ( playerGUIData == nil ) then
		return
	end
	
	if DoesPlayerHaveGUIOpen(player) then
		playerGUIData.guiElements.mainFrame.destroy()
		playerGUIData.guiElements.mainFrame = nil
		playerGUIData.guiElements.scrollPane = nil
		playerGUIData.guiElements.updateLabel = nil
		playerGUIData.actions = nil
		playerGUIData.lastItemSelected = nil
	end
end

function GUI.DestroySprites(player)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end
	
	if ( playerGUIData.directionalSprite ) then
		local label = playerGUIData.directionalSprite.label
		local arrow = playerGUIData.directionalSprite.arrow
		if ( rendering.is_valid(label) ) then rendering.destroy(label) end
		if ( rendering.is_valid(arrow) ) then rendering.destroy(arrow) end
		
		playerGUIData.directionalSprite = nil
	end
end

function DoesPlayerHaveGUIOpen(player)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end
	
	if ( playerGUIData.guiElements.mainFrame and playerGUIData.guiElements.mainFrame.valid ) then
		return true
	end
	
	return false
end

return GUI