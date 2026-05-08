local AccessorySystem = {}
AccessorySystem.__index = AccessorySystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Глобальная переменная для экземпляра системы
local systemInstance = nil

-- Поиск объекта по пути
local function findInstanceByPath(path)
    if not path or type(path) ~= "string" then
        warn("[AccessorySystem] Invalid path")
        return nil
    end
    
    local pathParts = string.split(path, "/")
    local current = game
    for _, part in ipairs(pathParts) do
        if part ~= "" then
            current = current:FindFirstChild(part)
            if not current then 
                warn("[AccessorySystem] Instance not found: " .. path)
                return nil 
            end
        end
    end
    return current
end

-- Получение значения с учетом уровня
local function getLeveledValue(value, level)
    if type(value) == "table" then
        return value[level] or value[#value] or 0
    end
    return value or 0
end

-- Поиск основной части аксессуара по instanceId
local function findPrimaryAccessoryByInstanceId(character, instanceId)
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute("InstanceId") == instanceId and child:GetAttribute("IsPrimary") then
            return child
        end
    end
    return nil
end

-- Поиск всех частей аксессуара по ID
local function findAllAccessoryParts(character, instanceId)
    local parts = {}
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute("InstanceId") == instanceId then
            table.insert(parts, child)
        end
    end
    return parts
end

-- Валидация конфигурации аксессуара
local function validateAccessoryConfig(config)
    if not config.name then
        return false, "Accessory name is missing"
    end
    
    if not config.modelPath then
        return false, "Model path is missing for accessory: " .. config.name
    end
    
    if config.level and config.modifiers then
        for _, modifier in ipairs(config.modifiers) do
            if modifier.individualUpgrade and config.level then
                return false, "Cannot have both global level and individual upgrade for accessory: " .. config.name
            end
        end
    end
    
    -- Валидация настроек смерти
    if config.deathSettings then
        if config.deathSettings.removeFromInventory ~= nil and type(config.deathSettings.removeFromInventory) ~= "boolean" then
            return false, "removeFromInventory must be boolean"
        end
        if config.deathSettings.reequipOnRespawn ~= nil and type(config.deathSettings.reequipOnRespawn) ~= "boolean" then
            return false, "reequipOnRespawn must be boolean"
        end
    end
    
    return true
end

-- Безопасный вызов методов DataManager
local function safeDataManagerCall(funcName, ...)
    local dataManager = _G.DataManager
    if not dataManager then
        dataManager = _G.AssetService and _G.AssetService:GetModule("DataManager")
    end
    
    if not dataManager then
        warn("[AccessorySystem] DataManager not available for " .. funcName)
        return nil
    end
    
    local func = dataManager[funcName]
    if type(func) ~= "function" then
        warn("[AccessorySystem] DataManager does not have method " .. funcName)
        return nil
    end
    
    local success, result, errorMessage = pcall(func, ...)
    if not success then
        warn("[AccessorySystem] DataManager." .. funcName .. " failed: " .. tostring(result))
        return nil
    end
    
    if result == nil then
        warn("[AccessorySystem] DataManager." .. funcName .. " returned nil: " .. tostring(errorMessage))
        return nil
    end
    
    return result
end

-- Получение данных игрока об аксессуарах
local function getPlayerAccessoryData(player)

    local playerData = safeDataManagerCall("GetData", player)
    if not playerData then return nil end
    
    -- Инициализируем структуру данных для аксессуаров, если её нет
    if not playerData.AccessorySystem then
        playerData.AccessorySystem = {
            ownedAccessories = {},    -- Все аксессуары игрока [instanceId] = accessoryData
            equippedAccessories = {}  -- Экипированные аксессуары [instanceId] = true
        }
    end
    
    return playerData.AccessorySystem
end

-- Сохранение данных игрока об аксессуарах
local function savePlayerAccessoryData(player, accessoryData)
    local success = safeDataManagerCall("UpdateData", player, function(currentData)
        currentData.AccessorySystem = accessoryData
        return currentData
    end)
    
    if success == nil then
        -- Попробуем альтернативный путь
        local dataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
        if dataManager and dataManager.UpdateData then
            return dataManager:UpdateData(player, function(currentData)
                currentData.AccessorySystem = accessoryData
                return currentData
            end)
        end
        return false
    end
    
    return success
end

-- Получение аксессуара по instanceId
local function getOwnedAccessoryByInstanceId(player, instanceId)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return nil end
    
    return accessoryData.ownedAccessories[instanceId]
end

-- Сохранение аксессуара в инвентарь
local function saveOwnedAccessory(player, instanceId, accessoryInfo)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    accessoryData.ownedAccessories[instanceId] = accessoryInfo
    return savePlayerAccessoryData(player, accessoryData)
end

-- Удаление аксессуара из инвентаря
local function removeOwnedAccessory(player, instanceId)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    accessoryData.ownedAccessories[instanceId] = nil
    return savePlayerAccessoryData(player, accessoryData)
end

-- Добавление в экипированные аксессуары
local function addToEquippedAccessories(player, instanceId)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    accessoryData.equippedAccessories[instanceId] = true
    return savePlayerAccessoryData(player, accessoryData)
end

-- Удаление из экипированных аксессуаров
local function removeFromEquippedAccessories(player, instanceId)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    accessoryData.equippedAccessories[instanceId] = nil
    return savePlayerAccessoryData(player, accessoryData)
end

-- Проверка экипирован ли аксессуар
local function isAccessoryEquipped(player, instanceId)
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    return accessoryData.equippedAccessories[instanceId] == true
end

-- Применение модификаторов аксессуара через DataManager
local function applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modifierLevels, isEquip)
    if not accessoryConfig or not accessoryConfig.modifiers then return end
    
    if isEquip then
        for i, modifier in ipairs(accessoryConfig.modifiers) do
            local levelToUse = 1
            
            if accessoryConfig.level then
                -- Глобальная прокачка
                levelToUse = accessoryLevel or 1
            elseif modifier.initial then
                -- Индивидуальная прокачка
                levelToUse = modifierLevels and modifierLevels[i] or modifier.initial
            end
            
            local value = getLeveledValue(modifier.value, levelToUse)
            local paramName = modifier.type
            local modifierId = "Accessory_"..accessoryName.."_"..i.."_"..instanceId
            
            -- Пробуем разные способы вызова AddModifier
            local success = false
            
            -- Способ 1: Через safeDataManagerCall
            local result = safeDataManagerCall("AddModifier", player, paramName, modifierId, value, modifier.operation or "add", "AccessorySystem")
            if result ~= nil then
                success = true
            else
                -- Способ 2: Прямой вызов, если DataManager в _G
                local dataManager = _G.DataManager
                if dataManager and dataManager.AddModifier then
                    local ok, err = pcall(function()
                        dataManager:AddModifier(player, paramName, modifierId, value, modifier.operation or "add", "AccessorySystem")
                    end)
                    if ok then
                        success = true
                    else
                        warn("[AccessorySystem] Failed to add modifier via direct call: " .. tostring(err))
                    end
                end
            end
            
            if not success then
                warn("[AccessorySystem] Could not apply modifier " .. modifierId .. " for " .. player.Name)
            end
        end
    else
        for i in ipairs(accessoryConfig.modifiers) do
            local modifierId = "Accessory_"..accessoryName.."_"..i.."_"..instanceId
            local paramName = accessoryConfig.modifiers[i].type
            
            -- Пробуем удалить модификатор
            local result = safeDataManagerCall("RemoveModifier", player, paramName, modifierId)
            if result == nil then
                local dataManager = _G.DataManager
                if dataManager and dataManager.RemoveModifier then
                    pcall(function()
                        dataManager:RemoveModifier(player, paramName, modifierId)
                    end)
                end
            end
        end
    end
