local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Подключение модуля системы инструментов
local ToolsSystem = require(ServerStorage:WaitForChild("ToolsSystem"))
local toolsConfig = ServerStorage.ConfigTool

local toolSystem = ToolsSystem.Init(toolsConfig)

local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("DataManager"))
DataManager.Init(game.ServerScriptService.ConfigModule)

-- Создание парта для улучшения инструмента
local upgradePart = Instance.new("Part")
upgradePart.Name = "UpgradeToolPart"
upgradePart.Size = Vector3.new(4, 1, 4)
upgradePart.Position = Vector3.new(0, 1.5, 10)
upgradePart.Anchored = true
upgradePart.CanCollide = true
upgradePart.BrickColor = BrickColor.new("Bright green")
upgradePart.Parent = workspace

local upgradeProximityPrompt = Instance.new("ProximityPrompt")
upgradeProximityPrompt.ActionText = "Улучшить инструмент"
upgradeProximityPrompt.ObjectText = "Станция улучшения"
upgradeProximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
upgradeProximityPrompt.MaxActivationDistance = 10
upgradeProximityPrompt.HoldDuration = 0
upgradeProximityPrompt.Parent = upgradePart

local upgradeBillboard = Instance.new("BillboardGui")
upgradeBillboard.Size = UDim2.new(0, 200, 0, 50)
upgradeBillboard.StudsOffset = Vector3.new(0, 2, 0)
upgradeBillboard.Parent = upgradePart

local upgradeText = Instance.new("TextLabel")
upgradeText.Size = UDim2.new(1, 0, 1, 0)
upgradeText.Text = "Нажмите E чтобы улучшить\nэкипированный инструмент"
upgradeText.BackgroundTransparency = 1
upgradeText.TextColor3 = Color3.new(1, 1, 1)
upgradeText.TextScaled = true
upgradeText.Parent = upgradeBillboard

-- Создание парта для отображения информации об инструменте
local infoPart = Instance.new("Part")
infoPart.Name = "ToolInfoPart"
infoPart.Size = Vector3.new(4, 1, 4)
infoPart.Position = Vector3.new(0, 1.5, 20)
infoPart.Anchored = true
infoPart.CanCollide = true
infoPart.BrickColor = BrickColor.new("Bright blue")
infoPart.Parent = workspace

local infoProximityPrompt = Instance.new("ProximityPrompt")
infoProximityPrompt.ActionText = "Информация об инструменте"
infoProximityPrompt.ObjectText = "Информационная панель"
infoProximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
infoProximityPrompt.MaxActivationDistance = 10
infoProximityPrompt.HoldDuration = 0
infoProximityPrompt.Parent = infoPart

local infoBillboard = Instance.new("BillboardGui")
infoBillboard.Size = UDim2.new(0, 200, 0, 50)
infoBillboard.StudsOffset = Vector3.new(0, 2, 0)
infoBillboard.Parent = infoPart

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, 0, 1, 0)
infoText.Text = "Нажмите E чтобы увидеть\nинформацию об инструменте"
infoText.BackgroundTransparency = 1
infoText.TextColor3 = Color3.new(1, 1, 1)
infoText.TextScaled = true
infoText.Parent = infoBillboard

