-- Объединённый клиентский скрипт для управления GameHubGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadingScreen = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingScreen"))
LoadingScreen.WaitForLoad()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local GameHubGui = PlayerGui:WaitForChild("GameHubGui")
GameHubGui.Enabled = false

-- Загрузка EventSystem
local EventSystem = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
EventSystem.Init()

local MainContainer = GameHubGui:WaitForChild("MainContainer")
local Header = MainContainer:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")

local TabsPanel = Header:WaitForChild("TabsPanel")
local LevelTab = TabsPanel:WaitForChild("levelTab")
local UpgradesTab = TabsPanel:WaitForChild("upgradesTab")
local QuestsTab = TabsPanel:WaitForChild("questsTab")

local ContentContainer = MainContainer:WaitForChild("ContentContainer")
local LevelPane = ContentContainer:WaitForChild("LevelPane")
local UpgradesPane = ContentContainer:WaitForChild("UpgradesPane")
local QuestsPane = ContentContainer:WaitForChild("QuestsPane")

-- === ЭЛЕМЕНТЫ ВКЛАДКИ УРОВЕНЬ ===
local LevelCard = LevelPane:WaitForChild("LevelCard")
local LevelBadge = LevelCard:WaitForChild("LevelBadge")
local LevelNumber = LevelBadge:WaitForChild("LevelNumber")
local PrestigeContainer = LevelCard:WaitForChild("PrestigeContainer")
local PrestigeValue = PrestigeContainer:WaitForChild("PrestigeValue")
local ExpBarContainer = LevelCard:WaitForChild("ExpBarContainer")
local ExpBarFill = ExpBarContainer:WaitForChild("ExpBarFill")
local ExpText = LevelCard:WaitForChild("ExpText")
local SkillsContainer = LevelCard:WaitForChild("SkillsContainer")
local SkillsValue = SkillsContainer:WaitForChild("SkillsValue")
local PrestigeButton = LevelCard:WaitForChild("PrestigeButton")
local PrestigeRequirementText = LevelCard:WaitForChild("PrestigeRequirementText")
local LevelGift = LevelCard:WaitForChild("LevelGift")
local lvlTemplate = LevelGift:FindFirstChild("lvlTemplate")

-- === ЭЛЕМЕНТЫ СТАТИСТИКИ АПГРЕЙДОВ ===
local StatsCard = LevelPane:WaitForChild("StatsCard")
local BonusesList = StatsCard:WaitForChild("BonusesList")

-- Скрываем шаблон награды
if lvlTemplate then
    lvlTemplate.Visible = false
end

-- === ЭЛЕМЕНТЫ ВКЛАДКИ УЛУЧШЕНИЯ ===
local UpgradesCard = UpgradesPane:WaitForChild("UpgradesCard")
local UpgradesList = UpgradesCard:WaitForChild("UpgradesList")

-- === ЭЛЕМЕНТЫ ВКЛАДКИ КВЕСТЫ ===
local QuestsCard = QuestsPane:WaitForChild("QuestsCard")
local RefreshInfo = QuestsCard:WaitForChild("RefreshInfo")
local RefreshText = RefreshInfo:WaitForChild("RefreshText")
local RefreshButton = RefreshInfo:WaitForChild("RefreshButton")
local QuestsList = QuestsCard:WaitForChild("QuestsList")

-- === ШАБЛОНЫ ===
local UpgradeTemplate = UpgradesList:FindFirstChild("UpgradeItemTemplate")
local QuestTemplate = QuestsList:FindFirstChild("QuestItemTemplate")

-- Скрываем шаблоны, если они видимы
if UpgradeTemplate then
    UpgradeTemplate.Visible = false
end
if QuestTemplate then
    QuestTemplate.Visible = false
end

-- === ПЕРЕМЕННЫЕ СОСТОЯНИЯ ===
local currentTab = "level"
local isSubscribed = false
local lastUpdateTime = 0

-- Данные для каждой вкладки
local levelData = {}
local upgradesData = {}
local questsData = {}
local itemTypesConfig = {}
local levelRewardsData = {}

-- Хранилище активных предметов для квестов
local activeQuestItems = {}

-- Переменная для хранения очков навыков
local playerSkillPoints = 0

-- === ФУНКЦИИ ПОКАЗА УВЕДОМЛЕНИЙ ===
local function showNotification(message, color)
    local notification = Instance.new("TextLabel")
    notification.Name = "Notification"
    notification.Text = message
    notification.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notification.BackgroundTransparency = 0.5
    notification.Size = UDim2.new(0.8, 0, 0.1, 0)
    notification.Position = UDim2.new(0.1, 0, 0.45, 0)
    notification.AnchorPoint = Vector2.new(0.5, 0.5)
    notification.Font = Enum.Font.GothamBold
    notification.TextSize = 14
    notification.ZIndex = 100
    notification.Parent = GameHubGui
    
    notification.BackgroundTransparency = 1
    notification.TextTransparency = 1
    
    local fadeIn = TweenService:Create(
        notification,
        TweenInfo.new(0.3),
        {BackgroundTransparency = 0.5, TextTransparency = 0}
    )
    
    local fadeOut = TweenService:Create(
        notification,
        TweenInfo.new(0.3),
        {BackgroundTransparency = 1, TextTransparency = 1}
    )
    
    fadeIn:Play()
    task.wait(2)
    fadeOut:Play()
    task.wait(0.3)
    notification:Destroy()
end

