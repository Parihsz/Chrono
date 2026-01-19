local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(script.Parent.tests)
require(ReplicatedStorage.Packages.chrono).Start()

require(ReplicatedStorage.Packages.chrono.Shared.Stats).REPLICATE_PERMISSIONS = nil
