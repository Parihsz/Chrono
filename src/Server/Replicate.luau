--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent.Shared

local Ticker = require(Shared.Ticker)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Snapshots = require(Shared.Snapshots)
local InterpolationMath = require(Shared.InterpolationMath)
local Entity = require(Shared.Entity)
local Sender = require(script.Parent.Sender)
-- local Receiver = require(script.Parent.Receiver)

local tickers: { Types.Ticker } = {}

Config._WaitForLock(function()  
    for _, entityConfig in Config._EntityConfigs do
        if entityConfig._TICKERS then
            table.insert(tickers, entityConfig._TICKERS.NORMAL)
            table.insert(tickers, entityConfig._TICKERS.HALF)
        else
            warn(entityConfig,"_TICKERS not found on server config load")
        end
    end
end)

local FULL_BYTES = 4*3 + 2*3 + 2
local YAW_BYTES = 4*3 + 2 + 2
local function MapRotation(x:number):number
    return math.round((x + math.pi) / (2 * math.pi / 65535))
end

local function SerializeFull(b:buffer,cf:CFrame,index:number)
    local x,y,z = cf.X,cf.Y,cf.Z
    local rx,ry,rz = cf:ToOrientation()
    buffer.writef32 (b,index,x); index+=4
    buffer.writef32 (b,index,y); index+=4
    buffer.writef32 (b,index,z); index+=4
    buffer.writeu16 (b,index,MapRotation(rx)); index+=2
    buffer.writeu16 (b,index,MapRotation(ry)); index+=2
    buffer.writeu16 (b,index,MapRotation(rz)); index+=2
    return index
end

local function SerializeYaw(b:buffer,cf:CFrame,index:number)
    local x,y,z = cf.X,cf.Y,cf.Z
    local _,ry,_ = cf:ToOrientation()
    buffer.writef32 (b,index,x); index+=4
    buffer.writef32 (b,index,y); index+=4
    buffer.writef32 (b,index,z); index+=4
    buffer.writeu16 (b,index,MapRotation(ry)); index+=2
    return index
end

local function CFrameChanged(cf1: CFrame?, cf2: CFrame?): boolean
   if cf1 == cf2 then
       return false
   end 
    if cf1 == nil or cf2 == nil then
         return true
    end
    return cf1:FuzzyEq(cf2, 0.0001) == false
end

local function PushLatest(entity: Types.Entity)
	if entity.autoUpdatePos and entity.isNetworkOwner and entity.model then
		local primaryPart = entity.model.PrimaryPart
		if not primaryPart then
			return
		end
		local cf = primaryPart.CFrame
		Entity.Push(entity, os.clock(), cf)
	end
end

local function CheckForChanges(entity: Types.Entity):CFrame?
    local lastCFrame = entity.lastCheckedCFrame
    local currentCFrame = entity.latestCFrame
    entity.lastCheckedCFrame = currentCFrame
    if CFrameChanged(lastCFrame, currentCFrame) then
        return currentCFrame
    end
    return nil
end

local function UpdateTickers()
	for _, ticker in tickers do
        if not next(ticker.objects) then
            continue
        end
		if Ticker.checkUpdate(ticker) then
            --[[ Using the ticker's config instead can help protect if entity configs change mid-game since that
                could potentially create a desync between the buffer serialization and deserialization    
            ]]
            --// thought idk if we want to allow that (better to be safe ig for now)
            local useFull = ticker.config.FULL_ROTATION == true
			for object, _ in ticker.objects do
                PushLatest(object)
                local changes = CheckForChanges(object)
                if changes then
                    if useFull then
                        local b = buffer.create(FULL_BYTES)
                        buffer.writeu16(b,0,object.id)
                        SerializeFull(b, changes, 2)
                        object.cframeBuffer = b
                    else
                        local b = buffer.create(YAW_BYTES)
                        buffer.writeu16(b,0,object.id)
                        SerializeYaw(b, changes, 2)
                        object.cframeBuffer = b
                    end
                else
                    object.cframeBuffer = nil
                end
			end
		end
	end
end

return {
    UpdateTickers = UpdateTickers,
}
