-- PremiumContentInit - Инициализация PremiumContentSystem и обработка магазина
-- Использует EventSystem для взаимодействия клиент-сервер
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Ожидание загрузки AssetService и EventSystem
local function waitForAssetService()
    local maxWaitTime = 30
    local startTime = os.time()
    
    while os.time() - startTime < maxWaitTime do
        if _G.AssetService and _G.AssetService:IsLoaded() then
            local eventSystemStatus = _G.AssetService:GetAssetStatus("EventSystem")
            if eventSystemStatus and eventSystemStatus.loaded and eventSystemStatus.moduleReference then
                return true
            end
        end
        task.wait(0.5)
    end
    
    return false
end

-- Локальные переменные
local EventSystem = nil
local PremiumContentSystem = nil
local processedPurchases = {} -- Кэш обработанных покупок для избежания дублирования
local isReceiptHandlerSet = false

-- Функция применения донатного бонуса к конкретному продукту
local function applyDonationBonusToProduct(player, productId, originalBonus)
    if not player or not productId then
        return false
    end
    
    -- Получаем DataManager для доступа к множителям
    local DataManager = _G.AssetService:GetModule("DataManager")
    if not DataManager then
        warn("[PremiumContentInit] DataManager not found")
        return false
    end
    
    -- Ждем загрузки данных игрока
    if not DataManager.IsDataLoaded(player) then
        local startTime = os.time()
        while os.time() - startTime < 5 do
            if DataManager.IsDataLoaded(player) then
                break
            end
            task.wait(0.5)
        end
    end
    
    -- Получаем вычисляемые данные игрока (уже с модификаторами)
    local computedData = DataManager.GetComputedData(player)
    if not computedData then
        warn("[PremiumContentInit] ComputedData not found for player", player.Name)
        return false
    end
    
    -- Рассчитываем бонус (если DonationBonusMultiplier = 1.5, то extraBonus = 0.5)
    local bonusMultiplier = computedData.DonationBonusMultiplier or 1.0
    local extraBonus = bonusMultiplier - 1.0
    
    if extraBonus <= 0 then
        return true -- Нет дополнительного бонуса
    end
    
    -- Применяем дополнительный бонус к уже выданным наградам
    local success, err = DataManager.UpdateData(player, function(currentData)
        local newData = table.clone(currentData)
        
        for resourceName, baseAmount in pairs(originalBonus) do
            -- Пропускаем модификаторы и не-числовые значения
            if type(baseAmount) == "number" and resourceName ~= "Modifiers" then
                local bonusAmount = baseAmount * extraBonus
                newData[resourceName] = (newData[resourceName] or 0) + bonusAmount
                
                print(string.format("[PremiumContentInit] Donation bonus applied: +%.2f %s to player %s (multiplier: %.2f)", 
                      bonusAmount, resourceName, player.Name, bonusMultiplier))
            end
        end
        
        return newData
    end)
    
    if not success then
        warn("[PremiumContentInit] Failed to apply donation bonus:", err)
        return false
    end
    
    return true
end

-- Функция для поиска названия продукта по ID
local function getProductNameById(productId)
    if not PremiumContentSystem then
        return nil
    end
    
    local products = PremiumContentSystem.GetAvailableProducts()
    for _, product in ipairs(products) do
        if product.Id == productId then
            return product.Name
        end
    end
    return nil
end

