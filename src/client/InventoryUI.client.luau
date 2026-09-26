--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Inventory")
local Types = require(Shared:WaitForChild("Types"))
local Definitions = require(Shared:WaitForChild("Definitions"))
local Behaviors = require(Shared:WaitForChild("Behaviors"))
local Request = Shared:WaitForChild("Request") :: RemoteEvent
local State = Shared:WaitForChild("State") :: RemoteEvent

-- This is a display snapshot only. Every edit is requested from the server.
local inventory: Types.Inventory? = nil
local movingFrom: string? = nil
local movingId: string? = nil
local messages: {string} = {"","","","","",}
local slotButtons: {[string]: TextButton} = {}
-- Layout and styling live in StarterGui.InventoryGUI.
-- Only server-derived text, selection colors and template clones change at runtime.

local plr = Players.LocalPlayer
local playerGui = plr and plr:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("InventoryGUI") :: ScreenGui
local root = gui:WaitForChild("Root")
local middle = root:WaitForChild("Inventory")
local right = root:WaitForChild("Runtime")
local dropList = root:WaitForChild("DroppedItems"):WaitForChild("List")
local actions = middle:WaitForChild("Actions")
local feed = middle:WaitForChild("Feed") :: TextLabel
local runtime = right:WaitForChild("Data") :: TextLabel
local details = right:WaitForChild("Definition") :: TextLabel
local moveButton = middle:WaitForChild("Move") :: TextButton
local actionTemplate = actions:WaitForChild("ActionTemplate") :: TextButton
local dropTemplate = dropList:WaitForChild("DropTemplate") :: TextButton
local selectedColor = gui:GetAttribute("SelectedSlotColor") :: Color3
local normalColors: {[string]: Color3} = {}
local moveIdleText = moveButton.Text

-- Templates are visible in the editor so their appearance is easy to edit.
actionTemplate.Visible = false
dropTemplate.Visible = false

local function chooseSlot(slot: string)
	if movingFrom and movingId then
		Request:FireServer({Kind = "Move", Slot = movingFrom, To = slot, UniqueId = movingId})
		movingFrom, movingId = nil, nil
		moveButton.Text = moveIdleText
	else
		Request:FireServer({Kind = "Select", Slot = slot})
	end
end

for _, group in {
	{Prefix = "H", Count = Types.HotbarSize},
	{Prefix = "B", Count = Types.BackpackSize},
} do
	local grid = middle:WaitForChild(`{group.Prefix}Slots`)
	for index = 1, group.Count do
		local slot = `{group.Prefix}{index}`
		local slotButton = grid:WaitForChild(slot) :: TextButton
		slotButtons[slot] = slotButton
		normalColors[slot] = slotButton.BackgroundColor3
		slotButton.Activated:Connect(function() chooseSlot(slot) end)
	end
end

moveButton.Activated:Connect(function()
	if movingFrom then
		movingFrom, movingId = nil, nil
		moveButton.Text = moveIdleText
		return
	end
	local current = inventory
	local slot = if current then current.SelectedSlot else nil
	local item = if current and slot then current.Slots[slot] else nil
	if not slot or not item then return end
	movingFrom, movingId = slot, item.UniqueId
	moveButton.Text = "Pick slot / Cancel"
end)

local hotkeys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = table.find(hotkeys, input.KeyCode)
	if index then chooseSlot(`H{index}`) end
end)

local function clearButtons(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("TextButton") and child ~= actionTemplate and child ~= dropTemplate then
			child:Destroy()
		end
	end
end

-- Escape item text before adding markup so names/descriptions remain literal text.
local function colored(value: any, color: string): string
	local escaped = tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		:gsub('"', "&quot;"):gsub("'", "&apos;")
	return `<font color="{color}">{escaped}</font>`
end

State.OnClientEvent:Connect(function(snapshot)
	inventory = snapshot.Inventory
	local current = inventory
	if not current then return end
	if snapshot.Message then
		table.insert(messages, `> {snapshot.Message}`)
		if #messages > 5 then table.remove(messages, 1) end
	end
	feed.Text = table.concat(messages, "\n")
	for slot, slotButton in slotButtons do
		local item = current.Slots[slot]
		slotButton.BackgroundColor3 = if current.SelectedSlot == slot then selectedColor else normalColors[slot]
		slotButton.Text = if item then `{slot}\n{item.ItemId}\nx{item.Amount}` else `{slot}\n`
	end
	clearButtons(actions)
	local selectedSlot = current.SelectedSlot
	local selected = if selectedSlot then current.Slots[selectedSlot] else nil
	if selected and selectedSlot then
		local lines = {`<b>{colored("Slot", "#94A3B8")}</b> = {colored(selectedSlot, "#A8DADC")}`}
		local keys = {}
		for key in selected do table.insert(keys, key) end
		table.sort(keys)
		for _, key in keys do
			local value = (selected :: any)[key]
			local color = if typeof(value) == "number" then "#F6C177" else "#A8DADC"
			if key == "UniqueId" then color = "#A6AFBD" end
			table.insert(lines, `<b>{colored(key, "#94A3B8")}</b> = {colored(value, color)}`)
		end
		runtime.Text = table.concat(lines, "\n\n")
		local definition = Definitions[selected.ItemId]
		details.Text = table.concat({
			`<b>{colored("DEFINITION", "#94A3B8")}</b>`,
			`<b>{colored(definition.DisplayName, "#A8DADC")}</b>`,
			colored(definition.Description, "#E6EBEF"),
			"",
			`<b>{colored("Capabilities", "#94A3B8")}</b>`,
			colored(table.concat(definition.Capabilities, ", "), "#F6C177"),
		}, "\n")
		local actionNames = {}
		for _, capability in definition.Capabilities do
			local behavior = Behaviors[capability]
			if behavior and not table.find(actionNames, behavior.Action) then
				table.insert(actionNames, behavior.Action)
			end
		end
		table.insert(actionNames, "Drop")
		for index, actionName in actionNames do
			local actionButton = actionTemplate:Clone()
			actionButton.Name = actionName
			actionButton.Text = actionName
			actionButton.LayoutOrder = index
			actionButton.Visible = true
			actionButton.Parent = actions
			actionButton.Activated:Connect(function()
				Request:FireServer({
					Kind = "Action",
					Slot = selectedSlot,
					UniqueId = selected.UniqueId,
					Action = actionName,
				})
			end)
		end
	else
		runtime.Text = `<b>{colored("Slot", "#94A3B8")}</b> = {colored(selectedSlot or "none", "#A8DADC")}\n\n<i>{colored("Empty", "#A6AFBD")}</i>`
		details.Text = ""
	end
	clearButtons(dropList)
	for index, item in snapshot.Drops do
		local dropButton = dropTemplate:Clone()
		dropButton.Name = item.UniqueId
		dropButton.Text = `{item.ItemId} x{item.Amount}\nPick up`
		dropButton.LayoutOrder = index
		dropButton.Visible = true
		dropButton.Parent = dropList
		dropButton.Activated:Connect(function()
			Request:FireServer({Kind = "Pickup", DropId = item.UniqueId})
		end)
	end
end)

-- Subscribe before requesting the initial state, avoiding a join-time message race.
Request:FireServer({Kind = "Sync"})
