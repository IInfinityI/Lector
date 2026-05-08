local PremiumContentSystem = {}
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local HttpService = game:GetService("HttpService")

local config
local dataManagerModule = nil
local isInitialized = false
local initializationPromise = nil
local purchaseHandlers = {}
local gamePassPurchaseCallbacks = {} -- Таблица для отслеживания колбэков покупки геймпасов

-- Асинхронная инициализация DataManager через AssetService
local function ensureDataManager()
    if dataManagerModule then
        return dataManagerModule
    end
    
    if _G.AssetService then
        dataManagerModule = _G.AssetService:GetModule("DataManager")
        
        if dataManagerModule then
            return dataManagerModule
        else
            local startTime = os.time()
            while os.time() - startTime < 10 do
                if _G.AssetService:IsModuleReady("DataManager") then
                    dataManagerModule = _G.AssetService:GetModule("DataManager")
                    if dataManagerModule then
                        return dataManagerModule
                    end
                end
                task.wait(1)
            end
            error("DataManager not found via AssetService after 10 seconds")
        end
    else
        error("AssetService not found in _G. Please ensure AssetService is initialized first.")
    end
end

-- Локальные вспомогательные функции
local function findItemByName(name, itemType)
    if not config then 
        return nil, "Configuration not initialized" 
    end
    
    local items = config[itemType == "GamePass" and "GamePasses" or "DeveloperProducts"] or {}
    
    for _, item in ipairs(items) do
        if item.Name == name then
            return item
        end
    end
    
    return nil, string.format("%s '%s' not found in configuration", itemType, name)
end

local function findItemById(id, itemType)
    if not config then 
        return nil, "Configuration not initialized" 
    end
    
    local items = config[itemType == "GamePass" and "GamePasses" or "DeveloperProducts"] or {}
    
    for _, item in ipairs(items) do
        if item.Id == id then
            return item
        end
    end
    
    return nil, string.format("%s with ID '%d' not found in configuration", itemType, id)
end

local function findAchievementByName(name)
    if not config or not config.Achievements then
        return nil, "Achievements not configured"
    end
    
    for _, achievement in ipairs(config.Achievements) do
        if achievement.Name == name then
            return achievement
        end
    end
    
    return nil, string.format("Achievement '%s' not found", name)
end

local function awardBadge(player, badgeId, badgeName)
    if not player then
        return false, "Player cannot be nil"
    end
    
    local success, badgeInfo = pcall(BadgeService.GetBadgeInfoAsync, BadgeService, badgeId)
    if not success then
        return false, "Failed to fetch badge info: " .. tostring(badgeInfo)
    end
    
    if not badgeInfo.IsEnabled then
        return false, "Badge '" .. badgeName .. "' is not enabled"
    end
    
    local awarded, errorMessage = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
    if not awarded then
        return false, "Failed to award badge: " .. tostring(errorMessage)
    end
    
    return true
end

-- Функции для обработки наград и модификаторов
local function applyRewardToSavedData(player, reward)
    if not player or not reward then
        return false, "Invalid parameters"
    end
    
    local DataManager = ensureDataManager()
    
    local success, err = DataManager.UpdateData(player, function(currentData)
        local newData = table.clone(currentData)
        
        -- Обрабатываем все элементы reward кроме Modifiers
        for rewardType, rewardValue in pairs(reward) do
            if rewardType ~= "Modifiers" then
                -- Для числовых значений (Currency, XP и т.д.)
                if type(rewardValue) == "number" then
                    newData[rewardType] = (newData[rewardType] or 0) + rewardValue
                
                -- Для строковых значений (Item и т.д.)
                elseif type(rewardValue) == "string" then
                    if rewardType == "Item" then
                        if not newData.Inventory then
                            newData.Inventory = {}
                        end
                        table.insert(newData.Inventory, rewardValue)
                    else
                        -- Для других строковых наград создаем или добавляем в массив
                        if not newData[rewardType] then
                            newData[rewardType] = {}
                        end
                        if type(newData[rewardType]) == "table" then
                            table.insert(newData[rewardType], rewardValue)
                        else
                            -- Если это не таблица, преобразуем в таблицу
                            local existingValue = newData[rewardType]
                            newData[rewardType] = {existingValue, rewardValue}
                        end
                    end
                
                -- Для табличных значений (массивы предметов и т.д.)
                elseif type(rewardValue) == "table" then
                    if not newData[rewardType] then
                        newData[rewardType] = {}
                    end
                    
                    for _, item in ipairs(rewardValue) do
                        table.insert(newData[rewardType], item)
                    end
                
                -- Для булевых значений и других типов
                else
                    newData[rewardType] = rewardValue
                end
            end
        end
        
        return newData
    end)
    
    if not success then
        return false, "Failed to update player data: " .. tostring(err)
    end
    
    return true
end

local function generateModifierId(sourceType, sourceName, modifierIndex)
    return string.format("%s_%s_%d", sourceType, sourceName, modifierIndex)
end

