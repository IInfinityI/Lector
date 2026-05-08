local NPCSystem = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Конфигурация системы по умолчанию
local systemConfig = {
    npcFolderName = "NPCs",
    damageIndicator = {
        enabled = true,
        color = Color3.fromRGB(255, 0, 0),
        duration = 0.5,
        tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    },
    pathfinding = {
        enabled = true,
        defaultAgentParams = {
            AgentRadius = 2.0,
            AgentHeight = 5.0,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 3.0,
            Costs = {
                Plastic = 1,
                Rock = 30,
                Lava = math.huge
            }
        }
    }
}

local configs = {}
NPCSystem.spawnedNPCs = {} -- Таблица для отслеживания созданных NPC по типам
NPCSystem.npcInstances = {} -- Таблица всех NPC по ID
NPCSystem.triggerNPCs = {} -- Триггеры для отложенного спавна

local function generateUniqueID()
    return HttpService:GenerateGUID(false)
end

-- Создание папки для NPC
local function setupNPCFolder()
    if not workspace:FindFirstChild(systemConfig.npcFolderName) then
        local npcFolder = Instance.new("Folder")
        npcFolder.Name = systemConfig.npcFolderName
        npcFolder.Parent = workspace
    end
end

-- Проверка позиции на поверхности
local function findSurfacePosition(position)
    local rayOrigin = Vector3.new(position.X, position.Y + 50, position.Z)
    local rayDirection = Vector3.new(0, -100, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {workspace[systemConfig.npcFolderName]}
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        return raycastResult.Position + Vector3.new(0, 0.5, 0)
    end
    return position
end

function NPCSystem.updateNPC(npcID, propertyTable)
    local npc = NPCSystem.npcInstances[npcID]
    if not npc then return false end
    
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    
    -- Обновляем стандартные свойства
    if propertyTable.properties then
        for prop, value in pairs(propertyTable.properties) do
            if humanoid and humanoid[prop] ~= nil then
                humanoid[prop] = value
            end
        end
    end
    
    -- Обновляем кастомные свойства
    if propertyTable.customProperties then
        for key, value in pairs(propertyTable.customProperties) do
            npc:SetAttribute(key, value)
        end
    end
    
    -- Обновляем конфигурацию скоростей
    if propertyTable.speeds then
        npc:SetAttribute("SpeedsConfig", HttpService:JSONEncode(propertyTable.speeds))
    end
    
    -- Обновляем конфигурацию анимаций
    if propertyTable.animations then
        npc:SetAttribute("AnimationsConfig", HttpService:JSONEncode(propertyTable.animations))
    end
    
    -- Обновляем конфигурацию скрипта
    if propertyTable.script then
        npc:SetAttribute("ScriptConfig", HttpService:JSONEncode(propertyTable.script))
    end
    
    -- Обновляем конфигурацию pathfinding
    if propertyTable.pathfinding then
        npc:SetAttribute("PathfindingConfig", HttpService:JSONEncode(propertyTable.pathfinding))
    end
    
    return true
end

function NPCSystem.getNPCInfo(npcID)
    local npc = NPCSystem.npcInstances[npcID]
    if not npc then return nil end
    
    local info = {
        type = npc:GetAttribute("NPCType"),
        model = npc,
        position = npc:GetPivot().Position,
        health = nil,
        maxHealth = nil,
        customProperties = {},
        attributes = {}
    }
    
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid then
        info.health = humanoid.Health
        info.maxHealth = humanoid.MaxHealth
    end
    
    -- Получаем все кастомные свойства
    for _, attr in ipairs(npc:GetAttributes()) do
        info.attributes[attr] = npc:GetAttribute(attr)
    end
    
    return info
end

-- Создание NPC
function NPCSystem.createNPC(npcType, npcConfig, spawnPosition)
    local npcModel = npcConfig.model:Clone()
    local surfacePosition = findSurfacePosition(spawnPosition)
    npcModel:SetPrimaryPartCFrame(CFrame.new(surfacePosition))
    
    local npcID = generateUniqueID()
    npcModel:SetAttribute("NPCID", npcID)
    NPCSystem.npcInstances[npcID] = npcModel
    
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for prop, value in pairs(npcConfig.properties) do
            if humanoid[prop] ~= nil then
                humanoid[prop] = value
            end
        end
    end
    
    -- Установка атрибутов
    npcModel:SetAttribute("NPCType", npcType)
    npcModel:SetAttribute("DetectionRange", npcConfig.detectionRange)
    npcModel:SetAttribute("RespawnTime", npcConfig.respawnTime or 0)
    npcModel:SetAttribute("PlayerReaction", npcConfig.script.playerReaction or "attack")
    npcModel:SetAttribute("ReactionSpeed", npcConfig.script.reactionSpeed or "Run")
    npcModel:SetAttribute("TargetLostTime", npcConfig.script.targetLostTime or 5)
    
    -- Сохраняем конфигурацию скоростей
    npcModel:SetAttribute("SpeedsConfig", HttpService:JSONEncode(npcConfig.speeds or {
        Walk = npcConfig.properties.WalkSpeed or 16,
        Run = npcConfig.properties.WalkSpeed or 16,
        Sneak = npcConfig.properties.WalkSpeed or 16
    }))
    
    if npcConfig.customProperties then
        for key, value in pairs(npcConfig.customProperties) do
            npcModel:SetAttribute(key, value)
        end    
    end

    
    -- Animations
    npcModel:SetAttribute("AnimationsConfig", HttpService:JSONEncode(npcConfig.animations))
    
    -- Script
    npcModel:SetAttribute("ScriptConfig", HttpService:JSONEncode(npcConfig.script))
    
    -- Pathfinding
    if npcConfig.pathfinding then
        npcModel:SetAttribute("PathfindingConfig", HttpService:JSONEncode(npcConfig.pathfinding))
    end
    
    -- Damage indicator
    npcModel:SetAttribute("DamageIndicatorEnabled", systemConfig.damageIndicator.enabled)
    npcModel:SetAttribute("DamageIndicatorColor", systemConfig.damageIndicator.color)
    npcModel:SetAttribute("DamageIndicatorDuration", systemConfig.damageIndicator.duration)
    
    -- Копируем шаблонный скрипт
    local aiTemplate = ReplicatedStorage:FindFirstChild("NPCAI")
    if aiTemplate then
        local aiScript = aiTemplate:Clone()
        aiScript.Parent = npcModel
        aiScript.Disabled = false
    else
        warn("NPCAI template not found in ReplicatedStorage")
    end
    
    -- Добавляем NPC в систему отслеживания
    if not NPCSystem.spawnedNPCs[npcType] then
        NPCSystem.spawnedNPCs[npcType] = {}
    end
    table.insert(NPCSystem.spawnedNPCs[npcType], npcModel)
    
    -- Настройка обработчиков смерти и удаления
    if humanoid then
        -- Обработчик смерти
        humanoid.Died:Connect(function()
            -- Удаляем NPC из системы отслеживания
            for i, npc in ipairs(NPCSystem.spawnedNPCs[npcType]) do
                if npc == npcModel then
                    table.remove(NPCSystem.spawnedNPCs[npcType], i)
                    break
                end
            end
            
            NPCSystem.npcInstances[npcID] = nil
            
            -- Запускаем респавн через указанное время
            task.delay(npcConfig.respawnTime or 0, function()
                NPCSystem.respawnNPC(npcType, npcConfig)
            end)
            
            -- Очистка модели через 5 секунд
            Debris:AddItem(npcModel, 5)
        end)
    end
    
    -- Обработчик удаления NPC
    npcModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            -- Удаляем NPC из системы отслеживания
            for i, npc in ipairs(NPCSystem.spawnedNPCs[npcType]) do
                if npc == npcModel then
                    table.remove(NPCSystem.spawnedNPCs[npcType], i)
                    break
                end
            end
            
            NPCSystem.npcInstances[npcID] = nil
        end
    end)
    
    npcModel.Parent = workspace[systemConfig.npcFolderName]
    return npcModel, npcID