-- === ФУНКЦИИ ПЕРЕКЛЮЧЕНИЯ ВКЛАДОК ===
local function switchTab(tabName)
    currentTab = tabName
    
    -- Обновляем цвета кнопок
    LevelTab.TextColor3 = Color3.fromRGB(126, 136, 168)
    UpgradesTab.TextColor3 = Color3.fromRGB(126, 136, 168)
    QuestsTab.TextColor3 = Color3.fromRGB(126, 136, 168)
    
    -- Активируем выбранную вкладку
    if tabName == "level" then
        LevelTab.TextColor3 = Color3.fromRGB(255, 205, 0)
        LevelPane.Visible = true
        UpgradesPane.Visible = false
        QuestsPane.Visible = false
    elseif tabName == "upgrades" then
        UpgradesTab.TextColor3 = Color3.fromRGB(255, 205, 0)
        LevelPane.Visible = false
        UpgradesPane.Visible = true
        QuestsPane.Visible = false
    elseif tabName == "quests" then
        QuestsTab.TextColor3 = Color3.fromRGB(255, 205, 0)
        LevelPane.Visible = false
        UpgradesPane.Visible = false
        QuestsPane.Visible = true
    end
end

-- === ФУНКЦИИ ВКЛАДКИ УРОВЕНЬ ===
local function updateLevelRewardsList()
    if not lvlTemplate then
        warn("[GameHub] Шаблон lvlTemplate не найден!")
        return
    end
    
    -- Удаляем все ранее созданные элементы (кроме шаблона и layout)
    for _, child in ipairs(LevelGift:GetChildren()) do
        if child.Name == "RewardItem" then
            child:Destroy()
        end
    end
    
    -- Убеждаемся, что UIListLayout существует
    local listLayout = LevelGift:FindFirstChild("RewardListLayout")
    if not listLayout then
        listLayout = Instance.new("UIListLayout")
        listLayout.Name = "RewardListLayout"
        listLayout.FillDirection = Enum.FillDirection.Horizontal
        listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        listLayout.Padding = UDim.new(0.02, 0)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = LevelGift
    end
    
    -- Убеждаемся, что UIPadding существует
    local padding = LevelGift:FindFirstChild("RewardPadding")
    if not padding then
        padding = Instance.new("UIPadding")
        padding.Name = "RewardPadding"
        padding.PaddingLeft = UDim.new(0.02, 0)
        padding.PaddingRight = UDim.new(0.02, 0)
        padding.PaddingTop = UDim.new(0.05, 0)
        padding.PaddingBottom = UDim.new(0.05, 0)
        padding.Parent = LevelGift
    end
    
    if not levelRewardsData.levelRewardsConfig then return end
    
    local currentLevel = levelRewardsData.currentLevel or 1
    local claimedRewards = levelRewardsData.claimedRewards or {}
    
    -- Сортируем уровни наград
    local sortedLevels = {}
    for level, _ in pairs(levelRewardsData.levelRewardsConfig) do
        table.insert(sortedLevels, level)
    end
    table.sort(sortedLevels)
    
    -- Считаем количество item-наград для расчёта размера
    local itemRewardsCount = 0
    for _, level in ipairs(sortedLevels) do
        local rewardConfig = levelRewardsData.levelRewardsConfig[level]
        if rewardConfig and rewardConfig.type == "item" then
            itemRewardsCount = itemRewardsCount + 1
        end
    end
    
    -- Рассчитываем размер элемента на основе количества наград
    local elementWidth = 0.15 -- Базовый размер элемента
    if itemRewardsCount > 0 then
        -- Автоматически подбираем размер, чтобы все элементы помещались
        local totalPadding = 0.02 * (itemRewardsCount - 1) + 0.04 -- Отступы слева и справа
        elementWidth = math.min(0.18, (1.0 - totalPadding) / itemRewardsCount)
    end
    
    for _, level in ipairs(sortedLevels) do
        local rewardConfig = levelRewardsData.levelRewardsConfig[level]
        if rewardConfig and rewardConfig.type == "item" then
            -- Клонируем шаблон
            local rewardItem = lvlTemplate:Clone()
            rewardItem.Name = "RewardItem"
            rewardItem.Visible = true
            rewardItem.LayoutOrder = level -- Используем уровень для сортировки
            rewardItem.Parent = LevelGift
            
            -- Настраиваем размер для равномерного распределения
            rewardItem.Size = UDim2.new(elementWidth, 0, 0.85, 0)
            rewardItem.AnchorPoint = Vector2.new(0.5, 0.5)
            rewardItem.Position = UDim2.new(0.5, 0, 0.5, 0)
            
            -- Добавляем UIAspectRatioConstraint если его нет
            local aspectConstraint = rewardItem:FindFirstChild("UIAspectRatioConstraint")
            if not aspectConstraint then
                aspectConstraint = Instance.new("UIAspectRatioConstraint")
                aspectConstraint.Name = "AspectConstraint"
                aspectConstraint.AspectRatio = 1 -- Квадратные элементы
                aspectConstraint.Parent = rewardItem
            end
            
            -- Заполняем данные
            local rewardName = rewardItem:FindFirstChild("Name")
            if rewardName then
                rewardName.Text = rewardConfig.displayName or rewardConfig.itemId
                rewardName.Size = UDim2.new(0.95, 0, 0.15, 0)
                rewardName.Position = UDim2.new(0.5, 0, 0.75, 0)
                rewardName.AnchorPoint = Vector2.new(0.5, 0.5)
                rewardName.TextSize = 10
                rewardName.TextWrapped = true
                rewardName.TextTruncate = Enum.TextTruncate.AtEnd
            end
            
            local rewardLevel = rewardItem:FindFirstChild("lvl")
            if rewardLevel then
                rewardLevel.Text = string.format("Ур. %d", level)
                rewardLevel.Size = UDim2.new(0.95, 0, 0.12, 0)
                rewardLevel.Position = UDim2.new(0.5, 0, 0.9, 0)
                rewardLevel.AnchorPoint = Vector2.new(0.5, 0.5)
                rewardLevel.TextSize = 9
            end
            
            -- Добавляем изображение, если его нет в шаблоне
            local rewardImage = rewardItem:FindFirstChild("RewardImage")
            if not rewardImage then
                rewardImage = Instance.new("ImageLabel")
                rewardImage.Name = "RewardImage"
                rewardImage.Size = UDim2.new(0.7, 0, 0.5, 0)
                rewardImage.Position = UDim2.new(0.5, 0, 0.35, 0)
                rewardImage.AnchorPoint = Vector2.new(0.5, 0.5)
                rewardImage.BackgroundTransparency = 1
                rewardImage.Parent = rewardItem
            end
            
            -- Настраиваем изображение
            if rewardConfig.imageId then
                rewardImage.Image = rewardConfig.imageId
            end
            rewardImage.Size = UDim2.new(0.7, 0, 0.5, 0)
            rewardImage.Position = UDim2.new(0.5, 0, 0.35, 0)
            
            if rewardImage and rewardConfig.imageId then
                rewardImage.Image = rewardConfig.imageId
            end
            
            -- Настраиваем обводку в зависимости от статуса
            local itemStroke = rewardItem:FindFirstChild("UIStroke")
            if itemStroke then
                if claimedRewards[level] then
                    -- Награда уже получена - серая обводка
                    itemStroke.Color = Color3.fromRGB(100, 100, 100)
                    itemStroke.Thickness = 2
                    rewardItem.BackgroundTransparency = 0.8
                elseif tonumber(currentLevel) >= tonumber(level) then
                    -- Уровень достигнут, можно получить - зеленая обводка
                    itemStroke.Color = Color3.fromRGB(62, 255, 158)
                    itemStroke.Thickness = 3
                    rewardItem.BackgroundTransparency = 0.5
                else
                    -- Уровень не достигнут - обычная обводка
                    itemStroke.Color = Color3.fromRGB(27, 42, 53)
                    itemStroke.Thickness = 1
                    rewardItem.BackgroundTransparency = 0.7
                end
            end
            
            -- Добавляем кнопку для получения награды
            local claimButton = rewardItem:FindFirstChild("ClaimButton")
            if not claimButton then
                claimButton = Instance.new("TextButton")
                claimButton.Name = "ClaimButton"
                claimButton.Size = UDim2.new(1, 0, 1, 0)
                claimButton.Position = UDim2.new(0, 0, 0, 0)
                claimButton.BackgroundTransparency = 1
                claimButton.Text = ""
                claimButton.Parent = rewardItem
            end
            
            -- Настраиваем интерактивность
            if not claimedRewards[level] and tonumber(currentLevel) >= tonumber(level) then
                claimButton.Active = true
                
                claimButton.MouseButton1Click:Connect(function()
                    -- Вызываем RPC для получения награды
                    local success, message = EventSystem.CallRPC("ClaimLevelReward", level)
                    if success then
                        showNotification(string.format("🎁 Награда за уровень %d получена!", level), Color3.fromRGB(0, 255, 0))
                    else
                        showNotification(message or "Ошибка получения награды", Color3.fromRGB(255, 0, 0))
                    end
                end)
            else
                claimButton.Active = false
            end
            
            -- Добавляем индикатор статуса
            local statusLabel = rewardItem:FindFirstChild("StatusLabel")
            if not statusLabel then
                statusLabel = Instance.new("TextLabel")
                statusLabel.Name = "StatusLabel"
                statusLabel.Size = UDim2.new(0.3, 0, 0.15, 0)
                statusLabel.Position = UDim2.new(0.85, 0, 0.1, 0)
                statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                statusLabel.BackgroundTransparency = 1
                statusLabel.Text = ""
                statusLabel.Font = Enum.Font.GothamBold
                statusLabel.TextSize = 14
                statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                statusLabel.Parent = rewardItem
            end
            
            -- Позиционируем статус-индикатор
            statusLabel.Size = UDim2.new(0.3, 0, 0.15, 0)
            statusLabel.Position = UDim2.new(0.85, 0, 0.1, 0)
            
            if claimedRewards[level] then
                statusLabel.Text = "✅"
            elseif tonumber(currentLevel) >= tonumber(level) then
                statusLabel.Text = "🎁"
            else
                statusLabel.Text = "🔒"
            end
        end
    end
