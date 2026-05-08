-- Клиентский скрипт (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

-- Ожидаем создание структуры RemoteEvents на сервере
local PremiumEvents = ReplicatedStorage:WaitForChild("PremiumEvents")
local PurchaseEvent = PremiumEvents:WaitForChild("PurchaseItem")
local AchievementEvent = PremiumEvents:WaitForChild("AchievementEvent")
local GetAchievementsFunction = PremiumEvents:WaitForChild("GetAchievements")
local DailyRewardsFunction = PremiumEvents:WaitForChild("DailyRewards")

-- Основной GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PremiumShopUI"
screenGui.Parent = PlayerGui

-- Создаем основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 650, 0, 550)
mainFrame.Position = UDim2.new(0.5, -325, 0.5, -275)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

-- Заголовок
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "ПРЕМИУМ КОНТЕНТ И ДОСТИЖЕНИЯ"
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 24
title.Parent = mainFrame

-- Кнопки навигации
local tabButtonsFrame = Instance.new("Frame")
tabButtonsFrame.Name = "TabButtons"
tabButtonsFrame.Size = UDim2.new(1, 0, 0, 40)
tabButtonsFrame.Position = UDim2.new(0, 0, 0, 50)
tabButtonsFrame.BackgroundTransparency = 1
tabButtonsFrame.Parent = mainFrame

local function createTabButton(name, text, position)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = UDim2.new(0.25, 0, 1, 0)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.Parent = tabButtonsFrame
    
    return button
end

local gamePassTab = createTabButton("GamePassTab", "GAME PASS", UDim2.new(0, 0, 0, 0))
local productsTab = createTabButton("ProductsTab", "ПРОДУКТЫ", UDim2.new(0.25, 0, 0, 0))
local achievementsTab = createTabButton("AchievementsTab", "ДОСТИЖЕНИЯ", UDim2.new(0.5, 0, 0, 0))
local dailyRewardsTab = createTabButton("DailyRewardsTab", "ЕЖЕДНЕВНЫЕ НАГРАДЫ", UDim2.new(0.75, 0, 0, 0))

-- Контейнеры для контента
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -90)
contentFrame.Position = UDim2.new(0, 0, 0, 90)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Контейнер для GamePass
local gamePassContainer = Instance.new("ScrollingFrame")
gamePassContainer.Name = "GamePassContainer"
gamePassContainer.Size = UDim2.new(1, 0, 1, 0)
gamePassContainer.Position = UDim2.new(0, 0, 0, 0)
gamePassContainer.BackgroundTransparency = 1
gamePassContainer.ScrollBarThickness = 6
gamePassContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
gamePassContainer.Visible = true
gamePassContainer.Parent = contentFrame

-- Контейнер для продуктов
local productsContainer = Instance.new("ScrollingFrame")
productsContainer.Name = "ProductsContainer"
productsContainer.Size = UDim2.new(1, 0, 1, 0)
productsContainer.Position = UDim2.new(0, 0, 0, 0)
productsContainer.BackgroundTransparency = 1
productsContainer.ScrollBarThickness = 6
productsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
productsContainer.Visible = false
productsContainer.Parent = contentFrame

-- Контейнер для достижений
local achievementsContainer = Instance.new("ScrollingFrame")
achievementsContainer.Name = "AchievementsContainer"
achievementsContainer.Size = UDim2.new(1, 0, 1, 0)
achievementsContainer.Position = UDim2.new(0, 0, 0, 0)
achievementsContainer.BackgroundTransparency = 1
achievementsContainer.ScrollBarThickness = 6
achievementsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
achievementsContainer.Visible = false
achievementsContainer.Parent = contentFrame

-- Контейнер для ежедневных наград
local dailyRewardsContainer = Instance.new("ScrollingFrame")
dailyRewardsContainer.Name = "DailyRewardsContainer"
dailyRewardsContainer.Size = UDim2.new(1, 0, 1, 0)
dailyRewardsContainer.Position = UDim2.new(0, 0, 0, 0)
dailyRewardsContainer.BackgroundTransparency = 1
dailyRewardsContainer.ScrollBarThickness = 6
dailyRewardsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
dailyRewardsContainer.Visible = false
dailyRewardsContainer.Parent = contentFrame