end

-- Респавн NPC при необходимости
function NPCSystem.respawnNPC(npcType, npcConfig)
    -- Проверяем, нужно ли создавать новых NPC
    local currentCount = #(NPCSystem.spawnedNPCs[npcType] or {})
    local targetCount = npcConfig.count or 3
    
    if currentCount < targetCount then
        -- Определяем тип спавна
        if npcConfig.spawnType == "Point" then
            NPCSystem.createNPC(npcType, npcConfig, npcConfig.spawnPoint)
        elseif npcConfig.spawnType == "Triggered" then
            NPCSystem.createTrigger(npcType, npcConfig)
        else -- Region или по умолчанию
            local spawnRegion = npcConfig.spawnRegion
            if spawnRegion then
                local spawnPos = Vector3.new(
                    math.random(spawnRegion.Min.X, spawnRegion.Max.X),
                    spawnRegion.Max.Y,
                    math.random(spawnRegion.Min.Z, spawnRegion.Max.Z)
                )
                NPCSystem.createNPC(npcType, npcConfig, spawnPos)
            end
        end
    end
end

-- Создание триггера для отложенного спавна
function NPCSystem.createTrigger(npcType, npcConfig)
    local triggerConfig = npcConfig.triggerConfig
    if not triggerConfig then return end
    
    local triggerPart = Instance.new("Part")
    triggerPart.Anchored = true
    triggerPart.CanCollide = false
    triggerPart.Transparency = 1
    triggerPart.Size = Vector3.new(0.1, 0.1, 0.1)
    
    if triggerConfig.triggerType == "Region" then
        triggerPart.Size = triggerConfig.region.Max - triggerConfig.region.Min
        triggerPart.CFrame = CFrame.new(
            (triggerConfig.region.Min + triggerConfig.region.Max) / 2
        )
    elseif triggerConfig.triggerType == "PointRadius" then
        triggerPart.Size = Vector3.new(triggerConfig.radius * 2, 10, triggerConfig.radius * 2)
        triggerPart.CFrame = CFrame.new(triggerConfig.point)
    end
    
    triggerPart.Parent = workspace
    triggerPart.Name = npcType .. "_Trigger"
    
    local function onPlayerEnter(player)
        if #(NPCSystem.spawnedNPCs[npcType] or {}) >= (npcConfig.count or 3) then
            return
        end
        
        local spawnPos
        if triggerConfig.triggerType == "Region" then
            spawnPos = Vector3.new(
                math.random(triggerConfig.region.Min.X, triggerConfig.region.Max.X),
                triggerConfig.region.Max.Y,
                math.random(triggerConfig.region.Min.Z, triggerConfig.region.Max.Z)
            )
        else
            local angle = math.random() * 2 * math.pi
            local radius = math.random() * triggerConfig.radius
            spawnPos = Vector3.new(
                triggerConfig.point.X + math.cos(angle) * radius,
                triggerConfig.point.Y,
                triggerConfig.point.Z + math.sin(angle) * radius
            )
        end
        
        NPCSystem.createNPC(npcType, npcConfig, spawnPos)
        Debris:AddItem(triggerPart, 0.1)
    end
    
    -- Отслеживание игроков
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            if character and character.PrimaryPart then
                local charPos = character.PrimaryPart.Position
                if triggerConfig.triggerType == "Region" then
                    if charPos.X > triggerConfig.region.Min.X and charPos.X < triggerConfig.region.Max.X and
                       charPos.Z > triggerConfig.region.Min.Z and charPos.Z < triggerConfig.region.Max.Z then
                        onPlayerEnter(player)
                        break
                    end
                else
                    if (charPos - triggerConfig.point).Magnitude < triggerConfig.radius then
                        onPlayerEnter(player)
                        break
                    end
                end
            end
        end
    end)
    
    -- Сохраняем соединение для последующей очистки
    table.insert(NPCSystem.triggerNPCs, {part = triggerPart, connection = connection})
