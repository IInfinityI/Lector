-- DioramaManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Загружаем модули
local DioramaFolder = ServerStorage:WaitForChild("Diorama")
local DioramaConfig = require(DioramaFolder:WaitForChild("DioramaConfig"))
local DioramaUtils = require(DioramaFolder:WaitForChild("DioramaUtils"))
local DioramaCustomization = require(DioramaFolder:WaitForChild("DioramaCustomization"))
local DioramaClass = require(DioramaFolder:WaitForChild("DioramaClass"))

-- DataStores
local criticalStore = DataStoreService:GetDataStore("DioramasData")
local customizationStore = DataStoreService:GetDataStore("DioramaCustomization")
local memoryLocks = MemoryStoreService:GetSortedMap("DioramaLocks")
local memoryCriticalCache = MemoryStoreService:GetSortedMap("DioramaCriticalCache")
local memoryCustCache = MemoryStoreService:GetSortedMap("DioramaCustCache")

-- Константы
local DIORAMA_CRITICAL_TOPIC = DioramaConfig.DIORAMA_CRITICAL_UPDATES_TOPIC
local SYNC_CHECK_INTERVAL = DioramaConfig.SYNC_CHECK_INTERVAL
local CUSTOMIZATION_SYNC_INTERVAL = DioramaConfig.CUSTOMIZATION_SYNC_INTERVAL
local CACHE_TTL = DioramaConfig.CACHE_TTL

-- Кэш диорам
local dioramaCache = {}
local dioramaSubscriptions = {}
local playerSubscriptions = {}

-- Загрузочный прогресс
local loadingProgressFolder = ReplicatedStorage:FindFirstChild("LoadingProgress")
if not loadingProgressFolder then
    loadingProgressFolder = Instance.new("Folder")
    loadingProgressFolder.Name = "LoadingProgress"
    loadingProgressFolder.Parent = ReplicatedStorage
end
local dioramasProgress = loadingProgressFolder:FindFirstChild("Dioramas")
if not dioramasProgress then
    dioramasProgress = Instance.new("Folder")
    dioramasProgress.Name = "Dioramas"
    dioramasProgress.Parent = loadingProgressFolder
    Instance.new("IntValue", dioramasProgress).Name = "Total"
    Instance.new("IntValue", dioramasProgress).Name = "Loaded"
end

-- Ожидание AssetService
local function waitForAssetService()
    local startTime = os.time()
    local timeout = 30
    while true do
        if _G.AssetService and _G.AssetService:IsLoaded() then
            local eventSystemStatus = _G.AssetService:GetAssetStatus("EventSystem")
            local PremiumSystemStatus = _G.AssetService:GetAssetStatus("PremiumContentSystem")
            if eventSystemStatus and eventSystemStatus.loaded and eventSystemStatus.moduleReference and PremiumSystemStatus then
                return true
            end
        end
        if os.time() - startTime > timeout then
            warn("[DioramaManager] Таймаут ожидания AssetService")
            return false
        end
        task.wait(1)
    end
end

if not waitForAssetService() then
    warn("Не удалось загрузить необходимые модули через AssetService")
    return
end

local EventSystem = _G.AssetService:GetModule("EventSystem")
if not EventSystem then
    warn("EventSystem не найден через AssetService")
    return
end

local PremiumContentSystem = _G.AssetService:GetModule("PremiumContentSystem")
if not PremiumContentSystem then
    warn("PremiumContentSystem не найден через AssetService")
    return
end

-- ==================== ПОДПИСКИ ====================

local function subscribePlayerToDiorama(player, dioramaId)
    local userId = player.UserId
    if not dioramaSubscriptions[dioramaId] then 
        dioramaSubscriptions[dioramaId] = {} 
    end
    if not playerSubscriptions[userId] then 
        playerSubscriptions[userId] = {} 
    end
    dioramaSubscriptions[dioramaId][userId] = true
    playerSubscriptions[userId][dioramaId] = true
end

