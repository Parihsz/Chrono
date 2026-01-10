--!native
local Players = game:GetService("Players")

local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent.Shared

local Bin = require(Shared.Bin)
local Holder = require(Shared.Holder)
local Events = require(Shared.Events)
local Ticker = require(Shared.Ticker)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Entity = require(Shared.Entity)
local EntityGrid = require(script.Parent.EntityGrid)
local _Player = require(script.Parent.Player)
local Sender = require(script.Parent.Sender)
local _Receiver = require(script.Parent.Receiver)

local tickers: { Types.Ticker } = {}

Config._WaitForLock(function()
	for _, entityConfig in Config._EntityConfigs do
		if entityConfig.TICKER then
			table.insert(tickers, entityConfig.TICKER)
		else
			warn(entityConfig, "TICKERS not found on server config load")
		end
	end
end)

local function FireEvent(entity: Types.Entity, eventName: string, ...: any)
	local events = entity._events
	if not events then
		return
	end
	local signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

local FULL_BYTES = 4 * 3 + 2 * 3 + 2
local YAW_BYTES = 4 * 3 + 2 + 2

local TAU = math.pi * 2

local function MapRotation(x: number): number
	return math.round((x + math.pi) / (TAU / 65535))
end

local function SerializeFull(b: buffer, cf: CFrame, index: number)
	local x, y, z = cf.X, cf.Y, cf.Z
	local rx, ry, rz = cf:ToOrientation()
	buffer.writef32(b, index, x)
	index += 4
	buffer.writef32(b, index, y)
	index += 4
	buffer.writef32(b, index, z)
	index += 4
	buffer.writeu16(b, index, MapRotation(rx))
	index += 2
	buffer.writeu16(b, index, MapRotation(ry))
	index += 2
	buffer.writeu16(b, index, MapRotation(rz))
	index += 2
	return index
end

local function SerializeYaw(b: buffer, cf: CFrame, index: number)
	local x, y, z = cf.X, cf.Y, cf.Z
	local _, ry, _ = cf:ToOrientation()
	buffer.writef32(b, index, x)
	index += 4
	buffer.writef32(b, index, y)
	index += 4
	buffer.writef32(b, index, z)
	index += 4
	buffer.writeu16(b, index, MapRotation(ry))
	index += 2
	return index
end

local function CFrameChanged(cframe1: CFrame?, cframe2: CFrame?): boolean
	if cframe1 == cframe2 then
		return false
	end
	if cframe1 == nil or cframe2 == nil then
		return true
	end
	return cframe1:FuzzyEq(cframe2, 0.0001) == false
end

local function PushLatest(entity: Types.Entity, time: number)
	if entity.autoUpdatePosition and entity.isContextOwner and entity.model then
		local primaryPart = Entity.GetPrimaryPart(entity)
		if not primaryPart then
			warn("Entity", entity, "has no primary part")
			return
		end
		local cframe = primaryPart.CFrame
		Entity.Push(entity, time, cframe)
	end
end

local function CheckForChanges(entity: Types.Entity): CFrame?
	local lastCFrame = entity.lastCheckedCFrame
	local currentCFrame = entity.latestCFrame

	if CFrameChanged(lastCFrame, currentCFrame) then
		entity.lastCheckedCFrame = currentCFrame
		return currentCFrame
	end
	return nil
end

local function CheckEntity(entity: Types.Entity, ticker: Types.Ticker, useFull: boolean, isHalfTick: boolean)
	if not entity.isContextOwner then
		return
	end

	local entityIsHalf = entity.isHalfTicked
	if (entityIsHalf and not isHalfTick) or entity.paused then
		entity.cframeBuffer = nil
		return
	end
	if entityIsHalf then
		FireEvent(entity, "Ticked", ticker.halfdt)
	else
		FireEvent(entity, "Ticked", ticker.dt)
	end

	PushLatest(entity, ticker.lastTicked)
	local changes = CheckForChanges(entity)

	if changes then
		if entity.id == 0 then
			error("Entity Should not have and id of 0")
		end
		if useFull then
			local b = buffer.create(FULL_BYTES)
			buffer.writeu16(b, 0, entity.id)
			SerializeFull(b, changes, 2)
			entity.cframeBuffer = b
		else
			local b = buffer.create(YAW_BYTES)
			buffer.writeu16(b, 0, entity.id)
			SerializeYaw(b, changes, 2)
			entity.cframeBuffer = b
		end
	else
		entity.cframeBuffer = nil
	end
