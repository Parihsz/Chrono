local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local Config = require(script.Shared.Config)
local HTTPS = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Player = require(script.Server.Player)
local Receiver = require(script.Server.Receiver)
local ServerClock = require(script.Server.ServerClock)
local Entity = require(script.Shared.Entity)
local Events = require(script.Shared.Events)
local Holder = require(script.Shared.Holder)
local ReplicationRules = require(script.Shared.ReplicationRules)
local Snapshots = require(script.Shared.Snapshots)

local function CheckVersion()
	task.spawn(function()
		pcall(function()
			local url = "https://api.github.com/repos/Parihsz/Chrono/releases/latest"
			local success, result = pcall(function()
				return HTTPS:GetAsync(url)
			end)
			if not success then
				return
			end
			local data = HTTPS:JSONDecode(result)
			local latestVersion = data.tag_name
			local currentVersion = Config._GetConfig("__VERSION")
			if latestVersion ~= currentVersion then
				warn(
					("Chrono: A new version is available! You are using version %s, but the latest version is %s."):format(
						currentVersion,
						latestVersion
					)
				)
			end
		end)
	end)
end
local STARTED = false
return {
	Start = function(config: ModuleScript?)
		if STARTED then
			warn("Chrono: Already Started. Ignoring subsequent calls.")
			return
		end
		STARTED = true
		if config then
			(require)(config)
		end
		if IS_SERVER then
			require(script.Server.Replicate)
		else
			require(script.Client.Replicate)
		end
		Config._Lock()
		if IS_SERVER and Config._GetConfig("CHECK_NEW_VERSION") then
			CheckVersion()
		end
	end,

	Holder = Holder,
	Entity = Entity,
	Stats = Stats,
	Config = Config,
	ReplicationRules = ReplicationRules,
	Events = Events,
	Snapshots = Snapshots,


	ServerClock = ServerClock,
	Player = Player,
	ServerReceiver = Receiver



}