local function applyModifiersFromBonus(player, bonus, sourceType, sourceName)
    if not bonus or not bonus.Modifiers then
        return {}
    end
    
    local DataManager = ensureDataManager()
    local appliedModifiers = {}
    
    for i, modifier in ipairs(bonus.Modifiers) do
        if modifier.Type and modifier.Operation and modifier.Value then
            local modifierId = generateModifierId(sourceType, sourceName, i)
            
            if modifier.Duration then
                -- Временный модификатор через DataManager
                local success = DataManager.AddTemporaryModifier(
                    player,
                    modifier.Type,
                    modifierId,
                    modifier.Value,
                    modifier.Operation,
                    sourceType,
                    modifier.Duration
                )
                
                if success then
                    table.insert(appliedModifiers, modifierId)
                else
                    warn(string.format("Failed to apply temporary modifier %s for player %s", modifier.Type, player.Name))
                end
            else
                -- Постоянный модификатор через DataManager
                local success = DataManager.AddModifier(
                    player,
                    modifier.Type,
                    modifierId,
                    modifier.Value,
                    modifier.Operation,
                    sourceType
                )
                
                if success then
                    table.insert(appliedModifiers, modifierId)
                else
                    warn(string.format("Failed to apply permanent modifier %s for player %s", modifier.Type, player.Name))
                end
            end
        else
            warn("Invalid modifier configuration: missing Type, Operation or Value")
        end
    end
    
    return appliedModifiers
end

local function removeAllModifiersBySource(player, sourceType, sourceName)
    if not player then
        return
    end
    
    local DataManager = ensureDataManager()
    local computedData = DataManager.GetComputedData(player)
    
    if not computedData then
        return
    end
    
    -- Получаем информацию о всех временных модификаторах
    local tempModifiers = DataManager.GetTemporaryModifiersInfo(player)
    
    -- Удаляем модификаторы по источнику
    for modifierId, modifierInfo in pairs(tempModifiers) do
        if modifierInfo.source == sourceType and (not sourceName or string.find(modifierId, sourceName)) then
            DataManager.RemoveModifier(player, modifierInfo.paramName, modifierId)
        end
    end
end

local function hasRewardBeenClaimed(player, rewardType, rewardId)
    local DataManager = ensureDataManager()
    local data = DataManager.GetData(player)
    
    if not data.claimedRewards then
        data.claimedRewards = {}
        return false
    end
    
    if not data.claimedRewards[rewardType] then
        data.claimedRewards[rewardType] = {}
        return false
    end
    
    return data.claimedRewards[rewardType][rewardId] == true
end

local function markRewardAsClaimed(player, rewardType, rewardId)
    local DataManager = ensureDataManager()
    
    local success, err = DataManager.UpdateData(player, function(currentData)
        local newData = table.clone(currentData)
        
        if not newData.claimedRewards then
            newData.claimedRewards = {}
        end
        
        if not newData.claimedRewards[rewardType] then
            newData.claimedRewards[rewardType] = {}
        end
        
        newData.claimedRewards[rewardType][rewardId] = true
        return newData
    end)
    
    return success, err
end

local function onGamePassPurchaseFinished(player, gamePassId, wasPurchased)
    if not player then
        return false, "Player cannot be nil"
    end
    
    if not gamePassId then
        return false, "GamePass ID cannot be nil"
    end
    
    -- Если покупка не была завершена успешно, возвращаем ошибку
    if not wasPurchased then
        return false, "Game pass purchase was not completed"
    end
    
    local gamePass, err = findItemById(gamePassId, "GamePass")
    if not gamePass then
        return false, "Game pass not found: " .. tostring(err)
    end
    
    -- Проверяем, что игрок действительно купил геймпас
    local hasPass, checkErr = PremiumContentSystem.HasGamePass(player, gamePass.Name)
    if not hasPass then
        return false, "Player does not own this game pass after purchase: " .. tostring(checkErr)
    end
    
    -- Проверяем, была ли уже выдана награда за этот геймпас
    if hasRewardBeenClaimed(player, "GamePasses", tostring(gamePassId)) then
        return false, "Reward for this game pass has already been claimed"
    end
    
    -- Применяем бонусы игрового пропуска (только обычные награды, без модификаторов)
    if gamePass.Bonus then
        -- Создаем копию бонуса без модификаторов для одноразовой выдачи
        local oneTimeBonus = {}
        for bonusType, value in pairs(gamePass.Bonus) do
            if bonusType ~= "Modifiers" then
                oneTimeBonus[bonusType] = value
            end
        end
        
        -- Применяем обычные награды
        if next(oneTimeBonus) ~= nil then
            local rewardResult, rewardErr = applyRewardToSavedData(player, oneTimeBonus)
            if not rewardResult then
                warn("Failed to apply game pass reward to saved data: " .. tostring(rewardErr))
                return false, "Failed to apply reward: " .. tostring(rewardErr)
            end
        end
        
        -- Помечаем награду как выданную
        local markSuccess, markErr = markRewardAsClaimed(player, "GamePasses", tostring(gamePassId))
        if not markSuccess then
            warn("Failed to mark game pass reward as claimed: " .. tostring(markErr))
        end
        
        print(string.format("Successfully processed game pass purchase for %s to player %s", gamePass.Name, player.Name))
        return true, gamePass.Bonus
    else
        return false, "Game pass has no bonus configured"
    end
end

