local DataManager = {}
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Локальные переменные
local Config = nil
local playerDataCache = {}
local updateQueues = {}
local isInitialized = false
local shutdownFlag = false
local shutdownEvent = Instance.new("BindableEvent")
local activeTemporaryModifiers = {}

-- Создание объектов данных
local function createDataObject(parent, name, valueType, value)
    local obj
    if valueType == "number" then
        obj = Instance.new("NumberValue")
    elseif valueType == "boolean" then
        obj = Instance.new("BoolValue")
    elseif valueType == "string" then
        obj = Instance.new("StringValue")
    end
    if obj then
        obj.Name = name
        obj.Value = value
        obj.Parent = parent
    end
    return obj
end

-- Пересчет вычисляемых параметров
local function recalculateComputedParam(computedFolder)
    if not computedFolder then return end
    
    local baseValue = computedFolder.BaseValue.Value
    local addTotal = 0
    local baseMultiplier = 1
    local totalMultiplier = 1
    
    for _, mod in ipairs(computedFolder.Modifiers:GetChildren()) do
        local op = mod:GetAttribute("Operation")
        local val = mod.Value
        
        if op == "Add" then
            addTotal += val
        elseif op == "MultiplyBase" then
            baseMultiplier *= val
        elseif op == "MultiplyTotal" then
            totalMultiplier *= val
        end
    end
    
    local computedValue = (baseValue * baseMultiplier + addTotal) * totalMultiplier
    computedFolder.CurrentValue.Value = computedValue
end

local function setupModifierListeners(modifier, computedFolder)
    if not modifier:IsA("ValueBase") then
        return
    end
    
    local function recalc()
        recalculateComputedParam(computedFolder)
    end

    modifier.Changed:Connect(recalc)
    modifier:GetAttributeChangedSignal("Operation"):Connect(recalc)
end

-- Управление временными модификаторами
local function cleanupExpiredModifiers(player)
    local userId = tostring(player.UserId)
    if not activeTemporaryModifiers[userId] then return end
    
    local currentTime = os.time()
    local toRemove = {}
    
    for modifierId, modifierData in pairs(activeTemporaryModifiers[userId]) do
        if currentTime >= modifierData.expireTime then
            table.insert(toRemove, {modifierId, modifierData.paramName})
        end
    end
    
    for _, removalData in ipairs(toRemove) do
        local modifierId, paramName = removalData[1], removalData[2]
        DataManager.RemoveModifier(player, paramName, modifierId)
        activeTemporaryModifiers[userId][modifierId] = nil
    end
end

local function startModifierCleanupLoop(player)
    local userId = tostring(player.UserId)
    
    task.spawn(function()
        while player:IsDescendantOf(game) and not shutdownFlag do
            cleanupExpiredModifiers(player)
            task.wait(1) -- Проверяем каждую секунду
        end
    end)
end

-- Сохранение временных модификаторов в данные
local function saveTemporaryModifiersToData(player)
    -- Проверяем, включено ли сохранение временных модификаторов в конфиге
    if not Config.DataStoreOptions.SaveTemporaryModifiers then
        return
    end
    
    local userId = tostring(player.UserId)
    if not activeTemporaryModifiers[userId] then return end
    
    local tempModifiersData = {}
    local currentTime = os.time()
    
    for modifierId, modifierData in pairs(activeTemporaryModifiers[userId]) do
        local remainingTime = math.max(0, modifierData.expireTime - currentTime)
        if remainingTime > 0 then
            tempModifiersData[modifierId] = {
                paramName = modifierData.paramName,
                value = modifierData.value,
                operation = modifierData.operation,
                source = modifierData.source,
                remainingTime = remainingTime
            }
        end
    end
    
    -- Обновляем данные игрока
    if playerDataCache[player] then
        playerDataCache[player].temporaryModifiers = tempModifiersData
        
        -- Обновляем SavedData если существует
        local savedData = player:FindFirstChild("SavedData")
        if savedData then
            local tempModsValue = savedData:FindFirstChild("temporaryModifiers")
            if tempModsValue then
                tempModsValue:Destroy()
            end
            -- Сохраняем как строку JSON
            local json = game:GetService("HttpService"):JSONEncode(tempModifiersData)
            createDataObject(savedData, "temporaryModifiers", "string", json)
        end
    end