-- Кнопка закрытия
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Text = "✕"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(215, 0, 0)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 20
closeButton.Parent = mainFrame

-- Тестовые данные (в реальном проекте эти данные должны приходить с сервера)
local testGamePasses = {
    {
        Name = "Test",
        DisplayName = "VIP Статус",
        Price = 52,
        Description = "Получите VIP статус с эксклюзивными бонусами!",
        Bonus = {
            Currency = 500,
            XP_Multiplier = 1.5,
            CustomTag = "[VIP]"
        }
    },
    {
        Name = "Premium_Status",
        DisplayName = "Премиум Статус",
        Price = 75,
        Description = "Максимальные бонусы и привилегии!",
        Bonus = {
            Currency = 750,
            XP_Multiplier = 1.8,
            CustomTag = "[PREMIUM]"
        }
    }
}

local testProducts = {
    {
        Name = "Money",
        DisplayName = "Набор монет (1000)",
        Price = 100,
        Description = "Получите 1000 монет для покупок в игре!",
        Bonus = {
            Currency = 1000
        }
    },
    {
        Name = "Money_Pack_Large",
        DisplayName = "Большой набор монет (5000)",
        Price = 450,
        Description = "Огромный набор из 5000 монет!",
        Bonus = {
            Currency = 5000
        }
    }
}