end

local function updateLevelGUI()
    LevelNumber.Text = tostring(levelData.level or 1)
    
    local expPercentage = math.min(((levelData.experience or 0) / (levelData.nextLevelExp or 100)) * 100, 100)
    ExpBarFill.Size = UDim2.new(expPercentage / 100, 0, 1, 0)
    ExpText.Text = string.format("%d / %d XP", levelData.experience or 0, levelData.nextLevelExp or 100)
    
    -- Обновляем очки улучшения
    SkillsValue.Text = tostring(levelData.skillPoints or 0)
    
    -- Обновляем престиж
    PrestigeValue.Text = tostring(levelData.prestigeLevel or 0)
    
    -- Проверяем доступность перерождения
    local minLevel = levelData.prestigeConfig and levelData.prestigeConfig.MinLevel or 90
    local canPrestige = (levelData.level or 1) >= minLevel
    
    if canPrestige then
        PrestigeButton.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
        PrestigeButton.Active = true
        PrestigeRequirementText.Text = "Перерождение доступно!"
    else
        PrestigeButton.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
        PrestigeButton.Active = false
        PrestigeRequirementText.Text = string.format("🔓 Доступно с %d уровня", minLevel)
    end
end

-- === ФУНКЦИЯ ОБНОВЛЕНИЯ СТАТИСТИКИ АПГРЕЙДОВ ===
local function updateStatsDisplay()
    if not BonusesList then return end
    
    -- Обновляем значения апгрейдов с учётом множителя характеристик от престижа
    local upgradeTypes = {"GoldPerMinute", "StorageCapacity", "DoubleChance", "QuestBonus"}
    
    -- Рассчитываем множитель характеристик от престижа
    local statsMultiplier = 1
    if levelData then
        local prestigeLevel = levelData.prestigeLevel or 0
        local statsMultiplierGrowth = levelData.prestigeConfig and levelData.prestigeConfig.StatsMultiplierGrowth or 0.02
        if prestigeLevel > 0 then
            statsMultiplier = 1 + prestigeLevel * statsMultiplierGrowth
        end
    end
    
    for _, upgradeType in ipairs(upgradeTypes) do
        local item = BonusesList:FindFirstChild(upgradeType)
        if item then
            local valueLabel = item:FindFirstChild("ValueLabel")
            if valueLabel and upgradesData and upgradesData.upgradeConfig then
                local config = upgradesData.upgradeConfig[upgradeType]
                local currentLevel = upgradesData.upgrades and upgradesData.upgrades[upgradeType] or 0
                
                if config and config.effect and type(config.effect.base) == "number" then
                    local baseValue = config.effect.base * (config.effect.multiplier ^ currentLevel)
                    local currentValue = baseValue * statsMultiplier
                    
                    if upgradeType == "GoldPerMinute" then
                        valueLabel.Text = string.format("%.1f/мин", currentValue)
                    elseif upgradeType == "StorageCapacity" then
                        valueLabel.Text = string.format("%d", math.floor(currentValue))
                    elseif upgradeType == "DoubleChance" then
                        valueLabel.Text = string.format("%.1f%%", currentValue * 100)
                    elseif upgradeType == "QuestBonus" then
                        valueLabel.Text = string.format("+%.0f%%", currentValue * 100)
                    end
                end
            end
        end
    end
    
    -- Обновляем множитель золота с диорам от перерождения
    local dioramaGoldItem = BonusesList:FindFirstChild("dioramaGoldBonus")
    if dioramaGoldItem then
        local valueLabel = dioramaGoldItem:FindFirstChild("ValueLabel")
        if valueLabel and levelData then
            local prestigeLevel = levelData.prestigeLevel or 0
            local dioramaGoldGrowth = levelData.prestigeConfig and levelData.prestigeConfig.DioramaGoldGrowth or 0.03
            
            if prestigeLevel > 0 then
                valueLabel.Text = string.format("+%.1f%%", prestigeLevel * dioramaGoldGrowth * 100)
            else
                valueLabel.Text = "+0%"
            end
        end
    end
    
    -- Обновляем множитель бонусов с доната от перерождения
    local donationBonusItem = BonusesList:FindFirstChild("donationBonus")
    if donationBonusItem then
        local valueLabel = donationBonusItem:FindFirstChild("ValueLabel")
        if valueLabel and levelData then
            local prestigeLevel = levelData.prestigeLevel or 0
            local donationBonusGrowth = levelData.prestigeConfig and levelData.prestigeConfig.DonationBonusGrowth or 0.02
            
            if prestigeLevel > 0 then
                valueLabel.Text = string.format("+%.1f%%", prestigeLevel * donationBonusGrowth * 100)
            else
                valueLabel.Text = "+0%"
            end
        end
    end
    
    -- Обновляем множитель характеристик от перерождения
    local statsBonusItem = BonusesList:FindFirstChild("statsBonus")
    if statsBonusItem then
        local valueLabel = statsBonusItem:FindFirstChild("ValueLabel")
        if valueLabel and levelData then
            local prestigeLevel = levelData.prestigeLevel or 0
            local statsMultiplierGrowth = levelData.prestigeConfig and levelData.prestigeConfig.StatsMultiplierGrowth or 0.02
            
            if prestigeLevel > 0 then
                valueLabel.Text = string.format("+%.1f%%", prestigeLevel * statsMultiplierGrowth * 100)
            else
                valueLabel.Text = "+0%"
            end
        end
    end
