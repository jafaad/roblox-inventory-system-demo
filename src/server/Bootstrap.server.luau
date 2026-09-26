--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared.Inventory
local InventoryService = require(script.Parent.InventoryService)
local ActionService = require(script.Parent.ActionService)
local Request = Shared.Request
local State = Shared.State
local lastRequest: {[Player]: number} = {}

local function sendState(player: Player, message: string?)
	local inventory = InventoryService.GetInventory(player)
	if inventory then
		State:FireClient(player, {
			Inventory = inventory,
			Drops = ActionService.GetDrops(),
			Message = message,
		})
	end
end

local function addPlayer(player: Player)
	InventoryService.Create(player)
	InventoryService.AddItem(player, InventoryService.NewItem("Apple", 5))
	for _, itemId in {"Spear", "Rifle", "Hammer"} do
		InventoryService.AddItem(player, InventoryService.NewItem(itemId, 1))
	end
	InventoryService.Select(player, "H1")
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
	InventoryService.RemovePlayer(player)
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
local origin = if spawn then spawn.Position + Vector3.new(0, 3, 0) else Vector3.new(0, 4, 0)
ActionService.CreateDrop(InventoryService.NewItem("Apple", 3), origin + Vector3.new(-5, 0, -7))
ActionService.CreateDrop(InventoryService.NewItem("Spear", 1), origin + Vector3.new(0, 0, -9))
ActionService.CreateDrop(InventoryService.NewItem("Rifle", 1), origin + Vector3.new(5, 0, -7))

Request.OnServerEvent:Connect(function(player: Player, request: any)
	-- Small flood guard; gameplay-specific cooldowns can be added when real combat exists.
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.08 then return end
	lastRequest[player] = now
	local message, dropsChanged = ActionService.Handle(player, request)
	sendState(player, message)
	if dropsChanged then
		for _, other in Players:GetPlayers() do
			if other ~= player then sendState(other, nil) end
		end
	end
end)