-- ФУНКЦИЯ ДЛЯ ПРЕМИУМ БОНУСОВ
local function processPremiumBonus(player)
    if not player then
        return false, "Player cannot be nil"
    end
    
    local isPremium, err = PremiumContentSystem.IsPremium(player)
    if err then
        return false, "Failed to check premium status: " .. tostring(err)
    end
    
    if not isPremium then
        return false, "Player is not premium"
    end
    
    -- Проверяем, была ли уже выдана одноразовая награда
    if hasRewardBeenClaimed(player, "Premium", "oneTimeBonus") then
        -- Для премиума выдаем только модификаторы при каждом входе
        if config and config.PremiumBonuses and #config.PremiumBonuses > 0 then
            local premiumBonus = config.PremiumBonuses[1].Bonus
            -- Применяем только модификаторы
            if premiumBonus.Modifiers then
                applyModifiersFromBonus(player, {Modifiers = premiumBonus.Modifiers}, "Premium", "Premium")
            end
        end
        return true, "Premium modifiers applied"
    else
        -- Первый вход премиум пользователя - выдаем полный бонус
        if config and config.PremiumBonuses and #config.PremiumBonuses > 0 then
            local premiumBonus = config.PremiumBonuses[1].Bonus
            
            -- Применяем полный бонус
            local rewardResult, rewardErr = PremiumContentSystem.ApplyReward(player, premiumBonus, "Premium", "Premium")
            if not rewardResult then
                return false, "Failed to apply premium reward: " .. tostring(rewardErr)
            end
            
            -- Помечаем одноразовую награду как выданную
            local markSuccess, markErr = markRewardAsClaimed(player, "Premium", "oneTimeBonus")
            if not markSuccess then
                warn("Failed to mark premium reward as claimed: " .. tostring(markErr))
            end
            
            print(string.format("Successfully applied premium bonus to player %s", player.Name))
            return true, premiumBonus
        else
            return false, "Premium bonuses not configured"
        end
    end
end

-- ФУНКЦИИ ДЛЯ ЕЖЕДНЕВНЫХ НАГРАД
local function getDailyRewardData(player)
    local DataManager = ensureDataManager()
    local data = DataManager.GetData(player)
    
    if not data.dailyRewards then
        data.dailyRewards = {
            lastLoginTime = 0,
            consecutiveDays = 0,
            currentCycleDay = 1,
            totalDaysClaimed = 0,
            lastClaimedGroup = nil
        }
    end
    
    return data.dailyRewards
end

local function updateDailyRewardData(player, newData)
    local DataManager = ensureDataManager()
    
    local success, err = DataManager.UpdateData(player, function(currentData)
        local updatedData = table.clone(currentData)
        if not updatedData.dailyRewards then
            updatedData.dailyRewards = {}
        end
        
        for key, value in pairs(newData) do
            updatedData.dailyRewards[key] = value
        end
        
        return updatedData
    end)
    
    return success, err
end

local function canClaimDailyReward(player, groupName)
    local rewardData = getDailyRewardData(player)
    local currentTime = os.time()
    local lastLogin = rewardData.lastLoginTime or 0
    
    -- Если никогда не заходил, можно получить награду
    if lastLogin == 0 then
        return true
    end
    
    local timeSinceLastLogin = currentTime - lastLogin
    local hoursSinceLastLogin = timeSinceLastLogin / 3600
    
    -- Если прошло больше 24 часов, сбрасываем последовательные дни
    if hoursSinceLastLogin > 48 then
        return true -- Можно получить награду, но счетчик сбросится
    elseif hoursSinceLastLogin > 24 then
        return true -- Можно получить награду за следующий день
    else
        return false -- Уже получал награду сегодня
    end
end

local function calculateConsecutiveDays(player)
    local rewardData = getDailyRewardData(player)
    local currentTime = os.time()
    local lastLogin = rewardData.lastLoginTime or 0
    
    if lastLogin == 0 then
        return 1 -- Первый вход
    end
    
    local timeSinceLastLogin = currentTime - lastLogin
    local hoursSinceLastLogin = timeSinceLastLogin / 3600
    
    if hoursSinceLastLogin > 48 then
        return 1 -- Сброс счетчика
    elseif hoursSinceLastLogin > 24 then
        return rewardData.consecutiveDays + 1 -- Увеличиваем счетчик
    else
        return rewardData.consecutiveDays -- Без изменений
    end
end

local function processProductPurchase(player, productId, purchaseId)
    local product, err = findItemById(productId, "Product")
    if not product then
        return false, "Product not found: " .. tostring(err)
    end
    
    -- Проверяем, не обрабатывалась ли уже эта покупка
    local purchaseKey = string.format("%d_%s", player.UserId, purchaseId)
    if purchaseHandlers[purchaseKey] then
        return false, "Purchase already processed"
    end
    
    -- Помечаем покупку как обработанную
    purchaseHandlers[purchaseKey] = true
    
    -- Применяем награды
    if product.Bonus then
        local rewardResult, rewardErr = PremiumContentSystem.ApplyReward(player, product.Bonus, "Product", product.Name)
        if not rewardResult then
            return false, "Failed to apply product reward: " .. tostring(rewardErr)
        end
        
        print(string.format("Successfully applied product reward for %s to player %s", product.Name, player.Name))
        return true, product.Bonus
    else
        return false, "Product has no bonus configured"
    end
end

