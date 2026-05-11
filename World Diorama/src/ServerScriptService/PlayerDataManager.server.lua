-- PlayerDataManager (ServerScriptService)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Загрузка конфигурации улучшений
local UpgradesConfig = require(game:GetService("ServerStorage"):FindFirstChild("Configs"):FindFirstChild("UpgradesConfig"))

local EventSystem
local DataManager
local PremiumContentSystem

-- Системные конфигурации
local GameSystems = {
    -- Система уровней
    LevelSystem = {
        BaseExp = 100,
        MaxLevel = 100,
        SkillPointsPerLevel = 1,
        SkillPointsOnPrestige = 5,
        LevelExpFormula = function(level)
            return math.ceil(100 * math.pow(1.1, level - 1) / 10) * 10
        end,
        LevelRewards = {
            [2] = {type = "gold", amount = 500, displayName = "500 Gold", imageId = "rbxassetid://7072702632"},
            [10] = {type = "gold", amount = 2000, displayName = "2000 Gold", imageId = "rbxassetid://7072702632"},
            [15] = {type = "gold", amount = 5000, displayName = "5000 Gold", imageId = "rbxassetid://7072702632"},
            [20] = {type = "gold", amount = 10000, displayName = "10000 Gold", imageId = "rbxassetid://7072702632"},
            [25] = {type = "item", itemId = "speed_boost", displayName = "Speed Boost", imageId = "rbxassetid://7072748232"},
            [30] = {type = "gold", amount = 25000, displayName = "25000 Gold", imageId = "rbxassetid://7072702632"},
            [35] = {type = "item", itemId = "double_gold_hour", displayName = "x2 Gold (1h)", imageId = "rbxassetid://7072758232"},
            [40] = {type = "gold", amount = 50000, displayName = "50000 Gold", imageId = "rbxassetid://7072702632"},
            [45] = {type = "item", itemId = "rare_frame", displayName = "Rare Frame", imageId = "rbxassetid://7072768232"},
            [50] = {type = "item", itemId = "legendary_stand", displayName = "Legendary Stand", imageId = "rbxassetid://7072778232"},
            [60] = {type = "gold", amount = 100000, displayName = "100000 Gold", imageId = "rbxassetid://7072702632"},
            [70] = {type = "item", itemId = "mythic_crown", displayName = "Mythic Crown", imageId = "rbxassetid://7072788232"},
            [80] = {type = "gold", amount = 200000, displayName = "200000 Gold", imageId = "rbxassetid://7072702632"},
            [90] = {type = "item", itemId = "divine_aura", displayName = "Divine Aura", imageId = "rbxassetid://7072798232"},
            [100] = {type = "item", itemId = "godly_title", displayName = "Godly Title", imageId = "rbxassetid://7072808232"}
        }
    },

    -- Система улучшений (загружена из модуля)
    Upgrades = UpgradesConfig,

    -- Система перерождений
    PrestigeSystem = {
        MinLevel = 90,
        BaseMultiplier = 0.1,
        MultiplierGrowth = 0.05,
        MaxPrestige = 100,
        DioramaGoldGrowth = 0.03,
        DonationBonusGrowth = 0.02,
        StatsMultiplierGrowth = 0.02
    },

    -- Система квестов
    QuestSystem = require(game:GetService("ServerStorage"):FindFirstChild("Configs"):FindFirstChild("QuestConfig"))
}

-- Обработчики наград за уровень
local LevelRewardHandlers = {
    gold = function(player, data, currentLevel)
        DataManager.UpdateData(player, function(pData)
            pData.Gold = (pData.Gold or 0) + data.amount
            if pData.Stats then
                pData.Stats.TotalGoldEarned = (pData.Stats.TotalGoldEarned or 0) + data.amount
            end
            return pData
        end)
        EventSystem.FireClient(player, "LevelRewardReceived", {
            type = "gold",
            amount = data.amount,
            level = currentLevel
        })
        print(string.format("[LevelReward] Игрок %s получил %d золота за уровень %d", 
            player.Name, data.amount, currentLevel))
    end,
    
    item = function(player, data, currentLevel)
        DataManager.UpdateData(player, function(pData)
            if not pData.Customization then
                pData.Customization = {}
            end
            if not pData.Customization.Items then
                pData.Customization.Items = {}
            end
            pData.Customization.Items[data.itemId] = true
            return pData
        end)
        
        EventSystem.FireClient(player, "LevelRewardReceived", {
            type = "item",
            itemId = data.itemId,
            level = currentLevel
        })
        print(string.format("[LevelReward] Игрок %s получил предмет %s за уровень %d", 
            player.Name, data.itemId, currentLevel))
    end
}

-- Стандартные предметы кастомизации для нового игрока
local DEFAULT_CUSTOMIZATION = {
    Frames = {
        DefaultFrame = true,
    },
    Stands = {
        DefaultStand = true,
    },
    Colors = {
        White = true,
        Black = false,
        Red = false,
        Green = false,
        Blue = false,
        Yellow = false,
        Cyan = false,
        Magenta = false,
        Gray = true,
    },
    Materials = {
        SmoothPlastic = true,
        Wood = false,
        Metal = false,
        Glass = false,
        Marble = false,
        Granite = false,
        Pebble = false,
        Slate = false,
        Brick = false,
        Cobblestone = false,
    }
}

-- Таблицы для отслеживания подписок
local goldGUISubscribers = {}
local upgradesGUISubscribers = {}
local levelGUISubscribers = {}
local questsGUISubscribers = {}
local updateInterval = 1

-- Ожидание загрузки AssetService
local function waitForAssetService()
    local startTime = os.time()
    local timeout = 30
    
    while true do
        if _G.AssetService and _G.AssetService:IsLoaded() then
            local eventSystemStatus = _G.AssetService:GetAssetStatus("EventSystem")
            local dataManagerStatus = _G.AssetService:GetAssetStatus("DataManager")
            if eventSystemStatus and eventSystemStatus.loaded and eventSystemStatus.moduleReference 
               and dataManagerStatus and dataManagerStatus.loaded and dataManagerStatus.moduleReference then
                return true
            end
        end
        
        if os.time() - startTime > timeout then
            warn("[PlayerDataManager] Таймаут ожидания AssetService")
            return false
        end
        
        task.wait(1)
    end
end

if not waitForAssetService() then
    warn("Не удалось загрузить необходимые модули через AssetService")
    return
end

EventSystem = _G.AssetService:GetModule("EventSystem")
DataManager = _G.AssetService:GetModule("DataManager")
PremiumContentSystem = _G.AssetService:GetModule("PremiumContentSystem")

if not EventSystem or not DataManager then
    warn("EventSystem или DataManager не найден через AssetService")
    return
end

if not PremiumContentSystem then
    warn("[PlayerDataManager] PremiumContentSystem не найден через AssetService, функции пропуска квестов будут недоступны")
end

-- Вспомогательные функции для работы с улучшениями
local function getUpgradeEffect(upgradeConfig, level)
    if upgradeConfig.effect == "unlock" then
        return level > 0
    end
    return upgradeConfig.effect.base * (upgradeConfig.effect.multiplier ^ level)
end

local function getUpgradeCost(upgradeConfig, level)
    return math.floor(upgradeConfig.cost.base * (upgradeConfig.cost.multiplier ^ level))
end