local function unsubscribePlayerFromDiorama(player, dioramaId)
    local userId = player.UserId
    if dioramaSubscriptions[dioramaId] then 
        dioramaSubscriptions[dioramaId][userId] = nil 
    end
    if playerSubscriptions[userId] then 
        playerSubscriptions[userId][dioramaId] = nil 
    end
end

local function unsubscribePlayerFromAll(player)
    local userId = player.UserId
    if playerSubscriptions[userId] then
        for dioramaId, _ in pairs(playerSubscriptions[userId]) do
            if dioramaSubscriptions[dioramaId] then 
                dioramaSubscriptions[dioramaId][userId] = nil 
            end
        end
        playerSubscriptions[userId] = nil
    end
end

local function updateDioramaSubscribers(dioramaId, data)
    if not dioramaSubscriptions[dioramaId] then 
        print(string.format("[DioramaManager] updateDioramaSubscribers: нет подписчиков для %s", tostring(dioramaId)))
        return 
    end
    
    local subscriberCount = 0
    for userId, _ in pairs(dioramaSubscriptions[dioramaId]) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            subscriberCount = subscriberCount + 1
            print(string.format("[DioramaManager] Отправка обновления игроку %s для диорамы %s (OwnerId: %s)", 
                player.Name, tostring(dioramaId), tostring(data.OwnerId)))
            EventSystem.FireClient(player, "DioramaDataUpdated", dioramaId, data)
        end
    end
    
    print(string.format("[DioramaManager] updateDioramaSubscribers: отправлено %d обновлений для %s", 
        subscriberCount, tostring(dioramaId)))
end