end

-- Получение валюты игрока
local function getPlayerCurrency(player, currencyName)
    local playerData = safeDataManagerCall("GetData", player)
    if not playerData then return 0 end
    
    return playerData[currencyName] or 0
end

-- Обновление валюты игрока
local function updatePlayerCurrency(player, currencyName, amount)
    local success = safeDataManagerCall("UpdateData", player, function(currentData)
        currentData[currencyName] = (currentData[currencyName] or 0) + amount
        return currentData
    end)
    
    if success == nil then
        local dataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
        if dataManager and dataManager.UpdateData then
            return dataManager:UpdateData(player, function(currentData)
                currentData[currencyName] = (currentData[currencyName] or 0) + amount
                return currentData
            end)
        end
        return false
    end
    
    return success
end

-- Получение настроек смерти для аксессуара
local function getDeathSettings(accessoryConfig)
    local defaultSettings = {
        removeFromInventory = false,
        reequipOnRespawn = true
    }
    
    if accessoryConfig.deathSettings then
        return {
            removeFromInventory = accessoryConfig.deathSettings.removeFromInventory or defaultSettings.removeFromInventory,
            reequipOnRespawn = accessoryConfig.deathSettings.reequipOnRespawn or defaultSettings.reequipOnRespawn
        }
    end
    
    return defaultSettings
end

-- Проверка лимита покупки аксессуара
local function checkPurchaseLimit(player, accessoryConfig)
    if not accessoryConfig.purchaseLimit then
        return true
    end
    
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return false end
    
    local count = 0
    for _, accessoryInfo in pairs(accessoryData.ownedAccessories) do
        if accessoryInfo.name == accessoryConfig.name then
            count = count + 1
        end
    end
    
    return count < accessoryConfig.purchaseLimit
end

-- Получение уровней по умолчанию из конфига
local function getDefaultAccessoryLevels(accessoryConfig)
    local level = 1
    local modifierLevels = {}

    if accessoryConfig.level then
        level = accessoryConfig.level.initial or 1
    end

    if accessoryConfig.modifiers then
        for i, modifier in ipairs(accessoryConfig.modifiers) do
            modifierLevels[i] = modifier.initial or 1
        end
    end

    return level, modifierLevels
end

-- Проверка возможности экипировки по instanceId
local function canEquipAccessoryById(player, instanceId)
    local character = player.Character
    if not character then return false, "Character not found" end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return false, "Accessory not found in inventory" end
    
    local accessoryConfig = systemInstance.accessories[ownedAccessory.name]
    if not accessoryConfig then return false, "Accessory config not found" end
    
    -- Проверка максимального количества слотов
    local maxSlots = systemInstance.maxCategorySlots[accessoryConfig.category]
    if not maxSlots then return false, "Category not found: " .. accessoryConfig.category end
    
    local currentCount = 0
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute("Category") == accessoryConfig.category then
            currentCount += 1
        end
    end
    
    if currentCount >= maxSlots then
        return false, "No available slots in category: " .. accessoryConfig.category
    end
    
    -- Проверка, не экипирован ли уже этот instanceId
    if isAccessoryEquipped(player, instanceId) then
        return false, "Accessory instance already equipped"
    end
    
    return true, ""
end

-- Обновление атрибутов аксессуара
function AccessorySystem:updateAccessoryAttributes(primaryPart, accessoryConfig, accessoryData)
    local globalLevel = accessoryConfig.level and accessoryData.level
    
    if accessoryConfig.modifiers then
        for i, modifier in ipairs(accessoryConfig.modifiers) do
            local modLevel = nil
            local useGlobalLevel = false
            
            -- Определение типа прокачки
            if globalLevel and not modifier.individualUpgrade then
                modLevel = globalLevel
                useGlobalLevel = true
            else
                modLevel = accessoryData.modifierLevels and accessoryData.modifierLevels[i] or modifier.initial or 1
            end
            
            -- Проверка максимального уровня
            local maxLevel = modifier.maxLevel or 1
            modLevel = math.clamp(modLevel, 1, maxLevel)
            
            -- Обновление уровня модификатора
            primaryPart:SetAttribute("ModifierLevel_"..i, modLevel)
            
            -- Получение значения с учетом уровня
            local baseValue = getLeveledValue(modifier.value, modLevel)
            primaryPart:SetAttribute("Modifier_"..i.."_Value", baseValue)
            
            -- Установка флага типа прокачки
            primaryPart:SetAttribute("Modifier_"..i.."_Global", useGlobalLevel)
        end
    end
end

