-- ShopClient - Клиентский скрипт для магазина
-- Использует EventSystem для взаимодействия с сервером
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Dialog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Dialog"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- GUI элементы
local shopGui = playerGui:WaitForChild("ShopGui")
local mainFrame = shopGui:WaitForChild("MainFrame")
local header = mainFrame:WaitForChild("Header")
local closeButton = header:WaitForChild("CloseButton")
local tabBar = header:WaitForChild("TabBar")
local tabButtons = tabBar:WaitForChild("TabButtons")
local contentContainer = mainFrame:WaitForChild("ContentContainer")

-- Ссылки на существующие кнопки вкладок
local tab1 = tabButtons:WaitForChild("Tab1")
local tab2 = tabButtons:WaitForChild("Tab2")
local tab3 = tabButtons:WaitForChild("Tab3")

-- Читаем стили из существующих элементов
local activeTabColor = tab1.TextColor3
local inactiveTabColor = tab2.TextColor3

-- Получаем размер шаблона из contentContainer
local templateSize = contentContainer:FindFirstChild("TemplateSize")
local cardWidth = 200
local cardHeight = 280
local productCardWidth = 200
local productCardHeight = 280

if templateSize then
    cardWidth = templateSize.AbsoluteSize.X
    cardHeight = templateSize.AbsoluteSize.Y
    productCardWidth = templateSize.AbsoluteSize.X
    productCardHeight = templateSize.AbsoluteSize.Y
end

-- Загрузка EventSystem через AssetService с ожиданием загрузки
local EventSystem
local maxWaitTime = 15
local waitTime = 0

while waitTime < maxWaitTime do
	local success, module = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
	end)
	
	if success and module then
		EventSystem = module
		break
	end
	
	task.wait(0.5)
	waitTime = waitTime + 0.5
end

if not EventSystem then
	warn("[ShopClient] EventSystem failed to load after waiting " .. maxWaitTime .. " seconds")
	return
end

EventSystem.Init()

-- Состояние
local currentTab = 1
local shopData = nil
local ownedGamePasses = {}

-- Функция для форматирования чисел
local function formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(math.floor(num))
end



-- Конфигурация вкладок (используем существующие кнопки из GUI)
local tabs = {
    {button = tab1, content = "GamePassesContent"},
    {button = tab2, content = "ProductsContent"},
    {button = tab3, content = "PremiumContent"}
}

-- Подключаем обработчики кликов на существующие кнопки
for i, tab in ipairs(tabs) do
    tab.button.MouseButton1Click:Connect(function()
        switchTab(i)
    end)
end

-- Функция переключения вкладок
function switchTab(tabIndex)
    currentTab = tabIndex
    
    -- Обновляем видимость контента
    for i, tab in ipairs(tabs) do
        local content = contentContainer:FindFirstChild(tab.content)
        if content then
            content.Visible = (i == tabIndex)
        end
    end
    
    for i, tab in ipairs(tabs) do
        if i == tabIndex then
            tab.button.TextColor3 = activeTabColor
        else
            tab.button.TextColor3 = inactiveTabColor
        end
    end
end

-- Функция для обновления CanvasSize скроллирующего фрейма
local function updateCanvasSize(scrollingFrame, itemCount, itemHeight, spacing)
    local uiListLayout = scrollingFrame:FindFirstChild("UIListLayout")
    if not uiListLayout then
        return
    end
    
    spacing = spacing or uiListLayout.Padding.Offset or 10
    local totalHeight = itemCount * (itemHeight + spacing) - spacing
    
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, scrollingFrame.AbsoluteSize.Y))
end