end

-- Инициализация системы
function NPCSystem.Init(configModule, customSystemConfig)
    -- Загружаем конфиг модуль
    local config = require(configModule)
    configs = config
    
    -- Обновляем системные настройки из конфига (раздел System)
    if config.System then
        for key, value in pairs(config.System) do
            systemConfig[key] = value
        end
    end
    
    -- Применяем кастомные настройки системы, если они есть (переопределяют настройки из конфига)
    if customSystemConfig then
        for key, value in pairs(customSystemConfig) do
            systemConfig[key] = value
        end
    end
    
    setupNPCFolder()
    
    for npcType, npcConfig in pairs(config) do
        if npcType ~= "System" then
            NPCSystem.spawnedNPCs[npcType] = {}
            
            -- Определение типа спавна
            local spawnType = npcConfig.spawnType or "Region"
            
            if spawnType == "Triggered" then
                NPCSystem.createTrigger(npcType, npcConfig)
            else
                for i = 1, npcConfig.count or 3 do
                    local spawnPos
                    if spawnType == "Point" then
                        spawnPos = npcConfig.spawnPoint
                    else -- Region
                        local spawnRegion = npcConfig.spawnRegion
                        if spawnRegion then
                            spawnPos = Vector3.new(
                                math.random(spawnRegion.Min.X, spawnRegion.Max.X),
                                spawnRegion.Max.Y,
                                math.random(spawnRegion.Min.Z, spawnRegion.Max.Z)
                            )
                        end
                    end
                    
                    if spawnPos then
                        NPCSystem.createNPC(npcType, npcConfig, spawnPos)
                    end
                end
            end
        end
    end
end

-- Очистка триггеров
function NPCSystem.Cleanup()
    for _, triggerData in ipairs(NPCSystem.triggerNPCs) do
        if triggerData.connection then
            triggerData.connection:Disconnect()
        end
        if triggerData.part then
            triggerData.part:Destroy()
        end
    end
    NPCSystem.triggerNPCs = {}
end

-- Получение всех NPC определенного типа
function NPCSystem.getNPCsOfType(npcType)
    return NPCSystem.spawnedNPCs[npcType] or {}
end

-- Получение NPC по ID
function NPCSystem.getNPCByID(npcID)
    return NPCSystem.npcInstances[npcID]
end

return NPCSystem