end

local Changes: { Types.Entity } = {}

--In the future we can optimize this so it uses buffers if really needed
local function CheckEntityChanges()
	for entity, changes in Entity._Changes do
		local newChanges = { id = entity.id, data = {} }

		for key, data in changes do
			data = data or entity[key]
			table.insert(newChanges.data, { key, data })
		end
		Entity._Changes[entity] = nil
		entity._changes = newChanges
		table.insert(Changes, entity)
	end
end

local function UpdateTickers()
	debug.profilebegin("UpdateTickers")
	for _, ticker in tickers do
		if not next(ticker.objects) then
			continue
		end
		debug.profilebegin(`{ticker.config.NAME}`)
		if Ticker.CheckUpdate(ticker) then
			--[[ Using the ticker's config instead can help protect if entity configs change mid-game since that
                could potentially create a desync between the buffer serialization and deserialization    
            ]]
			--// thought idk if we want to allow that (better to be safe ig for now)
			local useFull = ticker.config.FULL_ROTATION == true
			local isHalfTick = ticker.tickedHalf
			for _, object in ticker.objects do
				CheckEntity(object, ticker, useFull, isHalfTick)
			end
		end
		debug.profileend()
	end
	debug.profileend()
end

local function UpdatePlayerPositions()
	for _, entity: any in Holder._playerChars do
		local player = entity.networkOwner
		local character = entity.model

		if player and character then
			EntityGrid.UpdatePlayerPosition(player, character:GetPivot().Position)
		end
	end
end

local function Update()
	EntityGrid.Update()
	UpdatePlayerPositions()
	UpdateTickers()
	CheckEntityChanges()
	for _, player in Players:GetPlayers() do
		Sender.ReplicatePlayer(player)
	end
	for _, entity in Changes do
		entity._changes = nil
	end
	table.clear(Changes)
end

local function HandleEntity(plr, entity: Types.Entity)
	local add, clear = Bin()
	local function HandleModel(entity: Types.Entity)
		print(entity.model)
		if not entity.model then
			return
		end
		local primaryPart = Entity.GetPrimaryPart(entity)
		if not primaryPart then
			return
		end
		local partToUse = primaryPart
		local function CFrameChanged()
			local cframe = partToUse.CFrame
			if cframe == entity.latestCFrame then
				return
			end
			Entity.SetCFrame(entity, cframe)
		end

		if entity._lockedCFReplication then
			local locker = primaryPart:FindFirstChild("__CHRONO_LOCKER")

			if not locker then
				return
			end
			local lockerPart = locker:FindFirstChild("__CHRONO_LOCKER_PART") :: BasePart?
			if not lockerPart or not lockerPart:IsA("BasePart") then
				return
			end
			partToUse = lockerPart
			add(lockerPart:GetPropertyChangedSignal("CFrame"):Connect(CFrameChanged))
		else
			add(primaryPart:GetPropertyChangedSignal("CFrame"):Connect(CFrameChanged))
		end
	end
	local add2, clear2 = Bin()
	add2(Entity.GetEvent(entity, "ModelChanged"):Connect(function()
		clear()
		HandleModel(entity)
	end))
	add2(Entity.GetEvent(entity, "LockChanged"):Connect(function()
		clear()
		HandleModel(entity)
	end))

	Entity.GetEvent(entity, "NetworkOwnerChanged"):Once(function()
		clear()
		clear2()
	end)

	HandleModel(entity)
end

local function HandleCFrameSetters()
	local mode: "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS" = Config._GetConfig("REPLICATE_CFRAME_SETTERS")
	if mode == "NONE" then
		return
	end
	if mode == "PLAYER_ENTITIES" then
		Events.PlayerOwnedAdded:Connect(HandleEntity, true)
	else
		Events.PlayerCharacterRegistered:Connect(HandleEntity, true)
	end
end

Config._WaitForLock(function()
	RunService.PreSimulation:Connect(Update)
	HandleCFrameSetters()
end)

return nil