end

-- === ФУНКЦИИ ВКЛАДКИ УЛУЧШЕНИЯ ===
local function calculateUpgradeCost(base, multiplier, currentLevel)
    return math.floor(base * (multiplier ^ currentLevel))
end

local function calculateUpgradeEffect(base, multiplier, currentLevel, statsMultiplier)
    statsMultiplier = statsMultiplier or 1
    if type(base) == "number" then
        return base * (multiplier ^ currentLevel) * statsMultiplier
    end
    return base
end

local function updateUpgradesList()
    if not UpgradeTemplate then
        warn("[GameHub] Шаблон UpgradeItemTemplate не найден!")
        return
    end
    
    -- Удаляем все ранее созданные элементы (кроме шаблона)
    for _, child in ipairs(UpgradesList:GetChildren()) do
        if child.Name == "UpgradeItem" then
            child:Destroy()
        end
    end
    
    if not upgradesData.upgradeConfig then return end

    local playerGold = upgradesData.gold or 0
    local playerSP = playerSkillPoints

    -- Рассчитываем множитель характеристик от престижа
    local statsMultiplier = 1
    if levelData then
        local prestigeLevel = levelData.prestigeLevel or 0
        local statsMultiplierGrowth = levelData.prestigeConfig and levelData.prestigeConfig.StatsMultiplierGrowth or 0.02
        if prestigeLevel > 0 then
            statsMultiplier = 1 + prestigeLevel * statsMultiplierGrowth
        end
    end

    for skillType, config in pairs(upgradesData.upgradeConfig) do
        local currentLevel = upgradesData.upgrades[skillType] or 0
        if skillType == "AutoCollect" then
            currentLevel = upgradesData.upgrades.AutoCollect and 1 or 0
        end
        
        if currentLevel < config.maxLevel then
            -- Клонируем шаблон
            local upgradeItem = UpgradeTemplate:Clone()
            upgradeItem.Name = "UpgradeItem"
            upgradeItem.Visible = true
            upgradeItem.Parent = UpgradesList
            
            -- Заполняем данные
            local upgradeName = upgradeItem:FindFirstChild("UpgradeName")
            if upgradeName then
                upgradeName.Text = config.name
            end
            
            local upgradeLevel = upgradeItem:FindFirstChild("UpgradeLevel")
            if upgradeLevel then
                upgradeLevel.Text = string.format("Уровень %d/%d", currentLevel, config.maxLevel)
            end
            
            local upgradeDescription = upgradeItem:FindFirstChild("UpgradeDescription")
            if upgradeDescription then
                upgradeDescription.Text = config.description or ""
            end
            
            local upgradeEffect = upgradeItem:FindFirstChild("UpgradeEffect")
            if upgradeEffect then
                if config.effect == "unlock" then
                    upgradeEffect.Text = "Эффект: Автоматический сбор каждую минуту"
                else
                    local currentEffect = calculateUpgradeEffect(config.effect.base, config.effect.multiplier, currentLevel, statsMultiplier)
                    local nextEffect = calculateUpgradeEffect(config.effect.base, config.effect.multiplier, currentLevel + 1, statsMultiplier)
                    upgradeEffect.Text = string.format("Эффект: %.2f → %.2f", currentEffect, nextEffect)
                end
            end
            
            -- Стоимость в золоте
            local goldCost = calculateUpgradeCost(config.cost.base, config.cost.multiplier, currentLevel)
            local upgradeCostGold = upgradeItem:FindFirstChild("UpgradeCostGold")
            if upgradeCostGold then
                upgradeCostGold.Text = string.format("💰 %d", goldCost)
            end
            
            -- Стоимость в очках навыков
            local skillPointCost = config.skillPointCost or 1
            local upgradeCostSP = upgradeItem:FindFirstChild("UpgradeCostSP")
            if upgradeCostSP then
                upgradeCostSP.Text = string.format("💪 %d", skillPointCost)
            end
            
            local upgradeButton = upgradeItem:FindFirstChild("UpgradeButton")
            if upgradeButton then
                -- Проверяем и золото, и очки навыков
                if playerGold >= goldCost and playerSP >= skillPointCost then
                    upgradeButton.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
                    upgradeButton.Active = true
                    upgradeButton.Text = "Улучшить"
                else
                    upgradeButton.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
                    upgradeButton.Active = false
                    upgradeButton.Text = "Не хватает"
                end
                
                -- Подключаем обработчик клика
                upgradeButton.MouseButton1Click:Connect(function()
                    if upgradeButton.Active then
                        EventSystem.FireServer("UpgradeSkillRequest", skillType)
                        upgradeButton.Active = false
                        upgradeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    end
                end)
            end
        end
    end