-- Загрузка аксессуара в кеш
function AccessorySystem:loadAccessoryToCache(accessoryConfig)
    local accessoryParts = {}
    
    if type(accessoryConfig.modelPath) == "table" then
        for side, path in pairs(accessoryConfig.modelPath) do
            local model = findInstanceByPath(path)
            if model then
                model.Name = accessoryConfig.name .. "_" .. side
                table.insert(accessoryParts, model)
            else
                warn("[AccessorySystem] Accessory part not found: " .. path)
            end
        end
    else
        local model = findInstanceByPath(accessoryConfig.modelPath)
        if model then
            model.Name = accessoryConfig.name
            table.insert(accessoryParts, model)
        else
            warn("[AccessorySystem] Accessory model not found: " .. accessoryConfig.modelPath)
        end
    end

    if #accessoryParts == 0 then return nil end
    self.accessoryCache[accessoryConfig.name] = accessoryParts
    return accessoryParts
end

-- Экипировка аксессуара по instanceId
function AccessorySystem:equipAccessoryById(player, instanceId)
    if not player or not player:IsA("Player") then
        return false, "Invalid player object"
    end

    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    
    -- Получение информации об аксессуаре из инвентаря
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then
        return false, "Accessory not found in inventory"
    end

    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then
        return false, "Accessory config not found: " .. accessoryName
    end
    
    -- Проверка возможности экипировки
    local canEquip, reason = canEquipAccessoryById(player, instanceId)
    if not canEquip then
        return false, reason
    end

    local cachedParts = self.accessoryCache[accessoryName]
    if not cachedParts then
        return false, "Accessory not in cache: " .. accessoryName
    end

    local primaryPart = nil

    -- Клонирование и настройка частей
    for i, partTemplate in ipairs(cachedParts) do
        local part = partTemplate:Clone()
        
        -- Установка базовых атрибутов
        part:SetAttribute("AccessoryName", accessoryName)
        part:SetAttribute("Category", accessoryConfig.category)
        part:SetAttribute("InstanceId", instanceId)
        
        -- Первая часть считается основной
        if i == 1 then
            primaryPart = part
            primaryPart:SetAttribute("IsPrimary", true)
            
            -- Установка уровня аксессуара из данных инвентаря
            if accessoryConfig.level then
                local level = ownedAccessory.level or accessoryConfig.level.initial or 1
                level = math.clamp(level, 1, accessoryConfig.level.max or 1)
                primaryPart:SetAttribute("Level", level)
            end
            
            -- Установка уровней модификаторов из данных инвентаря
            if accessoryConfig.modifiers then
                primaryPart:SetAttribute("ModifiersCount", #accessoryConfig.modifiers)
                for i, modifier in ipairs(accessoryConfig.modifiers) do
                    local modLevel
                    
                    if ownedAccessory.modifierLevels and ownedAccessory.modifierLevels[i] then
                        modLevel = math.clamp(ownedAccessory.modifierLevels[i], 1, modifier.maxLevel or 1)
                    else
                        modLevel = modifier.initial or 1
                    end
                    
                    primaryPart:SetAttribute("ModifierLevel_"..i, modLevel)
                end
            end
            
            -- Обновление атрибутов
            self:updateAccessoryAttributes(primaryPart, accessoryConfig, ownedAccessory)
        else
            part:SetAttribute("IsPrimary", false)
        end
        
        part.Parent = character
    end

    if primaryPart then
        -- Применяем модификаторы через DataManager
        local accessoryLevel = ownedAccessory.level or 1
        local modLevels = ownedAccessory.modifierLevels or {}
        
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, true)
        
        -- Сохраняем в список экипированных
        local saveSuccess = addToEquippedAccessories(player, instanceId)
        
        return true, instanceId
    end
    
    return false, "Failed to create accessory"
end

-- Снятие аксессуара по instanceId
function AccessorySystem:unequipAccessoryById(player, instanceId)
    if not player or not player.Character then return false, "Character not found" end
    
    local character = player.Character
    
    -- Проверяем, экипирован ли аксессуар
    if not isAccessoryEquipped(player, instanceId) then
        return false, "Accessory not equipped"
    end
    
    -- Получаем информацию об аксессуаре
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then
        return false, "Accessory not found in inventory"
    end
    
    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    
    -- Снимаем модификаторы через DataManager
    if accessoryConfig then
        local accessoryLevel = ownedAccessory.level or 1
        local modLevels = ownedAccessory.modifierLevels or {}
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, false)
    end
    
    -- Удаляем из списка экипированных
    removeFromEquippedAccessories(player, instanceId)
    
    -- Удаление всех частей аксессуара
    local parts = findAllAccessoryParts(character, instanceId)
    for _, part in ipairs(parts) do
        part:Destroy()
    end
    
    return true, instanceId
end

-- Улучшение аксессуара (глобальная прокачка) по instanceId
function AccessorySystem:upgradeAccessoryById(player, instanceId)
    if not player then return false, "Player not found" end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return false, "Accessory not found in inventory" end
    
    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig or not accessoryConfig.level then return false, "Accessory cannot be upgraded" end
    
    local currentLevel = ownedAccessory.level or 1
    local maxLevel = accessoryConfig.level.max or 1
    
    if currentLevel >= maxLevel then
        return false, "Accessory already at maximum level"
    end
    
    local newLevel = currentLevel + 1
    
    -- Обновляем уровень в инвентаре
    ownedAccessory.level = newLevel
    local saveSuccess = saveOwnedAccessory(player, instanceId, ownedAccessory)
    if not saveSuccess then
        return false, "Failed to save accessory data"
    end
    
    -- Если аксессуар экипирован, обновляем модификаторы
    if isAccessoryEquipped(player, instanceId) then
        -- Снимаем старые модификаторы
        local oldModLevels = ownedAccessory.modifierLevels or {}
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, currentLevel, oldModLevels, false)
        
        -- Применяем новые модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, newLevel, oldModLevels, true)
        
        -- Обновляем атрибуты на модели
        local character = player.Character
        if character then
            local primaryPart = findPrimaryAccessoryByInstanceId(character, instanceId)
            if primaryPart then
                primaryPart:SetAttribute("Level", newLevel)
                self:updateAccessoryAttributes(primaryPart, accessoryConfig, ownedAccessory)
            end
        end
    end
    
    return true, newLevel
end

