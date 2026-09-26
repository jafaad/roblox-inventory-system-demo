--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared.Inventory
local Types = require(Shared.Types)
local Definitions = require(Shared.Definitions)

type ItemInstance = Types.ItemInstance
type Inventory = Types.Inventory

local inventories: {[Player]: Inventory} = {}
local InventoryService = {}
local slotOrder: {string} = {}
for index = 1, Types.HotbarSize do table.insert(slotOrder, "H" .. index) end
for index = 1, Types.BackpackSize do table.insert(slotOrder, "B" .. index) end

function InventoryService.IsValidSlot(slot: any): boolean
	return typeof(slot) == "string" and table.find(slotOrder, slot) ~= nil
end

function InventoryService.Create(player: Player)
	inventories[player] = {Slots = {}, SelectedSlot = nil}
end

function InventoryService.RemovePlayer(player: Player)
	inventories[player] = nil
end

function InventoryService.GetInventory(player: Player): Inventory?
	return inventories[player]
end

function InventoryService.NewItem(itemId: string, amount: number): ItemInstance
	local definition = assert(Definitions[itemId], "Unknown item: " .. itemId)
	assert(amount > 0 and amount % 1 == 0, "Amount must be a positive integer")
	return {
		UniqueId = HttpService:GenerateGUID(false),
		ItemId = itemId,
		Amount = amount,
		Ammo = definition.MaxAmmo,
	}
end

-- The incoming item is server-created. Check capacity first so pickup is all-or-nothing.
function InventoryService.AddItem(player: Player, item: ItemInstance): (boolean, string)
	local inventory = inventories[player]
	local definition = Definitions[item.ItemId]
	if not inventory or not definition then return false, "Unknown inventory or item" end
	local maxStack = if definition.Stackable then definition.MaxStack else 1
	local capacity = 0
	for _, slot in slotOrder do
		local current = inventory.Slots[slot]
		if not current then
			capacity += maxStack
		elseif definition.Stackable and current.ItemId == item.ItemId and current.Ammo == item.Ammo then
			capacity += maxStack - current.Amount
		end
	end
	if capacity < item.Amount then return false, "Inventory full" end

	local remaining = item.Amount
	if definition.Stackable then
		for _, slot in slotOrder do
			local current = inventory.Slots[slot]
			if current and current.ItemId == item.ItemId and current.Ammo == item.Ammo then
				local added = math.min(remaining, maxStack - current.Amount)
				current.Amount += added
				remaining -= added
				if remaining == 0 then return true, "Added item" end
			end
		end
	end
	local usedOriginalId = false
	for _, slot in slotOrder do
		if not inventory.Slots[slot] then
			local copy = table.clone(item)
			copy.Amount = math.min(remaining, maxStack)
			if usedOriginalId then copy.UniqueId = HttpService:GenerateGUID(false) end
			usedOriginalId = true
			inventory.Slots[slot] = copy
			remaining -= copy.Amount
			if remaining == 0 then break end
		end
	end
	return true, "Added item"
end

function InventoryService.GetItem(player: Player, slot: string, uniqueId: string): ItemInstance?
	local inventory = inventories[player]
	if not inventory or not InventoryService.IsValidSlot(slot) then return nil end
	local item = inventory.Slots[slot]
	return if item and item.UniqueId == uniqueId then item else nil
end

function InventoryService.RemoveItem(player: Player, slot: string, amount: number): boolean
	local inventory = inventories[player]
	local item = if inventory then inventory.Slots[slot] else nil
	if not inventory or not item or amount <= 0 or amount % 1 ~= 0 or amount > item.Amount then
		return false
	end
	item.Amount -= amount
	if item.Amount == 0 then inventory.Slots[slot] = nil end
	return true
end

function InventoryService.Select(player: Player, slot: string): boolean
	local inventory = inventories[player]
	if not inventory or not InventoryService.IsValidSlot(slot) then return false end
	inventory.SelectedSlot = slot
	return true
end

function InventoryService.GetSelectedItem(player: Player): ItemInstance?
	local inventory = inventories[player]
	if not inventory or not inventory.SelectedSlot then return nil end
	return inventory.Slots[inventory.SelectedSlot]
end

function InventoryService.Move(player: Player, from: string, to: string, uniqueId: string): (boolean, string)
	local inventory = inventories[player]
	local source = InventoryService.GetItem(player, from, uniqueId)
	if not inventory or not source or not InventoryService.IsValidSlot(to) then
		return false, "Invalid move or stale item"
	end
	if from == to then return false, "Choose a different slot" end
	local target = inventory.Slots[to]
	local definition = Definitions[source.ItemId]
	if target and target.ItemId == source.ItemId and definition.Stackable and target.Ammo == source.Ammo then
		local moved = math.min(source.Amount, definition.MaxStack - target.Amount)
		if moved == 0 then return false, "Destination stack is full" end
		target.Amount += moved
		InventoryService.RemoveItem(player, from, moved)
	else
		inventory.Slots[from], inventory.Slots[to] = target, source
	end
	inventory.SelectedSlot = to
	return true, "Moved " .. source.ItemId .. " to " .. to
end

return InventoryService