local function onProcessReceipt(receiptInfo)
    print(string.format("Processing receipt: PlayerId=%d, ProductId=%d, PurchaseId=%s", 
          receiptInfo.PlayerId, receiptInfo.ProductId, receiptInfo.PurchaseId))
    
    -- Получаем игрока
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Игрок не найден, откладываем обработку
        print("Player not found, delaying purchase processing")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Проверяем, что система инициализирована
    if not isInitialized then
        local initSuccess = pcall(PremiumContentSystem.WaitForInitialization)
        if not initSuccess then
            warn("PremiumContentSystem not initialized, delaying purchase")
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end
    
    -- Проверяем тип покупки - это Developer Product
    if receiptInfo.ProductId then
        print(string.format("Processing Developer Product: ID=%d", receiptInfo.ProductId))
        
        local success, result = processProductPurchase(player, receiptInfo.ProductId, receiptInfo.PurchaseId)
        if success then
            print("Purchase processed successfully")
            return Enum.ProductPurchaseDecision.PurchaseGranted
        else
            warn("Failed to process product purchase: " .. tostring(result))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end
    
    warn("Unknown purchase type or missing ProductId")
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Основное API
function PremiumContentSystem.Init(configuration)
    if not configuration then
        return nil, "Configuration cannot be nil"
    end
    config = configuration
    
    local success, err = pcall(ensureDataManager)
    if not success then
        return nil, "Failed to initialize DataManager: " .. tostring(err)
    end
        
    local setSuccess, setErr = pcall(function()
        MarketplaceService.ProcessReceipt = onProcessReceipt
    end)
    
    if not setSuccess then
        warn("Failed to set ProcessReceipt handler: " .. tostring(setErr))
        return nil, "Failed to set purchase handler: " .. tostring(setErr)
    end
        
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)

    isInitialized = true
    print("PremiumContentSystem initialized successfully with AssetService and purchase handler")
    
    return true
end

-- Асинхронная инициализация
function PremiumContentSystem.WaitForInitialization()
    if isInitialized then
        return true
    end
    
    if not initializationPromise then
        initializationPromise = task.spawn(function()
            local maxWaitTime = 30
            local startTime = os.time()
            
            while os.time() - startTime < maxWaitTime do
                if isInitialized then
                    return true
                end
                
                if _G.AssetService and _G.AssetService:IsModuleReady("DataManager") then
                    local success = pcall(ensureDataManager)
                    if success then
                        isInitialized = true
                        return true
                    end
                end
                
                task.wait(1)
            end
            
            error("PremiumContentSystem initialization timeout after " .. maxWaitTime .. " seconds")
        end)
    end
    
    return initializationPromise
end

-- GamePass функции
function PremiumContentSystem.HasGamePass(player, gamePassNameOrId)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local gamePass
    local err
    
    -- Проверяем, является ли параметр ID (число) или именем (строка)
    if type(gamePassNameOrId) == "number" then
        gamePass, err = findItemById(gamePassNameOrId, "GamePass")
    else
        gamePass, err = findItemByName(gamePassNameOrId, "GamePass")
    end
    
    if not gamePass then
        return nil, err
    end
    
    local success, hasPass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePass.Id)
    end)
    
    if not success then
        return nil, "Failed to check game pass ownership: " .. tostring(hasPass)
    end
    
    return hasPass
end

-- ОБНОВЛЕННАЯ ФУНКЦИЯ: Покупка GamePass с проверкой наличия и обработкой результата
function PremiumContentSystem.PromptGamePassPurchase(player, gamePassName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local gamePass, err = findItemByName(gamePassName, "GamePass")
    if not gamePass then
        return nil, err
    end
    
    -- Проверяем, нет ли уже этого геймпаса
    local hasPass, checkErr = PremiumContentSystem.HasGamePass(player, gamePassName)
    if hasPass then
        return nil, "Player already owns this game pass"
    elseif checkErr then
        warn("Error checking game pass ownership: " .. tostring(checkErr))
    end
    
    -- Регистрируем колбэк для обработки результата покупки
    local purchaseCallbackId = tostring(player.UserId) .. "_" .. tostring(gamePass.Id)
    
    local success = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePass.Id)
    end)
    
    if not success then
        return nil, "Failed to prompt game pass purchase"
    end
    
    return true
end

function PremiumContentSystem.PromptGamePassPurchaseFinished(player, gamePassId, wasPurchased)
    if not player then
        return false, "Player cannot be nil"
    end
    
    if not gamePassId then
        return false, "GamePass ID cannot be nil"
    end
    
    -- Проверяем, есть ли уже геймпас у игрока перед покупкой
    local hasPass, checkErr = PremiumContentSystem.HasGamePass(player, gamePassId)
    if hasPass then
        return false, "Player already owns this game pass"
    elseif checkErr then
        warn("Error checking game pass ownership: " .. tostring(checkErr))
    end
    
    -- Если покупка не была завершена успешно, возвращаем ошибку
    if not wasPurchased then
        return false, "Game pass purchase was not completed"
    end
    
    -- Обрабатываем успешную покупку
    local success, result = onGamePassPurchaseFinished(player, gamePassId, wasPurchased)
    return success, result
end