end

local function updateUpgradesGUI()
    if not upgradesData then return end
    playerSkillPoints = upgradesData.skillPoints or 0
    updateUpgradesList()
end

-- === ФУНКЦИИ ВКЛАДКИ КВЕСТЫ ===
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%02d:%02d", hours, minutes)
end

local function updateRefreshTime(refreshTime)
    local currentTime = os.time()
    local timeLeft = math.max(0, refreshTime - currentTime)
    if RefreshText then
        if timeLeft > 0 then
            RefreshText.Text = string.format("Обновление через: %s", formatTime(timeLeft))
            RefreshButton.Active = false
        end
    end
end

local function deactivateQuestItems(questId)
    for itemId, data in pairs(activeQuestItems) do
        if data.questId == questId then
            if data.clickDetector then
                data.clickDetector:Destroy()
            end
            if data.touchDetector then
                data.touchDetector:Destroy()
            end
            if data.proximityPrompt then
                data.proximityPrompt:Destroy()
            end
            activeQuestItems[itemId] = nil
        end
    end
end

local function deactivateItem(itemId)
    local data = activeQuestItems[itemId]
    if data then
        if data.clickDetector then
            data.clickDetector:Destroy()
        end
        if data.touchDetector then
            data.touchDetector:Destroy()
        end
        if data.proximityPrompt then
            data.proximityPrompt:Destroy()
        end
        activeQuestItems[itemId] = nil
    end
end

local function setupClickHandler(model, itemId, questId, itemType)
    local clickDetector = model:FindFirstChildOfClass("ClickDetector")
    if not clickDetector then
        clickDetector = Instance.new("ClickDetector")
        clickDetector.Parent = model
    end
    
    clickDetector.MouseClick:Connect(function(playerClick)
        if playerClick ~= Player then return end
        EventSystem.FireServer("CollectQuestItem", {
            itemType = itemType,
            itemId = itemId,
            questId = questId
        })
    end)
    
    return clickDetector
end