end

-- Восстановление временных модификаторов из данных
local function restoreTemporaryModifiers(player)
    if not playerDataCache[player] or not playerDataCache[player].temporaryModifiers then
        return
    end
    
    local tempModifiersData = playerDataCache[player].temporaryModifiers
    local userId = tostring(player.UserId)
    
    if not activeTemporaryModifiers[userId] then
        activeTemporaryModifiers[userId] = {}
    end
    
    for modifierId, modifierData in pairs(tempModifiersData) do
        local currentTime = os.time()
        local expireTime = currentTime + modifierData.remainingTime
        
        -- Добавляем модификатор с атрибутом ExpireTime
        DataManager.AddModifier(
            player,
            modifierData.paramName,
            modifierId,
            modifierData.value,
            modifierData.operation,
            modifierData.source
        )
        
        -- Устанавливаем атрибут ExpireTime для модификатора
        local computedData = player:FindFirstChild("ComputedData")
        if computedData then
            local paramFolder = computedData:FindFirstChild(modifierData.paramName)
            if paramFolder then
                local modifiers = paramFolder:FindFirstChild("Modifiers")
                if modifiers then
                    local modifier = modifiers:FindFirstChild(modifierId)
                    if modifier then
                        modifier:SetAttribute("ExpireTime", expireTime)
                        modifier:SetAttribute("IsTemporary", true)
                    end
                end
            end
        end
        
        -- Сохраняем данные для автоматического удаления
        activeTemporaryModifiers[userId][modifierId] = {
            paramName = modifierData.paramName,
            value = modifierData.value,
            operation = modifierData.operation,
            source = modifierData.source,
            expireTime = expireTime
        }
        
        -- Запускаем таймер удаления
        task.delay(modifierData.remainingTime, function()
            if player:IsDescendantOf(game) then
                DataManager.RemoveModifier(player, modifierData.paramName, modifierId)
                if activeTemporaryModifiers[userId] then
                    activeTemporaryModifiers[userId][modifierId] = nil
                end
            end
        end)
    end
end

-- Инициализация
function DataManager.Init(configPath)
    if isInitialized then return true end

    shutdownFlag = false

    local success, loadedConfig = pcall(require, configPath)
    if not success then
        warn("[DataManager] Failed to load config: " .. tostring(loadedConfig))
        return false, "ConfigLoadError"
    end

    Config = loadedConfig
    
    -- Устанавливаем значение по умолчанию для SaveTemporaryModifiers если не указано
    if Config.DataStoreOptions.SaveTemporaryModifiers == nil then
        Config.DataStoreOptions.SaveTemporaryModifiers = false
    end
    
    isInitialized = true

    -- Обработка уже подключенных игроков
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(DataManager.OnPlayerAdded, player)
    end

    -- Подключение обработчиков
    Players.PlayerAdded:Connect(DataManager.OnPlayerAdded)
    Players.PlayerRemoving:Connect(DataManager.OnPlayerRemoving)

    -- Привязка к завершению сервера
    game:BindToClose(function()
        shutdownFlag = true
        shutdownEvent:Fire()
        DataManager.SaveAllPlayers(true)
    end)

    -- Автосохранение
    task.spawn(function()
        while true do
            local success, result = pcall(function()
                return shutdownEvent.Event:Wait(Config.DataStoreOptions.SaveInterval)
            end)
            
            if shutdownFlag then break end
            if success and not result then -- Таймаут
                DataManager.AutoSaveAllPlayers()
            end
        end
    end)

    return true
end