-- Функция для получения экипированного инструмента
local function getEquippedTool(player)
    if not player or not player.Character then return nil end
    
    for _, tool in ipairs(player.Character:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("InstanceId") then
            return tool
        end
    end
    
    return nil
end

-- Обработка нажатия E для парта улучшения
upgradeProximityPrompt.Triggered:Connect(function(player)
    local equippedTool = getEquippedTool(player)
    if not equippedTool then
        -- Сообщение игроку, что инструмент не экипирован
        local hint = Instance.new("Hint")
        hint.Text = "У вас нет экипированного инструмента!"
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
        return
    end
    
    -- Проверяем, можно ли улучшить инструмент
    local currentLevel = equippedTool:GetAttribute("Level") or 1
    local maxLevel = equippedTool:GetAttribute("MaxLevel") or 1
    
    if currentLevel >= maxLevel then
        local hint = Instance.new("Hint")
        hint.Text = "Инструмент уже максимального уровня!"
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
        return
    end
    
    -- Получаем стоимость улучшения
    local upgradeCost = toolSystem:getToolUpgradeCost(equippedTool.Name, currentLevel)
    
    -- Здесь должна быть проверка наличия валюты у игрока
    -- Для примера предположим, что у игрока достаточно средств
    
    -- Улучшаем инструмент
    local success, newLevel = toolSystem:upgradeTool(player, equippedTool.Name)
    if success then
        local hint = Instance.new("Hint")
        hint.Text = string.format("Инструмент улучшен до уровня %d!", newLevel)
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
        
        -- Обновляем текст на билборде
        upgradeText.Text = string.format("Нажмите E чтобы улучшить\nэкипированный инструмент\nТекущий уровень: %d/%d", newLevel, maxLevel)
    else
        local hint = Instance.new("Hint")
        hint.Text = "Не удалось улучшить инструмент!"
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
    end
end)

-- Обработка нажатия E для парта информации
infoProximityPrompt.Triggered:Connect(function(player)
    local equippedTool = getEquippedTool(player)
    if not equippedTool then
        local hint = Instance.new("Hint")
        hint.Text = "У вас нет экипированного инструмента!"
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
        return
    end
    
    -- Получаем информацию об инструменте
    local toolInfo = toolSystem:getPlayerToolsInfo(player)
    local currentToolInfo
    
    for _, info in ipairs(toolInfo) do
        if info.Name == equippedTool.Name then
            currentToolInfo = info
            break
        end
    end
    
    if not currentToolInfo then
        local hint = Instance.new("Hint")
        hint.Text = "Информация об инструменте не найдена!"
        hint.Parent = player.PlayerGui
        game:GetService("Debris"):AddItem(hint, 3)
        return
    end
    
    -- Формируем текст информации
    local infoString = string.format("Инструмент: %s\nУровень: %d/%d\n", 
        currentToolInfo.Name, currentToolInfo.Level, currentToolInfo.MaxLevel)
    
    if currentToolInfo.Modifiers and #currentToolInfo.Modifiers > 0 then
        infoString = infoString .. "Модификаторы:\n"
        
        for i, modifier in ipairs(currentToolInfo.Modifiers) do
            infoString = infoString .. string.format("- %s: %s (ур. %d/%d)\n", 
                modifier.Type, tostring(modifier.Value), modifier.Level, modifier.MaxLevel)
        end
    end
    
    -- Показываем информацию игроку
    local screenGui = player.PlayerGui:FindFirstChild("ToolInfoScreen") or Instance.new("ScreenGui")
    screenGui.Name = "ToolInfoScreen"
    screenGui.Parent = player.PlayerGui
    
    local frame = screenGui:FindFirstChild("InfoFrame") or Instance.new("Frame")
    frame.Name = "InfoFrame"
    frame.Size = UDim2.new(0, 300, 0, 200)
    frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
    frame.Parent = screenGui
    
    local textLabel = frame:FindFirstChild("InfoText") or Instance.new("TextLabel")
    textLabel.Name = "InfoText"
    textLabel.Size = UDim2.new(0.9, 0, 0.9, 0)
    textLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Text = infoString
    textLabel.TextScaled = true
    textLabel.TextWrapped = true
    textLabel.Parent = frame
    
    local closeButton = frame:FindFirstChild("CloseButton") or Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.2, 0, 0.1, 0)
    closeButton.Position = UDim2.new(0.4, 0, 0.85, 0)
    closeButton.Text = "Закрыть"
    closeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = frame
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Автоматическое закрытие через 10 секунд
    delay(10, function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end)

-- Пример использования:
game.Players.PlayerAdded:Connect(function(player)
    -- Выдать меч в инвентарь
    toolSystem:giveToolToPlayer(player, "Sword", true)
    
    -- Создать GUI для игрока
    local playerGui = Instance.new("PlayerGui")
    playerGui.Name = "PlayerGui"
    playerGui.Parent = player
end)