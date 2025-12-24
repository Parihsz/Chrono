local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Packages.chrono.Shared.Config)
local Iris = require(ReplicatedStorage.DevPackages.iris)
local Replication = require(ReplicatedStorage.Packages.chrono.Client.Replicate)

local GetAllNetworkIds = Replication.GetAllNetworkIds
local BufferTracker = Replication.BufferTracker

local playerTickRates = Replication.playerTickRates
local idMap = Replication.idMap

local searchText = Iris.State("") :: typeof(Iris.State(""))
local networkIds = GetAllNetworkIds()

Iris.Init()

Iris:Connect(function()
	if Iris.Window({ "Replication Debug" }) then
		if Iris.Button({ "🔄 Refresh" }).clicked then
			networkIds = GetAllNetworkIds()
		end

		Iris.InputText({ "Search ID" }, { text = searchText })
		Iris.Separator()

		for _, id in networkIds do
			if not tostring(id):find(searchText:get()) then
				continue
			end

			if Iris.Tree({ `Player ID: {id}` }).state.isUncollapsed.value then
				local tickRate = playerTickRates[id] or Config.TICK_RATE
				local bufferTime = BufferTracker.GetBuffer(id, tickRate)
				local latencyInfo = BufferTracker.PlayerLatencies[id]

				Iris.Separator()

				if latencyInfo then
					local latencyLabel = if latencyInfo.averageLatency > 0.2 then "🔴" else "🟢"
					local deviationLabel = if latencyInfo.deviation > 0.05 then "🔴" else "🟢"

					Iris.Text({ `{latencyLabel} Client1 -> Server -> Client2 Latency: {latencyInfo.averageLatency}` })
					Iris.Text({ `{deviationLabel} Deviation: {latencyInfo.deviation}` })
					Iris.Text({ `Buffer Time: {bufferTime}` })
					Iris.Text({ `Tick Rate: {tickRate}` })
				else
					Iris.Text({ "No latency/deviation data, please investigate!" })
				end

				Iris.Separator()
				Iris.Text({ "📦 Snapshot Cache:" })

				for i, snapshot in idMap[id].snapshot.cache do
					local snapshotText = Iris.State("")

					Iris.Text({ snapshotText:get() })

					task.defer(function()
						local position = if snapshot.value
							then `({snapshot.value.Position.X}, {snapshot.value.Position.Y}, {snapshot.value.Position.Z})`
							else "❌ nil"
						snapshotText:set(`{i}: {snapshot.t} - Position {position}`)
					end)
				end
			end

			Iris.End()
		end

		Iris.End()
	end
end)