-- Защищенная загрузка данных игрока
function DataManager.OnPlayerAdded(player)
    if not isInitialized or shutdownFlag then 
        if shutdownFlag then
            playerDataCache[player] = table.clone(Config.DefaultData)
            DataManager.CreatePlayerDataFolders(player, Config.DefaultData)
            player:SetAttribute("DataLoaded", true)
        end
        return 
    end

    player:SetAttribute("DataLoaded", false)
    
    local userId = tostring(player.UserId)
    local dataStore = DataStoreService:GetDataStore(
        Config.DataStoreOptions.Name,
        Config.DataStoreOptions.Scope
    )

    updateQueues[userId] = {
        Busy = false,
        Queue = {},
        Active = true
    }

    local loadedData
    local retries = Config.DataStoreOptions.Retries
    local lastError = "No error recorded"

    for attempt = 1, retries + 1 do
        if shutdownFlag then 
            lastError = "Server shutdown during load"
            break 
        end
        
        local success, result = pcall(dataStore.GetAsync, dataStore, userId)
        if success then
            loadedData = result
            break
        else
            lastError = tostring(result) or "Unknown error"
            local waitStart = os.clock()
            while os.clock() - waitStart < Config.DataStoreOptions.WriteTimeout do
                if shutdownFlag then break end
                task.wait(0.1)
            end
        end
    end

    if shutdownFlag then
        loadedData = table.clone(Config.DefaultData)
    end

    if not loadedData then
        warn(string.format(
            "[DataManager] Failed to load data for %s (%s), using defaults. Error: %s",
            player.Name, userId, lastError
        ))
        loadedData = table.clone(Config.DefaultData)
    end

    playerDataCache[player] = loadedData
    DataManager.CreatePlayerDataFolders(player, loadedData)
    
    -- Восстанавливаем временные модификаторы после создания папок
    restoreTemporaryModifiers(player)
    
    player:SetAttribute("DataLoaded", true)
    
    -- Запускаем цикл очистки для игрока
    startModifierCleanupLoop(player)
end

-- Создание папок данных игрока
function DataManager.CreatePlayerDataFolders(player, data)
    -- Удаляем старые папки если есть
    local oldSavedData = player:FindFirstChild("SavedData")
    if oldSavedData then oldSavedData:Destroy() end
    
    local oldComputedData = player:FindFirstChild("ComputedData")
    if oldComputedData then oldComputedData:Destroy() end

    -- Папка сохраняемых данных
    local savedData = Instance.new("Folder")
    savedData.Name = "SavedData"
    savedData.Parent = player

    for key, value in pairs(data) do
        local valueType = type(value)
        if valueType == "number" or valueType == "boolean" or valueType == "string" then
            createDataObject(savedData, key, valueType, value)
        end
    end

    -- Папка вычисляемых данных
    local computedData = Instance.new("Folder")
    computedData.Name = "ComputedData"
    computedData.Parent = player

    for param, config in pairs(Config.ComputedFields) do
        local computedFolder = Instance.new("Folder")
        computedFolder.Name = param
        computedFolder.Parent = computedData

        local baseValue = createDataObject(computedFolder, "BaseValue", "number", config.base)
        local currentValue = createDataObject(computedFolder, "CurrentValue", "number", config.base)
        
        local modifiers = Instance.new("Folder")
        modifiers.Name = "Modifiers"
        modifiers.Parent = computedFolder

        -- Слушатели для базового значения
        baseValue.Changed:Connect(function()
            recalculateComputedParam(computedFolder)
        end)

        -- Слушатели для папки модификаторов
        modifiers.ChildAdded:Connect(function(child)
            setupModifierListeners(child, computedFolder)
            recalculateComputedParam(computedFolder)
        end)

        modifiers.ChildRemoved:Connect(function()
            recalculateComputedParam(computedFolder)
        end)

        -- Установка слушателей для существующих модификаторов
        for _, child in ipairs(modifiers:GetChildren()) do
            setupModifierListeners(child, computedFolder)
        end

        -- Первоначальный расчет
        recalculateComputedParam(computedFolder)
    end