-- Установка уровня аксессуара (глобальная прокачка) по instanceId
function AccessorySystem:setAccessoryLevelById(player, instanceId, newLevel)
    if not player then return false, "Player not found" end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return false, "Accessory not found in inventory" end
    
    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig or not accessoryConfig.level then return false, "Accessory cannot be leveled" end
    
    local maxLevel = accessoryConfig.level.max or 1
    newLevel = math.clamp(newLevel, 1, maxLevel)
    local currentLevel = ownedAccessory.level or 1
    
    if newLevel == currentLevel then
        return true
    end
    
    -- Обновляем уровень в инвентаре
    ownedAccessory.level = newLevel
    local saveSuccess = saveOwnedAccessory(player, instanceId, ownedAccessory)
    if not saveSuccess then
        return false, "Failed to save accessory data"
    end
    
    -- Если аксессуар экипирован, обновляем модификаторы
    if isAccessoryEquipped(player, instanceId) then
        local modLevels = ownedAccessory.modifierLevels or {}
        
        -- Снимаем старые модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, currentLevel, modLevels, false)
        
        -- Применяем новые модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, newLevel, modLevels, true)
        
        -- Обновляем атрибуты на модели
        local character = player.Character
        if character then
            local primaryPart = findPrimaryAccessoryByInstanceId(character, instanceId)
            if primaryPart then
                primaryPart:SetAttribute("Level", newLevel)
                self:updateAccessoryAttributes(primaryPart, accessoryConfig, ownedAccessory)
            end
        end
    end
    
    return true
end

-- Улучшение модификатора (индивидуальная прокачка) по instanceId
function AccessorySystem:upgradeModifierById(player, instanceId, modifierIndex)
    if not player then return false, "Player not found" end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return false, "Accessory not found in inventory" end
    
    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then return false, "Accessory config not found" end
    
    -- Проверка типа прокачки
    if accessoryConfig.level then
        return false, "Global upgrade accessory, individual upgrade not allowed"
    end
    
    if not accessoryConfig.modifiers or not accessoryConfig.modifiers[modifierIndex] then
        return false, "Invalid modifier index"
    end
    
    local modifierConfig = accessoryConfig.modifiers[modifierIndex]
    if not modifierConfig.maxLevel then return false, "Modifier cannot be upgraded" end
    
    -- Инициализируем modifierLevels если нужно
    if not ownedAccessory.modifierLevels then
        ownedAccessory.modifierLevels = {}
    end
    
    local currentLevel = ownedAccessory.modifierLevels[modifierIndex] or modifierConfig.initial or 1
    local maxLevel = modifierConfig.maxLevel or 1
    
    if currentLevel >= maxLevel then
        return false, "Modifier already at maximum level"
    end
    
    local nextLevel = currentLevel + 1
    
    -- Обновляем уровень модификатора в инвентаре
    ownedAccessory.modifierLevels[modifierIndex] = nextLevel
    local saveSuccess = saveOwnedAccessory(player, instanceId, ownedAccessory)
    if not saveSuccess then
        return false, "Failed to save accessory data"
    end
    
    -- Если аксессуар экипирован, обновляем модификаторы
    if isAccessoryEquipped(player, instanceId) then
        local accessoryLevel = ownedAccessory.level or 1
        local modLevels = ownedAccessory.modifierLevels or {}
        
        -- Снимаем все модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, false)
        
        -- Применяем новые модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, true)
        
        -- Обновляем атрибуты на модели
        local character = player.Character
        if character then
            local primaryPart = findPrimaryAccessoryByInstanceId(character, instanceId)
            if primaryPart then
                primaryPart:SetAttribute("ModifierLevel_"..modifierIndex, nextLevel)
                self:updateAccessoryAttributes(primaryPart, accessoryConfig, ownedAccessory)
            end
        end
    end
    
    return true, nextLevel
end

-- Установка уровня модификатора по instanceId
function AccessorySystem:setModifierLevelById(player, instanceId, modifierIndex, newLevel)
    if not player then return false, "Player not found" end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return false, "Accessory not found in inventory" end
    
    local accessoryName = ownedAccessory.name
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then return false, "Accessory config not found" end
    
    -- Проверка типа прокачки
    if not accessoryConfig.modifiers or not accessoryConfig.modifiers[modifierIndex] then
        return false, "Modifier not found"
    end
    
    local modifierConfig = accessoryConfig.modifiers[modifierIndex]
    if not modifierConfig.individualUpgrade then
        return false, "Modifier does not support individual upgrade"
    end
    
    local maxLevel = modifierConfig.maxLevel or 1
    newLevel = math.clamp(newLevel, 1, maxLevel)
    
    -- Инициализируем modifierLevels если нужно
    if not ownedAccessory.modifierLevels then
        ownedAccessory.modifierLevels = {}
    end
    
    local currentLevel = ownedAccessory.modifierLevels[modifierIndex] or modifierConfig.initial or 1
    
    if newLevel == currentLevel then
        return true
    end
    
    -- Обновляем уровень модификатора в инвентаре
    ownedAccessory.modifierLevels[modifierIndex] = newLevel
    local saveSuccess = saveOwnedAccessory(player, instanceId, ownedAccessory)
    if not saveSuccess then
        return false, "Failed to save accessory data"
    end
    
    -- Если аксессуар экипирован, обновляем модификаторы
    if isAccessoryEquipped(player, instanceId) then
        local accessoryLevel = ownedAccessory.level or 1
        local modLevels = ownedAccessory.modifierLevels or {}
        
        -- Снимаем все модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, false)
        
        -- Применяем новые модификаторы
        applyModifiers(player, accessoryName, instanceId, accessoryConfig, accessoryLevel, modLevels, true)
        
        -- Обновляем атрибуты на модели
        local character = player.Character
        if character then
            local primaryPart = findPrimaryAccessoryByInstanceId(character, instanceId)
            if primaryPart then
                primaryPart:SetAttribute("ModifierLevel_"..modifierIndex, newLevel)
                self:updateAccessoryAttributes(primaryPart, accessoryConfig, ownedAccessory)
            end
        end
    end
    
    return true
end

-- Получение уровня аксессуара по instanceId
function AccessorySystem:getAccessoryLevelById(player, instanceId)
    if not player then return nil end
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    return ownedAccessory and ownedAccessory.level or 1
end

-- Получение уровня модификатора по instanceId
function AccessorySystem:getModifierLevelById(player, instanceId, modifierIndex)
    if not player then return nil end
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory or not ownedAccessory.modifierLevels then return 1 end
    return ownedAccessory.modifierLevels[modifierIndex] or 1
end

-- Получение количества экипированных аксессуаров категории
function AccessorySystem:getEquippedCount(player, category)
    local character = player.Character
    if not character then return 0 end
    local count = 0
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute("Category") == category then
            count += 1
        end
    end
    return count
