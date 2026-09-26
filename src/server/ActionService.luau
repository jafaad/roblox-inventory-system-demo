--!strict
local Shared = game:GetService("ReplicatedStorage").Shared.Inventory
local Types = require(Shared.Types)
local Definitions = require(Shared.Definitions)
local Behaviors = require(Shared.Behaviors)
local InventoryService = require(script.Parent.InventoryService)

type Drop = {Item: Types.ItemInstance, Part: BasePart}
local drops: {[string]: Drop} = {}
local ActionService = {}
local PICKUP_DISTANCE = 18

local worldFolder = Instance.new("Folder")
worldFolder.Name = "InventoryDrops"
worldFolder.Parent = workspace

function ActionService.CreateDrop(item: Types.ItemInstance, position: Vector3)
	local part = Instance.new("Part")
	part.Name = item.ItemId
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(177, 191, 159)
	part.Position = position
	part:SetAttribute("DropId", item.UniqueId)
	part.Parent = worldFolder
	local labelGui = Instance.new("BillboardGui")
	labelGui.Size = UDim2.fromOffset(160, 45)
	labelGui.StudsOffset = Vector3.new(0, 1.5, 0)
	labelGui.AlwaysOnTop = true
	labelGui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(25, 29, 33)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	label.Text = item.ItemId .. " x" .. item.Amount
	label.Parent = labelGui
	drops[item.UniqueId] = {Item = table.clone(item), Part = part}
end

function ActionService.GetDrops(): {Types.ItemInstance}
	local result = {}
	for _, drop in drops do
		if drop.Part:IsDescendantOf(worldFolder) then table.insert(result, table.clone(drop.Item)) end
	end
	table.sort(result, function(a, b)
		if a.ItemId == b.ItemId then return a.UniqueId < b.UniqueId end
		return a.ItemId < b.ItemId
	end)
	return result
end

-- Returns message and whether the world-drop list changed.
function ActionService.Handle(player: Player, request: any): (string?, boolean)
	if typeof(request) ~= "table" or typeof(request.Kind) ~= "string" then
		return "Invalid request", false
	end
	local inventory = InventoryService.GetInventory(player)
	if not inventory then return "Inventory not ready", false end
	if request.Kind == "Sync" then return nil, false end
	if request.Kind == "Select" then
		if not InventoryService.IsValidSlot(request.Slot) then return "Invalid slot", false end
		InventoryService.Select(player, request.Slot)
		return nil, false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return "A living character is required", false
	end
	if request.Kind == "Pickup" then
		if typeof(request.DropId) ~= "string" then return "Invalid drop", false end
		local drop = drops[request.DropId]
		if not drop then return "Dropped item no longer exists", false end
		if not drop.Part:IsDescendantOf(worldFolder) then
			drops[request.DropId] = nil
			return "Dropped item no longer exists", true
		end
		if (root.Position - drop.Part.Position).Magnitude > PICKUP_DISTANCE then
			return "Move within 18 studs to pick up", false
		end
		-- No yields between checking, adding and deleting: two pickups cannot claim the same drop.
		local success, message = InventoryService.AddItem(player, drop.Item)
		if not success then return message, false end
		drops[request.DropId] = nil
		drop.Part:Destroy()
		return "Picked up " .. drop.Item.ItemId .. " x" .. drop.Item.Amount, true
	end
	if not InventoryService.IsValidSlot(request.Slot) or typeof(request.UniqueId) ~= "string" then
		return "Invalid item request", false
	end
	local item = InventoryService.GetItem(player, request.Slot, request.UniqueId)
	if not item then return "Item is no longer in that slot", false end
	if request.Kind == "Move" then
		if not InventoryService.IsValidSlot(request.To) then return "Invalid destination", false end
		local _, message = InventoryService.Move(player, request.Slot, request.To, request.UniqueId)
		return message, false
	end
	if request.Kind ~= "Action" or typeof(request.Action) ~= "string" then return "Invalid action", false end
	if InventoryService.GetSelectedItem(player) ~= item then return "Select this item first", false end
	if request.Action == "Drop" then
		ActionService.CreateDrop(item, root.Position + root.CFrame.LookVector * 5 - Vector3.new(0, 1, 0))
		local message = "Dropped " .. item.ItemId .. " x" .. item.Amount
		InventoryService.RemoveItem(player, request.Slot, item.Amount)
		return message, true
	end
	local definition = Definitions[item.ItemId]
	for _, capability in definition.Capabilities do
		local behavior = Behaviors[capability]
		if behavior and behavior.Action == request.Action then
			local message = behavior.Execute({
				Player = player,
				Item = item,
				Definition = definition,
				Remove = function(amount)
					InventoryService.RemoveItem(player, request.Slot, amount)
				end,
			})
			return message, false
		end
	end
	return "This item does not support " .. request.Action, false
end

return ActionService