end

-- Метод проверки загрузки данных
function DataManager.IsDataLoaded(player)
    return player:GetAttribute("DataLoaded") == true
end

-- Добавление модификатора
function DataManager.AddModifier(player, paramName, modifierId, value, operation, source)
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then return false end
    
    local paramFolder = computedData:FindFirstChild(paramName)
    if not paramFolder then return false end
    
    local modifiers = paramFolder:FindFirstChild("Modifiers")
    if not modifiers then return false end
    
    -- Удаляем существующий модификатор с таким же ID
    local existing = modifiers:FindFirstChild(modifierId)
    if existing then existing:Destroy() end
    
    -- Создаем новый модификатор
    local modifier = Instance.new("NumberValue")
    modifier.Name = modifierId
    modifier.Value = value
    modifier:SetAttribute("Operation", operation)
    modifier:SetAttribute("Source", source)
    modifier.Parent = modifiers
    
    return true
end

-- Добавление временного модификатора
function DataManager.AddTemporaryModifier(player, paramName, modifierId, value, operation, source, duration, saveToData)
    -- Используем переданное значение saveToData или значение из конфига по умолчанию
    local shouldSaveToData = saveToData
    if shouldSaveToData == nil then
        shouldSaveToData = Config.DataStoreOptions.SaveTemporaryModifiers
    end
    
    if not DataManager.AddModifier(player, paramName, modifierId, value, operation, source) then
        return false
    end
    
    local expireTime = os.time() + duration
    
    -- Устанавливаем атрибут ExpireTime для модификатора
    local computedData = player:FindFirstChild("ComputedData")
    if computedData then
        local paramFolder = computedData:FindFirstChild(paramName)
        if paramFolder then
            local modifiers = paramFolder:FindFirstChild("Modifiers")
            if modifiers then
                local modifier = modifiers:FindFirstChild(modifierId)
                if modifier then
                    modifier:SetAttribute("ExpireTime", expireTime)
                    modifier:SetAttribute("IsTemporary", true)
                end
            end
        end
    end
    
    local userId = tostring(player.UserId)
    if not activeTemporaryModifiers[userId] then
        activeTemporaryModifiers[userId] = {}
    end
    
    -- Сохраняем информацию о временном модификаторе
    activeTemporaryModifiers[userId][modifierId] = {
        paramName = paramName,
        value = value,
        operation = operation,
        source = source,
        expireTime = expireTime,
        saveToData = shouldSaveToData
    }
    
    -- Если нужно сохранять в данные, обновляем сразу
    if shouldSaveToData then
        saveTemporaryModifiersToData(player)
    end
    
    -- Запускаем таймер удаления
    task.delay(duration, function()
        if player:IsDescendantOf(game) then
            DataManager.RemoveModifier(player, paramName, modifierId)
            if activeTemporaryModifiers[userId] then
                activeTemporaryModifiers[userId][modifierId] = nil
            end
        end
    end)
    
    return true
end

-- Удаление модификатора
function DataManager.RemoveModifier(player, paramName, modifierId)
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then return end
    
    local paramFolder = computedData:FindFirstChild(paramName)
    if not paramFolder then return end
    
    local modifiers = paramFolder:FindFirstChild("Modifiers")
    if not modifiers then return end
    
    local modifier = modifiers:FindFirstChild(modifierId)
    if modifier then
        modifier:Destroy()
        
        -- Удаляем из активных временных модификаторов
        local userId = tostring(player.UserId)
        if activeTemporaryModifiers[userId] and activeTemporaryModifiers[userId][modifierId] then
            activeTemporaryModifiers[userId][modifierId] = nil
        end
        
        return true
    end
    return false
end