end

-- Получение конфига аксессуара
function AccessorySystem:getAccessoryConfig(accessoryName)
    return self.accessories[accessoryName]
end

-- Получение информации об аксессуарах игрока
function AccessorySystem:GetPlayerAccessories(player)
    if not player or not player.Character then return {} end
    
    local accessories = {}
    for _, child in ipairs(player.Character:GetChildren()) do
        if child:GetAttribute("IsPrimary") == true then
            local instanceId = child:GetAttribute("InstanceId")
            local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
            if ownedAccessory then
                local accessoryName = ownedAccessory.name
                local config = self.accessories[accessoryName]
                if config then
                    local accessoryInfo = {
                        InstanceId = instanceId,
                        Name = accessoryName,
                        Category = config.category,
                        Level = ownedAccessory.level or 1,
                        Modifiers = {}
                    }
                    
                    if config.modifiers then
                        for i, modifier in ipairs(config.modifiers) do
                            local modifierValue = child:GetAttribute("Modifier_"..i.."_Value")
                            if modifierValue then
                                table.insert(accessoryInfo.Modifiers, {
                                    Type = modifier.type,
                                    Value = modifierValue,
                                    Operation = modifier.operation,
                                    Level = ownedAccessory.modifierLevels and ownedAccessory.modifierLevels[i] or 1,
                                    MaxLevel = modifier.maxLevel,
                                    GlobalUpgrade = child:GetAttribute("Modifier_"..i.."_Global")
                                })
                            end
                        end
                    end
                    
                    table.insert(accessories, accessoryInfo)
                end
            end
        end
    end
    
    return accessories
end

-- Метод: Получение информации о всех аксессуарах
function AccessorySystem:GetAllAccessoriesInfo()
    local accessoriesInfo = {}
    for name, config in pairs(self.accessories) do
        table.insert(accessoriesInfo, {
            name = name,
            accessoryType = config.accessoryType or "Unknown",
            category = config.category or "Uncategorized",
            cost = config.cost or 0,
            currency = config.currency or "Coins",
            description = config.description or "No description",
            imageId = config.imageId or "",
            purchaseLimit = config.purchaseLimit or 1,
            maxLevel = config.level and config.level.max or nil,
            modifiers = config.modifiers,
            deathSettings = getDeathSettings(config)
        })
    end
    return accessoriesInfo
end

-- Метод: Получение аксессуаров по категории
function AccessorySystem:GetAccessoriesByCategory(category)
    local categoryAccessories = {}
    for name, config in pairs(self.accessories) do
        if config.category == category then
            table.insert(categoryAccessories, {
                name = name,
                accessoryType = config.accessoryType or "Unknown",
                category = config.category or "Uncategorized",
                cost = config.cost or 0,
                currency = config.currency or "Coins",
                description = config.description or "No description",
                imageId = config.imageId or "",
                purchaseLimit = config.purchaseLimit or 1,
                maxLevel = config.level and config.level.max or nil,
                modifiers = config.modifiers,
                deathSettings = getDeathSettings(config)
            })
        end
    end
    return categoryAccessories
end

-- Метод: Получение информации об аксессуаре
function AccessorySystem:GetAccessoryInfo(accessoryName)
    local config = self.accessories[accessoryName]
    if not config then return nil end
    
    return {
        name = accessoryName,
        accessoryType = config.accessoryType or "Unknown",
        category = config.category or "Uncategorized",
        cost = config.cost or 0,
        currency = config.currency or "Coins",
        description = config.description or "No description",
        imageId = config.imageId or "",
        purchaseLimit = config.purchaseLimit or 1,
        maxLevel = config.level and config.level.max or nil,
        modifiers = config.modifiers,
        deathSettings = getDeathSettings(config)
    }
end

-- Метод: Получение информации о слотах
function AccessorySystem:GetSlotInfo(player)
    local slotInfo = {}
    for category, maxSlots in pairs(self.maxCategorySlots) do
        slotInfo[category] = {
            Current = self:getEquippedCount(player, category),
            Max = maxSlots
        }
    end
    return slotInfo
end

-- Метод: Добавление аксессуара в инвентарь
function AccessorySystem:AddAccessoryToInventory(player, accessoryInfo)
    if not player then
        return nil, "Player is nil"
    end
    
    local dataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
    if not dataManager then
        return nil, "DataManager not found"
    end
    
    if not accessoryInfo or not accessoryInfo.name then
        return nil, "Invalid accessory info"
    end
    
    if not self.accessories[accessoryInfo.name] then
        return nil, "Accessory '"..accessoryInfo.name.."' not found in config"
    end
    
    local accessoryConfig = self.accessories[accessoryInfo.name]
    
    -- Получаем уровни по умолчанию из конфига, если не указаны
    local defaultLevel, defaultModifierLevels = getDefaultAccessoryLevels(accessoryConfig)
    local level = accessoryInfo.level or defaultLevel
    local modifierLevels = accessoryInfo.modifierLevels or defaultModifierLevels

    local instanceId = HttpService:GenerateGUID(false)
    local accessoryData = {
        name = accessoryInfo.name,
        level = level,
        modifierLevels = modifierLevels,
        obtainedTime = os.time(),
        obtainedMethod = accessoryInfo.obtainedMethod or "given"
    }
    
    local success = saveOwnedAccessory(player, instanceId, accessoryData)
    if not success then
        return nil, "Failed to save accessory to inventory"
    end
    
    return instanceId, ""
end

