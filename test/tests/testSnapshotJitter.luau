local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)
local Events = require(Chrono.Shared.Events)

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()
task.wait(1)

local TELEPORT_DIST = 15
local STALE_OFFSET = 0.05
local MOVE_SPEED = 8
local TELEPORT_INTERVAL = 3

local function addLabel(part: BasePart, text: string, color: Color3)
	local bg = Instance.new("BillboardGui", part)
	bg.Size = UDim2.fromOffset(120, 30)
	bg.StudsOffset = Vector3.new(0, 3, 0)
	bg.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", bg)
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = text
end

return {
	init = function()
		char.Archivable = true
		local c = char:Clone()
		c.Name = "JitterTestChar"
		c.PrimaryPart.Anchored = true
		Config.RegisterEntityModel("JitterTestChar", c)
	end,

	server = function()
		local jittery = Entity.new(nil, "JitterTestChar", "NATIVE")
		Entity.SetData(jittery, "jitterTest_jittery")
		local partJ = Entity.GetPrimaryPart(jittery)
		if partJ then
			partJ.Color = Color3.fromRGB(220, 80, 80)
			addLabel(partJ, "Jittery (no fix)", Color3.fromRGB(255, 100, 100))
		end

		local fixed = Entity.new(nil, "JitterTestChar", "NATIVE")
		Entity.SetData(fixed, "jitterTest_fixed")
		local partF = Entity.GetPrimaryPart(fixed)
		if partF then
			partF.Color = Color3.fromRGB(80, 200, 80)
			addLabel(partF, "Fixed (lockedTime)", Color3.fromRGB(100, 255, 100))
		end

		local originJ = CFrame.new(-3, 5, 0)
		local originF = CFrame.new(3, 5, 0)
		Entity.SetCFrame(jittery, originJ)
		Entity.SetCFrame(fixed, originF)

		task.spawn(function()
			while true do
				local dt = task.wait()
				if partJ and partJ.Parent then
					partJ.CFrame *= CFrame.new(0, 0, -MOVE_SPEED * dt)
				end
				if partF and partF.Parent then
					partF.CFrame *= CFrame.new(0, 0, -MOVE_SPEED * dt)
				end
			end
		end)

		task.spawn(function()
			while true do
				task.wait(TELEPORT_INTERVAL)
				Entity.SetCFrame(jittery, originJ)
				Entity.SetCFrame(fixed, originF)
			end
		end)
	end,

	client = function()
		local function hookEntity(entity, isFixed: boolean)
			local snapshot = entity.snapshot
			if not snapshot then
				return
			end

			local prevCFrame: CFrame? = nil

			Entity.GetEvent(entity, "PushedSnapShot")
				:Connect(function(_, time: number, value: CFrame, isNewest: boolean)
					if not isNewest then
						return
					end

					local prev = prevCFrame
					prevCFrame = value

					if not prev then
						return
					end

					if (value.Position - prev.Position).Magnitude < TELEPORT_DIST then
						return
					end

					task.defer(function()
						snapshot:Push(time - STALE_OFFSET, prev, Vector3.zero)

						if isFixed then
							snapshot.lockedTime = time
						end
					end)
				end)
		end

		local hooked = 0
		local conn
		conn = Events.EntityAdded:Connect(function(entity)
			local data = Entity.GetData(entity)
			if data == "jitterTest_jittery" then
				hookEntity(entity, false)
				hooked += 1
			elseif data == "jitterTest_fixed" then
				hookEntity(entity, true)
				hooked += 1
			end
			if hooked >= 2 then
				conn:Disconnect()
			end
		end)

		for _, entity in Holder.idMap do
			local data = Entity.GetData(entity)
			if data == "jitterTest_jittery" then
				hookEntity(entity, false)
			elseif data == "jitterTest_fixed" then
				hookEntity(entity, true)
			end
		end
	end,
}