-- Функция для создания карточки товара
local function createShopItem(parent, itemData, itemType)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = itemData.Name
    itemFrame.Size = UDim2.new(1, -20, 0, 120)
    itemFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    itemFrame.BorderSizePixel = 0
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Text = itemData.DisplayName or itemData.Name
    nameLabel.Size = UDim2.new(0.6, 0, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = itemFrame
    
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "Price"
    priceLabel.Text = "Цена: " .. (itemData.Price or 0) .. " Robux"
    priceLabel.Size = UDim2.new(0.4, 0, 0, 30)
    priceLabel.Position = UDim2.new(0.6, 0, 0, 10)
    priceLabel.BackgroundTransparency = 1
    priceLabel.TextColor3 = Color3.new(1, 1, 1)
    priceLabel.Font = Enum.Font.SourceSans
    priceLabel.TextSize = 16
    priceLabel.TextXAlignment = Enum.TextXAlignment.Right
    priceLabel.Parent = itemFrame
    
    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "Description"
    descriptionLabel.Text = itemData.Description or "Описание товара..."
    descriptionLabel.Size = UDim2.new(1, -20, 0, 40)
    descriptionLabel.Position = UDim2.new(0, 10, 0, 40)
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    descriptionLabel.Font = Enum.Font.SourceSans
    descriptionLabel.TextSize = 14
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
    descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    descriptionLabel.Parent = itemFrame
    
    -- Отображение бонусов
    local bonusesText = ""
    if itemData.Bonus then
        if itemData.Bonus.Currency then
            bonusesText = bonusesText .. "💰 " .. itemData.Bonus.Currency .. " монет\n"
        end
        if itemData.Bonus.XP_Multiplier then
            bonusesText = bonusesText .. "⚡ Множитель опыта: " .. itemData.Bonus.XP_Multiplier .. "x\n"
        end
        if itemData.Bonus.CustomTag then
            bonusesText = bonusesText .. "🏷️ " .. itemData.Bonus.CustomTag .. "\n"
        end
        if itemData.Bonus.PermanentUnlock then
            bonusesText = bonusesText .. "🔓 " .. itemData.Bonus.PermanentUnlock .. "\n"
        end
    end
    
    if bonusesText == "" then
        bonusesText = "Бонусы не указаны"
    end
    
    local bonusesLabel = Instance.new("TextLabel")
    bonusesLabel.Name = "Bonuses"
    bonusesLabel.Text = "Бонусы:\n" .. bonusesText
    bonusesLabel.Size = UDim2.new(0.7, 0, 0, 50)
    bonusesLabel.Position = UDim2.new(0, 10, 0, 80)
    bonusesLabel.BackgroundTransparency = 1
    bonusesLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    bonusesLabel.Font = Enum.Font.SourceSans
    bonusesLabel.TextSize = 12
    bonusesLabel.TextXAlignment = Enum.TextXAlignment.Left
    bonusesLabel.TextYAlignment = Enum.TextYAlignment.Top
    bonusesLabel.Parent = itemFrame
    
    local buyButton = Instance.new("TextButton")
    buyButton.Name = "BuyButton"
    buyButton.Text = "КУПИТЬ"
    buyButton.Size = UDim2.new(0, 100, 0, 30)
    buyButton.Position = UDim2.new(1, -110, 1, -40)
    buyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    buyButton.TextColor3 = Color3.new(1, 1, 1)
    buyButton.Font = Enum.Font.SourceSansBold
    buyButton.TextSize = 14
    buyButton.Parent = itemFrame
    
    buyButton.Activated:Connect(function()
        PurchaseEvent:FireServer(itemType, itemData.Name)
        print("Запрос на покупку:", itemType, itemData.Name)
    end)
    
    local uiListLayout = parent:FindFirstChildOfClass("UIListLayout")
    if not uiListLayout then
        uiListLayout = Instance.new("UIListLayout")
        uiListLayout.Padding = UDim.new(0, 10)
        uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        uiListLayout.Parent = parent
    end
    
    local uipadding = parent:FindFirstChildOfClass("UIPadding")
    if not uipadding then
        uipadding = Instance.new("UIPadding")
        uipadding.PaddingTop = UDim.new(0, 10)
        uipadding.PaddingLeft = UDim.new(0, 10)
        uipadding.PaddingRight = UDim.new(0, 10)
        uipadding.Parent = parent
    end
    
    itemFrame.Parent = parent
    return itemFrame
end

-- Функция для создания карточки достижения
local function createAchievementCard(parent, achievementData, isEarned)
    local cardFrame = Instance.new("Frame")
    cardFrame.Name = achievementData.Name
    cardFrame.Size = UDim2.new(1, -20, 0, 120)
    cardFrame.BackgroundColor3 = isEarned and Color3.fromRGB(40, 100, 40) or Color3.fromRGB(50, 50, 50)
    cardFrame.BorderSizePixel = 0
    
    local statusIndicator = Instance.new("Frame")
    statusIndicator.Name = "Status"
    statusIndicator.Size = UDim2.new(0, 10, 1, 0)
    statusIndicator.Position = UDim2.new(0, 0, 0, 0)
    statusIndicator.BackgroundColor3 = isEarned and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 0)
    statusIndicator.Parent = cardFrame
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Text = achievementData.DisplayName or achievementData.Name
    nameLabel.Size = UDim2.new(0.8, 0, 0, 30)
    nameLabel.Position = UDim2.new(0, 20, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = cardFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusText"
    statusLabel.Text = isEarned and "ПОЛУЧЕНО" or "НЕ ПОЛУЧЕНО"
    statusLabel.Size = UDim2.new(0.2, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.8, 0, 0, 10)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = isEarned and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 0)
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.TextSize = 14
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = cardFrame
    
    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "Description"
    descriptionLabel.Text = achievementData.Description or "Описание достижения"
    descriptionLabel.Size = UDim2.new(1, -20, 0, 40)
    descriptionLabel.Position = UDim2.new(0, 20, 0, 40)
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    descriptionLabel.Font = Enum.Font.SourceSans
    descriptionLabel.TextSize = 14
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
    descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    descriptionLabel.Parent = cardFrame
    
    local rewardsText = ""
    if achievementData.Rewards then
        if achievementData.Rewards.Currency then
            rewardsText = rewardsText .. "💰 " .. achievementData.Rewards.Currency .. " монет\n"
        end
        if achievementData.Rewards.XP then
            rewardsText = rewardsText .. "⭐ " .. achievementData.Rewards.XP .. " опыта\n"
        end
        if achievementData.Rewards.Item then
            rewardsText = rewardsText .. "🎁 " .. achievementData.Rewards.Item .. "\n"
        end
        if achievementData.Rewards.Title then
            rewardsText = rewardsText .. "👑 " .. achievementData.Rewards.Title .. "\n"
        end
    end
    
    if rewardsText == "" then
        rewardsText = "Награды не указаны"
    end
    
    local rewardsLabel = Instance.new("TextLabel")
    rewardsLabel.Name = "Rewards"
    rewardsLabel.Text = "Награды:\n" .. rewardsText
    rewardsLabel.Size = UDim2.new(1, -20, 0, 40)
    rewardsLabel.Position = UDim2.new(0, 20, 0, 80)
    rewardsLabel.BackgroundTransparency = 1
    rewardsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    rewardsLabel.Font = Enum.Font.SourceSans
    rewardsLabel.TextSize = 12
    rewardsLabel.TextXAlignment = Enum.TextXAlignment.Left
    rewardsLabel.TextYAlignment = Enum.TextYAlignment.Top
    rewardsLabel.Parent = cardFrame
    
    local uiListLayout = parent:FindFirstChildOfClass("UIListLayout")
    if not uiListLayout then
        uiListLayout = Instance.new("UIListLayout")
        uiListLayout.Padding = UDim.new(0, 10)
        uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        uiListLayout.Parent = parent
    end
    
    local uipadding = parent:FindFirstChildOfClass("UIPadding")
    if not uipadding then
        uipadding = Instance.new("UIPadding")
        uipadding.PaddingTop = UDim.new(0, 10)
        uipadding.PaddingLeft = UDim.new(0, 10)
        uipadding.PaddingRight = UDim.new(0, 10)
        uipadding.Parent = parent
    end
    
    cardFrame.Parent = parent
    return cardFrame