-- Метод: Покупка аксессуара
function AccessorySystem:PurchaseAccessory(player, accessoryName)
    if not player then
        return nil, "Player is nil"
    end
    
    local dataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
    if not dataManager then
        return nil, "DataManager not found"
    end
    
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then
        return nil, "Accessory '"..accessoryName.."' not found in config"
    end
    
    -- Проверяем, есть ли цена у аксессуара
    if not accessoryConfig.cost then
        return nil, "Accessory '"..accessoryName.."' is not available for purchase"
    end
    
    -- Проверка лимита покупки
    if not checkPurchaseLimit(player, accessoryConfig) then
        return nil, "Purchase limit reached for accessory '"..accessoryName.."'"
    end
    
    -- Используем валюту из конфига аксессуара или "Coins" по умолчанию
    local currencyName = accessoryConfig.currency or "Coins"
    
    -- Проверяем баланс игрока
    local currentBalance = getPlayerCurrency(player, currencyName)
    if currentBalance < accessoryConfig.cost then
        return nil, "Not enough "..currencyName.." to purchase accessory '"..accessoryName.."'"
    end
    
    -- Списываем валюту
    local success = updatePlayerCurrency(player, currencyName, -accessoryConfig.cost)
    if not success then
        return nil, "Failed to deduct currency for accessory purchase"
    end
    
    -- Создаем информацию об аксессуаре
    local accessoryInfo = {
        name = accessoryName,
        level = accessoryConfig.level and accessoryConfig.level.initial or 1,
        modifierLevels = {},
        obtainedMethod = "purchased"
    }
    
    if not accessoryConfig.level and accessoryConfig.modifiers then
        for i, modifier in ipairs(accessoryConfig.modifiers) do
            if modifier.initial then
                accessoryInfo.modifierLevels[i] = modifier.initial
            end
        end
    end
    
    -- Добавляем аксессуар в инвентарь
    local instanceId, err = self:AddAccessoryToInventory(player, accessoryInfo)
    if not instanceId then
        -- Возвращаем валюту в случае ошибки
        updatePlayerCurrency(player, currencyName, accessoryConfig.cost)
        return nil, "Failed to add accessory to inventory: " .. err
    end
    
    return instanceId, ""
end

-- Метод: Получение аксессуаров в инвентаре
function AccessorySystem:GetOwnedAccessories(player)
    if not player then
        return nil, "Player is nil"
    end
    
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return {} end
    
    local accessories = {}
    for instanceId, accessoryInfo in pairs(accessoryData.ownedAccessories) do
        local accessoryData = {
            id = instanceId,
            name = accessoryInfo.name,
            level = accessoryInfo.level,
            modifierLevels = accessoryInfo.modifierLevels,
            obtainedTime = accessoryInfo.obtainedTime,
            obtainedMethod = accessoryInfo.obtainedMethod,
            isEquipped = isAccessoryEquipped(player, instanceId)
        }
        table.insert(accessories, accessoryData)
    end
    return accessories, ""
end

-- Метод: Удаление аксессуара из инвентаря
function AccessorySystem:RemoveAccessoryFromInventory(player, instanceId)
    if not player then
        return false, "Player is nil"
    end
    
    -- Сначала снимаем аксессуар если он экипирован
    if isAccessoryEquipped(player, instanceId) then
        local success, err = self:unequipAccessoryById(player, instanceId)
        if not success then
            return false, "Failed to unequip accessory: " .. (err or "unknown error")
        end
    end
    
    -- Удаляем из инвентаря
    local success = removeOwnedAccessory(player, instanceId)
    if not success then
        return false, "Failed to remove accessory from inventory"
    end
    
    return true, ""
end

-- Метод: Снятие всех модификаторов аксессуаров
function AccessorySystem:RemoveAllAccessoryModifiers(player)
    if not player then return false, "Player is nil" end
    
    -- Получаем все экипированные аксессуары и снимаем их модификаторы
    local accessoryData = getPlayerAccessoryData(player)
    if accessoryData and accessoryData.equippedAccessories then
        for instanceId, _ in pairs(accessoryData.equippedAccessories) do
            local ownedAccessory = accessoryData.ownedAccessories[instanceId]
            if ownedAccessory then
                local accessoryConfig = self.accessories[ownedAccessory.name]
                if accessoryConfig then
                    applyModifiers(
                        player, 
                        ownedAccessory.name, 
                        instanceId, 
                        accessoryConfig, 
                        ownedAccessory.level, 
                        ownedAccessory.modifierLevels, 
                        false
                    )
                end
            end
        end
    end
    
    return true, ""
end

-- Метод: Повторное применение модификаторов аксессуаров
function AccessorySystem:ReapplyAccessoryModifiers(player)
    if not player then 
        return false, "Player is nil"
    end
    
    -- Снимаем все модификаторы
    self:RemoveAllAccessoryModifiers(player)
    
    -- Применяем заново все модификаторы экипированных аксессуаров
    local accessoryData = getPlayerAccessoryData(player)
    if accessoryData and accessoryData.equippedAccessories then
        for instanceId, _ in pairs(accessoryData.equippedAccessories) do
            local ownedAccessory = accessoryData.ownedAccessories[instanceId]
            if ownedAccessory then
                local accessoryConfig = self.accessories[ownedAccessory.name]
                if accessoryConfig then
                    applyModifiers(
                        player, 
                        ownedAccessory.name, 
                        instanceId, 
                        accessoryConfig, 
                        ownedAccessory.level, 
                        ownedAccessory.modifierLevels, 
                        true
                    )
                end
            end
        end
    end
    
    return true, ""
end

-- Метод: Разэкипировка всех аксессуаров
function AccessorySystem:UnequipAllAccessories(player)
    if not player then
        return false, "Player is nil"
    end
    
    if not player.Character then
        return false, "Character not found"
    end
    
    -- Получаем список экипированных аксессуаров
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then
        return true, "No accessories to unequip"
    end
    
    -- Снимаем все аксессуары
    local unequippedIds = {}
    for instanceId, _ in pairs(accessoryData.equippedAccessories) do
        local success, err = self:unequipAccessoryById(player, instanceId)
        if not success then
            warn("Failed to unequip accessory " .. instanceId .. ": " .. tostring(err))
        else
            table.insert(unequippedIds, instanceId)
        end
    end
    
    return true, ""
end

-- Метод: Удаление всех аксессуаров из инвентаря
function AccessorySystem:RemoveAllAccessoriesFromInventory(player)
    if not player then
        return false, "Player is nil"
    end
    
    -- Сначала снимаем все аксессуары
    self:UnequipAllAccessories(player)
    
    -- Получаем данные об аксессуарах
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then
        return true, "No accessories to remove"
    end
    
    -- Очищаем инвентарь
    accessoryData.ownedAccessories = {}
    accessoryData.equippedAccessories = {}
    
    -- Сохраняем изменения
    local success = savePlayerAccessoryData(player, accessoryData)
    if not success then
        return false, "Failed to save player data after removing accessories"
    end
    
    return true, ""
end