-- Функция для создания карточки GamePass
local function createGamePassCard(gamePass, isOwned)
    local gamePassesContent = contentContainer.GamePassesContent
    local template = gamePassesContent:FindFirstChild("TemplateCard")
    if not template then return end
    
    local card = template:Clone()
    card.Name = "Card_" .. gamePass.Name
    card.Visible = true
    
    -- Устанавливаем размер карточки в соответствии с TemplateSize
    card.Size = UDim2.new(0, cardWidth, 0, cardHeight)
    
    -- Заполняем данные
    local title = card:FindFirstChild("Title")
    if title then
        title.Text = gamePass.DisplayName or gamePass.Name
    end
    
    local description = card:FindFirstChild("Description")
    if description then
        local bonusText = ""
        if gamePass.Bonus then
            for bonusType, value in pairs(gamePass.Bonus) do
                if bonusType ~= "Modifiers" then
                    if type(value) == "number" then
                        bonusText = bonusText .. "• " .. bonusType .. ": " .. formatNumber(value) .. "\n"
                    end
                end
            end
        end
        description.Text = bonusText ~= "" and bonusText or "Бонусы не указаны"
    end
    
    local price = card:FindFirstChild("Price")
    if price then
        price.Text = gamePass.Price .. " Robux"
    end
    
    local buyButton = card:FindFirstChild("BuyButton")
    if buyButton then
        if isOwned then
            buyButton.Text = "✓ Owned"
            buyButton.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
            buyButton.Active = false
        else
            buyButton.Text = "Купить"
            buyButton.Active = true
            
            buyButton.MouseButton1Click:Connect(function()
				if not EventSystem then
					Dialog.show({type = "error", title = "Error", message = "EventSystem недоступен"})
					return
				end
				
				-- Запрашиваем покупку
				EventSystem.FireServer("PurchaseGamePass", gamePass.Name)
			end)
        end
    end
    
    card.Parent = gamePassesContent
    
    return card
end

-- Кэш для DonationBonusMultiplier
local cachedDonationMultiplier = 1.0

-- Функция для обновления кэша множителя
local function updateDonationMultiplier()
    if not EventSystem then return end
    local multiplier = EventSystem.CallRPC("GetDonationBonusMultiplier")
    if multiplier and type(multiplier) == "number" then
        cachedDonationMultiplier = multiplier
    end
end

-- Функция для создания карточки продукта
local function createProductCard(product)
    local productsContent = contentContainer.ProductsContent
    local template = productsContent:FindFirstChild("TemplateProductCard")
    if not template then return end
    
    local card = template:Clone()
    card.Name = "Card_" .. product.Name
    card.Visible = true
    card.Size = UDim2.new(0, productCardWidth, 0, productCardHeight)
    
    -- Заполняем данные
    local title = card:FindFirstChild("Title")
    if title then
        title.Text = product.DisplayName or product.Name
    end
    
    local description = card:FindFirstChild("Description")
    if description then
        local bonusText = ""
        if product.Bonus then
            for bonusType, value in pairs(product.Bonus) do
                if type(value) == "number" then
                    -- Проверяем, нужно ли применять множитель
                    local finalGold = math.floor(value * cachedDonationMultiplier)
                    if cachedDonationMultiplier > 1.0 then
                        bonusText = bonusText .. "• " .. bonusType .. ": " .. formatNumber(value) .. " → " .. formatNumber(finalGold) .. " (x" .. string.format("%.2f", cachedDonationMultiplier) .. ")\n"
                    else
                        bonusText = bonusText .. "• " .. bonusType .. ": " .. formatNumber(value) .. "\n"
                    end
                end
            end
        end
        description.Text = bonusText ~= "" and bonusText or "Бонусы не указаны"
    end
    
    local price = card:FindFirstChild("Price")
    if price then
        price.Text = product.Price .. " Robux"
    end
    
    local buyButton = card:FindFirstChild("BuyButton")
    if buyButton then
        buyButton.Text = "Купить"
        
        buyButton.MouseButton1Click:Connect(function()
            if not EventSystem then
                Dialog.show({type = "error", title = "Error", message = "EventSystem недоступен"})
                return
            end
            
            -- Запрашиваем покупку через RPC
            EventSystem.FireServer("PurchaseProduct", product.Name)
        end)
    end
    
    card.Parent = productsContent
    
    return card
end

-- Функция для обновления премиум статуса
local function updatePremiumStatus(isPremium)
    local premiumContent = contentContainer:FindFirstChild("PremiumContent")
    if not premiumContent then return end
    
    local premiumInfo = premiumContent:FindFirstChild("PremiumInfo")
    if not premiumInfo then return end
    
    local statusLabel = premiumInfo:FindFirstChild("PremiumStatus")
    if statusLabel then
        if isPremium then
            statusLabel.Text = "Status: ✓ Active"
            statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
        else
            statusLabel.Text = "Status: ✗ Inactive"
            statusLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
        end
    end
