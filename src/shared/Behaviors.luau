--!strict
local Types = require(script.Parent.Types)

-- This small registry keeps six short behaviors together.
-- Clients read Action names; only ActionService executes these with server-owned state.
local behaviors: {[string]: Types.Behavior} = {
	Consumable = {
		Action = "Consume",
		Execute = function(context)
			local character = context.Player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not humanoid or humanoid.Health <= 0 then
				return "Cannot consume without a living character"
			end
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (context.Definition.Health or 0))
			context.Remove(1)
			return "Consumed " .. context.Item.ItemId
		end,
	},
	Weapon = {
		Action = "Fire",
		Execute = function(context)
			local ammo = context.Item.Ammo
			if ammo ~= nil then
				if ammo <= 0 then
					return "Magazine empty; reload first"
				end
				context.Item.Ammo = ammo - 1
			end
			return context.Item.ItemId .. " fired (demo)"
		end,
	},
	Reloadable = {
		Action = "Reload",
		Execute = function(context)
			local maxAmmo = context.Definition.MaxAmmo
			if not maxAmmo then
				return "This item has no magazine"
			end
			context.Item.Ammo = maxAmmo
			return context.Item.ItemId .. " reloaded"
		end,
	},
	Scoped = {
		Action = "Scope",
		Execute = function(_context)
			return "Scope activated (demo)"
		end,
	},
	Throwable = {
		Action = "Throw",
		Execute = function(context)
			context.Remove(1)
			return "Threw " .. context.Item.ItemId .. " (demo)"
		end,
	},
	Tool = {
		Action = "Build",
		Execute = function(_context)
			return "Entered building mode (demo)"
		end,
	},
}

return behaviors