-- Получение информации о временных модификаторах
function DataManager.GetTemporaryModifiersInfo(player)
    local userId = tostring(player.UserId)
    if not activeTemporaryModifiers[userId] then
        return {}
    end
    
    local result = {}
    local currentTime = os.time()
    
    for modifierId, modifierData in pairs(activeTemporaryModifiers[userId]) do
        local remainingTime = math.max(0, modifierData.expireTime - currentTime)
        result[modifierId] = {
            paramName = modifierData.paramName,
            value = modifierData.value,
            operation = modifierData.operation,
            source = modifierData.source,
            remainingTime = remainingTime,
            saveToData = modifierData.saveToData
        }
    end
    
    return result
end

-- Получение информации о модификаторе по его ID
function DataManager.GetModifierInfo(player, paramName, modifierId)
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then return nil end
    
    local paramFolder = computedData:FindFirstChild(paramName)
    if not paramFolder then return nil end
    
    local modifiers = paramFolder:FindFirstChild("Modifiers")
    if not modifiers then return nil end
    
    local modifier = modifiers:FindFirstChild(modifierId)
    if not modifier then return nil end
    
    local info = {
        value = modifier.Value,
        operation = modifier:GetAttribute("Operation"),
        source = modifier:GetAttribute("Source"),
        isTemporary = modifier:GetAttribute("IsTemporary"),
        expireTime = modifier:GetAttribute("ExpireTime")
    }
    
    if info.isTemporary and info.expireTime then
        info.remainingTime = math.max(0, info.expireTime - os.time())
    end
    
    return info
end

-- Выход игрока
function DataManager.OnPlayerRemoving(player)
    if shutdownFlag then return end

    local userId = tostring(player.UserId)
    
    if updateQueues[userId] then
        updateQueues[userId].Active = false
    end

    -- Сохраняем временные модификаторы перед выходом (если включено в конфиге)
    saveTemporaryModifiersToData(player)
    
    local success, err = pcall(DataManager.SavePlayer, player, true)
    if not success then
        warn(string.format("[DataManager] Final save failed for %s: %s", player.Name, tostring(err)))
    end

    task.delay(10, function()
        playerDataCache[player] = nil
        updateQueues[userId] = nil
        activeTemporaryModifiers[userId] = nil
    end)
end

-- Получение данных
function DataManager.GetData(player)
    if shutdownFlag then
        return nil, "SystemShutdown"
    end
    
    if not playerDataCache[player] then
        return nil, "PlayerDataNotLoaded"
    end
    
    return playerDataCache[player]
end

-- Получение вычисляемых данных игрока
function DataManager.GetComputedData(player)
    -- Проверяем загружены ли данные игрока
    if not DataManager.IsDataLoaded(player) then
        return nil, "PlayerDataNotLoaded"
    end
    
    local computedData = player:FindFirstChild("ComputedData")
    if not computedData then
        return nil, "NoComputedData"
    end
    
    local result = {}
    
    -- Обходим все параметры в ComputedData
    for _, paramFolder in ipairs(computedData:GetChildren()) do
        if paramFolder:IsA("Folder") then
            local currentValue = paramFolder:FindFirstChild("CurrentValue")
            if currentValue and currentValue:IsA("NumberValue") then
                result[paramFolder.Name] = currentValue.Value
            end
        end
    end
    
    return result
end

