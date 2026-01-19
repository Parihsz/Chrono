local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chrono = ReplicatedStorage.Packages.chrono
local Shared = Chrono.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)
local Iris = require(ReplicatedStorage.DevPackages.iris)

local ClientStats = Stats.CLIENT

Iris.Init()

Iris:Connect(function()
	if Iris.Window({ "Replication Debug" }) then
		if Iris.Tree({ "Client Network Stats" }).state.isUncollapsed.value then
			Iris.Text({
				"Received (Non-Compressed): " .. tostring(ClientStats.BYTES_RECEIVED_PER_SEC / 1000) .. " KB/s",
			})
			Iris.Text({ "Entities Added: " .. tostring(ClientStats.NEW_ENTITIES_PER_SEC) .. "/s" })
			Iris.Text({ "Entity Changes: " .. tostring(ClientStats.ENTITY_CHANGES_PER_SEC) .. "/s" })
			Iris.Text({ "Entity Removals: " .. tostring(ClientStats.ENTITY_REMOVALS_PER_SEC) .. "/s" })
		end
		Iris.End()
		if Iris.Tree({ "Client Render Stats" }).state.isUncollapsed.value then
			Iris.Text({ "Avg Interpolation Time (ms): " .. tostring(ClientStats.AVG_INTERPOLATION_TIME_MS) })
			Iris.Text({ "Total Entities Culled: " .. tostring(ClientStats.TOTAL_ENTITIES_CULLED) })
			Iris.Text({ "Entities Moved This Frame: " .. tostring(ClientStats.ENTITIES_MOVED_THIS_FRAME) })
			Iris.Text({
				"Total Client Entities Checked This Frame: "
					.. tostring(ClientStats.TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME),
			})
			Iris.Text({ "Total Client Entities: " .. tostring(ClientStats.TOTAL_CLIENT_ENTITIES) })
		end
		Iris.End()
		if Iris.Tree({ "Server Stats" }).state.isUncollapsed.value then
			Iris.Text({ "Avg Ticker Time Per Frame (ms): " .. tostring(Stats.SERVER.AVG_TICKER_TIME_MS) })
			Iris.Text({ "Entity Grid Total Update Time (ms): " .. tostring(Stats.SERVER.ENTITY_GRID_UPDATE_TIME_MS) })
			Iris.Text({ "Entity Grid Section Time (ms): " .. tostring(Stats.SERVER.ENTITY_GRID_UPDATE_TIME_MS/Stats.SERVER.GRID_UPDATE_SECTIONS) })
			Iris.Text({ "Grid Update Sections: " .. tostring(Stats.SERVER.GRID_UPDATE_SECTIONS) })
			Iris.Text({ "Number of Entities: " .. tostring(Stats.SERVER.NUMBER_OF_ENTITIES) })
			Iris.Text({ "Entities Non-Ticked: " .. tostring(Stats.SERVER.NON_TICKED) })
			Iris.Text({ "Entities Full-Ticked: " .. tostring(Stats.SERVER.ENTITIES_FULL_TICKED) }) 
			Iris.Text({ "Entities Half-Ticked: " .. tostring(Stats.SERVER.ENTITIES_HALF_TICKED) })
			Iris.Text({
				"Bytes Received (Non-Compressed): " .. tostring(Stats.SERVER.BYTES_RECEIVED_PER_SEC / 1000) .. " KB/s",
			})
			Iris.Text({ "Bytes Sent (Non-Compressed): " .. tostring(Stats.SERVER.BYTES_SENT_PER_SEC / 1000) .. " KB/s" })
			Iris.Text({ "Packets Sent: " .. tostring(Stats.SERVER.PACKETS_SENT_PER_SEC) .. "/s" })
			Iris.Text({ "Replicate Player Time (ms): " .. tostring(Stats.SERVER.REPLICATE_PLAYER_TIME_MS) })
		end
		Iris.End()
		Iris.End()
	end
end)
