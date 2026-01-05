local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

if IS_SERVER then
	require(script.Server.Replicate)
else
	require(script.Client.Replicate)
end

return nil
