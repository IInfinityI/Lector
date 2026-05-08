local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AbilitySystem = require(ReplicatedStorage:WaitForChild("AbilitySystem"))
local AbilityConfig = require(ServerStorage:WaitForChild("AbilityConfig"))

-- Инициализация системы
local abilitySystem = AbilitySystem.Init(AbilityConfig)

local function onPlayerAdded(player)
    abilitySystem:AddAbility(player, "FireBall")
end

-- Подключаем событие PlayerAdded
Players.PlayerAdded:Connect(onPlayerAdded)