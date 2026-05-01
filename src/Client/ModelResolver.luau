local CollectionService = game:GetService("CollectionService")

local Warn = require(script.Parent.Parent.Shared.Warn)
local Config = require(script.Parent.Parent.Shared.Config)
local Types = require(script.Parent.Parent.Shared.Types)
local Entity = require(script.Parent.Parent.Shared.Entity)
local ModelHelper = require(script.Parent.Parent.Shared.ModelHelper)
local TAG = ModelHelper.TAG
local CHRONO_META_NAME = ModelHelper.CHRONO_META_NAME

local RegisteredModels = {}

local function OnInstanceAdded(instance: Instance)
	local metaStringValue: string? = instance:GetAttribute(CHRONO_META_NAME) :: any
	if metaStringValue then
		RegisteredModels[metaStringValue] = instance :: any
		Warn.low(
			`Model with meta {metaStringValue} was added to the game. Entities using this model will now be able to resolve it.`
		)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(OnInstanceAdded)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	local attribute: string? = instance:GetAttribute(CHRONO_META_NAME) :: any
	if attribute then
		RegisteredModels[attribute] = nil
		Warn.low(
			`Model with meta {attribute} was removed from the game. Entities using this model will no longer be able to resolve it.`
		)
	end
end)
for _, instance in CollectionService:GetTagged(TAG) do
	OnInstanceAdded(instance)
end

return function(entity: Types.Entity)
	local model = entity.model
	if model and model.Parent then
		return
	end
	local metaData = entity._modelMetaData

	if not metaData then
		return
	end
	local registered = RegisteredModels[metaData] :: Model | BasePart?
	if registered and registered ~= model then
		Entity.SetModel(entity, registered)
		Warn.low(`Model with meta {metaData} was resolved for entity {entity.id}.`)
	end
end