-- Developer Product функции
function PremiumContentSystem.PromptProductPurchase(player, productName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local product, err = findItemByName(productName, "Product")
    if not product then
        return nil, err
    end
    
    local success = pcall(function()
        MarketplaceService:PromptProductPurchase(player, product.Id)
    end)
    
    if not success then
        return nil, "Failed to prompt product purchase"
    end
    
    return true
end

function PremiumContentSystem.GrantProductReward(player, productName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local product, err = findItemByName(productName, "Product")
    if not product then
        return nil, err
    end
    
    local success, result = processProductPurchase(player, product.Id, "manual_grant_" .. HttpService:GenerateGUID(false))
    if not success then
        return nil, "Failed to grant product reward: " .. tostring(result)
    end
    
    return true, result
end

-- Premium функции
function PremiumContentSystem.IsPremium(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    return player.MembershipType == Enum.MembershipType.Premium
end

-- Бонусы с модификаторами (ОБНОВЛЕННАЯ версия)
function PremiumContentSystem.GetGamePassBonuses(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not config or not config.GamePasses then
        return {}, nil
    end
    
    local bonuses = {}
    
    for _, gamePass in ipairs(config.GamePasses) do
        if not gamePass.Name or not gamePass.Bonus then
            warn("Invalid game pass configuration: missing Name or Bonus")
            continue
        end
        
        local hasPass, err = PremiumContentSystem.HasGamePass(player, gamePass.Name)
        if err then
            warn("Error checking game pass "..gamePass.Name..": "..err)
        elseif hasPass then
            -- Применяем только модификаторы при каждом входе
            applyModifiersFromBonus(player, gamePass.Bonus, "GamePass", gamePass.Name)
            
            -- Добавляем обычные бонусы в результат
            for bonusType, value in pairs(gamePass.Bonus) do
                if bonusType ~= "Modifiers" then
                    bonuses[bonusType] = (bonuses[bonusType] or 0) + (type(value) == "number" and value or 1)
                end
            end
        end
    end
    
    return bonuses, nil
end

function PremiumContentSystem.GetPremiumBonuses(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local isPremium, err = PremiumContentSystem.IsPremium(player)
    if err then
        return nil, err
    end
    
    local bonuses = {}
    
    if isPremium and config and config.PremiumBonuses and #config.PremiumBonuses > 0 then
        local premiumBonus = config.PremiumBonuses[1].Bonus
        
        -- Применяем только модификаторы при каждом входе
        applyModifiersFromBonus(player, premiumBonus, "Premium", "Premium")
        
        -- Добавляем обычные бонусы в результат (только для информации)
        for bonusType, value in pairs(premiumBonus) do
            if bonusType ~= "Modifiers" then
                bonuses[bonusType] = value
            end
        end
    end
    
    return bonuses
end

function PremiumContentSystem.CanClaimDailyReward(player, groupName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not groupName then
        return nil, "Group name cannot be nil"
    end
    
    -- Проверяем доступ к группе наград
    local hasAccess, accessErr = PremiumContentSystem.HasAccessToRewardGroup(player, groupName)
    if not hasAccess then
        return nil, "No access to reward group: " .. tostring(accessErr)
    end
    
    return canClaimDailyReward(player, groupName)
end

function PremiumContentSystem.ClaimDailyReward(player, groupName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not groupName then
        return nil, "Group name cannot be nil"
    end
    
    -- Проверяем доступ к группе наград
    local hasAccess, accessErr = PremiumContentSystem.HasAccessToRewardGroup(player, groupName)
    if not hasAccess then
        return nil, "No access to reward group: " .. tostring(accessErr)
    end
    
    -- Проверяем, можно ли получить награду
    if not canClaimDailyReward(player, groupName) then
        return nil, "Cannot claim daily reward yet"
    end
    
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    local rewardData = getDailyRewardData(player)
    local consecutiveDays = calculateConsecutiveDays(player)
    local currentDay = rewardData.currentCycleDay or 1
    
    -- Получаем награду за текущий день
    local reward = PremiumContentSystem.GetRewardForDay(groupName, currentDay)
    if not reward then
        return nil, "No reward for day " .. currentDay
    end
    
    -- Применяем награду
    local applyResult, applyErr = PremiumContentSystem.ApplyReward(player, reward, "DailyReward", groupName)
    if not applyResult then
        return nil, "Failed to apply reward: " .. tostring(applyErr)
    end
    
    -- Обновляем данные
    local newData = {
        lastLoginTime = os.time(),
        consecutiveDays = consecutiveDays,
        currentCycleDay = currentDay + 1,
        totalDaysClaimed = (rewardData.totalDaysClaimed or 0) + 1,
        lastClaimedGroup = groupName
    }
    
    -- Проверяем завершение цикла
    if newData.currentCycleDay > group.CycleLength then
        -- Выдаем награду за завершение цикла
        local postReward = PremiumContentSystem.GetPostCompletionReward(groupName)
        if postReward then
            local postResult, postErr = PremiumContentSystem.ApplyReward(player, postReward, "DailyReward", groupName)
            if not postResult then
                warn("Failed to apply post completion reward: " .. tostring(postErr))
            end
        end
        
        -- Сбрасываем или продолжаем цикл в зависимости от настроек
        if group.Settings and group.Settings.ResetAfterCycle then
            newData.currentCycleDay = 1
        else
            newData.currentCycleDay = group.CycleLength -- Остаемся на последнем дне
        end
    end
    
    local updateSuccess, updateErr = updateDailyRewardData(player, newData)
    if not updateSuccess then
        warn("Failed to update daily reward data: " .. tostring(updateErr))
    end
    
    return {
        reward = reward,
        consecutiveDays = consecutiveDays,
        dayClaimed = currentDay,
        nextDay = newData.currentCycleDay
    }
end

function PremiumContentSystem.GetDailyRewardStatus(player, groupName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local rewardData = getDailyRewardData(player)
    local canClaim = canClaimDailyReward(player, groupName)
    local consecutiveDays = rewardData.consecutiveDays or 0
    local currentDay = rewardData.currentCycleDay or 1
    
    return {
        canClaim = canClaim,
        consecutiveDays = consecutiveDays,
        currentDay = currentDay,
        lastLoginTime = rewardData.lastLoginTime,
        totalDaysClaimed = rewardData.totalDaysClaimed or 0
    }
end

-- Получить все доступные достижения
function PremiumContentSystem.GetAllAchievements()
    if not config or not config.Achievements then
        return nil, "Achievements not configured"
    end
    return config.Achievements
end

-- Получить информацию о конкретном достижении
function PremiumContentSystem.GetAchievement(achievementName)
    if not config or not config.Achievements then
        return nil, "Achievements not configured"
    end
    
    return findAchievementByName(achievementName)
end

-- Проверить, есть ли у игрока достижение (ОБНОВЛЕННАЯ)
function PremiumContentSystem.PlayerHasAchievement(player, achievementName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local achievement, err = findAchievementByName(achievementName)
    if not achievement then
        return nil, err
    end
    
    local success, hasBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, achievement.BadgeId)
    if not success then
        return nil, "Failed to check badge ownership: " .. tostring(hasBadge)
    end
    
    return hasBadge
end

-- НОВАЯ ФУНКЦИЯ: Восстановить модификаторы достижений при входе
local function restoreAchievementModifiers(player)
    if not player then
        return
    end
    
    if not config or not config.Achievements then
        return
    end
    
    for _, achievement in ipairs(config.Achievements) do
        local hasAchievement, checkErr = PremiumContentSystem.PlayerHasAchievement(player, achievement.Name)
        if checkErr then
            warn("Error checking achievement "..achievement.Name..": "..tostring(checkErr))
            continue
        end
        
        if hasAchievement and achievement.Rewards and achievement.Rewards.Modifiers then
            -- Применяем только постоянные модификаторы (без Duration)
            for _, modifier in ipairs(achievement.Rewards.Modifiers) do
                if not modifier.Duration then
                    -- Применяем постоянный модификатор при каждом входе
                    local DataManager = ensureDataManager()
                    local modifierId = generateModifierId("Achievement", achievement.Name, _)
                    
                    local success = DataManager.AddModifier(
                        player,
                        modifier.Type,
                        modifierId,
                        modifier.Value,
                        modifier.Operation,
                        "Achievement"
                    )
                    
                    if not success then
                        warn(string.format("Failed to restore achievement modifier %s for player %s", modifier.Type, player.Name))
                    end
                end
            end
        end
    end
end

-- Выдать достижение игроку (ОБНОВЛЕННАЯ версия с правильной логикой модификаторов)
function PremiumContentSystem.AwardAchievement(player, achievementName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local achievement, err = findAchievementByName(achievementName)
    if not achievement then
        return nil, err
    end
    
    -- Проверяем, есть ли уже у игрока это достижение
    local hasAchievement, checkErr = PremiumContentSystem.PlayerHasAchievement(player, achievementName)
    if checkErr then
        return nil, "Failed to check existing achievement: " .. checkErr
    end
    
    if hasAchievement then
        return false, "Player already has this achievement"
    end
    
    -- Выдаем бэйдж
    local awarded, awardErr = awardBadge(player, achievement.BadgeId, achievement.Name)
    if not awarded then
        return nil, awardErr
    end
    
    -- Применяем награды к SavedData (все элементы кроме Modifiers)
    if achievement.Rewards then
        local success, rewardErr = applyRewardToSavedData(player, achievement.Rewards)
        if not success then
            warn("Failed to apply achievement rewards to SavedData: " .. tostring(rewardErr))
        end
        
        -- Применяем модификаторы из наград через DataManager
        -- Только для достижений с модификаторами, у которых есть Duration (временные модификаторы)
        local appliedModifiers = {}
        if achievement.Rewards.Modifiers then
            for i, modifier in ipairs(achievement.Rewards.Modifiers) do
                if modifier.Duration then
                    -- Применяем временные модификаторы только один раз при получении достижения
                    local modifierId = generateModifierId("Achievement", achievement.Name, i)
                    local DataManager = ensureDataManager()
                    
                    local success = DataManager.AddTemporaryModifier(
                        player,
                        modifier.Type,
                        modifierId,
                        modifier.Value,
                        modifier.Operation,
                        "Achievement",
                        modifier.Duration
                    )
                    
                    if success then
                        table.insert(appliedModifiers, modifierId)
                    else
                        warn(string.format("Failed to apply achievement modifier %s for player %s", modifier.Type, player.Name))
                    end
                end
                -- Постоянные модификаторы (без Duration) будут применяться при каждом входе
                -- через restoreAchievementModifiers
            end
        end
        
        -- Помечаем награду как выданную
        local markSuccess, markErr = markRewardAsClaimed(player, "Achievements", achievement.Name)
        if not markSuccess then
            warn("Failed to mark achievement reward as claimed: " .. tostring(markErr))
        end
        
        print(string.format("Achievement %s awarded to player %s", achievement.Name, player.Name))
        return true, {
            rewards = achievement.Rewards,
            appliedModifiers = appliedModifiers
        }
    else
        -- Помечаем достижение как полученное даже без наград
        local markSuccess, markErr = markRewardAsClaimed(player, "Achievements", achievement.Name)
        if not markSuccess then
            warn("Failed to mark achievement as claimed: " .. tostring(markErr))
        end
        
        print(string.format("Achievement %s awarded to player %s (no rewards)", achievement.Name, player.Name))
        return true, {appliedModifiers = {}}
    end
end

-- Восстановление модификаторов при повторном входе игрока (ОБНОВЛЕННАЯ с достижениями)
local function restorePlayerModifiers(player)
    local success = pcall(PremiumContentSystem.WaitForInitialization)
    if not success then
        warn("Failed to initialize PremiumContentSystem for player " .. player.Name)
        return
    end
    
    local DataManager = ensureDataManager()
    
    -- Ждем загрузки данных игрока через DataManager
    if not DataManager.IsDataLoaded(player) then
        local startTime = os.time()
        while os.time() - startTime < 10 do
            if DataManager.IsDataLoaded(player) then
                break
            end
            task.wait(0.5)
        end
    end
    
    -- Восстанавливаем GamePass бонусы (только модификаторы)
    local gamePassBonuses, err = PremiumContentSystem.GetGamePassBonuses(player)
    if err then
        warn("Failed to restore game pass bonuses for player " .. player.Name .. ": " .. tostring(err))
    end
    
    -- Восстанавливаем Premium бонусы (только модификаторы)
    local premiumBonuses, premiumErr = PremiumContentSystem.GetPremiumBonuses(player)
    if premiumErr then
        warn("Failed to restore premium bonuses for player " .. player.Name .. ": " .. tostring(premiumErr))
    end
    
    -- Восстанавливаем модификаторы достижений (только постоянные)
    restoreAchievementModifiers(player)
    
    -- Обрабатываем одноразовые премиум награды
    local premiumSuccess, premiumResult = processPremiumBonus(player)
    if not premiumSuccess and premiumResult ~= "Player is not premium" then
        warn("Failed to process premium bonus for player " .. player.Name .. ": " .. tostring(premiumResult))
    end
    
    print(string.format("Premium system ready for player %s", player.Name))
end

-- Обработчики игроков
Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        restorePlayerModifiers(player)
    end)
end)

-- Инициализация для уже подключенных игроков
task.spawn(function()
    local success = pcall(PremiumContentSystem.WaitForInitialization)
    if not success then
        warn("Failed to initialize PremiumContentSystem for existing players")
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            restorePlayerModifiers(player)
        end)
    end
end)


function PremiumContentSystem.GetAvailableGamePasses()
    if not config then
        return nil, "Configuration not initialized"
    end
    return config.GamePasses or {}
end

function PremiumContentSystem.GetAvailableProducts()
    if not config then
        return nil, "Configuration not initialized"
    end
    return config.DeveloperProducts or {}
end

function PremiumContentSystem.GetDailyRewardSettings()
    if not config or not config.DailyRewards then
        return nil, "Daily rewards not configured"
    end
    return config.DailyRewards.Settings or {}
end

function PremiumContentSystem.GetAllRewardGroups()
    if not config or not config.DailyRewards or not config.DailyRewards.RewardGroups then
        return nil, "Reward groups not configured"
    end
    return config.DailyRewards.RewardGroups
end

function PremiumContentSystem.GetRewardGroup(groupName)
    if not config or not config.DailyRewards or not config.DailyRewards.RewardGroups then
        return nil, "Reward groups not configured"
    end
    return config.DailyRewards.RewardGroups[groupName]
end

function PremiumContentSystem.HasAccessToRewardGroup(player, groupName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    if group.AccessType == "All" then
        return true
    elseif group.AccessType == "Premium" then
        return PremiumContentSystem.IsPremium(player)
    elseif group.AccessType == "GamePass" then
        if not group.RequiredGamePass then
            return false
        end
        return PremiumContentSystem.HasGamePass(player, group.RequiredGamePass)
    end
    
    return false
end

function PremiumContentSystem.GetAvailableRewardGroups(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local allGroups = PremiumContentSystem.GetAllRewardGroups()
    if not allGroups then
        return nil, "Failed to get reward groups"
    end
    
    local availableGroups = {}
    
    for groupName, groupData in pairs(allGroups) do
        local hasAccess, err = PremiumContentSystem.HasAccessToRewardGroup(player, groupName)
        if hasAccess then
            availableGroups[groupName] = groupData
        elseif err then
            warn("Error checking access to group "..groupName..": "..tostring(err))
        end
    end
    
    return availableGroups
end

function PremiumContentSystem.GetRewardForDay(groupName, day)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    if day < 1 or day > group.CycleLength then
        return nil, "Invalid day number"
    end
    
    return group.Rewards[day]
end

function PremiumContentSystem.GetPostCompletionReward(groupName)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    return group.PostCompletionReward
end

function PremiumContentSystem.GetGroupCycleLength(groupName)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    return group.CycleLength
end

function PremiumContentSystem.GetGroupDisplayName(groupName)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    return group.DisplayName or groupName
end

function PremiumContentSystem.GetGroupAccessType(groupName)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    return group.AccessType
end

function PremiumContentSystem.GetRequiredGamePassForGroup(groupName)
    local group = PremiumContentSystem.GetRewardGroup(groupName)
    if not group then
        return nil, "Reward group not found"
    end
    
    if group.AccessType ~= "GamePass" then
        return nil, "Group is not GamePass restricted"
    end
    
    return group.RequiredGamePass
end

function PremiumContentSystem.GetBadgeInfo(badgeId)
    local success, badgeInfo = pcall(BadgeService.GetBadgeInfoAsync, BadgeService, badgeId)
    if not success then
        return nil, "Failed to fetch badge info: " .. tostring(badgeInfo)
    end
    
    return badgeInfo
end

function PremiumContentSystem.GetPlayerAchievements(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not config or not config.Achievements then
        return {}
    end
    
    local playerAchievements = {}
    
    for _, achievement in ipairs(config.Achievements) do
        local hasAchievement, err = PremiumContentSystem.PlayerHasAchievement(player, achievement.Name)
        if hasAchievement then
            table.insert(playerAchievements, achievement)
        elseif err then
            warn("Error checking achievement "..achievement.Name..": "..tostring(err))
        end
    end
    
    return playerAchievements
end

function PremiumContentSystem.GetMissingAchievements(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not config or not config.Achievements then
        return {}
    end
    
    local missingAchievements = {}
    
    for _, achievement in ipairs(config.Achievements) do
        local hasAchievement, err = PremiumContentSystem.PlayerHasAchievement(player, achievement.Name)
        if not hasAchievement and not err then
            table.insert(missingAchievements, achievement)
        elseif err then
            warn("Error checking achievement "..achievement.Name..": "..tostring(err))
        end
    end
    
    return missingAchievements
end

function PremiumContentSystem.GetAchievementProgress(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    if not config or not config.Achievements then
        return 0, 0
    end
    
    local total = #config.Achievements
    local earned = #PremiumContentSystem.GetPlayerAchievements(player)
    
    return earned, total
end

function PremiumContentSystem.ApplyReward(player, reward, sourceType, sourceName)
    if not player or not reward then
        return nil, "Invalid parameters"
    end
    
    -- Применяем награды к SavedData
    local success, err = applyRewardToSavedData(player, reward)
    if not success then
        return nil, "Failed to apply reward to SavedData: " .. tostring(err)
    end
    
    -- Применяем модификаторы к ComputedData
    local appliedModifiers = applyModifiersFromBonus(player, reward, sourceType, sourceName)
    
    return {
        savedDataApplied = true,
        modifiersApplied = appliedModifiers
    }
end

function PremiumContentSystem.ApplyRewardModifiers(player, reward, sourceType, sourceName)
    if not player or not reward then
        return nil, "Invalid parameters"
    end
    
    return applyModifiersFromBonus(player, reward, sourceType, sourceName)
end

function PremiumContentSystem.RemoveAllModifiersBySource(player, sourceType, sourceName)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    removeAllModifiersBySource(player, sourceType, sourceName)
    return true
end

function PremiumContentSystem.GetActiveModifiers(player)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local DataManager = ensureDataManager()
    local tempModifiers = DataManager.GetTemporaryModifiersInfo(player)
    local computedData = DataManager.GetComputedData(player)
    
    if not computedData then
        return {}
    end
    
    -- Формируем информацию о активных модификаторах из DataManager
    local activeModifiers = {}
    
    -- Добавляем временные модификаторы
    for modifierId, modifierInfo in pairs(tempModifiers) do
        activeModifiers[modifierId] = {
            type = modifierInfo.paramName,
            sourceType = modifierInfo.source,
            sourceName = "Temporary",
            duration = modifierInfo.remainingTime,
            isPermanent = false,
            remainingTime = modifierInfo.remainingTime
        }
    end
    
    return activeModifiers
end

function PremiumContentSystem.HasActiveModifier(player, modifierType)
    if not player then
        return false
    end
    
    local DataManager = ensureDataManager()
    local tempModifiers = DataManager.GetTemporaryModifiersInfo(player)
    
    for _, modifierInfo in pairs(tempModifiers) do
        if modifierInfo.paramName == modifierType then
            return true
        end
    end
    
    return false
end

function PremiumContentSystem.GetRemainingModifierTime(player, modifierId)
    if not player then
        return nil, "Player cannot be nil"
    end
    
    local DataManager = ensureDataManager()
    local tempModifiers = DataManager.GetTemporaryModifiersInfo(player)
    
    if tempModifiers and tempModifiers[modifierId] then
        return tempModifiers[modifierId].remainingTime
    end
    
    return nil, "Modifier not found"
end

function PremiumContentSystem.GetComputedValue(player, paramName)
    local DataManager = ensureDataManager()
    local computedData = DataManager.GetComputedData(player)
    if computedData and computedData[paramName] then
        return computedData[paramName]
    end
    return nil
end

function PremiumContentSystem.ForceProcessPurchase(player, productId, purchaseId)
    print("Forcing purchase processing...")
    local success, result = processProductPurchase(player, productId, purchaseId or "forced_" .. HttpService:GenerateGUID(false))
    return success, result
end

-- API для AssetService
function PremiumContentSystem.SetAssetStatusAPI(api)
    print("PremiumContentSystem received AssetStatusAPI")
end

return PremiumContentSystem