-- Обновление всех диорам игрока
local function updatePlayerDioramas(player)
	local playerDioramas = {}
	local userId = player.UserId

	for dioramaId, diorama in pairs(dioramaCache) do
		if diorama.OwnerId == userId then
			-- Применяем множитель DioramaGoldMultiplier для владельца
			local accumulated = diorama:CalculateAccumulatedIncomeForPlayer(player)
			local maxAccumulated = diorama:GetMaxAccumulatedIncomeForPlayer(player)
			local incomeRate = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[diorama.Rarity] or 10

			playerDioramas[tostring(dioramaId)] = {
				SceneName = diorama.SceneName,
				AccumulatedIncome = accumulated,
				MaxAccumulatedIncome = maxAccumulated,
				IncomeRate = incomeRate,
				Rarity = diorama.Rarity,
				RarityName = DioramaConfig.RARITY_NAMES[diorama.Rarity] or diorama.Rarity
			}
		end
	end

	print(string.format("[DioramaManager] updatePlayerDioramas для %s: %d диорам", 
		player.Name, #playerDioramas))

	-- Всегда отправляем обновление, даже если список пуст (игрок потерял все диорамы)
	EventSystem.FireClient(player, "PlayerDioramasUpdated", playerDioramas)
end

-- ==================== MESSAGING SERVICE (ТОЛЬКО КРИТИЧЕСКИЕ) ====================

local function setupMessagingService()
    -- MessagingService подписка полностью обрабатывается в DioramaClass
    -- Здесь только логируем
    print("[DioramaManager] MessagingService управляется через DioramaClass")
end

-- Функция publishCriticalUpdate удалена - публикация происходит в DioramaClass

-- ==================== ПЕРИОДИЧЕСКАЯ ПРОВЕРКА СИНХРОНИЗАЦИИ ====================

-- Проверка критических данных (на случай потери сообщений)
local function startCriticalSyncCheck()
    while true do
        task.wait(SYNC_CHECK_INTERVAL)
        
        local checkedCount = 0
        local updatedCount = 0
        
        for dioramaId, diorama in pairs(dioramaCache) do
            -- Проверяем только диорамы с подписчиками
            if dioramaSubscriptions[dioramaId] and next(dioramaSubscriptions[dioramaId]) then
                checkedCount = checkedCount + 1
                
                local success, memoryData = pcall(function() 
                    return memoryCriticalCache:GetAsync(dioramaId) 
                end)
                
                if success and memoryData then
                    if memoryData.CriticalVersion > diorama.CriticalVersion then
                        updatedCount = updatedCount + 1
                        print(string.format("[SyncCheck] Обнаружены более новые критические данные для диорамы %s (локальная: %d, удалённая: %d)", 
                            tostring(dioramaId), diorama.CriticalVersion, memoryData.CriticalVersion))
                        
                        local applied, changeInfo = diorama:ApplyCriticalUpdate(memoryData)
                        if applied then
                            -- Обновляем подписчиков
                            updateDioramaSubscribers(dioramaId, diorama:GetData())
                            
                            -- Обрабатываем смену владельца
                            if changeInfo and changeInfo.ownerChanged then
                                print(string.format("[SyncCheck] Смена владельца: %s -> %s", 
                                    tostring(changeInfo.oldOwnerId), tostring(changeInfo.newOwnerId)))
                                
                                if changeInfo.oldOwnerId then
                                    local oldOwner = Players:GetPlayerByUserId(changeInfo.oldOwnerId)
                                    if oldOwner then
                                        EventSystem.FireClient(oldOwner, "DioramaOwnershipLost", dioramaId)
                                        updatePlayerDioramas(oldOwner)
                                    end
                                end
                                
                                if changeInfo.newOwnerId then
                                    local newOwner = Players:GetPlayerByUserId(changeInfo.newOwnerId)
                                    if newOwner then
                                        updatePlayerDioramas(newOwner)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if updatedCount > 0 then
            print(string.format("[SyncCheck] Проверено %d диорам, обновлено %d", checkedCount, updatedCount))
        end
    end
end

-- Проверка кастомизации (периодическая, eventual consistency)
local function startCustomizationSync()
    while true do
        task.wait(CUSTOMIZATION_SYNC_INTERVAL)
        
        local checkedCount = 0
        local updatedCount = 0
        
        for dioramaId, diorama in pairs(dioramaCache) do
            -- Проверяем только диорамы с подписчиками
            if dioramaSubscriptions[dioramaId] and next(dioramaSubscriptions[dioramaId]) then
                checkedCount = checkedCount + 1
                
                local success, custData = pcall(function() 
                    return memoryCustCache:GetAsync(dioramaId) 
                end)
                
                if success and custData then
                    if custData.CustomizationVersion > diorama.CustomizationVersion then
                        updatedCount = updatedCount + 1
                        print(string.format("[CustomizationSync] Обновление кастомизации для диорамы %s (локальная: %d, удалённая: %d)", 
                            dioramaId, diorama.CustomizationVersion, custData.CustomizationVersion))
                        if diorama:ApplyCustomizationUpdate(custData) then
                            updateDioramaSubscribers(dioramaId, diorama:GetData())
                        end
                    end
                end
            end
        end
        
        if updatedCount > 0 then
            print(string.format("[CustomizationSync] Проверено %d диорам, обновлено %d", checkedCount, updatedCount))
        end
    end
end

-- Периодическое обновление дохода для подписчиков
local function startAccumulatedIncomeUpdates()
    while true do
        task.wait(5)
        
        for dioramaId, diorama in pairs(dioramaCache) do
            if dioramaSubscriptions[dioramaId] and next(dioramaSubscriptions[dioramaId]) and diorama.OwnerId then
                local baseAccumulated = diorama:CalculateAccumulatedIncome()
                local baseMaxAccumulated = diorama:GetMaxAccumulatedIncome()
                local incomeRate = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[diorama.Rarity] or 10
                
                for userId, _ in pairs(dioramaSubscriptions[dioramaId]) do
                    local player = Players:GetPlayerByUserId(userId)
                    if player then
                        -- Для владельца применяем множитель, для остальных - базовые значения
                        local accumulated, maxAccumulated
                        if diorama.OwnerId == userId then
                            accumulated = diorama:CalculateAccumulatedIncomeForPlayer(player)
                            maxAccumulated = diorama:GetMaxAccumulatedIncomeForPlayer(player)
                        else
                            accumulated = baseAccumulated
                            maxAccumulated = baseMaxAccumulated
                        end
                        
                        local incomeData = {
                            SceneName = diorama.SceneName,
                            AccumulatedIncome = accumulated,
                            MaxAccumulatedIncome = maxAccumulated,
                            IncomeRate = incomeRate,
                            Rarity = diorama.Rarity,
                            RarityName = DioramaConfig.RARITY_NAMES[diorama.Rarity] or diorama.Rarity
                        }
                        
                        EventSystem.FireClient(player, "DioramaIncomeUpdated", dioramaId, incomeData)
                        
                        if diorama.OwnerId == userId then
                            local playerDioramasData = {}
                            playerDioramasData[tostring(dioramaId)] = incomeData
                            EventSystem.FireClient(player, "PlayerDioramasUpdated", playerDioramasData)
                        end
                    end
                end
            end
        end
    end
end

-- ==================== ЗАГРУЗКА ДАННЫХ ====================

local function loadDioramaData(dioramaId)
    -- Загружаем критические данные
    local criticalSuccess, criticalJson = pcall(function() 
        return criticalStore:GetAsync(dioramaId) 
    end)
    
    -- Загружаем кастомизацию
    local custSuccess, custJson = pcall(function() 
        return customizationStore:GetAsync(dioramaId) 
    end)
    
    local result = {}
    
    if criticalSuccess and criticalJson and criticalJson ~= "" then
        local criticalData = HttpService:JSONDecode(criticalJson)
        for k, v in pairs(criticalData) do
            result[k] = v
        end
    end
    
    if custSuccess and custJson and custJson ~= "" then
        local custData = HttpService:JSONDecode(custJson)
        for k, v in pairs(custData) do
            result[k] = v
        end
    end
    
    return result
end

-- Инициализация диорам
local function initDioramas()
    local dioramasFolder = workspace:FindFirstChild("Dioramas")
    if not dioramasFolder then
        dioramasFolder = Instance.new("Folder")
        dioramasFolder.Name = "Dioramas"
        dioramasFolder.Parent = workspace
    end

    local dioramaModels = dioramasFolder:GetChildren()
    dioramasProgress.Total.Value = #dioramaModels

    for _, dioramaModel in ipairs(dioramaModels) do
        if dioramaModel:IsA("Model") then
            local dioramaId = dioramaModel:GetAttribute("DioramaId") or dioramaModel.Name
            local initialData = loadDioramaData(dioramaId) or {}
            
            local callbacks = {
                onCriticalDataChanged = function(syncData)
                    -- Публикация происходит автоматически в DioramaClass:PublishCriticalUpdate()
                    -- Здесь только обновляем подписчиков локально
                    
                    print(string.format("[DioramaManager] onCriticalDataChanged для %s", tostring(dioramaId)))
                    
                    -- Обновляем подписчиков
                    local diorama = dioramaCache[dioramaId]
                    if diorama then
                        updateDioramaSubscribers(dioramaId, diorama:GetData())
                    end
                    
                    -- Обновляем данные владельца
                    if syncData.OwnerId then
                        local owner = Players:GetPlayerByUserId(syncData.OwnerId)
                        if owner then
                            updatePlayerDioramas(owner)
                        end
                    end
                end,
                onRemoteUpdate = function(updateData, changeInfo)
                    -- Вызывается при получении обновления от другого сервера
                    print(string.format("[DioramaManager] ========== onRemoteUpdate =========="))
                    print(string.format("[DioramaManager] Диорама: %s", tostring(dioramaId)))
                    print(string.format("[DioramaManager] ChangeInfo: %s", tostring(changeInfo)))
                    
                    local diorama = dioramaCache[dioramaId]
                    if not diorama then
                        print(string.format("[DioramaManager] Диорама не найдена в кеше!"))
                        return
                    end
                    
                    -- Получаем актуальные данные
                    local freshData = diorama:GetData()
                    print(string.format("[DioramaManager] Актуальный OwnerId: %s, версия: %d", 
                        tostring(freshData.OwnerId), freshData.CriticalVersion))
                    
                    -- Обновляем всех подписчиков новыми данными
                    updateDioramaSubscribers(dioramaId, freshData)
                    
                    -- Обрабатываем смену владельца
                    if changeInfo and changeInfo.ownerChanged then
                        print(string.format("[DioramaManager] СМЕНА ВЛАДЕЛЬЦА: %s -> %s", 
                            tostring(changeInfo.oldOwnerId), tostring(changeInfo.newOwnerId)))
                        
                        -- Уведомляем старого владельца о потере владения
                        if changeInfo.oldOwnerId then
                            local oldOwner = Players:GetPlayerByUserId(changeInfo.oldOwnerId)
                            if oldOwner then
                                print(string.format("[DioramaManager] → Уведомляем старого владельца %s о потере диорамы", oldOwner.Name))
                                -- Закрываем GUI и обновляем данные
                                EventSystem.FireClient(oldOwner, "DioramaOwnershipLost", dioramaId)
                                updatePlayerDioramas(oldOwner)
                            end
                        end
                        
                        -- Уведомляем нового владельца
                        if changeInfo.newOwnerId then
                            local newOwner = Players:GetPlayerByUserId(changeInfo.newOwnerId)
                            if newOwner then
                                print(string.format("[DioramaManager] → Уведомляем нового владельца %s о приобретении диорамы", newOwner.Name))
                                updatePlayerDioramas(newOwner)
                            end
                        end
                    end
                    
                    print(string.format("[DioramaManager] ========== END onRemoteUpdate =========="))
                end
            }
            
            local diorama = DioramaClass.new(dioramaModel, dioramaId, initialData, callbacks)
            dioramaCache[dioramaId] = diorama
            dioramasProgress.Loaded.Value += 1
        end
    end

    print(string.format("[DioramaManager] Загружено %d диорам", #dioramaModels))
    print("[DioramaManager] ID сервера:", DioramaClass.GetServerUUID())
end

-- Подсчёт количества диорам, принадлежащих игроку
local function getPlayerDioramaCount(userId)
    local count = 0
    for _, diorama in pairs(dioramaCache) do
        if diorama.OwnerId == userId then
            count = count + 1
        end
    end
    return count
end

local function getMaxDioramas(player)
    local maxDioramas = EventSystem.CallServerOnlyRPC("GetMaxDioramas", player)
    return maxDioramas or 6
end

local function checkDioramaLimit(player)
    local currentCount = getPlayerDioramaCount(player.UserId)
    local maxCount = getMaxDioramas(player)
    if currentCount >= maxCount then
        return false, string.format("Diorama limit reached (%d/%d)", currentCount, maxCount), currentCount, maxCount
    end
    return true, nil, currentCount, maxCount
end

-- ==================== RPC ОБРАБОТЧИКИ ====================

EventSystem.RegisterRPC("GetDioramaData", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local data = diorama:GetData()
        data.AvailableGold = EventSystem.CallServerOnlyRPC("GetPlayerGold", player) or 0
        data.IsOwner = (diorama.OwnerId == player.UserId)
        data.AvailableCustomization = EventSystem.CallServerOnlyRPC("GetCustomizationItems", player) or {}
        data.AvailableTickets = EventSystem.CallServerOnlyRPC("GetPurchaseBanTickets", player) or 0
        data.MaxDioramas = getMaxDioramas(player)
        data.OwnedDioramas = getPlayerDioramaCount(player.UserId)
        
        -- Применяем множитель DioramaGoldMultiplier для владельца
        if data.IsOwner then
            data.AccumulatedIncome = diorama:CalculateAccumulatedIncomeForPlayer(player)
            data.MaxAccumulatedIncome = diorama:GetMaxAccumulatedIncomeForPlayer(player)
        end
        
        return data
    end
    return nil
end)

-- RPC: Получение количества билетов для запрета покупки
EventSystem.RegisterRPC("GetPurchaseBanTickets", function(player)
    return EventSystem.CallServerOnlyRPC("GetPurchaseBanTickets", player) or 0
end)

EventSystem.RegisterRPC("GetDioramaLimit", function(player)
    local currentCount = getPlayerDioramaCount(player.UserId)
    local maxCount = getMaxDioramas(player)
    return {
        current = currentCount,
        max = maxCount,
        canBuyMore = currentCount < maxCount
    }
end)

EventSystem.RegisterRPC("GetPlayerDioramas", function(player)
    local result = {}
    for dioramaId, diorama in pairs(dioramaCache) do
        if diorama.OwnerId == player.UserId then
            -- Применяем множитель DioramaGoldMultiplier для владельца
            local accumulated = diorama:CalculateAccumulatedIncomeForPlayer(player)
            local maxAccumulated = diorama:GetMaxAccumulatedIncomeForPlayer(player)
            local incomeRate = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[diorama.Rarity] or 10
            result[tostring(dioramaId)] = {
                SceneName = diorama.SceneName,
                AccumulatedIncome = accumulated,
                MaxAccumulatedIncome = maxAccumulated,
                IncomeRate = incomeRate,
                Rarity = diorama.Rarity,
                RarityName = DioramaConfig.RARITY_NAMES[diorama.Rarity] or diorama.Rarity
            }
        end
    end
    return result
end)

EventSystem.RegisterServerOnlyRPC("DioramaInteraction", function(player, dioramaId)
    subscribePlayerToDiorama(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local data = diorama:GetData()
        data.AvailableGold = EventSystem.CallServerOnlyRPC("GetPlayerGold", player) or 0
        data.IsOwner = (diorama.OwnerId == player.UserId)
        data.AvailableCustomization = EventSystem.CallServerOnlyRPC("GetCustomizationItems", player) or {}
        EventSystem.FireClient(player, "ShowDioramaGUI", dioramaId, data)
    end
end)

EventSystem.OnServer("SubscribeToDiorama", function(player, dioramaId)
    subscribePlayerToDiorama(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local data = diorama:GetData()
        data.AvailableGold = EventSystem.CallServerOnlyRPC("GetPlayerGold", player) or 0
        data.IsOwner = (diorama.OwnerId == player.UserId)
        EventSystem.FireClient(player, "DioramaDataUpdated", dioramaId, data)
    end
end)

EventSystem.OnServer("UnsubscribeFromDiorama", function(player, dioramaId)
    unsubscribePlayerFromDiorama(player, dioramaId)
end)

EventSystem.OnServer("PurchaseDiorama", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if not diorama then return end
    
    -- Запоминаем количество диорам до покупки для проверки первого достижения
    local dioramaCountBeforePurchase = getPlayerDioramaCount(player.UserId)
    
    if diorama.OwnerId ~= player.UserId then
        local canBuy, limitMessage, currentCount, maxCount = checkDioramaLimit(player)
        if not canBuy then
            EventSystem.FireClient(player, "PurchaseResult", false, limitMessage)
            return
        end
    end
    
    local success, message = diorama:Purchase(player)
    EventSystem.FireClient(player, "PurchaseResult", success, message)
    
    -- Награждаем достижением "Первая диорама" если это была первая покупка
    if success and dioramaCountBeforePurchase == 0 then
        local awarded, awardMessage = PremiumContentSystem.AwardAchievement(player, "FirstDiorama")
        if awarded then
            print(string.format("[DioramaManager] Игрок %s получил достижение 'Первая диорама'", player.Name))
        else
            warn(string.format("[DioramaManager] Не удалось наградить достижением 'Первая диорама': %s", tostring(awardMessage)))
        end
    end
end)

EventSystem.OnServer("CollectIncome", function(player, dioramaId, from)
    local diorama = dioramaCache[dioramaId]
    if diorama  == nil then
        EventSystem.FireClient(player, "ShowDialogGUI", "error", "Error", "Diorama does not exist")
        return
    end
    local canCollect = from == "Diorama"
    if from == "AccumGui" then
        canCollect = PremiumContentSystem.HasGamePass(player, "CollectIncome")
    end
    if canCollect then
        local success, message = diorama:CollectIncome(player)
        if not success then
            EventSystem.FireClient(player, "ShowDialogGUI", "error", "Ошибка", message)
        end
    else
        EventSystem.FireClient(player, "GamepassOfferByName", "CollectIncome", "No pass for collecting gold outside diorama. Would you like to purchase?")
    end

end)

EventSystem.OnServer("ChangeDioramaSpot", function(player, dioramaId, spotNumber)
    local diorama = dioramaCache[dioramaId]
    if diorama and diorama.OwnerId == player.UserId then
        local success, message = diorama:ChangeSpot(spotNumber)
        EventSystem.FireClient(player, "ChangeSpotResult", success, message)
    end
end)

EventSystem.OnServer("ChangeDioramaFrameType", function(player, dioramaId, newFrameType)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:ChangeFrameType(player, newFrameType)
        EventSystem.FireClient(player, "ChangeFrameTypeResult", success, message)
    end
end)

EventSystem.OnServer("ChangeDioramaStandType", function(player, dioramaId, newStandType)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:ChangeStandType(player, newStandType)
        EventSystem.FireClient(player, "ChangeStandTypeResult", success, message)
    end
end)

EventSystem.OnServer("ChangeDioramaWallColor", function(player, dioramaId, colorName)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:ChangeWallColor(player, colorName)
        EventSystem.FireClient(player, "ChangeWallColorResult", success, message)
    end
end)

EventSystem.OnServer("ChangeDioramaWallMaterial", function(player, dioramaId, materialName)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:ChangeWallMaterial(player, materialName)
        EventSystem.FireClient(player, "ChangeWallMaterialResult", success, message)
    end
end)

EventSystem.OnServer("SetDioramaGamePass", function(player, dioramaId, gamePassId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:SetGamePass(player, gamePassId)
        EventSystem.FireClient(player, "SetGamePassResult", success, message)
    end
end)

EventSystem.OnServer("RemoveDioramaGamePass", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:RemoveGamePass(player)
        EventSystem.FireClient(player, "RemoveGamePassResult", success, message)
    end
end)

EventSystem.OnServer("PurchaseDioramaWithGamePass", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if not diorama then return end
    
    local canBuy, limitMessage = checkDioramaLimit(player)
    if not canBuy then
        EventSystem.FireClient(player, "PurchaseWithGamePassResult", false, limitMessage)
        return
    end
    
    local success, message = diorama:PurchaseWithGamePass(player)
    EventSystem.FireClient(player, "PurchaseWithGamePassResult", success, message)
end)

EventSystem.OnServer("QuickSellDiorama", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:QuickSell(player)
        EventSystem.FireClient(player, "QuickSellResult", success, message)
    end
end)

EventSystem.OnServer("VoteForDiorama", function(player, dioramaId, voteType)
    local diorama = dioramaCache[dioramaId]
    if diorama then
        local success, message = diorama:Vote(player, voteType)
        EventSystem.FireClient(player, "VoteResult", success, message)
    end
end)

EventSystem.OnServer("RequestPlayerDioramasUpdate", function(player)
    updatePlayerDioramas(player)
end)

EventSystem.OnServer("CheckGamePassOwnership", function(player, gamePassId)
    return DioramaUtils.hasGamePass(player, gamePassId)
end)

-- RPC: Запрет покупки диорамы на 1 час
EventSystem.OnServer("BanDioramaPurchase", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if not diorama then
        EventSystem.FireClient(player, "BanPurchaseResult", false, "Diorama not found")
        return
    end
    
    if diorama.OwnerId ~= player.UserId then
        EventSystem.FireClient(player, "BanPurchaseResult", false, "You are not the owner of this diorama")
        return
    end
    
    -- Проверяем наличие билета
    local hasTicket = EventSystem.CallServerOnlyRPC("GetPurchaseBanTickets", player)
    if not hasTicket or hasTicket < 1 then
        EventSystem.FireClient(player, "BanPurchaseResult", false, "Not enough tickets")
        return
    end
    
    -- Используем билет
    local ticketUsed, ticketMessage = EventSystem.CallServerOnlyRPC("UsePurchaseBanTicket", player)
    if not ticketUsed then
        EventSystem.FireClient(player, "BanPurchaseResult", false, ticketMessage or "Error using ticket")
        return
    end
    
    -- Устанавливаем запрет на 1 час
    local currentTime = os.time()
    local banEndTime = currentTime + 3600 -- 1 час в секундах
    
    local success, message = diorama:SetPurchaseBan(banEndTime)
    
    if success then
        EventSystem.FireClient(player, "BanPurchaseResult", true, "Ban set for 1 hour", banEndTime)
        -- Обновляем всех подписчиков
        updateDioramaSubscribers(dioramaId, diorama:GetData())
    else
        -- Возвращаем билет если не удалось установить запрет
        EventSystem.CallServerOnlyRPC("AddPurchaseBanTickets", player, 1)
        EventSystem.FireClient(player, "BanPurchaseResult", false, message)
    end
end)

-- RPC: Увеличение времени запрета на 1 час
EventSystem.OnServer("ExtendPurchaseBan", function(player, dioramaId)
    local diorama = dioramaCache[dioramaId]
    if not diorama then
        EventSystem.FireClient(player, "ExtendBanResult", false, "Diorama not found")
        return
    end
    
    if diorama.OwnerId ~= player.UserId then
        EventSystem.FireClient(player, "ExtendBanResult", false, "You are not the owner of this diorama")
        return
    end
    
    -- Проверяем наличие билета
    local hasTicket = EventSystem.CallServerOnlyRPC("GetPurchaseBanTickets", player)
    if not hasTicket or hasTicket < 1 then
        EventSystem.FireClient(player, "ExtendBanResult", false, "Not enough tickets")
        return
    end
    
    -- Используем билет
    local ticketUsed, ticketMessage = EventSystem.CallServerOnlyRPC("UsePurchaseBanTicket", player)
    if not ticketUsed then
        EventSystem.FireClient(player, "ExtendBanResult", false, ticketMessage or "Error using ticket")
        return
    end
    
    -- Увеличиваем время запрета на 1 час
    local success, message, newBanEndTime = diorama:ExtendPurchaseBan(3600)
    
    if success then
        EventSystem.FireClient(player, "ExtendBanResult", true, "Ban time extended by 1 hour", newBanEndTime)
        -- Обновляем всех подписчиков
        updateDioramaSubscribers(dioramaId, diorama:GetData())
    else
        -- Возвращаем билет если не удалось увеличить время
        EventSystem.CallServerOnlyRPC("AddPurchaseBanTickets", player, 1)
        EventSystem.FireClient(player, "ExtendBanResult", false, message)
    end
end)

-- RPC: Добавление билетов
EventSystem.OnServer("AddBanTickets", function(player, amount)
    if type(amount) ~= "number" or amount <= 0 then
        EventSystem.FireClient(player, "AddBanTicketsResult", false, "Invalid amount")
        return
    end
    
    local success, message = EventSystem.CallServerOnlyRPC("AddPurchaseBanTickets", player, amount)
    EventSystem.FireClient(player, "AddBanTicketsResult", success, message)
end)

-- Обработка отложенных начислений при входе игрока
Players.PlayerAdded:Connect(function(player)
    -- Небольшая задержка чтобы все системы успели загрузиться
    task.wait(2)
    DioramaClass.ProcessPendingPaymentsForPlayer(player)
end)

-- Очистка подписок при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    unsubscribePlayerFromAll(player)
end)

-- ==================== ЗАПУСК ====================

local function main()
    setupMessagingService()
    task.spawn(startCriticalSyncCheck)
    task.spawn(startCustomizationSync)
    task.spawn(startAccumulatedIncomeUpdates)
    initDioramas()
    -- Expose diorama cache for LeaderboardManager
    _G.DioramaCache = dioramaCache
end

main()