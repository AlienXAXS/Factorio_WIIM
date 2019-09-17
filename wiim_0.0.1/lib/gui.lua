local mod_gui = require '__core__/lualib/mod-gui'
local GUI = {}

-- Callback for GUI Search Resusts
GUI.SearchRequestFunction = nil

local GUIFuntionality = {
	search = function(event, playerData)
		local innerEvent = event.event
		local player = event.player
		local guiElement = event.guiElement
		
		player.print("clicky search")
		
		if ( guiElement and guiElement.valid ) then
			if ( guiElement.elem_value ) then -- do we have a selected item?
				player.print("GUI Element Selected: " .. guiElement.elem_value)
				if ( GUI.SearchRequestFunction ) then
					GUI.SearchRequestFunction(player, guiElement.elem_value)
				end
			end
		end
		
	end,
	
	find_button = function(event, playerData)
		
	end,
}

function GUI.Init()
	if not global.guiData then global.guiData = {} end
end

function addGUIAction(guiElement, playerGUIData, actionData)
	local playerAction = playerGUIData.actions
	if ( not playerAction ) then
		playerGUIData.actions = {}
		playerAction = playerGUIData.actions
	end
	
	playerAction[guiElement.index] = actionData
end

function GUI.PlayerCreatedRaisedEvent(eventData)
	local playerIndex = eventData.player_index
	local playerData = global.guiData[playerIndex] or {}
	
	global.guiData[playerIndex] = {
		guiElements = playerData.guiElements or {},
		actions = playerData.actions or {},
		updateLabel = playerData.updateLabel or {}
	}
end

function GUI.RaisedEvent(event)
	local player = game.players[event.player_index]
	local guiElementName = event.prototype_name or nil
	local guiElement = event.element or nil
	
	game.print(serpent.block(event))
	
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
	local playerActionableEvent = playerGUIData.actions[guiElement.index] or nil
	if ( playerActionableEvent ) then
		-- We have an actionable player, let's process it
		GUIFuntionality[playerActionableEvent.actionName]({event = event, player = player, guiElement = playerActionableEvent.guiElement or nil}, playerGUIData)
	end
end

function GUI.SearchProgressUpdate(player, progress, total)
	local playerGUIData = global.guiData[player.index]
	if ( playerGUIData == nil ) then
		return
	end
	
	playerGUIData.updateLabel.caption = "Searching: " .. progress .. "/" .. total
end

function GUI.SearchComplete(player, results)
	
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
    bordered_frame.style.horizontally_stretchable = true
	
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
	
	--[[
		SCROLL PANE, USED FOR SEARCH RESULTS - IF ANY.
		
		local pusher = title_flow.add{type = "empty-widget", direction = "horizontal", style = "draggable_space_header"}
  pusher.style.horizontally_stretchable = true
  pusher.style.vertically_stretchable = true
  pusher.drag_target = frame
		
	]]--
	
	local results_pane = bordered_frame.add{
		type = "frame",
        style = "bordered_frame",
        direction = "vertical"
	}
	results_pane.style.horizontally_stretchable = true
	local results_label = results_pane.add{
		type = "label",
		caption="Results: None"
	}
	playerGUIData.updateLabel = results_label
	
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
		playerGUIData.actions = nil
		playerGUIData.updateLabel = nil
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