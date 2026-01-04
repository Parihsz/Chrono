local Types = require(script.Parent.Types)

local currentId = 0 -- First Id will start at 1
local idStack = {}
local idMap:{[number]:Types.Entity} = {} 

local MAX_ID = 2 ^ 16 - 1


local function GetNextId(): number
    local reusedId = table.remove(idStack)
    if reusedId then
        return reusedId
    else
        if currentId >= MAX_ID then
            error("Max ID reached, please investigate.")
        end
        currentId += 1
        return currentId
    end
end

local RandomOffset = Random.new()
local function ReleaseId(id: number)
    -- Delay the reuse of the id to avoid immediate collisions
    task.delay(RandomOffset:NextNumber(5, 10), table.insert, idStack, id)
end



return {
    idMap = idMap,
}