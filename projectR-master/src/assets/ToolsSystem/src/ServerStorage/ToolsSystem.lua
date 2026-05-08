local ToolsSystem = {}
ToolsSystem.__index = ToolsSystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local toolCache = {}
local playerTools = {}

-- Валидация ассета
local function validateAsset(assetType, assetId)
    local cleanId = tonumber(tostring(assetId):match("%d+$"))
    if not cleanId then return false end
    
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(cleanId)
    end)
    
    return success and info.AssetTypeId == assetType
end

-- Получение значения с учетом уровня
local function getLeveledValue(value, level)
    if type(value) == "table" then
        return value[level] or value[#value]
    end
    return value
end

-- Получение стоимости улучшения
local function getUpgradeCost(costTable, currentLevel)
    if type(costTable) == "table" then
        return costTable[currentLevel] or costTable[#costTable] or 0
    end
    return costTable or 0
end

-- Настройка звуков инструмента
local function setupToolSounds(tool, config)
    if not config.sounds then return end

    local soundsFolder = Instance.new("Folder")
    soundsFolder.Name = "Sounds"
    soundsFolder.Parent = tool

    for soundName, soundId in pairs(config.sounds) do
        local cleanId = tonumber(tostring(soundId):match("%d+$"))
        if cleanId and validateAsset(3, cleanId) then
            local sound = Instance.new("Sound")
            sound.Name = soundName
            sound.SoundId = "rbxassetid://"..cleanId
            sound.Volume = 0.5
            sound.Parent = soundsFolder
        else
            warn(string.format("Invalid sound ID for %s: %s", soundName, soundId))
        end
    end
end

-- Настройка анимаций инструмента
local function setupToolAnimations(tool, config)
    if not config.animations then return end

    local animFolder = Instance.new("Folder")
    animFolder.Name = "Animations"
    animFolder.Parent = tool

    for animName, animId in pairs(config.animations) do
        local cleanId = tonumber(tostring(animId):match("%d+$"))
        if cleanId and validateAsset(24, cleanId) then
            local animation = Instance.new("Animation")
            animation.Name = animName
            animation.AnimationId = "rbxassetid://"..cleanId
            animation.Parent = animFolder
        else
            warn(string.format("Invalid animation ID for %s: %s", animName, animId))
        end
    end
end

-- Настройка модификаторов инструмента
local function setupToolModifiers(tool, config)
    if not config.modifiers then return end

    -- Установка базовых атрибутов уровня
    if config.level then
        tool:SetAttribute("Level", config.level.initial or 1)
        tool:SetAttribute("MaxLevel", config.level.max or 1)
    end

    -- Настройка модификаторов
    for i, modifier in ipairs(config.modifiers) do
        local modLevel = modifier.initial or 1
        local maxLevel = modifier.maxLevel or 1
        
        tool:SetAttribute("ModifierLevel_"..i, modLevel)
        tool:SetAttribute("ModifierMaxLevel_"..i, maxLevel)
        tool:SetAttribute("Modifier_"..i.."_Type", modifier.type)
        tool:SetAttribute("Modifier_"..i.."_Operation", modifier.operation)
        
        -- Установка начального значения
        local value = getLeveledValue(modifier.value, modLevel)
        tool:SetAttribute("Modifier_"..i.."_Value", value)
    end
    
    tool:SetAttribute("ModifiersCount", #config.modifiers)
end

-- Применение текстуры инструмента
local function applyToolTexture(tool, textureId)
    if not textureId then return end
    tool.TextureId = textureId
end

-- Поиск шаблонного скрипта
local function findTemplateScript(templatePath)
    if not templatePath then return nil end
    
    local pathParts = string.split(templatePath, "/")
    local current = game
    for _, part in ipairs(pathParts) do
        if part ~= "" then
            current = current:FindFirstChild(part)
            if not current then break end
        end
    end
    
    return current
end

-- Создание инструмента из конфигурации
local function createToolFromConfig(toolConfig, remotesFolder, scriptTemplatePath)
    if toolCache[toolConfig.name] then
        return toolCache[toolConfig.name]:Clone()
    end

    local toolModel
    if toolConfig.modelPath then
        local pathParts = string.split(toolConfig.modelPath, "/")
        local current = game
        for _, part in ipairs(pathParts) do
            if part ~= "" then
                current = current:FindFirstChild(part)
                if not current then break end
            end
        end
        
        if current and current:IsA("Tool") then
            toolModel = current
        end
    end

    if not toolModel then
        warn("Tool model not found for: " .. toolConfig.name)
        return nil
    end

    local tool = toolModel:Clone()
    tool.Name = toolConfig.name
    tool.Enabled = true
    tool.CanBeDropped = toolConfig.canBeDropped ~= false

    if not tool:FindFirstChild("Handle") then
        warn("Tool " .. toolConfig.name .. " is missing Handle part")
        return nil
    end

    applyToolTexture(tool, toolConfig.textureId)
    setupToolSounds(tool, toolConfig)
    setupToolAnimations(tool, toolConfig)
    setupToolModifiers(tool, toolConfig)

    local scriptTemplate = findTemplateScript(scriptTemplatePath)
    if scriptTemplate then
        local toolScript = scriptTemplate:Clone()
        toolScript.Name = scriptTemplate.Name
        toolScript.Parent = tool
        
        toolScript:SetAttribute("RemotesFolder", remotesFolder)
        
        if toolConfig.actions then
            for actionName, action in pairs(toolConfig.actions) do
                toolScript:SetAttribute(actionName.."_Event", action.event or "")
                toolScript:SetAttribute(actionName.."_Animation", action.animation or "")
                toolScript:SetAttribute(actionName.."_Sound", action.sound or "")
                toolScript:SetAttribute(actionName.."_Cooldown", action.cooldown or 1)
                
                local inputs = {}
                for _, input in ipairs(action.inputs) do
                    table.insert(inputs, tostring(input))
                end
                toolScript:SetAttribute(actionName.."_Inputs", table.concat(inputs, ","))
            end
        end
    else
        warn("Tool script template not found at path: " .. tostring(scriptTemplatePath))
    end

    toolCache[toolConfig.name] = tool
    return tool
end

-- Применение модификаторов инструмента к ComputedData
function ToolsSystem:applyToolModifiers(player, tool)
    if not player or not player.Character then return end
    
    local toolConfig = self.tools[tool.Name]
    if not toolConfig then return end
    
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then
        computedData = Instance.new("Folder")
        computedData.Name = "ComputedData"
        computedData.Parent = player
    end
    
    local instanceId = tool:GetAttribute("InstanceId")
    if not instanceId then
        instanceId = HttpService:GenerateGUID(false)
        tool:SetAttribute("InstanceId", instanceId)
    end
    
    if toolConfig.modifiers then
        for i, modifier in ipairs(toolConfig.modifiers) do
            local value = tool:GetAttribute("Modifier_"..i.."_Value")
            if value then
                local paramName = modifier.type
                local paramFolder = computedData:FindFirstChild(paramName)
                if not paramFolder then
                    paramFolder = Instance.new("Folder")
                    paramFolder.Name = paramName
                    paramFolder.Parent = computedData
                end
                
                local modifiersFolder = paramFolder:FindFirstChild("Modifiers")
                if not modifiersFolder then
                    modifiersFolder = Instance.new("Folder")
                    modifiersFolder.Name = "Modifiers"
                    modifiersFolder.Parent = paramFolder
                end
                
                local modifierId = "Tool_"..tool.Name.."_"..i
                local modifierValue = modifiersFolder:FindFirstChild(modifierId)
                if not modifierValue then
                    modifierValue = Instance.new("NumberValue")
                    modifierValue.Name = modifierId
                end
                
                modifierValue.Value = value
                modifierValue:SetAttribute("Operation", modifier.operation)
                modifierValue:SetAttribute("Source", "ToolsSystem")
                modifierValue:SetAttribute("InstanceId", instanceId)
                modifierValue.Parent = modifiersFolder
            end
        end
    end
end

-- Удаление модификаторов инструмента из ComputedData
function ToolsSystem:removeToolModifiers(player, tool)
    if not player then return end
    
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then return end
    
    local instanceId = tool:GetAttribute("InstanceId")
    if not instanceId then return end
    
    for _, paramFolder in ipairs(computedData:GetChildren()) do
        local modifiersFolder = paramFolder:FindFirstChild("Modifiers")
        if modifiersFolder then
            for _, modifierValue in ipairs(modifiersFolder:GetChildren()) do
                if modifierValue:GetAttribute("InstanceId") == instanceId then
                    modifierValue:Destroy()
                end
            end
        end
    end
end

-- Обработчик изменения родителя инструмента
local function onToolParentChanged(tool, player, system)
    if tool.Parent == player.Character then
        -- Инструмент экипирован
        system:applyToolModifiers(player, tool)
    else
        -- Инструмент снят
        system:removeToolModifiers(player, tool)
    end
end

-- Выдача инструмента игроку
function ToolsSystem:giveToolToPlayer(player, toolName, toBackpack, level, modifierLevels)
    if not player or not player:IsA("Player") then
        warn("Invalid player object")
        return false
    end

    if not self.tools[toolName] then
        warn("Tool not found: " .. toolName)
        return false
    end

    local tool = createToolFromConfig(self.tools[toolName], self.remotesFolder, self.scriptTemplatePath)
    if not tool then return false end
    
    -- Установка уровня и модификаторов
    local toolConfig = self.tools[toolName]
    if toolConfig.level and level then
        tool:SetAttribute("Level", math.clamp(level, 1, toolConfig.level.max or 1))
    end
    
    if toolConfig.modifiers and modifierLevels then
        for i, _ in ipairs(toolConfig.modifiers) do
            if modifierLevels[i] then
                local maxLevel = tool:GetAttribute("ModifierMaxLevel_"..i) or 1
                tool:SetAttribute("ModifierLevel_"..i, math.clamp(modifierLevels[i], 1, maxLevel))
            end
        end
    end
    
    -- Обновление значений модификаторов
    if toolConfig.modifiers then
        for i, modifier in ipairs(toolConfig.modifiers) do
            local modLevel = tool:GetAttribute("ModifierLevel_"..i) or 1
            local value = getLeveledValue(modifier.value, modLevel)
            tool:SetAttribute("Modifier_"..i.."_Value", value)
        end
    end

    if not tool:GetAttribute("InstanceId") then
        tool:SetAttribute("InstanceId", HttpService:GenerateGUID(false))
    end

    -- Подписка на изменение родителя инструмента
    local parentChangedConn
    parentChangedConn = tool:GetPropertyChangedSignal("Parent"):Connect(function()
        onToolParentChanged(tool, player, self)
    end)

    -- Обработка уничтожения инструмента
    tool.Destroying:Connect(function()
        self:removeToolModifiers(player, tool)
        if parentChangedConn then
            parentChangedConn:Disconnect()
        end
    end)

    local function giveTool()
        local targetParent
        if toBackpack then
            local startTime = os.time()
            while not player:FindFirstChild("Backpack") do
                if os.time() - startTime > 5 then
                    warn("Player backpack not found after 5 seconds")
                    return false
                end
                task.wait(0.1)
            end
            targetParent = player.Backpack
        else
            if not player.Character then
                warn("Player character not found")
                return false
            end
            targetParent = player.Character
        end
        
        tool.Parent = targetParent
        return true
    end

    local success, err = pcall(giveTool)
    if not success then
        warn("Failed to give tool: " .. tostring(err))
        tool:Destroy()
        return false
    end

    if not playerTools[player] then
        playerTools[player] = {}
    end
    table.insert(playerTools[player], tool)
    
    return true
end

-- Инициализация системы
function ToolsSystem.Init(configPath)
    local config = require(configPath)
    local system = setmetatable({
        config = config,
        tools = {},
        remotesFolder = config.remotesFolder or "ToolRemotes",
        scriptTemplatePath = config.scriptTemplatePath
    }, ToolsSystem)

    for _, toolConfig in ipairs(config.tools) do
        system.tools[toolConfig.name] = toolConfig
        createToolFromConfig(toolConfig, system.remotesFolder, system.scriptTemplatePath)
    end

    local function handlePlayer(player)
        if not player or not player:IsA("Player") then return end

        local function giveDefaultTools()
            if not config.defaultTools then return end
            
            local maxAttempts = 10
            local attempts = 0
            
            while attempts < maxAttempts do
                if player:FindFirstChild("Backpack") then
                    for _, toolName in ipairs(config.defaultTools) do
                        system:giveToolToPlayer(player, toolName, true)
                    end
                    break
                end
                attempts += 1
                task.wait(0.5)
            end
        end

        player.CharacterAdded:Connect(function(character)
            task.wait(1)
            giveDefaultTools()
        end)
        
        if player.Character then
            task.spawn(function()
                task.wait(1)
                giveDefaultTools()
            end)
        end
    end

    Players.PlayerAdded:Connect(handlePlayer)
    
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(handlePlayer, player)
    end

    -- Очистка при выходе игрока
    Players.PlayerRemoving:Connect(function(player)
        if playerTools[player] then
            for _, tool in ipairs(playerTools[player]) do
                tool:Destroy()
            end
            playerTools[player] = nil
        end
    end)

    return system
end

-- Получение конфига инструмента
function ToolsSystem:getToolConfig(toolName)
    return self.tools[toolName]
end

-- Получение стоимости инструмента
function ToolsSystem:getToolCost(toolName)
    local config = self.tools[toolName]
    return config and config.cost or 0
end

-- Получение описания инструмента
function ToolsSystem:getToolDescription(toolName)
    local config = self.tools[toolName]
    return config and config.description or ""
end

-- Получение уровня инструмента
function ToolsSystem:getToolLevel(player, toolName)
    if not player or not player:IsA("Player") then return nil end
    
    for _, tool in ipairs(playerTools[player] or {}) do
        if tool.Name == toolName then
            return tool:GetAttribute("Level") or 1
        end
    end
    
    return nil
end

-- Получение стоимости улучшения инструмента
function ToolsSystem:getToolUpgradeCost(toolName, currentLevel)
    local toolConfig = self.tools[toolName]
    if not toolConfig or not toolConfig.level or not toolConfig.level.upgradeCost then
        return 0
    end
    
    return getUpgradeCost(toolConfig.level.upgradeCost, currentLevel)
end

-- Получение стоимости улучшения модификатора
function ToolsSystem:getModifierUpgradeCost(toolName, modifierIndex, currentLevel)
    local toolConfig = self.tools[toolName]
    if not toolConfig or not toolConfig.modifiers or not toolConfig.modifiers[modifierIndex] then
        return 0
    end
    
    local modifier = toolConfig.modifiers[modifierIndex]
    return getUpgradeCost(modifier.upgradeCost, currentLevel)
end

-- Улучшение инструмента
function ToolsSystem:upgradeTool(player, toolName)
    if not player or not player:IsA("Player") then return false end
    
    local tool
    for _, t in ipairs(playerTools[player] or {}) do
        if t.Name == toolName then
            tool = t
            break
        end
    end
    
    if not tool then return false end
    
    local toolConfig = self.tools[toolName]
    if not toolConfig or not toolConfig.level then return false end
    
    local currentLevel = tool:GetAttribute("Level") or 1
    local maxLevel = toolConfig.level.max or 1
    
    if currentLevel >= maxLevel then
        return false
    end
    
    local newLevel = currentLevel + 1
    tool:SetAttribute("Level", newLevel)
    
    -- Обновление значений модификаторов
    if toolConfig.modifiers then
        for i, modifier in ipairs(toolConfig.modifiers) do
            local value = getLeveledValue(modifier.value, newLevel)
            tool:SetAttribute("Modifier_"..i.."_Value", value)
        end
    end
    
    -- Обновление модификаторов в ComputedData если инструмент экипирован
    if tool.Parent == player.Character then
        self:removeToolModifiers(player, tool)
        self:applyToolModifiers(player, tool)
    end
    
    return true, newLevel
end

-- Улучшение модификатора
function ToolsSystem:upgradeModifier(player, toolName, modifierIndex)
    if not player or not player:IsA("Player") then return false end
    
    local tool
    for _, t in ipairs(playerTools[player] or {}) do
        if t.Name == toolName then
            tool = t
            break
        end
    end
    
    if not tool then return false end
    
    local toolConfig = self.tools[toolName]
    if not toolConfig or not toolConfig.modifiers then return false end
    
    if modifierIndex < 1 or modifierIndex > #toolConfig.modifiers then
        return false
    end
    
    local modifier = toolConfig.modifiers[modifierIndex]
    local currentLevel = tool:GetAttribute("ModifierLevel_"..modifierIndex) or 1
    local maxLevel = modifier.maxLevel or 1
    
    if currentLevel >= maxLevel then
        return false
    end
    
    local newLevel = currentLevel + 1
    tool:SetAttribute("ModifierLevel_"..modifierIndex, newLevel)
    
    -- Обновление значения модификатора
    local value = getLeveledValue(modifier.value, newLevel)
    tool:SetAttribute("Modifier_"..modifierIndex.."_Value", value)
    
    -- Обновление модификаторов в ComputedData если инструмент экипирован
    if tool.Parent == player.Character then
        self:removeToolModifiers(player, tool)
        self:applyToolModifiers(player, tool)
    end
    
    return true, newLevel
end

-- Получение информации о инструментах игрока
function ToolsSystem:getPlayerToolsInfo(player)
    if not player or not player:IsA("Player") then return {} end
    
    local toolsInfo = {}
    for _, tool in ipairs(playerTools[player] or {}) do
        local toolConfig = self.tools[tool.Name]
        if toolConfig then
            local toolInfo = {
                Name = tool.Name,
                Level = tool:GetAttribute("Level") or 1,
                MaxLevel = tool:GetAttribute("MaxLevel") or 1,
                Modifiers = {}
            }
            
            if toolConfig.level and toolConfig.level.upgradeCost then
                toolInfo.UpgradeCost = getUpgradeCost(toolConfig.level.upgradeCost, toolInfo.Level)
            end
            
            local modifiersCount = tool:GetAttribute("ModifiersCount") or 0
            for i = 1, modifiersCount do
                local modifierType = tool:GetAttribute("Modifier_"..i.."_Type")
                local modifierValue = tool:GetAttribute("Modifier_"..i.."_Value")
                local modifierLevel = tool:GetAttribute("ModifierLevel_"..i) or 1
                local modifierMaxLevel = tool:GetAttribute("ModifierMaxLevel_"..i) or 1
                
                if modifierType then
                    local modifierInfo = {
                        Type = modifierType,
                        Value = modifierValue,
                        Level = modifierLevel,
                        MaxLevel = modifierMaxLevel,
                        Operation = tool:GetAttribute("Modifier_"..i.."_Operation")
                    }
                    
                    -- Получаем стоимость улучшения для модификатора
                    if toolConfig.modifiers and toolConfig.modifiers[i] and toolConfig.modifiers[i].upgradeCost then
                        modifierInfo.UpgradeCost = getUpgradeCost(toolConfig.modifiers[i].upgradeCost, modifierLevel)
                    end
                    
                    table.insert(toolInfo.Modifiers, modifierInfo)
                end
            end
            
            table.insert(toolsInfo, toolInfo)
        end
    end
    
    return toolsInfo
end

function ToolsSystem:getToolInfo(player, toolName)
    if not player or not player:IsA("Player") then return nil end
    
    for _, tool in ipairs(playerTools[player] or {}) do
        if tool.Name == toolName then
            local toolConfig = self.tools[toolName]
            if not toolConfig then return nil end
            
            local toolInfo = {
                Name = tool.Name,
                Level = tool:GetAttribute("Level") or 1,
                MaxLevel = tool:GetAttribute("MaxLevel") or 1,
                Modifiers = {}
            }
            
            local modifiersCount = tool:GetAttribute("ModifiersCount") or 0
            for i = 1, modifiersCount do
                local modifierType = tool:GetAttribute("Modifier_"..i.."_Type")
                local modifierValue = tool:GetAttribute("Modifier_"..i.."_Value")
                local modifierLevel = tool:GetAttribute("ModifierLevel_"..i) or 1
                local modifierMaxLevel = tool:GetAttribute("ModifierMaxLevel_"..i) or 1
                
                if modifierType then
                    local modifierInfo = {
                        Type = modifierType,
                        Value = modifierValue,
                        Level = modifierLevel,
                        MaxLevel = modifierMaxLevel,
                        Operation = tool:GetAttribute("Modifier_"..i.."_Operation")
                    }
                    
                    table.insert(toolInfo.Modifiers, modifierInfo)
                end
            end
            
            return toolInfo
        end
    end
    
    return nil
end

return ToolsSystem