-- Функция ожидания загрузки данных игрока
local function waitForDataLoaded(player, timeoutSeconds)
    timeoutSeconds = timeoutSeconds or 30
    local startTime = os.time()
    
    while not DataManager.IsDataLoaded(player) do
        if os.time() - startTime > timeoutSeconds then
            warn(string.format("[PlayerDataManager] Таймаут загрузки данных игрока %s (%d)", player.Name, player.UserId))
            return false
        end
        task.wait(0.1)
    end
    
    return true
end

-- Функция безопасного получения данных (сырых)
local function getPlayerData(player)
    if not waitForDataLoaded(player) then
        return nil, "DataLoadTimeout"
    end
    
    local data, error = DataManager.GetData(player)
    if not data then
        warn(string.format("[PlayerDataManager] Не удалось получить данные игрока %s: %s", player.Name, tostring(error)))
        return nil, error or "UnknownError"
    end
    
    return data
end

-- Функция для обновления модификаторов перерождения
local function updatePrestigeModifiers(player)
    local data = getPlayerData(player)
    if not data then return false end
    
    local prestigeLevel = data.PrestigeLevel or 0
    
    -- Удаляем все старые модификаторы перерождения
    DataManager.RemoveModifier(player, "DioramaGoldMultiplier", "Prestige_Diorama")
    DataManager.RemoveModifier(player, "DonationBonusMultiplier", "Prestige_Donation")
    DataManager.RemoveModifier(player, "StatsMultiplier", "Prestige_Stats")

    -- Применяем новые модификаторы, если есть хотя бы 1 перерождение
    if prestigeLevel > 0 then
        -- Множитель золота с диорам
        local dioramaGoldBonus = 1 + prestigeLevel * GameSystems.PrestigeSystem.DioramaGoldGrowth
        DataManager.AddModifier(
            player,
            "DioramaGoldMultiplier",
            "Prestige_Diorama",
            dioramaGoldBonus,
            "MultiplyTotal",
            "Prestige",
            math.huge,
            false
        )
        
        -- Множитель бонусов с доната
        local donationBonus = 1 + prestigeLevel * GameSystems.PrestigeSystem.DonationBonusGrowth
        DataManager.AddModifier(
            player,
            "DonationBonusMultiplier",
            "Prestige_Donation",
            donationBonus,
            "MultiplyTotal",
            "Prestige",
            math.huge,
            false
        )
        
        -- Множитель характеристик (GoldPerMinute, StorageCapacity, DoubleChance, QuestBonus)
        local statsMultiplier = 1 + prestigeLevel * GameSystems.PrestigeSystem.StatsMultiplierGrowth
        DataManager.AddModifier(
            player,
            "StatsMultiplier",
            "Prestige_Stats",
            statsMultiplier,
            "MultiplyTotal",
            "Prestige",
            math.huge,
            false
        )
    end
    
    return true
end

-- Функция получения множителей из DataManager (ComputedFields)
local function getMultiplierData(player)
    if not waitForDataLoaded(player) then
        return nil, "DataLoadTimeout"
    end
    
    local computedData, error = DataManager.GetComputedData(player)
    if not computedData then
        warn(string.format("[PlayerDataManager] Не удалось получить вычисляемые данные игрока %s: %s", player.Name, tostring(error)))
        return nil, error or "UnknownError"
    end
    
    return computedData
end

-- Функция получения итоговых эффективных параметров
local function getEffectiveComputedData(player)
    local data = getPlayerData(player)
    if not data then return nil end
    
    local multipliers = getMultiplierData(player)
    if not multipliers then return nil end
    
    local upgrades = data.Upgrades
    local result = {}
    
    local statsMultiplier = multipliers.StatsMultiplier or 1
    
    local goldLevel = upgrades.GoldPerMinuteLevel or 0
    local goldBase = getUpgradeEffect(GameSystems.Upgrades.GoldPerMinute, goldLevel)
    result.GoldPerMinute = goldBase * (multipliers.GoldPerMinuteMultiplier or 1) * statsMultiplier
    
    local storageLevel = upgrades.StorageCapacityLevel or 0
    local storageBase = getUpgradeEffect(GameSystems.Upgrades.StorageCapacity, storageLevel)
    result.StorageCapacity = storageBase * (multipliers.StorageCapacityMultiplier or 1) * statsMultiplier
    
    local doubleLevel = upgrades.DoubleChanceLevel or 0
    local doubleBase = getUpgradeEffect(GameSystems.Upgrades.DoubleChance, doubleLevel)
    result.DoubleChance = doubleBase * (multipliers.DoubleChanceMultiplier or 1) * statsMultiplier
    
    -- Расчет бонуса к заданиям (только золото)
    local questBonusLevel = upgrades.QuestBonusLevel or 0
    local questBonusBase = getUpgradeEffect(GameSystems.Upgrades.QuestBonus, questBonusLevel)
    result.QuestBonusMultiplier = 1 + (questBonusBase * (multipliers.QuestBonusMultiplier or 1) * statsMultiplier)
    
    result.GoldMultiplier = multipliers.GoldMultiplier or 1
    result.DioramaGoldMultiplier = multipliers.DioramaGoldMultiplier or 1
    result.DonationBonusMultiplier = multipliers.DonationBonusMultiplier or 1
    result.StatsMultiplier = statsMultiplier
    result.ExperienceMultiplier = multipliers.ExperienceMultiplier or 1
    result.AutoCollect = upgrades.AutoCollect or false
    
    return result
end

-- Расчет опыта для следующего уровня
local function calculateExpForLevel(level)
    return GameSystems.LevelSystem.LevelExpFormula(level)
end

-- Проверка наличия бонусного геймпаса
local function playerHasQuestBonusPass(player)
    local passId = GameSystems.QuestSystem.GamePassBonusId
    if not passId then return false end
    local success, owned = pcall(function()
        return false -- заменить на реальную проверку
    end)
    return success and owned
end

-- Проверка наличия геймпаса "quests" для пропуска и обновления квестов
local function playerHasQuestsPass(player)
    if not PremiumContentSystem then return false end
    local hasPass, _ = PremiumContentSystem.HasGamePass(player, "quests")
    return hasPass or false
end

-- Функция получения данных для Quests GUI
local function getQuestsData(player)
    local data = getPlayerData(player)
    if not data then return nil end
    
    return {
        quests = data.DailyQuests or {},
        questRefreshTime = data.QuestRefreshTime or 0,
        maxDailyQuests = GameSystems.QuestSystem.MaxDailyQuests,
        itemTypesConfig = GameSystems.QuestSystem.ItemTypes,
        hasBonusPass = playerHasQuestBonusPass(player),
        hasQuestsPass = playerHasQuestsPass(player)
    }
end

-- Функция активации предметов для квестов на сбор
local function activateQuestItemsForPlayer(player, quests)
    for _, quest in ipairs(quests) do
        if quest.type == "collect_items" and not quest.completed then
            local collectedIds = quest.collectedItemIds or {}
            EventSystem.FireClient(player, "ActivateQuestItems", {
                itemType = quest.itemType,
                questId = quest.id,
                mechanic = quest.mechanic,
                holdTime = quest.holdTime,
                collectedIds = collectedIds
            })
        end
    end
end

local function sendQuestsDataUpdate(player)
    local questsData = getQuestsData(player)
    if questsData then
        EventSystem.FireClient(player, "QuestsDataUpdated", questsData)
    end
end