end

-- Функция для загрузки данных магазина
local function loadShopData()
    if not EventSystem then
        Dialog.show({type = "error", title = "Error", message = "EventSystem недоступен"})
        return
    end
    
    -- Обновляем кэш множителя перед загрузкой данных
    updateDonationMultiplier()
    
    -- Запрашиваем данные с сервера через RPC
    local data = EventSystem.CallRPC("GetShopData")
    
    if not data then
        Dialog.show({type = "error", title = "Error", message = "Error loading data"})
        return
    end
    
    shopData = data
    ownedGamePasses = data.ownedGamePasses or {}
    
    -- Очищаем существующие карточки (кроме шаблонов)
    local gamePassesContent = contentContainer:FindFirstChild("GamePassesContent")
    if gamePassesContent then
        for _, child in ipairs(gamePassesContent:GetChildren()) do
            if child.Name ~= "TemplateCard" and child.Name ~= "UIListLayout" then
                child:Destroy()
            end
        end
    end
    
    local productsContent = contentContainer:FindFirstChild("ProductsContent")
    if productsContent then
        for _, child in ipairs(productsContent:GetChildren()) do
            if child.Name ~= "TemplateProductCard" and child.Name ~= "UIListLayout" then
                child:Destroy()
            end
        end
    end
    
    local gamePassCount = 0
    local productCount = 0
    
    -- Создаем карточки GamePasses
    if data.gamePasses then
        gamePassCount = #data.gamePasses
        for _, gamePass in ipairs(data.gamePasses) do
            local isOwned = ownedGamePasses[gamePass.Name] == true
            createGamePassCard(gamePass, isOwned)
        end
    end
    
    -- Создаем карточки Products
    if data.products then
        productCount = #data.products
        for _, product in ipairs(data.products) do
            createProductCard(product)
        end
    end
    
    if gamePassesContent then
        local uiListLayout = gamePassesContent:FindFirstChild("UIListLayout")
        local spacing = uiListLayout and uiListLayout.Padding.Offset or 10
        updateCanvasSize(gamePassesContent, gamePassCount, cardHeight, spacing)
    end
    
    if productsContent then
        local uiListLayout = productsContent:FindFirstChild("UIListLayout")
        local spacing = uiListLayout and uiListLayout.Padding.Offset or 10
        updateCanvasSize(productsContent, productCount, productCardHeight, spacing)
    end
    
    -- Обновляем премиум статус
    updatePremiumStatus(data.isPremium)
end

-- Обработка уведомления об обновлении владения через EventSystem
if EventSystem then
	EventSystem.OnClient("OwnershipUpdated", function(itemType, itemName, isOwned)
		if itemType == "GamePass" then
			ownedGamePasses[itemName] = isOwned
			-- Перезагружаем данные для обновления интерфейса
			loadShopData()
		end
	end)
else
	warn("[ShopClient] EventSystem unavailable for handling OwnershipUpdated")
end

-- Закрытие магазина
local function closeShop()
    shopGui.Enabled = false
end

closeButton.MouseButton1Click:Connect(closeShop)

-- Закрытие по ESC
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape and shopGui.Enabled then
        closeShop()
    end
end)

-- Функция для открытия магазина (вызывается извне)
function openShop()
    shopGui.Enabled = true
    loadShopData()
end

-- Экспортируем функцию открытия
_G.ShopClient = {
    Open = openShop,
    Close = closeShop,
    Refresh = loadShopData
}

-- Инициализация при первом открытии
shopGui.Enabled = false

-- Устанавливаем начальную вкладку
switchTab(1)

-- Подключаем кнопку магазина в TopBar
task.wait(1) -- Ждем загрузки GUI
local topBar = playerGui:FindFirstChild("TopBar")
if topBar then
    local leftButtons = topBar:FindFirstChild("LeftButtons")
    if leftButtons then
        local shopButton = leftButtons:FindFirstChild("ShopButton")
        if shopButton then
            shopButton.MouseButton1Click:Connect(function()
                openShop()
            end)
            print("[ShopClient] Shop button connected")
        end
    end
end

print("[ShopClient] Initialized successfully with EventSystem integration")