local function setupHoldPrompt(model, itemId, questId, itemType, holdTime)
    local prompt = Instance.new("ProximityPrompt")
    prompt.HoldDuration = holdTime or 2
    prompt.MaxActivationDistance = 10
    prompt.ActionText = "Собрать"
    prompt.ObjectText = itemType
    prompt.RequiresLineOfSight = false
    prompt.Parent = model

    local triggered = false
    prompt.Triggered:Connect(function(player)
        if player ~= Player or triggered then return end
        triggered = true
        EventSystem.FireServer("CollectQuestItem", {
            itemType = itemType,
            itemId = itemId,
            questId = questId
        })
    end)

    return prompt
end

local function setupTouchHandler(model, itemId, questId, itemType)
    if model:IsA("BasePart") then
        model.Touched:Connect(function(hit)
            if hit.Parent == Player.Character then
                if not model:GetAttribute("CollectedBy_" .. Player.UserId) then
                    model:SetAttribute("CollectedBy_" .. Player.UserId, true)
                    EventSystem.FireServer("CollectQuestItem", {
                        itemType = itemType,
                        itemId = itemId,
                        questId = questId
                    })
                end
            end
        end)
    else
        local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            primaryPart.Touched:Connect(function(hit)
                if hit.Parent == Player.Character then
                    if not primaryPart:GetAttribute("CollectedBy_" .. Player.UserId) then
                        primaryPart:SetAttribute("CollectedBy_" .. Player.UserId, true)
                        EventSystem.FireServer("CollectQuestItem", {
                            itemType = itemType,
                            itemId = itemId,
                            questId = questId
                        })
                    end
                end
            end)
        end
    end
    return nil
end

local function activateItemsForType(itemType, questId, mechanic, holdTime, collectedIds)
    collectedIds = collectedIds or {}
    for _, model in ipairs(game.Workspace:GetDescendants()) do
        if model:IsA("BasePart") or model:IsA("Model") then
            local attrItemType = model:GetAttribute("QuestItemType")
            local attrItemId = model:GetAttribute("QuestItemId")
            if attrItemType == itemType and attrItemId and not activeQuestItems[attrItemId] then
                if collectedIds[attrItemId] then
                    continue
                end
                
                local clickDetector, touchDetector, proximityPrompt
                
                if mechanic == "click" then
                    clickDetector = setupClickHandler(model, attrItemId, questId, itemType)
                elseif mechanic == "hold" then
                    proximityPrompt = setupHoldPrompt(model, attrItemId, questId, itemType, holdTime)
                elseif mechanic == "touch" then
                    touchDetector = setupTouchHandler(model, attrItemId, questId, itemType)
                end
                
                activeQuestItems[attrItemId] = {
                    model = model,
                    clickDetector = clickDetector,
                    touchDetector = touchDetector,
                    proximityPrompt = proximityPrompt,
                    itemType = itemType,
                    questId = questId,
                    mechanic = mechanic
                }
            end
        end
    end
end

local function updateQuestsList()
    if not QuestTemplate then
        warn("[GameHub] Шаблон QuestItemTemplate не найден!")
        return
    end
    
    -- Удаляем все ранее созданные элементы (кроме шаблона)
    for _, child in ipairs(QuestsList:GetChildren()) do
        if child.Name == "QuestItem" then
            child:Destroy()
        end
    end
    
    for _, quest in ipairs(questsData.quests or {}) do
        -- Клонируем шаблон
        local questItem = QuestTemplate:Clone()
        questItem.Name = "QuestItem"
        questItem.Visible = true
        questItem.Parent = QuestsList
        
        -- Заполняем данные
        local questName = questItem:FindFirstChild("QuestName")
        if questName then
            questName.Text = quest.name
        end
        
        local questRarity = questItem:FindFirstChild("QuestRarity")
        if questRarity then
            questRarity.Text = string.format("[%s]", quest.rarity)
            -- Устанавливаем цвет редкости
            local rarityColors = {
                ["Обычный"] = Color3.fromRGB(200, 200, 200),
                ["Необычный"] = Color3.fromRGB(100, 150, 255),
                ["Редкий"] = Color3.fromRGB(200, 100, 255),
                ["Эпический"] = Color3.fromRGB(255, 100, 100),
                ["Легендарный"] = Color3.fromRGB(255, 215, 0)
            }
            questRarity.TextColor3 = rarityColors[quest.rarity] or Color3.fromRGB(255, 255, 255)
        end
        
        local questProgress = questItem:FindFirstChild("QuestProgress")
        if questProgress then
            questProgress.Text = string.format("%d/%d", quest.current, quest.target)
        end
        
        -- Прогресс-бар
        local progressFill = questItem:FindFirstChild("ProgressFill", true)
        if progressFill then
            local progressPercentage = math.min((quest.current / quest.target) * 100, 100)
            progressFill.Size = UDim2.new(progressPercentage / 100, 0, 1, 0)
        end
        
        local questReward = questItem:FindFirstChild("QuestReward")
        if questReward then
            questReward.Text = string.format("💰 %d золота  ⭐ %d опыта", quest.reward.gold, quest.reward.exp)
        end
        
        local questItemInfo = questItem:FindFirstChild("QuestItemInfo")
        if questItemInfo then
            if quest.description and quest.description ~= "" then
                questItemInfo.Text = quest.description
                questItemInfo.Visible = true
            else
                questItemInfo.Visible = false
            end
        end
        
        -- Обводка для выполненных квестов
        local itemStroke = questItem:FindFirstChildOfClass("UIStroke")
        if itemStroke then
            if quest.completed then
                itemStroke.Color = Color3.fromRGB(255, 205, 0)
            end
        end
        
        -- Кнопка получения награды
        local claimButton = questItem:FindFirstChild("ClaimButton")
        if claimButton then
            if quest.completed and not quest.claimed then   
                claimButton.Visible = true
                claimButton.Active = true
                claimButton.Text = "🎁 Получить"
                claimButton.BackgroundColor3 = Color3.fromRGB(45, 122, 61)
                
                claimButton.MouseButton1Click:Connect(function()
                    EventSystem.FireServer("ClaimQuest", quest.id)
                end)
            elseif quest.claimed then
                claimButton.Visible = true
                claimButton.Text = "✅ Получено"
                claimButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                claimButton.Active = false
            else
                claimButton.Visible = false
            end
        end
        
        -- Кнопка пропуска
        local skipButton = questItem:FindFirstChild("SkipButton")
        if skipButton then
            if not quest.completed and not quest.claimed then
                skipButton.Visible = true
                skipButton.Active = true
                
                skipButton.MouseButton1Click:Connect(function()
                    EventSystem.FireServer("SkipQuest", quest.id)
                end)
            else
                skipButton.Visible = false
            end
        end
    end