-- Метод: Продажа аксессуара
function AccessorySystem:SellAccessory(player, instanceId)
    if not player then
        return false, "Player is nil"
    end
    
    -- Получаем информацию об аксессуаре
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then
        return false, "Accessory not found in inventory"
    end
    
    -- Получаем конфиг аксессуара
    local accessoryConfig = self.accessories[ownedAccessory.name]
    if not accessoryConfig then
        return false, "Accessory config not found"
    end
    
    -- Проверяем, можно ли продать аксессуар (должна быть цена)
    if not accessoryConfig.cost or accessoryConfig.cost <= 0 then
        return false, "Accessory cannot be sold"
    end
    
    -- Вычисляем стоимость продажи (процент от исходной цены)
    local sellPercentage = self.config.sellPercentage or 0.5
    local sellPrice = math.floor(accessoryConfig.cost * sellPercentage)
    
    -- Удаляем аксессуар из инвентаря
    local success, err = self:RemoveAccessoryFromInventory(player, instanceId)
    if not success then
        return false, "Failed to remove accessory: " .. err
    end
    
    -- Добавляем валюту игроку
    local currencyName = accessoryConfig.currency or "Coins"
    local currencyAdded = updatePlayerCurrency(player, currencyName, sellPrice)
    if not currencyAdded then
        warn("Failed to add currency after selling accessory for player " .. player.Name)
        -- Но аксессуар уже удален, поэтому возвращаем успех, но с предупреждением
        return true, "Accessory sold but failed to add currency"
    end
    
    return true, sellPrice
end

-- Метод: Получение цены продажи аксессуара
function AccessorySystem:GetAccessorySellPrice(player, accessoryName)
    if not player then
        return 0, "Player is nil"
    end
    
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then
        return 0, "Accessory not found"
    end
    
    if not accessoryConfig.cost or accessoryConfig.cost <= 0 then
        return 0, "Accessory cannot be sold"
    end
    
    local sellPercentage = self.config.sellPercentage or 0.5
    return math.floor(accessoryConfig.cost * sellPercentage), ""
end

-- Метод: Получение цены продажи аксессуара по instanceId
function AccessorySystem:GetAccessorySellPriceById(player, instanceId)
    if not player then
        return 0, "Player is nil"
    end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then
        return 0, "Accessory not found in inventory"
    end
    
    return self:GetAccessorySellPrice(player, ownedAccessory.name)
end

-- Метод: Получение базовой стоимости аксессуара
function AccessorySystem:GetAccessoryBaseCost(accessoryName)
    local accessoryConfig = self.accessories[accessoryName]
    if not accessoryConfig then
        return 0
    end
    
    return accessoryConfig.cost or 0
end

-- Метод: Получение списка экипированных аксессуаров
function AccessorySystem:GetEquippedAccessories(player)
    if not player then return {} end
    
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return {} end
    
    local equipped = {}
    for instanceId, _ in pairs(accessoryData.equippedAccessories) do
        local ownedAccessory = accessoryData.ownedAccessories[instanceId]
        if ownedAccessory then
            table.insert(equipped, {
                instanceId = instanceId,
                name = ownedAccessory.name,
                level = ownedAccessory.level,
                modifierLevels = ownedAccessory.modifierLevels
            })
        end
    end
    
    return equipped
end

-- Метод: Получение полной информации об аксессуаре по instanceId
function AccessorySystem:GetAccessoryDetailsById(player, instanceId)
    if not player then return nil end
    
    local ownedAccessory = getOwnedAccessoryByInstanceId(player, instanceId)
    if not ownedAccessory then return nil end
    
    local accessoryConfig = self.accessories[ownedAccessory.name]
    if not accessoryConfig then return nil end
    
    return {
        instanceId = instanceId,
        name = ownedAccessory.name,
        config = accessoryConfig,
        level = ownedAccessory.level,
        modifierLevels = ownedAccessory.modifierLevels,
        obtainedTime = ownedAccessory.obtainedTime,
        obtainedMethod = ownedAccessory.obtainedMethod,
        isEquipped = isAccessoryEquipped(player, instanceId),
        sellPrice = self:GetAccessorySellPriceById(player, instanceId)
    }
end

-- Метод: Проверка возможности экипировки по instanceId
function AccessorySystem:CanEquipAccessoryById(player, instanceId)
    if not player then return false, "Player is nil" end
    return canEquipAccessoryById(player, instanceId)
end

-- Обработка смерти персонажа
local function onCharacterDied(character, player)
    if not systemInstance then return end
    
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return end
    
    -- Снимаем все модификаторы
    systemInstance:RemoveAllAccessoryModifiers(player)
    
    -- Удаляем аксессуары, помеченные для удаления из инвентаря
    local accessoriesToRemove = {}
    
    for instanceId, ownedAccessory in pairs(accessoryData.ownedAccessories) do
        local accessoryConfig = systemInstance.accessories[ownedAccessory.name]
        if accessoryConfig then
            local deathSettings = getDeathSettings(accessoryConfig)
            if deathSettings.removeFromInventory then
                table.insert(accessoriesToRemove, instanceId)
            end
        end
    end
    
    -- Удаляем аксессуары из инвентаря
    for _, instanceId in ipairs(accessoriesToRemove) do
        removeOwnedAccessory(player, instanceId)
        removeFromEquippedAccessories(player, instanceId)
    end
    
    -- Очищаем список экипированных аксессуаров
    accessoryData.equippedAccessories = {}
    savePlayerAccessoryData(player, accessoryData)
    
    -- Удаляем все видимые части аксессуаров
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute("AccessoryName") then
            child:Destroy()
        end
    end
end

-- Экипировка аксессуаров при респавне
local function onCharacterRespawn(player, self)
    if not player or not player.Character then return end
    
    local character = player.Character
    local accessoryData = getPlayerAccessoryData(player)
    if not accessoryData then return end
    
    -- Экипируем аксессуары, которые должны оставаться после смерти
    for instanceId, _ in pairs(accessoryData.equippedAccessories) do
        local ownedAccessory = accessoryData.ownedAccessories[instanceId]
        if ownedAccessory then
            local accessoryConfig = self.accessories[ownedAccessory.name]
            if accessoryConfig then
                local deathSettings = getDeathSettings(accessoryConfig)
                if deathSettings.reequipOnRespawn then
                    -- Проверяем, не экипирован ли уже аксессуар
                    if not isAccessoryEquipped(player, instanceId) then
                        local canEquip, _ = canEquipAccessoryById(player, instanceId)
                        if canEquip then
                            self:equipAccessoryById(player, instanceId)
                        end
                    end
                end
            end
        end
    end
    
    -- Экипируем дефолтные аксессуары, если слоты свободны
    if self.config.defaultAccessories then
        for _, accessoryName in ipairs(self.config.defaultAccessories) do
            -- Ищем instanceId дефолтного аксессуара в инвентаре
            for instanceId, ownedAccessory in pairs(accessoryData.ownedAccessories) do
                if ownedAccessory.name == accessoryName then
                    local accessoryConfig = self.accessories[accessoryName]
                    if accessoryConfig then
                        local canEquip, _ = canEquipAccessoryById(player, instanceId)
                        if canEquip and not isAccessoryEquipped(player, instanceId) then
                            task.spawn(function()
                                local success, err = pcall(function()
                                    self:equipAccessoryById(player, instanceId)
                                end)
                                if not success then
                                    warn("Failed to equip default accessory: " .. accessoryName .. " for " .. player.Name .. " | Error: " .. tostring(err))
                                end
                            end)
                        end
                    end
                    break
                end
            end
        end
    end