end

local displayDailyRewards
local showRewardNotification
-- Функция загрузки данных ежедневных наград
local function loadDailyRewardsData()
    local success, data = pcall(function()
        return DailyRewardsFunction:InvokeServer("GetStatus")
    end)
    
    if success and data then
        return data
    else
        return {
            Status = {},
            AvailableGroups = {}
        }
    end
end

-- Функция для создания карточки ежедневной награды
local function createDailyRewardCard(parent, groupData, statusData, groupName)
    local cardFrame = Instance.new("Frame")
    cardFrame.Name = groupName
    cardFrame.Size = UDim2.new(1, -20, 0, 200)
    cardFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cardFrame.BorderSizePixel = 0
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Text = groupData.DisplayName or groupName
    nameLabel.Size = UDim2.new(1, 0, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = cardFrame
    
    -- Информация о прогрессе
    local progressText = string.format("День %d/%d • Подряд: %d дней", 
        statusData.currentDay or 1, 
        groupData.CycleLength or 7,
        statusData.consecutiveDays or 0)
    
    local progressLabel = Instance.new("TextLabel")
    progressLabel.Name = "Progress"
    progressLabel.Text = progressText
    progressLabel.Size = UDim2.new(1, 0, 0, 20)
    progressLabel.Position = UDim2.new(0, 10, 0, 40)
    progressLabel.BackgroundTransparency = 1
    progressLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    progressLabel.Font = Enum.Font.SourceSans
    progressLabel.TextSize = 14
    progressLabel.TextXAlignment = Enum.TextXAlignment.Left
    progressLabel.Parent = cardFrame
    
    -- Сетка наград за дни
    local rewardsGrid = Instance.new("Frame")
    rewardsGrid.Name = "RewardsGrid"
    rewardsGrid.Size = UDim2.new(1, -20, 0, 80)
    rewardsGrid.Position = UDim2.new(0, 10, 0, 70)
    rewardsGrid.BackgroundTransparency = 1
    rewardsGrid.Parent = cardFrame
    
    -- Создаем UIListLayout для сетки
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.14, 0, 1, 0)
    gridLayout.CellPadding = UDim2.new(0, 2, 0, 0)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.Parent = rewardsGrid
    
    -- Создаем карточки для каждого дня
    for day = 1, groupData.CycleLength do
        local dayFrame = Instance.new("Frame")
        dayFrame.Name = "Day" .. day
        dayFrame.BackgroundColor3 = if day <= (statusData.currentDay or 1) then Color3.fromRGB(70, 130, 70) else Color3.fromRGB(70, 70, 70)
        dayFrame.BorderSizePixel = 0
        
        local dayLabel = Instance.new("TextLabel")
        dayLabel.Name = "Day"
        dayLabel.Text = "День " .. day
        dayLabel.Size = UDim2.new(1, 0, 0.4, 0)
        dayLabel.Position = UDim2.new(0, 0, 0, 0)
        dayLabel.BackgroundTransparency = 1
        dayLabel.TextColor3 = Color3.new(1, 1, 1)
        dayLabel.Font = Enum.Font.SourceSansBold
        dayLabel.TextSize = 10
        dayLabel.Parent = dayFrame
        
        local reward = groupData.Rewards[day]
        if reward then
            local rewardText = ""
            if reward.Currency then
                rewardText = rewardText .. "💰" .. reward.Currency .. "\n"
            end
            if reward.XP then
                rewardText = rewardText .. "⭐" .. reward.XP
            end
            
            if rewardText == "" and reward.Item then
                rewardText = "🎁"
            end
            
            local rewardLabel = Instance.new("TextLabel")
            rewardLabel.Name = "Reward"
            rewardLabel.Text = rewardText
            rewardLabel.Size = UDim2.new(1, 0, 0.6, 0)
            rewardLabel.Position = UDim2.new(0, 0, 0.4, 0)
            rewardLabel.BackgroundTransparency = 1
            rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
            rewardLabel.Font = Enum.Font.SourceSans
            rewardLabel.TextSize = 10
            rewardLabel.Parent = dayFrame
        end
        
        -- Подсвечиваем текущий день
        if day == (statusData.currentDay or 1) then
            local highlight = Instance.new("Frame")
            highlight.Name = "Highlight"
            highlight.Size = UDim2.new(1, 0, 0, 3)
            highlight.Position = UDim2.new(0, 0, 0, 0)
            highlight.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            highlight.BorderSizePixel = 0
            highlight.Parent = dayFrame
        end
        
        dayFrame.Parent = rewardsGrid
    end
    
    -- Кнопка получения награды
    local claimButton = Instance.new("TextButton")
    claimButton.Name = "ClaimButton"
    claimButton.Text = statusData.canClaim and "ПОЛУЧИТЬ НАГРАДУ" or "УЖЕ ПОЛУЧЕНО"
    claimButton.Size = UDim2.new(0, 200, 0, 30)
    claimButton.Position = UDim2.new(0.5, -100, 1, -40)
    claimButton.BackgroundColor3 = statusData.canClaim and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(100, 100, 100)
    claimButton.TextColor3 = Color3.new(1, 1, 1)
    claimButton.Font = Enum.Font.SourceSansBold
    claimButton.TextSize = 14
    claimButton.Parent = cardFrame
    
    claimButton.Activated:Connect(function()
        if statusData.canClaim then
            local result = DailyRewardsFunction:InvokeServer("ClaimReward", groupName)
            if result and result.Success then
                -- Обновляем интерфейс
                displayDailyRewards()
                -- Показываем уведомление
                showRewardNotification(result.Data.reward, "Ежедневная награда получена!")
            else
                warn("Ошибка получения награды:", result and result.Error or "Неизвестная ошибка")
            end
        end
    end)
    
    local uiListLayout = parent:FindFirstChildOfClass("UIListLayout")
    if not uiListLayout then
        uiListLayout = Instance.new("UIListLayout")
        uiListLayout.Padding = UDim.new(0, 10)
        uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        uiListLayout.Parent = parent
    end
    
    local uipadding = parent:FindFirstChildOfClass("UIPadding")
    if not uipadding then
        uipadding = Instance.new("UIPadding")
        uipadding.PaddingTop = UDim.new(0, 10)
        uipadding.PaddingLeft = UDim.new(0, 10)
        uipadding.PaddingRight = UDim.new(0, 10)
        uipadding.Parent = parent
    end
    
    cardFrame.Parent = parent
    return cardFrame