local function sendQuestsGUIUpdates()
    for userId, _ in pairs(questsGUISubscribers) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player:IsA("Player") then
            local guiData = getQuestsData(player)
            if guiData then
                EventSystem.FireClient(player, "QuestsGUIUpdate", guiData)
            end
        end
    end
end

-- Обновление прогресса квестов
local function updateQuestProgress(player, questType, amount, itemId, itemType)
    local data = getPlayerData(player)
    if not data or not data.DailyQuests then return end
    
    local updated = false
    
    for _, quest in ipairs(data.DailyQuests) do
        if not quest.completed and quest.type == questType then
            if questType == "collect_items" then
                if quest.itemType == itemType and itemId then
                    if not quest.collectedItemIds then 
                        quest.collectedItemIds = {} 
                    end
                    if not quest.collectedItemIds[itemId] then
                        quest.collectedItemIds[itemId] = true
                        quest.current = math.min(quest.current + amount, quest.target)
                        updated = true
                    end
                end
            else
                quest.current = math.min(quest.current + amount, quest.target)
                updated = true
            end
            
            if quest.current >= quest.target then
                quest.completed = true
                if data.Stats then
                    data.Stats.TotalQuestsCompleted = (data.Stats.TotalQuestsCompleted or 0) + 1
                end
            end
        end
    end
    
    if updated then
        DataManager.UpdateData(player, function() return data end)
        EventSystem.FireClient(player, "QuestProgress", questType, amount)
        sendQuestsDataUpdate(player)
        sendQuestsGUIUpdates()
    end
end

-- Функция получения данных для Level GUI
local function getLevelData(player)
    local data = getPlayerData(player)
    if not data then return nil end
    
    return {
        level = data.Level or 1,
        experience = data.Experience or 0,
        nextLevelExp = calculateExpForLevel(data.Level or 1),
        skillPoints = data.SkillPoints or 0,
        prestigeLevel = data.PrestigeLevel or 0,
        prestigeConfig = GameSystems.PrestigeSystem
    }
end

local function sendLevelDataUpdate(player)
    local levelData = getLevelData(player)
    if levelData then
        EventSystem.FireClient(player, "LevelDataUpdated", levelData)
    end
end

local function sendLevelGUIUpdates()
    for userId, _ in pairs(levelGUISubscribers) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player:IsA("Player") then
            local guiData = getLevelData(player)
            if guiData then
                EventSystem.FireClient(player, "LevelGUIUpdate", guiData)
            end
        end
    end
end

-- Функция получения данных для Upgrades GUI
local function getUpgradesData(player)
    local data = getPlayerData(player)
    if not data then return nil end
    
    local upgradesForClient = {}
    for key, value in pairs(data.Upgrades) do
        local clientKey = key:gsub("Level$", "")
        upgradesForClient[clientKey] = value
    end
    
    return {
        upgrades = upgradesForClient,
        gold = data.Gold or 0,
        skillPoints = data.SkillPoints or 0,
        upgradeConfig = GameSystems.Upgrades
    }
end

local function sendUpgradesGUIUpdates()
    for userId, _ in pairs(upgradesGUISubscribers) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player:IsA("Player") then
            local guiData = getUpgradesData(player)
            if guiData then
                EventSystem.FireClient(player, "UpgradesGUIUpdate", guiData)
            end
        end
    end
end

-- Внутренняя функция обработки повышения уровня (с наградами)
local function processLevelUp(player, data)
    local currentExp = data.Experience or 0
    local currentLevel = data.Level or 1
    local leveledUp = false
    local levelsGained = 0
    
    local requiredExp = calculateExpForLevel(currentLevel)
    
    while currentExp >= requiredExp and currentLevel < GameSystems.LevelSystem.MaxLevel do
        currentLevel = currentLevel + 1
        levelsGained = levelsGained + 1
        currentExp = currentExp - requiredExp
        requiredExp = calculateExpForLevel(currentLevel)
        leveledUp = true
        
        if currentLevel % 10 == 0 then
            data.SkillPoints = (data.SkillPoints or 0) + 2
        else
            data.SkillPoints = (data.SkillPoints or 0) + 1
        end
        
        local rewardConfig = GameSystems.LevelSystem.LevelRewards and GameSystems.LevelSystem.LevelRewards[currentLevel]
        if rewardConfig then
            local handler = LevelRewardHandlers[rewardConfig.type]
            if handler then
                handler(player, rewardConfig, currentLevel)
            else
                warn("Unknown reward type for level", currentLevel, rewardConfig.type)
            end
        end
        
        if data.Stats then
            if currentLevel > (data.Stats.MaxLevelReached or 1) then
                data.Stats.MaxLevelReached = currentLevel
            end
        end
    end
    
    if leveledUp then
        data.Level = currentLevel
        data.Experience = currentExp
        EventSystem.FireClient(player, "LevelUp", currentLevel, data.SkillPoints, levelsGained)
    end
    
    return leveledUp, currentLevel, levelsGained
end

-- Публичная функция проверки уровня
local function checkLevelUp(player)
    local data = getPlayerData(player)
    if not data then return false end
    
    local leveledUp, newLevel, levelsGained = processLevelUp(player, data)
    
    if leveledUp then
        DataManager.UpdateData(player, function() return data end)
        
        DataManager.AddTemporaryModifier(
            player,
            "GoldMultiplier",
            "LevelUpBonus_" .. os.time(),
            0.5,
            "MultiplyTotal",
            "Level Up",
            300,
            false
        )
        
        updateQuestProgress(player, "reach_level", levelsGained)
        sendLevelDataUpdate(player)
        sendLevelGUIUpdates()
        sendUpgradesGUIUpdates()
    end
    
    return leveledUp, newLevel
end

-- Универсальная функция добавления опыта
local function addExperience(player, amount)
    if amount <= 0 then return false, 0, 0 end
    
    local data = getPlayerData(player)
    if not data then return false end
    
    data.Experience = (data.Experience or 0) + amount
    
    local leveledUp, newLevel, levelsGained = processLevelUp(player, data)
    
    DataManager.UpdateData(player, function() return data end)
    
    if leveledUp then
        DataManager.AddTemporaryModifier(
            player,
            "GoldMultiplier",
            "LevelUpBonus_" .. os.time(),
            0.5,
            "MultiplyTotal",
            "Level Up",
            300,
            false
        )
        updateQuestProgress(player, "reach_level", levelsGained)
    end
    
    sendLevelDataUpdate(player)
    sendLevelGUIUpdates()
    
    return true, data.Level, data.Experience
end

-- Применение бонуса от геймпаса к награде
local function applyGamePassBonus(player, baseReward)
    if playerHasQuestBonusPass(player) then
        local multiplier = GameSystems.QuestSystem.GamePassBonusMultiplier or 1.0
        return {
            gold = math.floor(baseReward.gold * multiplier),
            exp = math.floor(baseReward.exp * multiplier)
        }
    end
    return baseReward
end

