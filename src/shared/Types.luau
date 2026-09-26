--!strict
export type ItemDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	DisplayImage: number?,
	Weight: number,
	Stackable: boolean,
	MaxStack: number,
	Capabilities: {string},
	Health: number?,
	Damage: number?,
	MaxAmmo: number?,
}

export type ItemInstance = {
	UniqueId: string,
	ItemId: string,
	Amount: number,
	Ammo: number?,
}

export type Inventory = {
	-- String slot keys keep empty slots and snapshots safe to serialize.
	Slots: {[string]: ItemInstance},
	SelectedSlot: string?,
}

export type BehaviorContext = {
	Player: Player,
	Item: ItemInstance,
	Definition: ItemDefinition,
	Remove: (amount: number) -> (),
}

export type Behavior = {
	Action: string,
	Execute: (context: BehaviorContext) -> string,
}

return {
	HotbarSize = 5,
	BackpackSize = 10,
}
