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
			Iris.Text({ "Received (Non-Compressed): " .. tostring(ClientStats.BYTES_RECEIVED_PER_SEC/1000)..' KB/s' })
            Iris.Text({ "Entities Added: " .. tostring(ClientStats.NEW_ENTITIES_PER_SEC)..'/s' })
            Iris.Text({ "Entity Changes: " .. tostring(ClientStats.ENTITY_CHANGES_PER_SEC)..'/s' })
            Iris.Text({ "Entity Removals: " .. tostring(ClientStats.ENTITY_REMOVALS_PER_SEC)..'/s' })
		end
		Iris.End()
		if Iris.Tree({ "Client Render Stats" }).state.isUncollapsed.value then
            Iris.Text({ "Avg Interpolation Time (ms): " .. tostring(ClientStats.AVG_INTERPOLATION_TIME_MS) })
			Iris.Text({ "Total Entities Culled: " .. tostring(ClientStats.TOTAL_ENTITIES_CULLED) })
            Iris.Text({ "Entities Moved This Frame: " .. tostring(ClientStats.ENTITIES_MOVED_THIS_FRAME) })
            Iris.Text({ "Total Client Entities Checked This Frame: " .. tostring(ClientStats.TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME) })
            Iris.Text({ "Total Client Entities: " .. tostring(ClientStats.TOTAL_CLIENT_ENTITIES) })
		
		end
		Iris.End()
		Iris.End()
	end
end)