-- Обновление данных
function DataManager.UpdateData(player, updateCallback)
    if shutdownFlag then
        return false, "SystemShutdown"
    end
    
    local userId = tostring(player.UserId)
    local queue = updateQueues[userId]
    
    if not queue or not queue.Active then
        return false, "PlayerNotActive"
    end
    
    if not playerDataCache[player] then
        return false, "PlayerDataNotLoaded"
    end
    
    local updateTask = {
        Callback = updateCallback,
        Completed = false
    }
    
    table.insert(queue.Queue, updateTask)
    
    if not queue.Busy then
        queue.Busy = true
        task.spawn(function()
            while #queue.Queue > 0 and queue.Active and not shutdownFlag do
                local taskItem = table.remove(queue.Queue, 1)
                if type(taskItem.Callback) == "function" then
                    local success, newData = pcall(taskItem.Callback, table.clone(playerDataCache[player]))
                    if success and newData then
                        playerDataCache[player] = newData
                        
                        -- Обновление объектов в SavedData
                        local savedData = player:FindFirstChild("SavedData")
                        if savedData then
                            for key, value in pairs(newData) do
                                local valueType = type(value)
                                if valueType == "number" or valueType == "boolean" or valueType == "string" then
                                    local valueObj = savedData:FindFirstChild(key)
                                    if valueObj and valueObj:IsA("ValueBase") then
                                        valueObj.Value = value
                                    end
                                end
                            end
                        end
                    else
                        warn("[DataManager] Update callback error: " .. tostring(newData))
                    end
                end
                taskItem.Completed = true
            end
            queue.Busy = false
        end)
    end
    
    local startTime = os.clock()
    while not updateTask.Completed and queue.Active and not shutdownFlag do
        if os.clock() - startTime > Config.DataStoreOptions.QueueTimeout then
            return false, "QueueTimeout"
        end
        RunService.Heartbeat:Wait()
    end
    
    return updateTask.Completed
end

-- Сохранение данных
function DataManager.SavePlayer(player, isFinal)
    if shutdownFlag and not isFinal then
        return false, "SystemShutdown"
    end
    
    local userId = tostring(player.UserId)
    local queue = updateQueues[userId]
    
    if not playerDataCache[player] then
        return false, "PlayerDataNotLoaded"
    end
    
    if queue and not shutdownFlag then
        local startTime = os.clock()
        while queue.Busy or #queue.Queue > 0 do
            if os.clock() - startTime > Config.DataStoreOptions.QueueTimeout then
                break
            end
            RunService.Heartbeat:Wait()
        end
    end
    
    -- Сохраняем временные модификаторы перед сохранением данных (если включено в конфиге)
    saveTemporaryModifiersToData(player)
    
    local dataStore = DataStoreService:GetDataStore(
        Config.DataStoreOptions.Name,
        Config.DataStoreOptions.Scope
    )
    
    local retries = Config.DataStoreOptions.Retries
    local success, errorMessage
    local dataToSave = table.clone(playerDataCache[player])
    
    for attempt = 1, retries + 1 do
        if shutdownFlag and not isFinal then
            return false, "SystemShutdown"
        end
        
        success, errorMessage = pcall(dataStore.SetAsync, dataStore, userId, dataToSave)
        if success then
            break
        else
            errorMessage = tostring(errorMessage) or "Unknown error"
            warn(string.format(
                "[DataManager] Save attempt %d failed for %s. Error: %s",
                attempt, player.Name, errorMessage
            ))
            
            if attempt <= retries then
                local waitStart = os.clock()
                while os.clock() - waitStart < Config.DataStoreOptions.WriteTimeout do
                    if shutdownFlag and not isFinal then break end
                    task.wait(0.1)
                end
            end
        end
    end
    
    if not success then
        return false, errorMessage
    end
    
    return true
end

-- Автосохранение
function DataManager.AutoSaveAllPlayers()
    if shutdownFlag then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player:IsDescendantOf(game) and playerDataCache[player] then
            -- Сохраняем временные модификаторы перед автосохранением (если включено в конфиге)
            saveTemporaryModifiersToData(player)
            
            local success, err = pcall(DataManager.SavePlayer, player)
            if not success then
                warn(string.format("[DataManager] Autosave failed for %s: %s", player.Name, tostring(err)))
            end
        end
    end
end

-- Принудительное сохранение
function DataManager.SaveAllPlayers(isFinal)
    for _, player in ipairs(Players:GetPlayers()) do
        if player:IsDescendantOf(game) and playerDataCache[player] then
            -- Сохраняем временные модификаторы перед сохранением (если включено в конфиге)
            saveTemporaryModifiersToData(player)
            pcall(DataManager.SavePlayer, player, isFinal)
        end
    end
end

return DataManager