end

local function updateQuestsGUI()
    if not questsData then return end
    updateQuestsList()
    updateRefreshTime(questsData.questRefreshTime or 0)
    
    for _, quest in ipairs(questsData.quests or {}) do
        if quest.type == "collect_items" and not quest.completed then
            activateItemsForType(quest.itemType, quest.id, quest.mechanic, quest.holdTime, quest.collectedItemIds or {})
        elseif quest.completed then
            deactivateQuestItems(quest.id)
        end
    end
end

-- === ПОДПИСКА И ОТПИСКА ===
local function subscribeToGameHub()
    if not isSubscribed then
        EventSystem.FireServer("SubscribeToLevelGUI")
        EventSystem.FireServer("SubscribeToUpgradesGUI")
        EventSystem.FireServer("SubscribeToQuestsGUI")
        isSubscribed = true
        print("[GameHub] Подписались на обновления")
    end
end

local function unsubscribeFromGameHub()
    if isSubscribed then
        EventSystem.FireServer("UnsubscribeFromLevelGUI")
        EventSystem.FireServer("UnsubscribeFromUpgradesGUI")
        EventSystem.FireServer("UnsubscribeFromQuestsGUI")
        isSubscribed = false
        GameHubGui.Enabled = false
        print("[GameHub] Отписались от обновлений")
    end
end

-- === ОБРАБОТЧИКИ СОБЫТИЙ ОТ СЕРВЕРА ===
-- Level GUI события
EventSystem.OnClient("LevelGUIInitialData", function(guiData)
    print("[GameHub] Получены начальные данные уровня")
    GameHubGui.Enabled = true
    isSubscribed = true
    levelData = guiData
    updateLevelGUI()
    updateStatsDisplay()
end)

EventSystem.OnClient("LevelGUIUpdate", function(guiData)
    lastUpdateTime = os.time()
    levelData = guiData
    updateLevelGUI()
    updateStatsDisplay()
    -- Обновляем награды при изменении уровня
    if levelRewardsData and levelRewardsData.levelRewardsConfig then
        levelRewardsData.currentLevel = guiData.level
        updateLevelRewardsList()
    end
end)

EventSystem.OnClient("LevelUp", function(newLevel, skillPoints, levelsGained)
    showNotification(string.format("🎉 Новый уровень: %d! +%.0f очков навыков", newLevel, skillPoints), Color3.fromRGB(0, 255, 0))
    -- Обновляем награды при повышении уровня
    if levelRewardsData then
        levelRewardsData.currentLevel = newLevel
        updateLevelRewardsList()
    end
end)

EventSystem.OnClient("PrestigeComplete", function(prestigeLevel, multiplier, goldEarned, dioramaGoldBonus, donationBonus, statsBonus)
    showNotification(string.format("✨ Перерождение %d! Множитель: +%.1f%% | 🏛️ Диорамы: +%.1f%% | 💎 Донат: +%.1f%% | ⚔️ Характеристики: +%.1f%%", prestigeLevel, multiplier * 100, (dioramaGoldBonus or 0) * 100, (donationBonus or 0) * 100, (statsBonus or 0) * 100), Color3.fromRGB(255, 0, 255))
end)

EventSystem.OnClient("LevelDataUpdated", function(data)
    levelData = data
    updateLevelGUI()
end)

EventSystem.OnClient("LevelRewardReceived", function(reward)
    if reward.type == "gold" then
        showNotification(string.format("🎁 Награда за %d уровень: %d золота!", reward.level, reward.amount), Color3.fromRGB(255, 215, 0))
    elseif reward.type == "item" then
        showNotification(string.format("🎁 Награда за %d уровень: особый предмет!", reward.level), Color3.fromRGB(200, 100, 255))
    end
    -- Обновляем статус награды как полученной
    if levelRewardsData then
        if not levelRewardsData.claimedRewards then
            levelRewardsData.claimedRewards = {}
        end
        levelRewardsData.claimedRewards[reward.level] = true
    end
    -- Обновляем список наград после получения
    if levelRewardsData and levelRewardsData.levelRewardsConfig then
        updateLevelRewardsList()
    end
end)

-- Upgrades GUI события
EventSystem.OnClient("UpgradesGUIInitialData", function(guiData)
    print("[GameHub] Получены начальные данные улучшений")
    upgradesData = guiData
    updateUpgradesGUI()
    updateStatsDisplay()
end)

EventSystem.OnClient("UpgradesGUIUpdate", function(guiData)
    lastUpdateTime = os.time()
    upgradesData = guiData
    updateUpgradesGUI()
    updateStatsDisplay()
end)