-- Единый обработчик ProcessReceipt
local function onProcessReceipt(receiptInfo)
    print(string.format("[PremiumContentInit] Processing receipt: PlayerId=%d, ProductId=%d, PurchaseId=%s", 
          receiptInfo.PlayerId, receiptInfo.ProductId, receiptInfo.PurchaseId))
    
    -- Проверяем, что PremiumContentSystem инициализирован
    if not PremiumContentSystem then
        warn("[PremiumContentInit] PremiumContentSystem not ready, delaying purchase")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Получаем игрока
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        print("[PremiumContentInit] Player not found, delaying purchase processing")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Создаем уникальный ключ для проверки дублирования
    local purchaseKey = tostring(receiptInfo.PlayerId) .. "_" .. tostring(receiptInfo.ProductId) .. "_" .. tostring(receiptInfo.PurchaseId)
    
    -- Проверяем, не обработали ли уже эту покупку
    if processedPurchases[purchaseKey] then
        print("[PremiumContentInit] Duplicate purchase detected, skipping")
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- Находим конфигурацию продукта
    local products = PremiumContentSystem.GetAvailableProducts()
    local productConfig = nil
    
    for _, product in ipairs(products) do
        if product.Id == receiptInfo.ProductId then
            productConfig = product
            break
        end
    end
    
    if not productConfig then
        warn("[PremiumContentInit] Product not found:", receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Применяем базовые награды через PremiumContentSystem
    -- Для этого нужно вызвать внутреннюю логику PremiumContentSystem
    -- Так как мы не можем изменить PremiumContentSystem, используем обходной путь:
    -- Применяем награду напрямую через ApplyReward функцию PremiumContentSystem
    
    local bonus = productConfig.Bonus
    if bonus then
        -- Применяем базовую награду
        local rewardResult, rewardErr = PremiumContentSystem.ApplyReward(player, bonus, "Product", productConfig.Name)
        if not rewardResult then
            warn("[PremiumContentInit] Failed to apply product reward:", rewardErr)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        
        print(string.format("[PremiumContentInit] Base reward applied for %s to player %s", productConfig.Name, player.Name))
        
        -- Помечаем покупку как обработанную
        processedPurchases[purchaseKey] = true
        
        -- Применяем донатный бонус
        task.spawn(function()
            -- Небольшая задержка, чтобы базовые награды сохранились
            task.wait(0.5)
            applyDonationBonusToProduct(player, receiptInfo.ProductId, bonus)
            
            -- Уведомляем клиента об обновлении
            if EventSystem then
                EventSystem.FireClient(player, "DonationBonusApplied", productConfig.Name)
                EventSystem.FireClient(player, "PurchaseCompleted", productConfig.Name, bonus)
            end
        end)
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        warn("[PremiumContentInit] Product has no bonus configured:", productConfig.Name)
        processedPurchases[purchaseKey] = true
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
end

-- Функция регистрации всех RPC после загрузки EventSystem
local function registerRPCs()
    if not EventSystem or not PremiumContentSystem then
        warn("[PremiumContentInit] EventSystem или PremiumContentSystem не загружен, пропускаем регистрацию RPC")
        return
    end
    
    -- RPC: Получение данных магазина
    EventSystem.RegisterRPC("GetShopData", function(player)
        if not PremiumContentSystem then
            return nil, "PremiumContentSystem not initialized"
        end
        
        -- Получаем данные о GamePasses
        local gamePasses = PremiumContentSystem.GetAvailableGamePasses()
        
        -- Получаем данные о DeveloperProducts
        local products = PremiumContentSystem.GetAvailableProducts()
        
        -- Проверяем владение для каждого GamePass
        local ownedGamePasses = {}
        for _, gamePass in ipairs(gamePasses) do
            local hasPass, _ = PremiumContentSystem.HasGamePass(player, gamePass.Name)
            ownedGamePasses[gamePass.Name] = hasPass or false
        end
        
        -- Проверяем премиум статус
        local isPremium = PremiumContentSystem.IsPremium(player)
        
        -- Получаем донатный множитель игрока для отображения в UI
        local DataManager = _G.AssetService:GetModule("DataManager")
        local donationMultiplier = 1.0
        if DataManager then
            local computedData = DataManager.GetComputedData(player)
            if computedData then
                donationMultiplier = computedData.DonationBonusMultiplier or 1.0
            end
        end
        
        return {
            gamePasses = gamePasses,
            products = products,
            ownedGamePasses = ownedGamePasses,
            isPremium = isPremium,
            donationMultiplier = donationMultiplier
        }
    end)

    -- RPC: Проверка владения предметом
    EventSystem.RegisterRPC("CheckOwnership", function(player, itemType, itemName)
        if not PremiumContentSystem then
            return false, "PremiumContentSystem not initialized"
        end
        
        local hasItem = false
        
        if itemType == "GamePass" then
            local hasPass, _ = PremiumContentSystem.HasGamePass(player, itemName)
            hasItem = hasPass or false
        elseif itemType == "Premium" then
            hasItem = PremiumContentSystem.IsPremium(player) or false
        end
        
        return hasItem
    end)

    -- RPC: Покупка GamePass
    EventSystem.OnServer("PurchaseGamePass", function(player, gamePassName)
        if not PremiumContentSystem then
            return false, "PremiumContentSystem not initialized"
        end
        
        -- Проверяем, есть ли уже GamePass
        local hasPass, checkErr = PremiumContentSystem.HasGamePass(player, gamePassName)
        if hasPass then
            return false, "Already owned"
        end
        
        -- Инициируем покупку
        local success, err = PremiumContentSystem.PromptGamePassPurchase(player, gamePassName)
        if not success then
            return false, err or "Failed to prompt purchase"
        end
        
        return true, "Purchase prompted"
    end)

    -- RPC: Покупка DeveloperProduct
    EventSystem.OnServer("PurchaseProduct", function(player, productName)
        if not PremiumContentSystem then
            return false, "PremiumContentSystem not initialized"
        end
        
        -- Инициируем покупку
        local success, err = PremiumContentSystem.PromptProductPurchase(player, productName)
        if not success then
            return false, err or "Failed to prompt purchase"
        end
        
        return true, "Purchase prompted"
    end)

    -- RPC: Получение премиум статуса
    EventSystem.RegisterRPC("GetPlayerPremiumStatus", function(player)
        if not PremiumContentSystem then
            return false
        end
        
        return PremiumContentSystem.IsPremium(player)
    end)

    -- RPC: Получение данных ежедневных наград
    EventSystem.RegisterRPC("GetDailyRewardsData", function(player)
        if not PremiumContentSystem then
            return nil, "PremiumContentSystem not initialized"
        end
        
        local isPremium = PremiumContentSystem.IsPremium(player)
        local allGroups = PremiumContentSystem.GetAllRewardGroups()
        
        if not allGroups then
            return { groups = {}, isPremium = isPremium }
        end
        
        local groupsData = {}
        
        for groupName, groupConfig in pairs(allGroups) do
            local hasAccess, accessErr = PremiumContentSystem.HasAccessToRewardGroup(player, groupName)
            if hasAccess then
                local status = PremiumContentSystem.GetDailyRewardStatus(player, groupName)
                local cycleLength = PremiumContentSystem.GetGroupCycleLength(groupName)
                local displayName = PremiumContentSystem.GetGroupDisplayName(groupName)
                local accessType = PremiumContentSystem.GetGroupAccessType(groupName)
                
                local rewards = {}
                for day = 1, cycleLength do
                    local reward = PremiumContentSystem.GetRewardForDay(groupName, day)
                    rewards[day] = reward
                end
                
                groupsData[groupName] = {
                    displayName = displayName,
                    accessType = accessType,
                    cycleLength = cycleLength,
                    rewards = rewards,
                    postCompletionReward = PremiumContentSystem.GetPostCompletionReward(groupName),
                    status = status
                }
            end
        end
        
        return {
            groups = groupsData,
            isPremium = isPremium
        }
    end)

    -- RPC: Забрать ежедневную награду
    EventSystem.RegisterRPC("ClaimDailyReward", function(player, groupName)
        if not PremiumContentSystem then
            return nil, "PremiumContentSystem not initialized"
        end
        
        if not groupName then
            return nil, "Group name is required"
        end
        
        local result, err = PremiumContentSystem.ClaimDailyReward(player, groupName)
        if not result then
            return nil, err or "Failed to claim daily reward"
        end
        
        -- Уведомляем клиента об успешном клейме
        if EventSystem then
            EventSystem.FireClient(player, "DailyRewardClaimed", groupName, result)
        end
        
        return result
    end)

    -- Обработка клейма награды через FireServer
    EventSystem.OnServer("ClaimDailyRewardEvent", function(player, groupName)
        if not PremiumContentSystem then
            return
        end
        
        if not groupName then return end
        
        local result, err = PremiumContentSystem.ClaimDailyReward(player, groupName)
        if result then
            EventSystem.FireClient(player, "DailyRewardClaimed", groupName, result)
        end
    end)

    print("[PremiumContentInit] RPC функции зарегистрированы")
end

-- Обработка события покупки GamePass
local function onGamePassPurchased(player, gamePassName)
    if EventSystem then
        EventSystem.FireClient(player, "OwnershipUpdated", "GamePass", gamePassName, true)
    end
end

-- Подключаемся к событию PromptGamePassPurchaseFinished
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
    if wasPurchased and PremiumContentSystem then
        local gamePasses = PremiumContentSystem.GetAvailableGamePasses()
        for _, gamePass in ipairs(gamePasses) do
            if gamePass.Id == gamePassId then
                onGamePassPurchased(player, gamePass.Name)
                break
            end
        end
    end
end)

-- Слушаем добавление игрока для очистки кэша
Players.PlayerRemoving:Connect(function(player)
    for key in pairs(processedPurchases) do
        if string.match(key, "^" .. tostring(player.UserId) .. "_") then
            processedPurchases[key] = nil
        end
    end
end)

-- Инициализация при старте
task.spawn(function()
    if not waitForAssetService() then
        warn("[PremiumContentInit] AssetService или EventSystem не загружен")
        return false
    end
    
    EventSystem = _G.AssetService:GetModule("EventSystem")
    PremiumContentSystem = _G.AssetService:GetModule("PremiumContentSystem")
    local ContentConfig = require(game.ServerStorage.Configs.PremiumContentConfig)
    PremiumContentSystem.Init(ContentConfig)
    MarketplaceService.ProcessReceipt = onProcessReceipt
    registerRPCs()
end)

print("[PremiumContentInit] Script loaded with EventSystem integration")