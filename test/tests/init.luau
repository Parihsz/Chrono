local RunService = game:GetService("RunService")

type tests = "" | "testPart" | "testChar" | "largeCharTest"

local test: tests = ""
if test == "" then
	return nil
end
local data = (require)(script:FindFirstChild(test))
data.init()
task.delay(1, function()
	if RunService:IsServer() then
		data.server()
	else
		data.client()
	end
end)
return nil