-- Генерация одного нового квеста
local function generateSingleQuest(player)
    local questTypes = GameSystems.QuestSystem.Types
    local rarities = GameSystems.QuestSystem.Rarities
    local itemTypes = GameSystems.QuestSystem.ItemTypes
    
    local questType = questTypes[math.random(#questTypes)]
    
    local rarityRoll = math.random()
    local rarityName, rarityData
    local cumulative = 0
    for name, data in pairs(rarities) do
        cumulative = cumulative + data.chance
        if rarityRoll <= cumulative then
            rarityName = name
            rarityData = data
            break
        end
    end
    
    local target, reward, itemTypeData
    
    if questType.id == "collect_items" then
        itemTypeData = itemTypes[math.random(#itemTypes)]
        local targetIndex = math.random(#itemTypeData.targets)
        target = itemTypeData.targets[targetIndex] * rarityData.multiplier
        local baseReward = itemTypeData.rewards[targetIndex]
        reward = {
            gold = math.floor(baseReward.gold * rarityData.multiplier),
            exp = math.floor(baseReward.exp * rarityData.multiplier)
        }
    else
        local targetIndex = math.random(#questType.targets)
        target = questType.targets[targetIndex] * rarityData.multiplier
        local baseReward = questType.rewards[targetIndex]
        reward = {
            gold = math.floor(baseReward.gold * rarityData.multiplier),
            exp = math.floor(baseReward.exp * rarityData.multiplier)
        }
    end
    
    local finalReward = applyGamePassBonus(player, reward)
    
    local quest = {
        id = questType.id .. "_" .. os.time() .. "_" .. HttpService:GenerateGUID(false):sub(1,8),
        type = questType.id,
        name = questType.name,
        rarity = rarityData.name or rarityName,
        rarityName = rarityName,
        target = math.floor(target),
        current = 0,
        reward = finalReward,
        completed = false,
        claimed = false,
        createdAt = os.time()
    }
    
    -- Генерация описания квеста
    if questType.id == "collect_items" then
        quest.itemType = itemTypeData.type
        quest.itemName = itemTypeData.name
        quest.mechanic = itemTypeData.mechanic
        quest.holdTime = itemTypeData.holdTime
        quest.collectedItemIds = {}
        quest.description = (questType.description or "Item: {itemName}"):gsub("{itemName}", itemTypeData.name)
    else
        quest.description = (questType.description or ""):gsub("{target}", tostring(quest.target))
    end
    
    return quest
end

-- Генерация полного набора ежедневных квестов
local function generateDailyQuests(player)
    local quests = {}
    local maxQuests = GameSystems.QuestSystem.MaxDailyQuests
    
    for i = 1, maxQuests do
        local quest = generateSingleQuest(player)
        table.insert(quests, quest)
    end
    
    return quests
end

-- Проверка и обновление квестов
local function updateDailyQuests(player, forceRefresh)
    local data = getPlayerData(player)
    if not data then return end
    
    local currentTime = os.time()
    
    if forceRefresh or not data.DailyQuests or #data.DailyQuests == 0 or 
       currentTime >= (data.QuestRefreshTime or 0) then
        
        data.DailyQuests = generateDailyQuests(player)
        data.QuestRefreshTime = currentTime + (GameSystems.QuestSystem.RefreshHours * 3600)
        
        DataManager.UpdateData(player, function() return data end)
        sendQuestsDataUpdate(player)
    end
end

-- Замена квеста, если осталось 0
local function replaceQuestIfNeeded(player, quests)
    if #quests == 0 then
        local newQuest = generateSingleQuest(player)
        table.insert(quests, newQuest)
    end
    return quests
end

-- Удаление квеста и замена новым
local function removeQuestAndReplace(player, questId)
    local data = getPlayerData(player)
    if not data or not data.DailyQuests then return end
    
    local newQuests = {}
    for _, q in ipairs(data.DailyQuests) do
        if q.id ~= questId then
            table.insert(newQuests, q)
        end
    end
    
    data.DailyQuests = replaceQuestIfNeeded(player, newQuests)
    
    DataManager.UpdateData(player, function() return data end)
    sendQuestsDataUpdate(player)
    sendQuestsGUIUpdates()
    activateQuestItemsForPlayer(player, data.DailyQuests)
end

-- Расчет накопленного золота
local function calculateAccumulatedGold(player)
    local effectiveData = getEffectiveComputedData(player)
    if not effectiveData then return 0 end
    
    local data = getPlayerData(player)
    if not data then return 0 end
    
    local currentTime = os.time()
    local lastCollectTime = data.LastCollectTime or currentTime
    local timePassed = math.max(0, currentTime - lastCollectTime)
    
    local goldPerMinute = effectiveData.GoldPerMinute or 10
    local storageCapacity = effectiveData.StorageCapacity or 1000
    
    local goldPerSecond = goldPerMinute / 60
    local accumulated = data.CollectedGold or 0
    accumulated = accumulated + (timePassed * goldPerSecond)
    
    return math.min(accumulated, storageCapacity)
end

-- Функция сбора накопленного золота
local function collectAccumulatedGold(player)
    local data = getPlayerData(player)
    if not data then return 0, 0 end
    
    local effectiveData = getEffectiveComputedData(player)
    if not effectiveData then return 0, 0 end
    
    local currentTime = os.time()
    local accumulated = calculateAccumulatedGold(player)
    
    if accumulated <= 0 then
        return 0, 0
    end
    
    local doubleChance = effectiveData.DoubleChance or 0.01
    local isDouble = math.random() < doubleChance
    
    local baseMultiplier = 1.0
    if isDouble then baseMultiplier = baseMultiplier * 2 end
    
    local goldMultiplier = effectiveData.GoldMultiplier or 1.0
    local totalMultiplier = baseMultiplier * goldMultiplier
    
    local collectedGold = math.floor(accumulated * totalMultiplier)
    
    local success = DataManager.UpdateData(player, function(playerData)
        playerData.Gold = (playerData.Gold or 0) + collectedGold
        playerData.CollectedGold = 0
        playerData.LastCollectTime = currentTime
        
        if playerData.Stats then
            playerData.Stats.TotalGoldEarned = (playerData.Stats.TotalGoldEarned or 0) + collectedGold
        end
        
        return playerData
    end)
    
    if success then
        updateQuestProgress(player, "collect_gold", collectedGold)
        
        EventSystem.FireClient(player, "GoldCollected", collectedGold, {
            isDouble = isDouble,
            multiplier = totalMultiplier
        })
        
        sendUpgradesGUIUpdates()
        
        return collectedGold, totalMultiplier
    end
    
    return 0, 0
end

local function sendUpgradesDataUpdate(player)
    local upgradesData = getUpgradesData(player)
    if upgradesData then
        EventSystem.FireClient(player, "UpgradesDataUpdated", upgradesData)
    end
end

-- Функция улучшения параметра (с проверкой очков навыков)
local function upgradeSkill(player, skillType)
    local data = getPlayerData(player)
    
    if not data or not GameSystems.Upgrades[skillType] then
        return false, "Invalid upgrade type"
    end
    
    local upgradeConfig = GameSystems.Upgrades[skillType]
    local skillPointCost = upgradeConfig.skillPointCost or 1
    
    local dataKey = (skillType == "AutoCollect") and "AutoCollect" or (skillType .. "Level")
    local currentLevel = data.Upgrades[dataKey] or 0
    
    if currentLevel >= upgradeConfig.maxLevel then
        return false, "Maximum level reached"
    end
    
    local goldCost = getUpgradeCost(upgradeConfig, currentLevel)
    
    if (data.Gold or 0) < goldCost then
        return false, "Not enough gold"
    end
    
    if (data.SkillPoints or 0) < skillPointCost then
        return false, "Not enough skill points"
    end
    
    data.Gold = (data.Gold or 0) - goldCost
    data.SkillPoints = (data.SkillPoints or 0) - skillPointCost
    
    if skillType == "AutoCollect" then
        data.Upgrades.AutoCollect = true
    else
        data.Upgrades[dataKey] = currentLevel + 1
    end
    
    local success = DataManager.UpdateData(player, function() return data end)
    
    if success then
        updateQuestProgress(player, "upgrade", 1)
        
        local effect = (skillType == "AutoCollect") and "unlock" 
                      or getUpgradeEffect(upgradeConfig, currentLevel + 1)
        EventSystem.FireClient(player, "SkillUpgraded", skillType, currentLevel + 1, effect)
        
        sendUpgradesDataUpdate(player)
        sendUpgradesGUIUpdates()
        sendLevelDataUpdate(player)
        
        return true, "Upgrade successfully applied", currentLevel + 1
    end
    
    return false, "Data update error"
end

-- Функция перерождения
local function prestige(player)
    local data = getPlayerData(player)
    
    if not data then return false, "Data load error" end
    
    if data.Level < GameSystems.PrestigeSystem.MinLevel then
        return false, string.format("Level %d required for prestige", GameSystems.PrestigeSystem.MinLevel)
    end
    
    local currentPrestige = data.PrestigeLevel or 0
    
    if currentPrestige >= GameSystems.PrestigeSystem.MaxPrestige then
        return false, string.format("Maximum prestige level reached (%d)", GameSystems.PrestigeSystem.MaxPrestige)
    end
    
    local prestigeGold = data.Gold or 0
    local totalPrestigeGold = (data.Stats and data.Stats.TotalPrestigeGold or 0) + prestigeGold
    
    local prestigeBonuses = data.PrestigeBonuses or {}
    table.insert(prestigeBonuses, {
        level = data.Level,
        gold = prestigeGold,
        time = os.time(),
        fromPrestige = currentPrestige + 1
    })
    
    local newData = {
        Gold = 100,
        Level = 1,
        Experience = 0,
        PrestigeLevel = currentPrestige + 1,
        LastCollectTime = os.time(),
        CollectedGold = 0,
        SkillPoints = GameSystems.LevelSystem.SkillPointsOnPrestige,
        CompletedQuests = 0,
        DailyQuests = data.DailyQuests or {},
        QuestRefreshTime = data.QuestRefreshTime or 0,
        Upgrades = {},
        ClaimedLevelRewards = data.ClaimedLevelRewards or {},
        Stats = {
            TotalGoldEarned = data.Stats and data.Stats.TotalGoldEarned or 0,
            TotalPrestigeGold = totalPrestigeGold,
            TotalQuestsCompleted = data.Stats and data.Stats.TotalQuestsCompleted or 0,
            MaxLevelReached = math.max(data.Stats and data.Stats.MaxLevelReached or 1, data.Level),
            PlayTime = data.Stats and data.Stats.PlayTime or 0
        },
        LastLogin = os.time(),
        PrestigeBonuses = prestigeBonuses,
        Customization = data.Customization or DEFAULT_CUSTOMIZATION,
        TutorialCompleted = data.TutorialCompleted or false,
        Settings = data.Settings or {},
        dailyRewards = data.dailyRewards or {}
    }
    
    local success = DataManager.UpdateData(player, function() return newData end)
    
    if success then
        -- Обновляем модификаторы перерождения
        updatePrestigeModifiers(player)
        
        updateQuestProgress(player, "prestige", 1)
        
        -- Получаем новый множитель для отображения
        local newMultiplier = GameSystems.PrestigeSystem.BaseMultiplier + 
                             ((currentPrestige + 1) * GameSystems.PrestigeSystem.MultiplierGrowth)
        
        local dioramaBonus = (currentPrestige + 1) * GameSystems.PrestigeSystem.DioramaGoldGrowth
        local donationBonus = (currentPrestige + 1) * GameSystems.PrestigeSystem.DonationBonusGrowth
        local statsBonus = (currentPrestige + 1) * GameSystems.PrestigeSystem.StatsMultiplierGrowth
        
        EventSystem.FireClient(player, "PrestigeComplete", currentPrestige + 1, newMultiplier, prestigeGold, dioramaBonus, donationBonus, statsBonus)
        sendLevelDataUpdate(player)
        sendQuestsDataUpdate(player)
        sendLevelGUIUpdates()
        sendUpgradesGUIUpdates()
        
        print(string.format("[Prestige] Игрок %s выполнил перерождение! Новый уровень: %d. Множители: Gold=%.2f, Diorama=%.2f, Donation=%.2f, Stats=%.2f",
            player.Name, currentPrestige + 1, newMultiplier, dioramaBonus, donationBonus, statsBonus))
        
        return true, "Prestige successful!", currentPrestige + 1, newMultiplier
    end
    
    return false, "Data save error"
end

-- Функция применения автосбора
local function applyAutoCollect(player)
    local data = getPlayerData(player)
    if not data then return 0 end
    
    local effectiveData = getEffectiveComputedData(player)
    if not effectiveData then return 0 end
    
    if not effectiveData.AutoCollect then
        return 0
    end
    
    local currentTime = os.time()
    local lastCollectTime = data.LastCollectTime or currentTime
    local timePassed = math.max(0, currentTime - lastCollectTime)
    
    if timePassed < 1 then
        return 0
    end
    
    local goldPerMinute = effectiveData.GoldPerMinute or 10
    local goldPerSecond = goldPerMinute / 60
    local autoCollected = timePassed * goldPerSecond
    
    if autoCollected <= 0 then
        return 0
    end
    
    DataManager.UpdateData(player, function(playerData)
        playerData.Gold = (playerData.Gold or 0) + math.floor(autoCollected)
        playerData.LastCollectTime = currentTime
        
        if playerData.Stats then
            playerData.Stats.TotalGoldEarned = (playerData.Stats.TotalGoldEarned or 0) + math.floor(autoCollected)
        end
        
        return playerData
    end)
    
    return math.floor(autoCollected)
end

-- Функция получения данных для Gold GUI
local function getGoldGUIData(player)
    local data = getPlayerData(player)
    local effectiveData = getEffectiveComputedData(player)
    
    if not data or not effectiveData then
        return nil
    end
    
    return {
        gold = data.Gold or 0,
        accumulatedGold = calculateAccumulatedGold(player),
        storageCapacity = effectiveData.StorageCapacity or 1000,
        incomeRate = effectiveData.GoldPerMinute or 10,
        doubleChance = effectiveData.DoubleChance or 0.01,
        lastCollectTime = data.LastCollectTime or os.time(),
        autoCollectEnabled = effectiveData.AutoCollect or false
    }
end

local function sendGoldGUIUpdates()
    for userId, _ in pairs(goldGUISubscribers) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player:IsA("Player") then
            local guiData = getGoldGUIData(player)
            if guiData then
                EventSystem.FireClient(player, "GoldGUIUpdate", guiData)
            end
        end
    end
end

-- Обработчик сбора предмета для квеста
EventSystem.OnServer("CollectQuestItem", function(player, data)
    if not data or not data.itemType or not data.itemId then
        EventSystem.FireClient(player, "CollectItemError", "Invalid item data")
        return
    end
    
    local playerData = getPlayerData(player)
    if not playerData or not playerData.DailyQuests then 
        EventSystem.FireClient(player, "CollectItemError", "Player data load error")
        return
    end
    
    local targetQuest = nil
    for _, quest in ipairs(playerData.DailyQuests) do
        if quest.type == "collect_items" and quest.itemType == data.itemType and not quest.completed then
            targetQuest = quest
            break
        end
    end
    
    if not targetQuest then
        EventSystem.FireClient(player, "CollectItemError", "No active quest for this item type")
        return
    end
    
    if not targetQuest.collectedItemIds then
        targetQuest.collectedItemIds = {}
    end
    
    if targetQuest.collectedItemIds[data.itemId] then
        EventSystem.FireClient(player, "CollectItemError", "This item has already been collected")
        return
    end
    
    targetQuest.current = math.min(targetQuest.current + 1, targetQuest.target)
    targetQuest.collectedItemIds[data.itemId] = true
    
    local questCompleted = false
    if targetQuest.current >= targetQuest.target then
        targetQuest.completed = true
        questCompleted = true
        
        if playerData.Stats then
            playerData.Stats.TotalQuestsCompleted = (playerData.Stats.TotalQuestsCompleted or 0) + 1
        end
    end
    
    DataManager.UpdateData(player, function() return playerData end)
    
    EventSystem.FireClient(player, "ItemCollected", {
        itemId = data.itemId, 
        questId = targetQuest.id
    })
    
    EventSystem.FireClient(player, "QuestProgress", "collect_items", 1)
    
    if questCompleted then
        EventSystem.FireClient(player, "QuestCompleted", {
            questId = targetQuest.id,
            questType = "collect_items"
        })
    end
    
    sendQuestsDataUpdate(player)
    sendQuestsGUIUpdates()
end)

-- RPC: Получение данных квестов
EventSystem.RegisterRPC("GetQuestsData", function(player)
    applyAutoCollect(player)
    return getQuestsData(player) or {}
end)

-- RPC: Получение данных улучшений
EventSystem.RegisterRPC("GetUpgradesData", function(player)
    applyAutoCollect(player)
    return getUpgradesData(player) or {}
end)

-- RPC: Получение данных уровня
EventSystem.RegisterRPC("GetLevelData", function(player)
    applyAutoCollect(player)
    return getLevelData(player) or {}
end)

-- RPC: Получение данных о наградах за уровень
EventSystem.RegisterRPC("GetLevelRewardsData", function(player)
    local data = getPlayerData(player)
    if not data then return {} end
    
    return {
        currentLevel = data.Level or 1,
        claimedRewards = data.ClaimedLevelRewards or {},
        levelRewardsConfig = GameSystems.LevelSystem.LevelRewards
    }
end)

-- RPC: Получение награды за уровень
EventSystem.RegisterRPC("ClaimLevelReward", function(player, level)
    local data = getPlayerData(player)
    if not data then 
        return false, "Data load error"
    end
    
    local currentLevel = data.Level or 1
    if currentLevel < tonumber(level) then
        return false, "Insufficient level"
    end
    
    -- Проверяем, не получена ли уже награда
    if not data.ClaimedLevelRewards then
        data.ClaimedLevelRewards = {}
    end
    
    if data.ClaimedLevelRewards[tonumber(level)] then
        return false, "Reward already claimed"
    end
    
    -- Получаем конфигурацию награды
    local rewardConfig = GameSystems.LevelSystem.LevelRewards[tonumber(level)]
    if not rewardConfig then
        return false, "Reward not found"
    end
    
    -- Выдаем награду
    local handler = LevelRewardHandlers[rewardConfig.type]
    if handler then
        handler(player, rewardConfig, level)
    else
        return false, "Unknown reward type"
    end
    
    -- Отмечаем награду как полученную
    data.ClaimedLevelRewards[tonumber(level)] = true
    DataManager.UpdateData(player, function() return data end)
    
    return true, "Reward successfully claimed"
end)

-- RPC: Получение данных игрока
EventSystem.RegisterServerOnlyRPC("GetPlayerGold", function(player)
    applyAutoCollect(player)
    local data = getPlayerData(player)
    return data and data.Gold or 0
end)

-- RPC: Обновление золота игрока
EventSystem.RegisterServerOnlyRPC("UpdatePlayerGold", function(player, amount, reason)
    if type(amount) ~= "number" then
        return false, "Invalid amount type"
    end
    
    applyAutoCollect(player)
    
    local success, error = DataManager.UpdateData(player, function(data)
        local currentGold = data.Gold or 0
        local newGold = currentGold + amount
        
        if newGold < 0 then
            newGold = 0
        end
        
        data.Gold = newGold
        
        if amount > 0 and data.Stats then
            data.Stats.TotalGoldEarned = (data.Stats.TotalGoldEarned or 0) + amount
        end
        
        return data
    end)
    
    if not success then
        return false, "Ошибка обновления данных: " .. tostring(error)
    end
    
    local data = getPlayerData(player)
    if data then
        EventSystem.FireClient(player, "UpdateGold", data.Gold)
        return true, data.Gold
    end
    
    return false, "Failed to get updated data"
end)

-- RPC: Получение статистики игрока
EventSystem.RegisterRPC("GetPlayerStats", function(player)
    applyAutoCollect(player)
    
    local data = getPlayerData(player)
    local effectiveData = getEffectiveComputedData(player)
    
    if not data or not effectiveData then
        return {}
    end
    
    return {
        basic = {
            level = data.Level or 1,
            experience = data.Experience or 0,
            nextLevelExp = calculateExpForLevel(data.Level or 1),
            skillPoints = data.SkillPoints or 0,
            prestigeLevel = data.PrestigeLevel or 0
        },
        computed = {
            GoldPerMinute = effectiveData.GoldPerMinute or 10,
            DoubleChance = effectiveData.DoubleChance or 0.01,
            StorageCapacity = effectiveData.StorageCapacity or 1000,
            GoldMultiplier = effectiveData.GoldMultiplier or 1.0,
            DioramaGoldMultiplier = effectiveData.DioramaGoldMultiplier or 1.0,
            DonationBonusMultiplier = effectiveData.DonationBonusMultiplier or 1.0,
            StatsMultiplier = effectiveData.StatsMultiplier or 1.0,
            QuestBonusMultiplier = effectiveData.QuestBonusMultiplier or 1.0
        },
        gold = data.Gold or 0
    }
end)

-- RPC: Получение DonationBonusMultiplier игрока
EventSystem.RegisterRPC("GetDonationBonusMultiplier", function(player)
    local effectiveData = getEffectiveComputedData(player)
    if not effectiveData then
        return 1.0
    end
    return effectiveData.DonationBonusMultiplier or 1.0
end)

-- RPC: Перерождение
EventSystem.RegisterRPC("Prestige", function(player)
    return prestige(player)
end)

-- RPC: Получение системных конфигураций
EventSystem.RegisterRPC("GetGameSystems", function(player)
    return GameSystems
end)

-- RPC: Проверка наличия предмета кастомизации у игрока
EventSystem.RegisterServerOnlyRPC("CheckCustomizationItem", function(player, category, itemId)
    local data = getPlayerData(player)
    if not data then return false end
    if not data.Customization then return false end
    if not data.Customization[category] then return false end
    return data.Customization[category][itemId] == true
end)

-- RPC: Получение всех предметов кастомизации игрока
EventSystem.RegisterServerOnlyRPC("GetCustomizationItems", function(player)
    local data = getPlayerData(player)
    if not data or not data.Customization then return DEFAULT_CUSTOMIZATION end
    return data.Customization
end)

-- RPC: Получение максимального количества диорам для игрока
EventSystem.RegisterServerOnlyRPC("GetMaxDioramas", function(player)
    local computedData = getMultiplierData(player)
    if not computedData then
        return
    end
    return computedData.MaxDioramas or 6
end)

-- RPC: Получение количества билетов для запрета покупки
EventSystem.RegisterServerOnlyRPC("GetPurchaseBanTickets", function(player)
    local data = getPlayerData(player)
    if not data then return 0 end
    return data.PurchaseBanTickets or 0
end)

-- RPC: Использование билета для запрета покупки диорамы
EventSystem.RegisterServerOnlyRPC("UsePurchaseBanTicket", function(player, dioramaId)
    local data = getPlayerData(player)
    if not data then
        return false, "Data load error"
    end
    
    local tickets = data.PurchaseBanTickets or 0
    if tickets < 1 then
        return false, "Not enough tickets"
    end
    
    -- Списываем билет
    local success = DataManager.UpdateData(player, function(playerData)
        playerData.PurchaseBanTickets = (playerData.PurchaseBanTickets or 0) - 1
        return playerData
    end)
    
    if not success then
        return false, "Data update error"
    end
    
    return true, "Ticket used"
end)

-- RPC: Добавление билетов
EventSystem.RegisterServerOnlyRPC("AddPurchaseBanTickets", function(player, amount)
    if type(amount) ~= "number" or amount <= 0 then
        return false, "Invalid amount"
    end
    
    local success = DataManager.UpdateData(player, function(playerData)
        playerData.PurchaseBanTickets = (playerData.PurchaseBanTickets or 0) + amount
        return playerData
    end)
    
    if success then
        return true, tostring(amount) .. " tickets added"
    end
    
    return false, "Data update error"
end)

EventSystem.OnServer("CollectGold", function(player)
    local collected, multiplier = collectAccumulatedGold(player)
end)

EventSystem.OnServer("UpgradeSkillRequest", function(player, skillType)
    local success, message, newLevel = upgradeSkill(player, skillType)
    EventSystem.FireClient(player, "UpgradeSkillResponse", success, message, skillType, newLevel)
end)

-- Подписки на GUI обновления
EventSystem.OnServer("SubscribeToGoldGUI", function(player)
    goldGUISubscribers[player.UserId] = true
    print(string.format("[PlayerDataManager] Игрок %s подписался на обновления Gold GUI", player.Name))
    
    local guiData = getGoldGUIData(player)
    if guiData then
        EventSystem.FireClient(player, "GoldGUIInitialData", guiData)
    end
end)

EventSystem.OnServer("UnsubscribeFromGoldGUI", function(player)
    goldGUISubscribers[player.UserId] = nil
    print(string.format("[PlayerDataManager] Игрок %s отписался от обновлений Gold GUI", player.Name))
end)

EventSystem.OnServer("SubscribeToUpgradesGUI", function(player)
    upgradesGUISubscribers[player.UserId] = true
    print(string.format("[PlayerDataManager] Игрок %s подписался на обновления Upgrades GUI", player.Name))
    
    local guiData = getUpgradesData(player)
    if guiData then
        EventSystem.FireClient(player, "UpgradesGUIInitialData", guiData)
    end
end)

EventSystem.OnServer("UnsubscribeFromUpgradesGUI", function(player)
    upgradesGUISubscribers[player.UserId] = nil
    print(string.format("[PlayerDataManager] Игрок %s отписался от обновлений Upgrades GUI", player.Name))
end)

EventSystem.OnServer("SubscribeToLevelGUI", function(player)
    levelGUISubscribers[player.UserId] = true
    print(string.format("[PlayerDataManager] Игрок %s подписался на обновления Level GUI", player.Name))
    
    local guiData = getLevelData(player)
    if guiData then
        EventSystem.FireClient(player, "LevelGUIInitialData", guiData)
    end
end)

EventSystem.OnServer("UnsubscribeFromLevelGUI", function(player)
    levelGUISubscribers[player.UserId] = nil
    print(string.format("[PlayerDataManager] Игрок %s отписался от обновлений Level GUI", player.Name))
end)

EventSystem.OnServer("SubscribeToQuestsGUI", function(player)
    questsGUISubscribers[player.UserId] = true
    print(string.format("[PlayerDataManager] Игрок %s подписался на обновления Quests GUI", player.Name))
    
    local guiData = getQuestsData(player)
    if guiData then
        EventSystem.FireClient(player, "QuestsGUIInitialData", guiData)
        activateQuestItemsForPlayer(player, guiData.quests)
    end
end)

EventSystem.OnServer("UnsubscribeFromQuestsGUI", function(player)
    questsGUISubscribers[player.UserId] = nil
    print(string.format("[PlayerDataManager] Игрок %s отписался от обновлений Quests GUI", player.Name))
end)

EventSystem.OnServer("RefreshQuests", function(player)
    -- Проверка наличия геймпаса "quests" для обновления квестов
    if not playerHasQuestsPass(player) then
        EventSystem.FireClient(player, "GamepassOfferByName", "quests", "A pass is required to update quests. Would you like to purchase?")
        return
    end
    
    updateDailyQuests(player, true)
    local data = getPlayerData(player)
    if data and data.DailyQuests then
        activateQuestItemsForPlayer(player, data.DailyQuests)
    end
    sendQuestsGUIUpdates()
    EventSystem.FireClient(player, "RefreshQuestsResponse", true, "Quests updated")
end)

-- Пропуск квеста
EventSystem.OnServer("SkipQuest", function(player, questId)
    local data = getPlayerData(player)
    if not data or not data.DailyQuests then 
        EventSystem.FireClient(player, "SkipQuestResponse", false, "No data")
        return
    end
    
    local canSkip = playerHasQuestsPass(player)
    
    if not canSkip then
        EventSystem.FireClient(player, "GamepassOfferByName", "quests", "A pass is required to skip quests. Would you like to purchase?")
        return
    end
    
    local questRemoved = false
    for i, quest in ipairs(data.DailyQuests) do
        if quest.id == questId then
            table.remove(data.DailyQuests, i)
            questRemoved = true
            break
        end
    end
    
    if not questRemoved then
        EventSystem.FireClient(player, "SkipQuestResponse", false, "Quest not found")
        return
    end
    
    -- Всегда генерируем новый квест взамен пропущенного
    local newQuest = generateSingleQuest(player)
    table.insert(data.DailyQuests, newQuest)
    
    DataManager.UpdateData(player, function() return data end)
    sendQuestsDataUpdate(player)
    sendQuestsGUIUpdates()
    activateQuestItemsForPlayer(player, data.DailyQuests)
    
    EventSystem.FireClient(player, "SkipQuestResponse", true, "Quest successfully skipped")
end)

-- Получение награды за квест (исправлено с учетом QuestBonus)
EventSystem.OnServer("ClaimQuest", function(player, questId)
    applyAutoCollect(player)
    
    local data = getPlayerData(player)
    if not data or not data.DailyQuests then
        return false, "No data or quests"
    end
    
    local effectiveData = getEffectiveComputedData(player)
    if not effectiveData then
        return false, "Failed to get efficiency data"
    end
    
    for i, quest in ipairs(data.DailyQuests) do
        if quest.id == questId and quest.completed and not quest.claimed then
            local goldAdded = quest.reward.gold or 0
            local expAdded = quest.reward.exp or 0
            
            -- Применяем множитель от улучшения QuestBonus (только к золоту)
            local questBonusMultiplier = effectiveData.QuestBonusMultiplier or 1.0
            goldAdded = math.floor(goldAdded * questBonusMultiplier)
            
            DataManager.UpdateData(player, function(playerData)
                playerData.Gold = (playerData.Gold or 0) + goldAdded
                if playerData.Stats then
                    playerData.Stats.TotalGoldEarned = (playerData.Stats.TotalGoldEarned or 0) + goldAdded
                end
                return playerData
            end)
            
            if expAdded > 0 then
                addExperience(player, expAdded)
            end
            
            DataManager.UpdateData(player, function(playerData)
                table.remove(playerData.DailyQuests, i)
                return playerData
            end)
            
            data = getPlayerData(player)
            data.DailyQuests = replaceQuestIfNeeded(player, data.DailyQuests)
            DataManager.UpdateData(player, function() return data end)
            
            sendQuestsDataUpdate(player)
            sendQuestsGUIUpdates()
            sendLevelGUIUpdates()
            sendUpgradesGUIUpdates()
            activateQuestItemsForPlayer(player, data.DailyQuests)
            
            EventSystem.FireClient(player, "ClaimQuestResponse", questId, true, "Reward received", {gold = goldAdded, exp = expAdded})
            return
        end
    end
    EventSystem.FireClient(player, "ClaimQuestResponse", questId, false, "Quest not found or not completed")
end)

-- Периодическое обновление подписчиков
local function startPeriodicUpdates()
    while true do
        task.wait(updateInterval)
        sendGoldGUIUpdates()
        sendUpgradesGUIUpdates()
        sendLevelGUIUpdates()
        sendQuestsGUIUpdates()
    end
end

-- Обработка подключения игроков
Players.PlayerAdded:Connect(function(player)
    print(string.format("[PlayerDataManager] Игрок подключился: %s (%d)", player.Name, player.UserId))
    
    task.spawn(function()
        local success = waitForDataLoaded(player)
        if success then
            local isFirstLogin = false
            
            DataManager.UpdateData(player, function(data)
                -- Проверяем, первый ли это вход игрока
                if not data.FirstLoginTime then
                    isFirstLogin = true
                    data.FirstLoginTime = os.time()
                end
                
                data.LastLogin = os.time()
                if not data.Customization then
                    data.Customization = DEFAULT_CUSTOMIZATION
                else
                    for category, items in pairs(DEFAULT_CUSTOMIZATION) do
                        if not data.Customization[category] then
                            data.Customization[category] = {}
                        end
                        for item, _ in pairs(items) do
                            if data.Customization[category][item] == nil then
                                data.Customization[category][item] = true
                            end
                        end
                    end
                end
                if not data.ClaimedLevelRewards then
                    data.ClaimedLevelRewards = {}
                end
                return data
            end)
            
            -- Выдаем достижение FirstSteps при первом входе
            if isFirstLogin and PremiumContentSystem then
                local awarded, awardMessage = PremiumContentSystem.AwardAchievement(player, "FirstSteps")
                if awarded then
                    print(string.format("[PlayerDataManager] Игрок %s получил достижение 'FirstSteps'", player.Name))
                else
                    warn(string.format("[PlayerDataManager] Не удалось наградить достижением 'FirstSteps': %s", tostring(awardMessage)))
                end
            end
            
            -- Обновляем модификаторы перерождения при загрузке игрока
            updatePrestigeModifiers(player)
            
            updateDailyQuests(player)
            applyAutoCollect(player)
            
            local data = getPlayerData(player)
            if data and data.DailyQuests then
                activateQuestItemsForPlayer(player, data.DailyQuests)
            end
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    print(string.format("[PlayerDataManager] Игрок отключился: %s (%d)", player.Name, player.UserId))
    
    goldGUISubscribers[player.UserId] = nil
    upgradesGUISubscribers[player.UserId] = nil
    levelGUISubscribers[player.UserId] = nil
    questsGUISubscribers[player.UserId] = nil
    
    local data = getPlayerData(player)
    if data then
        local playTime = os.time() - (data.LastLogin or os.time())
        DataManager.UpdateData(player, function(playerData)
            if playerData.Stats then
                playerData.Stats.PlayTime = (playerData.Stats.PlayTime or 0) + playTime
            end
            return playerData
        end)
    end
end)

-- Загрузка данных уже подключенных игроков
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        local data = getPlayerData(player)
        if data then
            if not data.Customization then
                DataManager.UpdateData(player, function(d)
                    d.Customization = DEFAULT_CUSTOMIZATION
                    return d
                end)
            end
            
            -- Обновляем модификаторы перерождения для уже подключенных игроков
            updatePrestigeModifiers(player)
            
            updateDailyQuests(player)
            if data and data.DailyQuests then
                activateQuestItemsForPlayer(player, data.DailyQuests)
            end
        end
    end)
end

-- Запуск периодических обновлений
task.spawn(startPeriodicUpdates)

-- RPC: Проверка, пройдено ли обучение
EventSystem.RegisterRPC("GetTutorialCompleted", function(player)
    local data = getPlayerData(player)
    if not data then return false end
    return data.TutorialCompleted or false
end)

-- RPC: Отметить обучение как пройденное
EventSystem.RegisterRPC("SetTutorialCompleted", function(player)
    local success, error = DataManager.UpdateData(player, function(pData)
        pData.TutorialCompleted = true
        return pData
    end)
    if not success then
        warn(string.format("[PlayerDataManager] Ошибка сохранения TutorialCompleted для %s: %s", player.Name, tostring(error)))
        return false
    end
    print(string.format("[PlayerDataManager] Игрок %s завершил обучение", player.Name))
    
    -- Награждаем достижением "Обучение пройдено"
    if PremiumContentSystem then
        local awarded, awardMessage = PremiumContentSystem.AwardAchievement(player, "TutorialComplete")
        if awarded then
            print(string.format("[PlayerDataManager] Игрок %s получил достижение 'Обучение пройдено'", player.Name))
        else
            warn(string.format("[PlayerDataManager] Не удалось наградить достижением 'Обучение пройдено': %s", tostring(awardMessage)))
        end
    end
    
    return true
end)

EventSystem.OnServer("SaveSettings", function(player, settings)
    if type(settings) ~= "table" then return end

    local success = DataManager.UpdateData(player, function(data)
        if not data.Settings then
            data.Settings = {}
        end

        -- Валидация и сохранение только разрешённых полей
        if type(settings.musicEnabled) == "boolean" then
            data.Settings.musicEnabled = settings.musicEnabled
        end
        if type(settings.sfxEnabled) == "boolean" then
            data.Settings.sfxEnabled = settings.sfxEnabled
        end
        if type(settings.musicVolume) == "number" then
            data.Settings.musicVolume = math.clamp(settings.musicVolume, 0, 1)
        end
        if type(settings.sfxVolume) == "number" then
            data.Settings.sfxVolume = math.clamp(settings.sfxVolume, 0, 1)
        end

        return data
    end)

    if not success then
        warn(string.format("[PlayerDataManager] Ошибка сохранения настроек для %s", player.Name))
    end
end)

EventSystem.RegisterRPC("GetSavedSettings", function(player)
    if not waitForDataLoaded(player) then
        return nil
    end

    local data = getPlayerData(player)
    if not data or not data.Settings then
        return nil
    end

    return {
        musicEnabled = data.Settings.musicEnabled,
        sfxEnabled = data.Settings.sfxEnabled,
        musicVolume = data.Settings.musicVolume,
        sfxVolume = data.Settings.sfxVolume,
    }
end)

print("[PlayerDataManager] Инициализация завершена")