EventSystem.OnClient("SkillUpgraded", function(skillType, newLevel, effect)
    showNotification(string.format("⬆️ Улучшение %s до уровня %d", skillType, newLevel), Color3.fromRGB(0, 150, 255))
end)

EventSystem.OnClient("GoldCollected", function(amount, bonuses)
    if upgradesData then
        updateUpgradesList()
    end
end)

EventSystem.OnClient("UpgradesDataUpdated", function(data)
    upgradesData = data
    updateUpgradesGUI()
end)

EventSystem.OnClient("UpgradeSkillResponse", function(success, message, skillType, newLevel)
    if success then
        showNotification("✅ Улучшение применено!", Color3.fromRGB(0, 255, 0))
    else
        showNotification(message, Color3.fromRGB(255, 0, 0))
    end
    if upgradesData then
        updateUpgradesList()
    end
end)

-- Quests GUI события
EventSystem.OnClient("QuestsGUIInitialData", function(guiData)
    print("[GameHub] Получены начальные данные квестов")
    questsData = guiData
    if guiData.itemTypesConfig then
        itemTypesConfig = guiData.itemTypesConfig
    end
    updateQuestsGUI()
end)

EventSystem.OnClient("QuestsGUIUpdate", function(guiData)
    lastUpdateTime = os.time()
    questsData = guiData
    if guiData.itemTypesConfig then
        itemTypesConfig = guiData.itemTypesConfig
    end
    updateQuestsGUI()
end)

EventSystem.OnClient("QuestProgress", function(questType, amount)
    showNotification(string.format("📊 Прогресс квеста: %s +%d", questType, amount), Color3.fromRGB(100, 255, 100))
end)

EventSystem.OnClient("CollectItemError", function(errorMessage)
    showNotification("❌ Ошибка: " .. errorMessage, Color3.fromRGB(255, 0, 0))
end)

EventSystem.OnClient("QuestsRefreshed", function()
    showNotification("🔄 Квесты обновлены!", Color3.fromRGB(0, 200, 255))
end)

EventSystem.OnClient("ActivateQuestItems", function(data)
    activateItemsForType(data.itemType, data.questId, data.mechanic, data.holdTime, data.collectedIds)
end)

EventSystem.OnClient("ItemCollected", function(data)
    showNotification("✅ Предмет собран!", Color3.fromRGB(0, 255, 0))
    deactivateItem(data.itemId)
end)

EventSystem.OnClient("QuestsDataUpdated", function(data)
    questsData = data
    if data.itemTypesConfig then
        itemTypesConfig = data.itemTypesConfig
    end
    updateQuestsGUI()
end)

EventSystem.OnClient("RefreshQuestsResponse", function(success, info)
    if success then
        showNotification("✅ Квесты обновлены!", Color3.fromRGB(0, 255, 0))
    else
        showNotification(info or "Ошибка", Color3.fromRGB(255, 0, 0))
    end
end)

EventSystem.OnClient("ClaimQuestResponse", function(questId, success, info, reward)
    if success then
        showNotification(string.format("🎁 Награда получена: %d золота, %d опыта", reward.gold, reward.exp), Color3.fromRGB(0, 255, 0))
        deactivateQuestItems(questId)
    else
        showNotification(info or "Ошибка", Color3.fromRGB(255, 0, 0))
    end
end)

EventSystem.OnClient("SkipQuestResponse", function(success, info)
    if success then
        showNotification("⏭ Квест пропущен!", Color3.fromRGB(255, 200, 0))
    else
        showNotification(info or "Ошибка", Color3.fromRGB(255, 0, 0))
    end
end)

-- === RPC ДЛЯ НАГРАД ЗА УРОВЕНЬ ===
-- Загрузка данных о наградах при подписке
task.spawn(function()
    local rewardsData = EventSystem.CallRPC("GetLevelRewardsData")
    if rewardsData then
        levelRewardsData = rewardsData
        updateLevelRewardsList()
    end
end)

-- === ОБРАБОТЧИКИ КНОПОК ===
CloseButton.MouseButton1Click:Connect(function()
    unsubscribeFromGameHub()
end)

LevelTab.MouseButton1Click:Connect(function()
    switchTab("level")
end)

UpgradesTab.MouseButton1Click:Connect(function()
    switchTab("upgrades")
end)

QuestsTab.MouseButton1Click:Connect(function()
    switchTab("quests")
end)

PrestigeButton.MouseButton1Click:Connect(function()
    if PrestigeButton.Active then
        local result = EventSystem.CallRPC("Prestige")
        if result and result[1] == true then
            showNotification("✅ Перерождение успешно!", Color3.fromRGB(0, 255, 0))
        else
            showNotification(result and result[2] or "Ошибка", Color3.fromRGB(255, 0, 0))
        end
    end
end)

RefreshButton.MouseButton1Click:Connect(function()
    EventSystem.FireServer("RefreshQuests")
end)

-- Ссылка на кнопку управления в TopBar
local TopBarLeftButtons = PlayerGui:WaitForChild("TopBar"):WaitForChild("LeftButtons")
local ManageTopBarButton = TopBarLeftButtons:WaitForChild("ManageButton")

-- Кнопка управления в TopBar
ManageTopBarButton.MouseButton1Click:Connect(function()
    if GameHubGui.Enabled then
        unsubscribeFromGameHub()
    else
        subscribeToGameHub()
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Q then
        if GameHubGui.Enabled then
            unsubscribeFromGameHub()
        else
            subscribeToGameHub()
        end
    end
end)

-- === ОТПИСКА ПРИ ВЫХОДЕ ===
Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        unsubscribeFromGameHub()
    end
end)

print("[GameHub] Клиентский скрипт загружен")