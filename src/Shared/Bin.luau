type BinItem = Instance | RBXScriptConnection | thread | () -> ...any | { _binCleanup: (...any) -> () }

export type Add = <T>(Item: T & BinItem) -> T
export type Clear = () -> ()

return function(): (Add, Clear)
	local Bin: { BinItem } = {}

	return function<T>(Item: T & BinItem)
		table.insert(Bin, Item :: any)

		return Item
	end :: any,
		function()
			for _, Item in Bin do
				if typeof(Item) == "Instance" then
					Item:Destroy()
				elseif typeof(Item) == "RBXScriptConnection" then
					Item:Disconnect()
				elseif typeof(Item) == "function" then
					task.spawn(Item)
				elseif typeof(Item) == "thread" then
					pcall(task.cancel, Item) -- must pcall or could error when passing its own thread in
				elseif typeof(Item) == "table" and Item._binCleanup and type(Item._binCleanup) == "function" then
					Item:_binCleanup()
				end
			end

			table.clear(Bin)
		end
end