end

-- Функция отображения ежедневных наград
displayDailyRewards = function()
    -- Очищаем контейнер
    for _, child in ipairs(dailyRewardsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local rewardsData = loadDailyRewardsData()
    
    -- Создаем заголовок
    local header = Instance.new("TextLabel")
    header.Name = "DailyRewardsHeader"
    header.Text = "ЕЖЕДНЕВНЫЕ НАГРАДЫ:"
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 18
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = dailyRewardsContainer
    
    -- Отображаем доступные группы наград
    if rewardsData.AvailableGroups and next(rewardsData.AvailableGroups) then
        for groupName, groupData in pairs(rewardsData.AvailableGroups) do
            local status = rewardsData.Status or {}
            createDailyRewardCard(dailyRewardsContainer, groupData, status, groupName)
        end
    else
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Text = "Ежедневные награды временно недоступны"
        emptyLabel.Size = UDim2.new(1, -20, 0, 50)
        emptyLabel.Position = UDim2.new(0, 0, 0, 40)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        emptyLabel.Font = Enum.Font.SourceSans
        emptyLabel.TextSize = 16
        emptyLabel.Parent = dailyRewardsContainer
    end
end

-- Функция для показа уведомления о награде
showRewardNotification = function(reward, title)
    local notification = Instance.new("Frame")
    notification.Name = "RewardNotification"
    notification.Size = UDim2.new(0, 300, 0, 120)
    notification.Position = UDim2.new(1, 320, 0, 20)
    notification.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
    notification.BorderSizePixel = 0
    notification.Parent = PlayerGui
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = title
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 18
    titleLabel.Parent = notification
    
    local rewardsText = ""
    if reward.Currency then
        rewardsText = rewardsText .. "💰 " .. reward.Currency .. " монет\n"
    end
    if reward.XP then
        rewardsText = rewardsText .. "⭐ " .. reward.XP .. " опыта\n"
    end
    if reward.Item then
        rewardsText = rewardsText .. "🎁 " .. reward.Item .. "\n"
    end
    
    if rewardsText == "" then
        rewardsText = "Награды получены!"
    end
    
    local rewardsLabel = Instance.new("TextLabel")
    rewardsLabel.Text = rewardsText
    rewardsLabel.Size = UDim2.new(1, 0, 0, 60)
    rewardsLabel.Position = UDim2.new(0, 0, 0, 30)
    rewardsLabel.BackgroundTransparency = 1
    rewardsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    rewardsLabel.Font = Enum.Font.SourceSans
    rewardsLabel.TextSize = 16
    rewardsLabel.Parent = notification
    
    local closeButton = Instance.new("TextButton")
    closeButton.Text = "OK"
    closeButton.Size = UDim2.new(0, 80, 0, 25)
    closeButton.Position = UDim2.new(0.5, -40, 1, -30)
    closeButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 14
    closeButton.Parent = notification
    
    closeButton.Activated:Connect(function()
        notification:Destroy()
    end)
    
    -- Анимация появления
    local tweenIn = TweenService:Create(notification, TweenInfo.new(0.5), {Position = UDim2.new(1, -320, 0, 20)})
    tweenIn:Play()
    
    -- Автоматическое скрытие через 10 секунд
    task.delay(10, function()
        if notification.Parent then
            notification:Destroy()
        end
    end)
end

-- Функция загрузки данных достижений
local function loadAchievementsData()
    local success, data = pcall(function()
        return GetAchievementsFunction:InvokeServer("GetPlayerAchievements")
    end)
    
    if success and data then
        return data
    else
        return {
            PlayerAchievements = {},
            MissingAchievements = {},
            Progress = {Earned = 0, Total = 0}
        }
    end
end

-- Функция отображения GamePass
local function displayGamePasses()
    -- Очищаем контейнер
    for _, child in ipairs(gamePassContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Создаем заголовок
    local header = Instance.new("TextLabel")
    header.Name = "GamePassHeader"
    header.Text = "ДОСТУПНЫЕ GAME PASS:"
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 18
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = gamePassContainer
    
    -- Создаем карточки GamePass
    for _, gamePass in ipairs(testGamePasses) do
        createShopItem(gamePassContainer, gamePass, "GamePass")
    end
    
    -- Если нет GamePass, показываем сообщение
    if #testGamePasses == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Text = "GamePass временно недоступны"
        emptyLabel.Size = UDim2.new(1, -20, 0, 50)
        emptyLabel.Position = UDim2.new(0, 0, 0, 40)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        emptyLabel.Font = Enum.Font.SourceSans
        emptyLabel.TextSize = 16
        emptyLabel.Parent = gamePassContainer
    end
end

-- Функция отображения продуктов
local function displayProducts()
    -- Очищаем контейнер
    for _, child in ipairs(productsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Создаем заголовок
    local header = Instance.new("TextLabel")
    header.Name = "ProductsHeader"
    header.Text = "ДОСТУПНЫЕ ПРОДУКТЫ:"
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 18
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = productsContainer
    
    -- Создаем карточки продуктов
    for _, product in ipairs(testProducts) do
        createShopItem(productsContainer, product, "Product")
    end
    
    -- Если нет продуктов, показываем сообщение
    if #testProducts == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Text = "Продукты временно недоступны"
        emptyLabel.Size = UDim2.new(1, -20, 0, 50)
        emptyLabel.Position = UDim2.new(0, 0, 0, 40)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        emptyLabel.Font = Enum.Font.SourceSans
        emptyLabel.TextSize = 16
        emptyLabel.Parent = productsContainer
    end
end

-- Функция отображения достижений
local function displayAchievements()
    -- Очищаем контейнер
    for _, child in ipairs(achievementsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local achievementsData = loadAchievementsData()
    
    -- Создаем заголовок прогресса
    local progressFrame = Instance.new("Frame")
    progressFrame.Name = "ProgressHeader"
    progressFrame.Size = UDim2.new(1, -20, 0, 60)
    progressFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    progressFrame.BorderSizePixel = 0
    progressFrame.Parent = achievementsContainer
    
    local progressText = Instance.new("TextLabel")
    progressText.Name = "ProgressText"
    progressText.Text = string.format("ДОСТИЖЕНИЯ: %d/%d (%.1f%%)", 
        achievementsData.Progress.Earned, 
        achievementsData.Progress.Total,
        (achievementsData.Progress.Earned / math.max(achievementsData.Progress.Total, 1)) * 100)
    progressText.Size = UDim2.new(1, 0, 1, 0)
    progressText.Position = UDim2.new(0, 0, 0, 0)
    progressText.BackgroundTransparency = 1
    progressText.TextColor3 = Color3.new(1, 1, 1)
    progressText.Font = Enum.Font.SourceSansBold
    progressText.TextSize = 18
    progressText.Parent = progressFrame
    
    -- Отображаем полученные достижения
    if #achievementsData.PlayerAchievements > 0 then
        local earnedHeader = Instance.new("TextLabel")
        earnedHeader.Name = "EarnedHeader"
        earnedHeader.Text = "ПОЛУЧЕННЫЕ ДОСТИЖЕНИЯ:"
        earnedHeader.Size = UDim2.new(1, -20, 0, 30)
        earnedHeader.Position = UDim2.new(0, 0, 0, 70)
        earnedHeader.BackgroundTransparency = 1
        earnedHeader.TextColor3 = Color3.fromRGB(0, 255, 0)
        earnedHeader.Font = Enum.Font.SourceSansBold
        earnedHeader.TextSize = 16
        earnedHeader.TextXAlignment = Enum.TextXAlignment.Left
        earnedHeader.Parent = achievementsContainer
        
        for _, achievement in ipairs(achievementsData.PlayerAchievements) do
            createAchievementCard(achievementsContainer, achievement, true)
        end
    end
    
    -- Отображаем недостающие достижения
    if #achievementsData.MissingAchievements > 0 then
        local startPosition = 70 + (#achievementsData.PlayerAchievements * 130)
        local missingHeader = Instance.new("TextLabel")
        missingHeader.Name = "MissingHeader"
        missingHeader.Text = "НЕДОСТАЮЩИЕ ДОСТИЖЕНИЯ:"
        missingHeader.Size = UDim2.new(1, -20, 0, 30)
        missingHeader.Position = UDim2.new(0, 0, 0, startPosition)
        missingHeader.BackgroundTransparency = 1
        missingHeader.TextColor3 = Color3.fromRGB(255, 100, 0)
        missingHeader.Font = Enum.Font.SourceSansBold
        missingHeader.TextSize = 16
        missingHeader.TextXAlignment = Enum.TextXAlignment.Left
        missingHeader.Parent = achievementsContainer
        
        for _, achievement in ipairs(achievementsData.MissingAchievements) do
            createAchievementCard(achievementsContainer, achievement, false)
        end
    end
    
    -- Если нет достижений вообще
    if #achievementsData.PlayerAchievements == 0 and #achievementsData.MissingAchievements == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Text = "Достижения временно недоступны"
        emptyLabel.Size = UDim2.new(1, -20, 0, 50)
        emptyLabel.Position = UDim2.new(0, 0, 0, 80)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        emptyLabel.Font = Enum.Font.SourceSans
        emptyLabel.TextSize = 16
        emptyLabel.Parent = achievementsContainer
    end
end

-- Навигация по вкладкам
local function showTab(tabName)
    gamePassContainer.Visible = (tabName == "GamePass")
    productsContainer.Visible = (tabName == "Products")
    achievementsContainer.Visible = (tabName == "Achievements")
    dailyRewardsContainer.Visible = (tabName == "DailyRewards")
    
    -- Обновляем внешний вид кнопок
    gamePassTab.BackgroundColor3 = tabName == "GamePass" and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(60, 60, 60)
    productsTab.BackgroundColor3 = tabName == "Products" and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(60, 60, 60)
    achievementsTab.BackgroundColor3 = tabName == "Achievements" and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(60, 60, 60)
    dailyRewardsTab.BackgroundColor3 = tabName == "DailyRewards" and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(60, 60, 60)
    
    -- Загружаем данные для активной вкладки
    if tabName == "GamePass" then
        displayGamePasses()
    elseif tabName == "Products" then
        displayProducts()
    elseif tabName == "Achievements" then
        displayAchievements()
    elseif tabName == "DailyRewards" then
        displayDailyRewards()
    end
end

-- Обработчики кнопок навигации
gamePassTab.Activated:Connect(function()
    showTab("GamePass")
end)

productsTab.Activated:Connect(function()
    showTab("Products")
end)

achievementsTab.Activated:Connect(function()
    showTab("Achievements")
end)

dailyRewardsTab.Activated:Connect(function()
    showTab("DailyRewards")
end)

closeButton.Activated:Connect(function()
    screenGui:Destroy()
end)

-- Обработчик уведомлений о достижениях
AchievementEvent.OnClientEvent:Connect(function(action, data)
    if action == "AchievementAwarded" then
        -- Показываем уведомление о получении достижения
        local notification = Instance.new("Frame")
        notification.Name = "AchievementNotification"
        notification.Size = UDim2.new(0, 300, 0, 100)
        notification.Position = UDim2.new(1, 320, 0, 20)
        notification.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
        notification.BorderSizePixel = 0
        notification.Parent = PlayerGui
        
        local title = Instance.new("TextLabel")
        title.Text = "НОВОЕ ДОСТИЖЕНИЕ!"
        title.Size = UDim2.new(1, 0, 0, 30)
        title.Position = UDim2.new(0, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 18
        title.Parent = notification
        
        local achievementName = Instance.new("TextLabel")
        achievementName.Text = data.Name
        achievementName.Size = UDim2.new(1, 0, 0, 40)
        achievementName.Position = UDim2.new(0, 0, 0, 30)
        achievementName.BackgroundTransparency = 1
        achievementName.TextColor3 = Color3.new(1, 1, 1)
        achievementName.Font = Enum.Font.SourceSans
        achievementName.TextSize = 16
        achievementName.Parent = notification
        
        local rewardsText = Instance.new("TextLabel")
        rewardsText.Text = "Награды получены!"
        rewardsText.Size = UDim2.new(1, 0, 0, 30)
        rewardsText.Position = UDim2.new(0, 0, 0, 70)
        rewardsText.BackgroundTransparency = 1
        rewardsText.TextColor3 = Color3.fromRGB(255, 215, 0)
        rewardsText.Font = Enum.Font.SourceSans
        rewardsText.TextSize = 14
        rewardsText.Parent = notification
        
        -- Анимация появления
        local tweenIn = TweenService:Create(notification, TweenInfo.new(0.5), {Position = UDim2.new(1, -320, 0, 20)})
        tweenIn:Play()
        
        -- Автоматическое скрытие через 5 секунд
        task.delay(5, function()
            if notification.Parent then
                local tweenOut = TweenService:Create(notification, TweenInfo.new(0.5), {Position = UDim2.new(1, 320, 0, 20)})
                tweenOut:Play()
                tweenOut.Completed:Connect(function()
                    notification:Destroy()
                end)
            end
        end)
        
        -- Обновляем вкладку достижений, если она открыта
        if achievementsContainer.Visible then
            displayAchievements()
        end
        
    elseif action == "AchievementError" then
        warn("Ошибка достижения:", data)
    end
end)

-- Инициализация UI
showTab("GamePass")

print("Клиентская система Premium Content загружена")