end

-- Обработчик добавления персонажа
local function onCharacterAdded(character, player, self)
    -- Ждем загрузки данных игрока
    local maxWait = 30
    local waited = 0
    
    -- Ждем установки атрибута DataLoaded
    while waited < maxWait do
        local dataLoaded = player:GetAttribute("DataLoaded")
        if dataLoaded == true then
            break
        end
        
        -- Также проверяем через DataManager, если он доступен
        if self.dataManager and self.dataManager.IsDataLoaded then
            local success, isLoaded = pcall(function()
                return self.dataManager:IsDataLoaded(player)
            end)
            if success and isLoaded then
                break
            end
        end
        
        task.wait(0.1)
        waited = waited + 1
    end
    
    if waited >= maxWait then
        warn("[AccessorySystem] Timeout waiting for player data: " .. player.Name)
        -- Продолжаем без данных, чтобы не блокировать игру
        return
    end
    
    -- Небольшая дополнительная задержка для гарантии
    task.wait(0.5)
    
    -- Экипируем аксессуары из сохраненных данных
    local accessoryData = getPlayerAccessoryData(player)
    if accessoryData and accessoryData.equippedAccessories then
        for instanceId, _ in pairs(accessoryData.equippedAccessories) do
            local ownedAccessory = accessoryData.ownedAccessories[instanceId]
            if ownedAccessory then
                -- Проверяем, не экипирован ли уже
                if not isAccessoryEquipped(player, instanceId) then
                    local success, err = self:equipAccessoryById(player, instanceId)
                    if not success then
                        warn("[AccessorySystem] Failed to equip accessory " .. instanceId .. " for player " .. player.Name .. ": " .. tostring(err))
                    end
                end
            end
        end
    end
    
    -- Подключаемся к событию смерти
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        onCharacterDied(character, player)
    end)
    
    -- Обрабатываем респавн
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if humanoid.Health > 0 and humanoid:GetState() == Enum.HumanoidStateType.GettingUp then
            onCharacterRespawn(player, self)
        end
    end)
end

-- Экипировка аксессуаров по умолчанию
local function equipDefaultAccessories(player, self)
    if not self.config.defaultAccessories or #self.config.defaultAccessories == 0 then return end

    if not player or not player.Parent then return end
    
    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
        if not character or not character:IsDescendantOf(workspace) then return end
    end

    for _, accessoryName in ipairs(self.config.defaultAccessories) do
        task.spawn(function()
            -- Проверяем наличие в инвентаре перед экипировкой
            local accessoryData = getPlayerAccessoryData(player)
            local foundInstanceId = nil
            
            if accessoryData then
                for instanceId, ownedAccessory in pairs(accessoryData.ownedAccessories) do
                    if ownedAccessory.name == accessoryName then
                        foundInstanceId = instanceId
                        break
                    end
                end
            end
            
            if not foundInstanceId then
                -- Добавляем дефолтный аксессуар в инвентарь
                local accessoryInfo = {
                    name = accessoryName,
                    level = 1,
                    obtainedMethod = "default"
                }
                local instanceId, err = self:AddAccessoryToInventory(player, accessoryInfo)
                if not instanceId then
                    warn("[AccessorySystem] Failed to add default accessory to inventory: " .. tostring(err))
                    return
                end
                foundInstanceId = instanceId
            end
            
            -- Пытаемся экипировать
            local success, err = pcall(function()
                self:equipAccessoryById(player, foundInstanceId)
            end)
            if not success then
                warn("[AccessorySystem] Failed to equip default accessory: " .. accessoryName .. " for " .. player.Name .. " | Error: " .. tostring(err))
            end
        end)
    end
end

-- Инициализация системы
function AccessorySystem.Init(configPath)
    if systemInstance then 
        warn("[AccessorySystem] System already initialized")
        return systemInstance, ""
    end
    
    local success, config = pcall(require, configPath)
    if not success then
        return nil, "Failed to load accessory system config: " .. tostring(config)
    end

    -- Проверяем доступность DataManager
    local dataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
    if not dataManager then
        warn("[AccessorySystem] DataManager not found. Some functions may not work.")
    end

    local self = setmetatable({
        config = config,
        accessories = {},
        maxCategorySlots = config.maxCategorySlots or {},
        accessoryCache = {},
        dataManager = dataManager,
        sellPercentage = config.sellPercentage or 0.5  -- Процент возврата при продаже
    }, AccessorySystem)

    -- Загрузка и валидация аксессуаров
    for _, accessoryConfig in ipairs(config.accessories) do
        local isValid, errorMsg = validateAccessoryConfig(accessoryConfig)
        if isValid then
            self.accessories[accessoryConfig.name] = accessoryConfig
            self:loadAccessoryToCache(accessoryConfig)
        else
            warn("[AccessorySystem] Invalid accessory config: " .. errorMsg)
        end
    end

    local function handlePlayer(player)
        player.CharacterAdded:Connect(function(character)
            onCharacterAdded(character, player, self)
            if player and player.Parent then
                equipDefaultAccessories(player, self)
            end
        end)
        
        if player.Character then
            task.spawn(function()
                onCharacterAdded(player.Character, player, self)
                if player and player.Parent then
                    equipDefaultAccessories(player, self)
                end
            end)
        end
    end

    Players.PlayerAdded:Connect(handlePlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(handlePlayer, player)
    end

    systemInstance = self
    return self, ""
end

return AccessorySystem