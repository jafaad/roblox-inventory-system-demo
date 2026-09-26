--!strict
local Types = require(script.Parent.Types)

-- Add a definition here; services and UI never branch on ItemId.
local definitions: {[string]: Types.ItemDefinition} = {
	Apple = {
		Id = "Apple",
		DisplayName = "Red Apple",
		Description = "A fresh apple. Restores 4 health.",
		DisplayImage = 0,
		Weight = 0.2,
		Stackable = true,
		MaxStack = 20,
		Capabilities = {"Consumable"},
		Health = 4,
	},
	Spear = {
		Id = "Spear",
		DisplayName = "Spear",
		Description = "A simple weapon that can also be thrown.",
		DisplayImage = 0,
		Weight = 2,
		Stackable = false,
		MaxStack = 1,
		Capabilities = {"Weapon", "Throwable"},
		Damage = 15,
	},
	Rifle = {
		Id = "Rifle",
		DisplayName = "Rifle",
		Description = "A demo rifle with a refillable magazine.",
		DisplayImage = 0,
		Weight = 4,
		Stackable = false,
		MaxStack = 1,
		Capabilities = {"Weapon", "Reloadable", "Scoped"},
		Damage = 25,
		MaxAmmo = 30,
	},
	Hammer = {
		Id = "Hammer",
		DisplayName = "Hammer",
		Description = "Demonstrates the building action.",
		DisplayImage = 0,
		Weight = 1.5,
		Stackable = false,
		MaxStack = 1,
		Capabilities = {"Tool"},
	},
}

return definitions
