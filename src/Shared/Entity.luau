local Entity = {}

local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)
local Snapshot = require(script.Parent.Snapshots)
local InterpolationMath = require(script.Parent.InterpolationMath)
local VelocityAt = InterpolationMath.VelocityAt

local IS_SERVER = RunService:IsServer()

function Entity.new(entityConfig: string, model: Model?): Types.Entity
	local config = Config._GetEntityType(entityConfig)
	if model and not model.PrimaryPart then
		error(`{model:GetFullName()} must have a PrimaryPart set to be used as an Entity model.`)
    elseif model and not model.Archivable then
        warn(`{model:GetFullName()} is not Archivable. It is recommended to set Archivable to true for entity models to prevent potential issues when cloning.`)
        model.Archivable = true
	end
	local self = {
		id = -1,
    
		autoUpdatePos = config.AUTO_UPDATE_POS ~= false,
		isNetworkOwner = false,
        networkOwner =  false::any,

		entityConfig = config,
		model = model,
        destroyed = false,
	}
    if IS_SERVER then
        Entity.SetNetworkOwner(self,nil)
    end
	return self
end

function Entity.SetNetworkOwner(self: Types.Entity, player: Player?)
	if IS_SERVER and player ~= self.networkOwner then
		self.networkOwner = player
		self.isNetworkOwner = player == nil
        if self.isNetworkOwner and not self.entityConfig.STORE_SNAPSHOTS then
            self.snapshot = nil
        else
            self.snapshot = Snapshot(InterpolationMath.Hermite)
        end
	elseif not IS_SERVER then
		warn("setNetworkOwner can only be called on the server")
	end
end


function Entity.Push(self: Types.Entity, time: number, value: CFrame)
    local snapshot = self.snapshot
    if snapshot then
        self.latestCFrame = value
        snapshot:Push(time, value, VelocityAt(snapshot:GetLatest(), time,value))
    else
        self.latestCFrame = value
    end
end

function Entity.GetAt(self: Types.Entity, time: number): CFrame?
    local snapshot = self.snapshot
    if snapshot then
        return snapshot:GetAt(time)
    else
        return self.latestCFrame
    end
end
return Entity
