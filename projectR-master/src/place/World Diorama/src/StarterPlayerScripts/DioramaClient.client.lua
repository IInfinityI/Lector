-- DioramaClient (LocalScript) - Обновленный для нового GUI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadingScreen = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingScreen"))
LoadingScreen.Start()
LoadingScreen.WaitForLoad()

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Загружаем EventSystem через AssetService с ожиданием загрузки
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
	warn("EventSystem не удалось загрузить после ожидания " .. maxWaitTime .. " секунд")
	return
end

EventSystem.Init()

-- GUI элементы - новая структура
local purchaseGui = playerGui:WaitForChild("PurchaseGui")
local mainFrame = purchaseGui:WaitForChild("MainFrame")
local topBar = mainFrame:WaitForChild("TopBar")
local contentFrame = mainFrame:WaitForChild("Content")

-- Top Bar элементы
local closeButton = topBar:WaitForChild("CloseButton")

-- Info Panel элементы
local infoPanel = contentFrame:WaitForChild("InfoPanel")
local titleLabel = infoPanel:WaitForChild("Title")
local sceneRarity = infoPanel:WaitForChild("SceneRarity")
local sceneIncome = infoPanel:WaitForChild("SceneIncome")
local ownerInfo = infoPanel:WaitForChild("OwnerInfo")

-- Tab Bar
local tabBar = topBar:WaitForChild("TabBar")
local tabButtons = tabBar:WaitForChild("TabButtons")

-- Tab Content
local tabContent = contentFrame:WaitForChild("TabContent")
local tab2Content = tabContent:FindFirstChild("Tab2Content")
local tab3Content = tabContent:FindFirstChild("Tab3Content")
local tabConnections = {} -- Таблица для хранения подключений

if tab2Content and tab3Content then
	local votingSection = tab2Content:FindFirstChild("VotingSection")
	if votingSection and not tab3Content:FindFirstChild("VotingSection") then
		-- Клонируем VotingSection со всем содержимым
		local newVotingSection = votingSection:Clone()
		newVotingSection.Parent = tab3Content
		newVotingSection.Visible = false -- изначально скрыта, показом управляет switchTab
	end
else
	warn("Tab2Content или Tab3Content не найдены, копирование VotingSection не выполнено")
end

-- Status Text
local statusText = contentFrame:WaitForChild("StatusText")

-- Хранилища для подключений кнопок
local allButtonConnections = {}   -- для статических кнопок (владелец/покупатель/голосование)
local spotConnections = {}        -- для кнопок выбора места (SpotDropdown)
local pickerConnections = {}      -- для кнопок кастомизации (цвета, материалы, рамки, стенды)

-- Функция очистки всех статических подключений
local function clearAllStaticConnections()
    for _, conn in ipairs(allButtonConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    allButtonConnections = {}
end

-- Функция очистки подключений для выбора места
local function clearSpotConnections()
    for _, conn in ipairs(spotConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    spotConnections = {}
end

-- Функция очистки подключений для пикеров кастомизации
local function clearPickerConnections()
    for _, conn in ipairs(pickerConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    pickerConnections = {}
end

-- Очистка всех подключений
local function clearAllConnections()
    clearAllStaticConnections()
    clearSpotConnections()
    clearPickerConnections()
end

-- Переменные для текущего режима (владелец/покупатель)
local currentMode = "buyer" -- или "owner"
local currentTab = 1

local currentDioramaId = nil
local currentDioramaData = {}
local isOwner = false

-- Маппинги для рамок и стендов (имена кнопок -> ID предметов на сервере)
local frameMap = {
	frameDefault = "DefaultFrame",
	frameGolden = "Golden",
	frameWooden = "Wooden",
	frameIce = "Ice",
	frameTech = "Tech"
}

local standMap = {
	standDefaul = "DefaultStand",
	standMarble = "Marble",
	standGolden = "Golden",
	standTech = "Tech",
	standRustic = "Rustic"
}

-- Маппинг цветов для визуального отображения
local colorMap = {
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	Red = Color3.new(1, 0, 0),
	Green = Color3.new(0, 1, 0),
	Blue = Color3.new(0, 0, 1),
	Yellow = Color3.new(1, 1, 0),
	Cyan = Color3.new(0, 1, 1),
	Magenta = Color3.new(1, 0, 1),
	Gray = Color3.new(0.5, 0.5, 0.5),
}

-- Функция для форматирования чисел
local function formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(math.floor(num))
end

-- Функция для проверки наличия предмета кастомизации у игрока
local function hasItem(category, itemId)
	if not currentDioramaData.AvailableCustomization then return false end
	local cat = currentDioramaData.AvailableCustomization[category]
	return cat and cat[itemId] == true
end

-- Функция для создания кнопки из шаблона
local function createButtonFromTemplate(template, name, text, color, isAvailable)
	local button = template:Clone()
	button.Name = name
	button.Text = text
	button.Visible = true
	
	if color then
		button.BackgroundColor3 = color
		-- Для светлых цветов используем темный текст
		if (color.R + color.G + color.B) / 3 > 0.5 then
			button.TextColor3 = Color3.new(0, 0, 0)
		else
			button.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	
	if isAvailable then
		button.BackgroundTransparency = 0
		button.Active = true
	else
		button.BackgroundTransparency = 0.5
		button.Active = false
	end
	
	return button
end

-- Функция для обновления выделения текущего элемента в пикере
local function updatePickerHighlight(scrollingFrame, selectedItemId, actionType)
	if not scrollingFrame then return end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("TextButton") then
			-- Удаляем существующий UIStroke
			local existingStroke = child:FindFirstChildOfClass("UIStroke")
			if existingStroke then
				existingStroke:Destroy()
			end

			-- Добавляем UIStroke для выбранного элемента
			if selectedItemId and actionType and child.Name == actionType .. selectedItemId then
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(255, 205, 0)
				stroke.Thickness = 1
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = child
			end
		end
	end
end

-- Функция для очистки ScrollingFrame и создания кнопок из данных с обработчиками
local function populatePickerFromData(pickerFrame, itemsData, category, actionType, serverEventName, currentSelection)
	if not pickerFrame then return end
	local customizeSection = tab2Content:FindFirstChild("CustomizeSection")
    if not customizeSection then return end

	local scrollingFrame = pickerFrame:FindFirstChild("ScrollingFrame")
	if not scrollingFrame then return end

    local templateSize = customizeSection:FindFirstChild("TemplateSize")
	if not templateSize then return end
	
	local templateButton = scrollingFrame:FindFirstChild("TemplateButton")
	if not templateButton then return end
	
	-- Удаляем все существующие кнопки (кроме шаблона)
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("TextButton") and child ~= templateButton then
			child:Destroy()
		end
	end
	
	local totalWidth = 0
	local buttonWidth = templateButton.Size.X.Offset
	local padding = 8
	
	-- Создаем кнопки из данных
	for itemId, isAvailable in pairs(itemsData) do
		local buttonColor = nil
		local buttonText = itemId
		
		-- Для цветов используем визуальное отображение
		if category == "Colors" then
			buttonColor = colorMap[itemId]
			buttonText = ""
		end
		
		local button = createButtonFromTemplate(templateButton, actionType .. itemId, buttonText, buttonColor, isAvailable)
        templateButton.Visible = false

        if category == "Colors" then
            local newSize = scrollingFrame.AbsoluteSize.Y * 0.7
            button.Size = UDim2.new(0, newSize, 0, newSize)
            buttonWidth = newSize  
        else
            button.Size = UDim2.new(0, templateSize.AbsoluteSize.X, 0, templateSize.AbsoluteSize.Y)
            buttonWidth = templateSize.AbsoluteSize.X  
		end

		button.Parent = scrollingFrame
		if currentSelection and (itemId == currentSelection or (category == "Colors" and colorMap[itemId].b == currentSelection["B"] and colorMap[itemId].g == currentSelection["G"] and colorMap[itemId].r == currentSelection["R"])) then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 205, 0)
			stroke.Thickness = 1
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = button
		end

		-- Привязываем обработчик клика
		local connection = button.MouseButton1Click:Connect(function()
			if not currentDioramaId then return end
			if not isAvailable then
				statusText.Text = "✗ У вас нет этого предмета"
				statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
				return
			end
			-- Обновляем выделение
			updatePickerHighlight(scrollingFrame, itemId, actionType)
			-- Вызываем соответствующее серверное событие
			EventSystem.FireServer(serverEventName, currentDioramaId, itemId)
		end)
		
		table.insert(pickerConnections, connection)
		
		totalWidth = totalWidth + buttonWidth + padding
	end
	
	-- Обновляем CanvasSize ScrollingFrame
	scrollingFrame.CanvasSize = UDim2.new(0, totalWidth + 16, 1, 0)
end

-- Функция для обновления выделения и видимости мест в SpotDropdown
local function updateSpotDropdownHighlight()
	local tab2Content = tabContent:FindFirstChild("Tab2Content")
	if not tab2Content then return end

	local customizeSection = tab2Content:FindFirstChild("CustomizeSection")
	if not customizeSection then return end

	local spotDropdown = customizeSection:FindFirstChild("SpotDropdown")
	if not spotDropdown then return end

	local availableSpots = currentDioramaData.AvailableSpots or 1
	local currentSpot = currentDioramaData.CurrentSpot

	for _, spotBtn in ipairs(spotDropdown:GetChildren()) do
		if spotBtn:IsA("TextButton") then
			-- Удаляем существующий UIStroke
			local existingStroke = spotBtn:FindFirstChildOfClass("UIStroke")
			if existingStroke then
				existingStroke:Destroy()
			end

			-- Скрываем кнопки для недоступных мест
			local spotNumber = tonumber(spotBtn.Name:sub(5))
			if spotNumber then
				spotBtn.Visible = spotNumber <= availableSpots

				-- Добавляем UIStroke для текущего выбранного места
				if currentSpot and spotNumber == currentSpot then
					local stroke = Instance.new("UIStroke")
					stroke.Color = Color3.fromRGB(255, 205, 0)
					stroke.Thickness = 1
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					stroke.Parent = spotBtn
				end
			end
		end
	end
end

-- Функция для обновления визуальной доступности кнопок кастомизации
local function updateCustomizationButtonsAvailability()
	local tab2Content = tabContent:FindFirstChild("Tab2Content")
	if not tab2Content then return end
	local customizeSection = tab2Content:FindFirstChild("CustomizeSection")
	if not customizeSection then return end

	if not currentDioramaData.AvailableCustomization then return end
	
	local customization = currentDioramaData.AvailableCustomization
	
	-- Очищаем старые подключения пикеров
	clearPickerConnections()
	
	-- Цвета
	local wallColorPicker = customizeSection:FindFirstChild("WallColorPicker")
	if wallColorPicker and customization.Colors then
		populatePickerFromData(wallColorPicker, customization.Colors, "Colors", "Color", "ChangeDioramaWallColor", currentDioramaData.WallColor)
	end

	-- Материалы
	local wallMaterialPicker = customizeSection:FindFirstChild("WallMaterialPicker")
	if wallMaterialPicker and customization.Materials then
		populatePickerFromData(wallMaterialPicker, customization.Materials, "Materials", "Material", "ChangeDioramaWallMaterial", currentDioramaData.WallMaterial)
	end

	-- Рамки
	local frameTypePicker = customizeSection:FindFirstChild("FrameTypePicker")
	if frameTypePicker and customization.Frames then
		populatePickerFromData(frameTypePicker, customization.Frames, "Frames", "Frame", "ChangeDioramaFrameType", currentDioramaData.FrameType)
	end

	-- Стенды
	local standTypePicker = customizeSection:FindFirstChild("StandTypePicker")
	if standTypePicker and customization.Stands then
		populatePickerFromData(standTypePicker, customization.Stands, "Stands", "Stand", "ChangeDioramaStandType", currentDioramaData.StandType)
	end

	-- Обновляем SpotDropdown
	updateSpotDropdownHighlight()
end

-- Функция для переключения вкладок
local function switchTab(tabIndex)
    currentTab = tabIndex

    -- Скрываем все вкладки
    for _, child in ipairs(tabContent:GetChildren()) do
        if child.Name:sub(1, 3) == "Tab" then
            child.Visible = false
        end
    end

    -- Показываем выбранную вкладку
    local targetTab = tabContent:FindFirstChild("Tab" .. tabIndex .. "Content")
    if targetTab then
        targetTab.Visible = true

        -- Дополнительное управление видимостью внутренних фреймов
        if targetTab.Name == "Tab2Content" then
            local customizeSection = targetTab:FindFirstChild("CustomizeSection")
            local votingSection = targetTab:FindFirstChild("VotingSection")

            if currentMode == "owner" then
                -- Вкладка кастомизации (для владельца)
                if customizeSection then customizeSection.Visible = true end
                if votingSection then votingSection.Visible = false end
            else -- buyer
                -- Вкладка голосования (для покупателя)
                if customizeSection then customizeSection.Visible = false end
                if votingSection then votingSection.Visible = true end
            end
        elseif targetTab.Name == "Tab3Content" then
            -- Только голосование (для владельца)
            local votingSection = targetTab:FindFirstChild("VotingSection")
            if votingSection then votingSection.Visible = true end

            -- Скрываем другие возможные фреймы
            for _, child in ipairs(targetTab:GetChildren()) do
                if child ~= votingSection and child:IsA("Frame") then
                    child.Visible = false
                end
            end
        elseif targetTab.Name == "Tab1Content" then
            -- Управление видимостью в первой вкладке
            local manageSection = targetTab:FindFirstChild("ManageSection")
            local purchaseSection = targetTab:FindFirstChild("PurchaseSection")
            
            if currentMode == "owner" then
                if manageSection then manageSection.Visible = true end
                if purchaseSection then purchaseSection.Visible = false end
            else -- buyer
                if manageSection then manageSection.Visible = false end
                if purchaseSection then purchaseSection.Visible = true end
            end
        end
    end

    -- Обновляем кнопки вкладок
    for i, btn in ipairs(tabButtons:GetChildren()) do
        if btn:IsA("TextButton") then
            if i == tabIndex then
                btn.TextColor3 = Color3.fromRGB(255, 205, 0)
            else
                btn.TextColor3 = Color3.fromRGB(126, 136, 168)
            end
        end
    end
end

local function clearTabConnections()
    for i = 1, 3 do
        if tabConnections[i] then
            tabConnections[i]:Disconnect()
            tabConnections[i] = nil
        end
    end
end

-- Функция для переключения режима (владелец/покупатель)
local function setMode(mode)
    currentMode = mode
    
    -- Очищаем старые подключения
    clearTabConnections()
    
    if mode == "owner" then
        local tabs = {"Управление", "Кастомизация", "Голосование"}
        for i, tabName in ipairs(tabs) do
            local btn = tabButtons:WaitForChild("Tab" .. i)
            btn.Text = tabName
            btn.Visible = true
            tabConnections[i] = btn.MouseButton1Click:Connect(function()
                switchTab(i)
            end)
        end
    else
        local tabs = {"Покупка", "Голосование"}
        for i, tabName in ipairs(tabs) do
            local btn = tabButtons:WaitForChild("Tab" .. i)
            btn.Text = tabName
            btn.Visible = true
            tabConnections[i] = btn.MouseButton1Click:Connect(function()
                switchTab(i)
            end)
        end
        
        local thirdBtn = tabButtons:FindFirstChild("Tab3")
        if thirdBtn then
            thirdBtn.Visible = false
        end
    end
    
    switchTab(1)
end

-- Функция для запроса данных диорамы через RPC
local function requestDioramaData(dioramaId)
	if not EventSystem then
		warn("EventSystem недоступен для запроса данных диорамы")
		return nil
	end
	return EventSystem.CallRPC("GetDioramaData", dioramaId)
end

-- Функция для обновления секции голосования
local function updateVotingSection(data)
    if not data then return end
    
    -- Для покупателя голосование находится в Tab2Content
    -- Для владельца - в Tab3Content
    local votingTab
    if isOwner then
        votingTab = tabContent:FindFirstChild("Tab3Content")
    else
        votingTab = tabContent:FindFirstChild("Tab2Content")
    end
    
    if not votingTab then return end
    
    local votingSection = votingTab:FindFirstChild("VotingSection")
    if not votingSection then return end
    
    local ratingInfo = votingSection:FindFirstChild("RatingInfo")
    local votePrice = votingSection:FindFirstChild("VotePrice")
    local ratingEffect = votingSection:FindFirstChild("RatingEffect")
    
    if ratingInfo then
        ratingInfo.Text = string.format("Рейтинг: %.1f/10  |  ↑ %d ↓ %d", data.Rating, data.Upvotes, data.Downvotes)
    end
    
    if votePrice then
        votePrice.Text = string.format("Цена голоса: %d золота", data.VotePrice)
    end
    
    if ratingEffect then
        local effectPercent = data.RatingEffect * 100
        if effectPercent > 0 then
            ratingEffect.Text = string.format("Влияние на цену: +%.1f%%", effectPercent)
            ratingEffect.TextColor3 = Color3.fromRGB(46, 204, 113)
        elseif effectPercent < 0 then
            ratingEffect.Text = string.format("Влияние на цену: %.1f%%", effectPercent)
            ratingEffect.TextColor3 = Color3.fromRGB(139, 31, 31)
        else
            ratingEffect.Text = "Влияние на цену: 0%"
            ratingEffect.TextColor3 = Color3.fromRGB(126, 136, 168)
        end
    end
end

-- Функция для обновления фрейма владельца
local function updateOwnerFrame(data)
    if not data then return end
    
    local tab1Content = tabContent:FindFirstChild("Tab1Content")
    if not tab1Content then return end
    
    local manageSection = tab1Content:FindFirstChild("ManageSection")
    if not manageSection then return end
    
    -- Накопленный доход
    local incomeBlock = manageSection:FindFirstChild("IncomeBlock")
    if incomeBlock then
        local accumulatedIncome = incomeBlock:FindFirstChild("AccumulatedIncome")
        local incomeProgressFillContainer = incomeBlock:FindFirstChild("IncomeProgressFill")
        local incomeProgressFillBar = incomeProgressFillContainer and incomeProgressFillContainer:FindFirstChild("IncomeProgressFillBar")
        
        if accumulatedIncome then
            accumulatedIncome.Text = string.format("%d / %d", data.AccumulatedIncome, data.MaxAccumulatedIncome)
        end
        
        if incomeProgressFillBar then
            local progress = math.min(data.AccumulatedIncome / data.MaxAccumulatedIncome, 1)
            local progressPercentage = math.min(progress * 100, 100)
            incomeProgressFillBar.Size = UDim2.new(progressPercentage / 100, 0, 1, 0)
        end
    end
    
    -- Быстрая продажа
    local quickSellLabel = manageSection:FindFirstChild("QuickSellLabel")
    if quickSellLabel then
        quickSellLabel.Text = string.format("Быстрая продажа: %d (10%%)", data.QuickSellAmount)
    end
    
    -- GamePass
    local gamePassActive = manageSection:FindFirstChild("GamePassActive")
    local gamePassInactive = manageSection:FindFirstChild("GamePassInactive")
    
    if data.GamePassInfo then
        if gamePassActive then
            gamePassActive.Visible = true
            local currentGamePass = gamePassActive:FindFirstChild("CurrentGamePass")
            if currentGamePass then
                currentGamePass.Text = string.format("Текущий GamePass: %s", data.GamePassInfo.Name)
            end
        end
        if gamePassInactive then
            gamePassInactive.Visible = false
        end
    else
        if gamePassActive then
            gamePassActive.Visible = false
        end
        if gamePassInactive then
            gamePassInactive.Visible = true
        end
    end
    
    -- Кнопки запрета покупки
    local banPurchaseBtn = manageSection:FindFirstChild("BanPurchaseBtn")
    local extendBanBtn = manageSection:FindFirstChild("ExtendBanBtn")
    local ticketsLabel = manageSection:FindFirstChild("TicketsLabel")
    
    -- Получаем количество билетов
    local tickets = 0
    if EventSystem then
        tickets = EventSystem.CallRPC("GetPurchaseBanTickets") or 0
    end
    
    if ticketsLabel then
        ticketsLabel.Text = string.format("Билеты: %d", tickets)
    end
    
    -- Проверяем статус запрета покупки
    local isBanned = data.IsPurchaseBanned or false
    local banEndTime = data.PurchaseBanEndTime or 0
    
    if banPurchaseBtn then
        if isBanned then
            local remainingTime = banEndTime - os.time()
            if remainingTime > 0 then
                local minutes = math.floor(remainingTime / 60)
                local seconds = remainingTime % 60
                banPurchaseBtn.Text = string.format("Запрет активен: %d:%02d", minutes, seconds)
                banPurchaseBtn.Active = false
            else
                -- Запрет истёк
                if tickets >= 1 then
                    banPurchaseBtn.Text = "Запретить покупку (1 билет)"
                    banPurchaseBtn.Active = true
                else
                    banPurchaseBtn.Text = "Нет билетов"
                    banPurchaseBtn.Active = false
                end
            end
        else
            if tickets >= 1 then
                banPurchaseBtn.Text = "Запретить покупку (1 билет)"
                banPurchaseBtn.Active = true
            else
                banPurchaseBtn.Text = "Нет билетов"
                banPurchaseBtn.Active = false
            end
        end
    end
    
    if extendBanBtn then
        extendBanBtn.Visible = false
        if isBanned then
            local remainingTime = banEndTime - os.time()
            if remainingTime > 0 then
                extendBanBtn.Visible = true
                
                if tickets >= 1 then
                    extendBanBtn.Text = "Увеличить время (1 билет)"
                    extendBanBtn.Active = true
                    if extendBanBtn.BackgroundColor3 then
                        extendBanBtn.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
                    end
                else
                    extendBanBtn.Text = "Нет билетов"
                    extendBanBtn.Active = false
                    if extendBanBtn.BackgroundColor3 then
                        extendBanBtn.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
                    end
                end
            end
        end
    end
end

-- Функция для обновления фрейма покупателя
local function updateBuyerFrame(data)
    if not data then return end
    
    local tab1Content = tabContent:FindFirstChild("Tab1Content")
    if not tab1Content then return end
    
    local purchaseSection = tab1Content:FindFirstChild("PurchaseSection")
    if not purchaseSection then return end
    
    -- Проверяем запрет покупки
    local isBanned = data.IsPurchaseBanned or false
    local banEndTime = data.PurchaseBanEndTime or 0
    
    -- Доступное золото
    local goldBlock = purchaseSection:FindFirstChild("GoldBlock")
    if goldBlock then
        -- Цена покупки
        local priceLabel = goldBlock:FindFirstChild("PriceLabel")
        if priceLabel then
            priceLabel.Text = string.format(formatNumber(data.CurrentPrice))
        end
    end
    
    -- Кнопка покупки за золото
    local buyGoldBtn = purchaseSection:FindFirstChild("BuyGoldBtn")
    if buyGoldBtn then
        if isBanned then
            local remainingTime = banEndTime - os.time()
            if remainingTime > 0 then
                local minutes = math.floor(remainingTime / 60)
                local seconds = remainingTime % 60
                buyGoldBtn.Text = string.format("Запрет на покупку: %d:%02d", minutes, seconds)
                buyGoldBtn.BackgroundColor3 = Color3.fromRGB(139, 31, 31)
                buyGoldBtn.Active = false
            else
                -- Запрет истёк, но данные ещё не обновились
                if data.AvailableGold >= data.CurrentPrice then
                    buyGoldBtn.Text = "Купить за золото"
                    buyGoldBtn.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
                    buyGoldBtn.Active = true
                else
                    buyGoldBtn.Text = string.format("Недостаточно золота")
                    buyGoldBtn.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
                    buyGoldBtn.Active = false
                end
            end
        else
            if data.AvailableGold >= data.CurrentPrice then
                buyGoldBtn.Text = "Купить за золото"
                buyGoldBtn.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
                buyGoldBtn.Active = true
            else
                buyGoldBtn.Text = string.format("Недостаточно золота")
                buyGoldBtn.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
                buyGoldBtn.Active = false
            end
        end
    end
    
    local robuxBlock = purchaseSection:FindFirstChild("RobuxBlock")
    if robuxBlock then
        -- Цена покупки
        local robuxPriceLabel = robuxBlock:FindFirstChild("PriceLabel")
        local buyRobuxBtn = purchaseSection:FindFirstChild("BuyRobuxBtn")
        if data.GamePassInfo then
            if robuxPriceLabel then
                robuxPriceLabel.Text = string.format("Купить за Robux: %d Robux", data.GamePassInfo.PriceInRobux)
                robuxBlock.Visible = true
            end
            if buyRobuxBtn then
                buyRobuxBtn.Visible = true
                if isBanned then
                    buyRobuxBtn.Active = false
                else
                    buyRobuxBtn.Active = true
                end
            end
        else
            if robuxBlock then
                robuxBlock.Visible = false
            end
            if buyRobuxBtn then
                buyRobuxBtn.Visible = false
            end
        end
    end
end

-- Функция для обновления GUI с данными диорамы
local function updateDioramaGUI(data)
    if not data then return end
    
    -- Общая информация
    titleLabel.Text = data.SceneName
    sceneRarity.Text = data.RarityName
    sceneIncome.Text = string.format("Доход: %s /ч", formatNumber(data.IncomeRate))
    
    -- Информация о владельце
    if data.OwnerId then
        if data.OwnerId == player.UserId then
            ownerInfo.Text = "Вы владелец"
            isOwner = true
        else
            ownerInfo.Text = "Владелец: " .. (data.OwnerName or "Игрок " .. tostring(data.OwnerId))
            isOwner = false
        end
    else
        ownerInfo.Text = "Свободно для покупки"
        isOwner = false
    end
    
    -- Переключаем режим
    setMode(isOwner and "owner" or "buyer")
    
    -- Обновляем секции
    if isOwner then
        updateOwnerFrame(data)
    else
        updateBuyerFrame(data)
    end
    
    -- Обновляем голосование
    updateVotingSection(data)
    
    -- Обновляем доступность кнопок кастомизации
    if isOwner then
        updateCustomizationButtonsAvailability()
    end
    
    -- Сброс статусного текста
    statusText.Text = ""
end

-- Обработка кнопок владельца
local function setupOwnerButtons()
    local tab1Content = tabContent:FindFirstChild("Tab1Content")
    if not tab1Content then return end
    
    local manageSection = tab1Content:FindFirstChild("ManageSection")
    if not manageSection then return end
    
    local collectBtn = manageSection:FindFirstChild("CollectBtn")
    local quickSellBtn = manageSection:FindFirstChild("QuickSellBtn")
    local gamePassActive = manageSection:FindFirstChild("GamePassActive")
    local gamePassInactive = manageSection:FindFirstChild("GamePassInactive")
    
    if collectBtn then
        table.insert(allButtonConnections, collectBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("CollectIncome", currentDioramaId, "Diorama")
        end))
    end
    
    if quickSellBtn then
        table.insert(allButtonConnections, quickSellBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("QuickSellDiorama", currentDioramaId)
        end))
    end
    
    if gamePassInactive then
        local setGamePassBtn = gamePassInactive:FindFirstChild("SetGamePassBtn")
        local gamePassInput = gamePassInactive:FindFirstChild("GamePassInput")
        
        if setGamePassBtn and gamePassInput then
            table.insert(allButtonConnections, setGamePassBtn.MouseButton1Click:Connect(function()
                if not currentDioramaId then return end
                local gamePassId = tonumber(gamePassInput.Text)
                if not gamePassId then
                    statusText.Text = "✗ Введите корректный ID GamePass"
                    statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
                    return
                end
                EventSystem.FireServer("SetDioramaGamePass", currentDioramaId, gamePassId)
            end))
        end
    end
    
    if gamePassActive then
        local removeGamePassBtn = gamePassActive:FindFirstChild("RemoveGamePassBtn")
        if removeGamePassBtn then
            table.insert(allButtonConnections, removeGamePassBtn.MouseButton1Click:Connect(function()
                if not currentDioramaId then return end
                EventSystem.FireServer("RemoveDioramaGamePass", currentDioramaId)
            end))
        end
    end
    
    -- Кнопка запрета покупки
    local banPurchaseBtn = manageSection:FindFirstChild("BanPurchaseBtn")
    if banPurchaseBtn then
        table.insert(allButtonConnections, banPurchaseBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("BanDioramaPurchase", currentDioramaId)
        end))
    end
    
    -- Кнопка увеличения времени запрета
    local extendBanBtn = manageSection:FindFirstChild("ExtendBanBtn")
    if extendBanBtn then
        table.insert(allButtonConnections, extendBanBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("ExtendPurchaseBan", currentDioramaId)
        end))
    end
end

-- Обработка кнопок покупателя
local function setupBuyerButtons()
    local tab1Content = tabContent:FindFirstChild("Tab1Content")
    if not tab1Content then return end
    
    local purchaseSection = tab1Content:FindFirstChild("PurchaseSection")
    if not purchaseSection then return end
    
    local buyGoldBtn = purchaseSection:FindFirstChild("BuyGoldBtn")
    local buyRobuxBtn = purchaseSection:FindFirstChild("BuyRobuxBtn")
    
    if buyGoldBtn then
        table.insert(allButtonConnections, buyGoldBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("PurchaseDiorama", currentDioramaId)
        end))
    end
    
    if buyRobuxBtn then
        table.insert(allButtonConnections, buyRobuxBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId or not currentDioramaData.GamePassId then return end
            MarketplaceService:PromptGamePassPurchase(player, currentDioramaData.GamePassId)
        end))
    end
end

-- Обработка кнопок голосования
local function setupVotingButtons()
    -- Для покупателя голосование находится в Tab2Content
    -- Для владельца - в Tab3Content
    local votingTab
    if isOwner then
        votingTab = tabContent:FindFirstChild("Tab3Content")
    else
        votingTab = tabContent:FindFirstChild("Tab2Content")
    end
    
    if not votingTab then return end
    
    local votingSection = votingTab:FindFirstChild("VotingSection")
    if not votingSection then return end
    
    local voteButtons = votingSection:FindFirstChild("VoteButtons")
    if not voteButtons then return end
    
    local upvoteBtn = voteButtons:FindFirstChild("UpvoteBtn")
    local downvoteBtn = voteButtons:FindFirstChild("DownvoteBtn")
    
    if upvoteBtn then
        table.insert(allButtonConnections, upvoteBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("VoteForDiorama", currentDioramaId, "up")
        end))
    end
    
    if downvoteBtn then
        table.insert(allButtonConnections, downvoteBtn.MouseButton1Click:Connect(function()
            if not currentDioramaId then return end
            EventSystem.FireServer("VoteForDiorama", currentDioramaId, "down")
        end))
    end
end

-- Обработка кастомизации (только для владельца)
local function setupCustomizationButtons()
    local tab2Content = tabContent:FindFirstChild("Tab2Content")
    if not tab2Content then return end
    
    local customizeSection = tab2Content:FindFirstChild("CustomizeSection")
    if not customizeSection or not isOwner then return end -- только для владельца
    
    -- Очищаем старые обработчики для кнопок мест
    clearSpotConnections()
    
    -- Выбор места (всегда доступно, без проверки)
    local spotDropdown = customizeSection:FindFirstChild("SpotDropdown")
    if spotDropdown then
        -- Обновляем видимость и выделение мест
        updateSpotDropdownHighlight()

        for _, spotBtn in ipairs(spotDropdown:GetChildren()) do
            if spotBtn:IsA("TextButton") then
                table.insert(spotConnections, spotBtn.MouseButton1Click:Connect(function()
                    if not currentDioramaId then return end
                    local spotNumber = tonumber(spotBtn.Name:sub(5))
                    if spotNumber then
                        -- Обновляем выделение
                        currentDioramaData.CurrentSpot = spotNumber
                        updateSpotDropdownHighlight()
                        EventSystem.FireServer("ChangeDioramaSpot", currentDioramaId, spotNumber)
                    end
                end))
            end
        end
    end
    
    -- Все остальные кнопки кастомизации создаются динамически в updateCustomizationButtonsAvailability
end

-- Настраиваем все кнопки при открытии GUI
local function setupButtons()
    clearAllStaticConnections()   -- убираем старые обработчики
    
    if isOwner then
        setupOwnerButtons()
        setupCustomizationButtons()
    else
        setupBuyerButtons()
    end
    setupVotingButtons()
end

-- Таймер для обновления времени запрета покупки
local function startBanTimer()
	while true do
		task.wait(1)
		
		if currentDioramaId and purchaseGui.Enabled and currentDioramaData.OwnerId == player.UserId then
			-- Проверяем статус запрета
			local isBanned = currentDioramaData.IsPurchaseBanned or false
			local banEndTime = currentDioramaData.PurchaseBanEndTime or 0
			
			if isBanned and banEndTime > 0 then
				local remainingTime = banEndTime - os.time()
				
				if remainingTime <= 0 then
					-- Запрет истёк, обновляем данные
					local data = requestDioramaData(currentDioramaId)
					if data then
						currentDioramaData = data
						updateDioramaGUI(data)
					end
				else
					-- Обновляем только таймер
					updateOwnerFrame(currentDioramaData)
					updateBuyerFrame(currentDioramaData)
				end
			end
		end
	end
end

-- Обработка обновления накопленного дохода
if EventSystem then
	EventSystem.OnClient("DioramaIncomeUpdated", function(dioramaId, incomeData)
		if currentDioramaId == dioramaId and purchaseGui.Enabled and currentDioramaData.OwnerId == player.UserId then
			-- Обновляем только данные о накопленном доходе
			currentDioramaData.AccumulatedIncome = incomeData.AccumulatedIncome
			currentDioramaData.MaxAccumulatedIncome = incomeData.MaxAccumulatedIncome
			
			-- Обновляем фрейм владельца
			updateOwnerFrame(currentDioramaData)
		end
	end)
else
	warn("EventSystem недоступен для обработки DioramaIncomeUpdated")
end

-- Обработка результата покупки
if EventSystem then
	EventSystem.OnClient("PurchaseResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки PurchaseResult")
end

-- Обработка результата сбора дохода
if EventSystem then
	EventSystem.OnClient("CollectResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)
else
	warn("EventSystem недоступен для обработки CollectResult")
end

-- Обработка результата быстрой продажи
if EventSystem then
	EventSystem.OnClient("QuickSellResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки QuickSellResult")
end

-- Обработка результата установки GamePass
if EventSystem then
	EventSystem.OnClient("SetGamePassResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки SetGamePassResult")
end

-- Обработка результата удаления GamePass
if EventSystem then
	EventSystem.OnClient("RemoveGamePassResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки RemoveGamePassResult")
end

-- Обработка результата покупки через GamePass
if EventSystem then
	EventSystem.OnClient("PurchaseWithGamePassResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки PurchaseWithGamePassResult")
end

-- Обработка результата голосования
if EventSystem then
	EventSystem.OnClient("VoteResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки VoteResult")
end

-- Уведомление о продаже GamePass
if EventSystem then
	EventSystem.OnClient("GamePassSaleCompleted", function(dioramaId, robuxAmount)
		statusText.Text = string.format("✓ Ваша диорама продана за %d Robux!", robuxAmount)
		statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
	end)
else
	warn("EventSystem недоступен для обработки GamePassSaleCompleted")
end

-- Обработка результата смены места
if EventSystem then
	EventSystem.OnClient("ChangeSpotResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ChangeSpotResult")
end

-- Обработка результата смены рамки
if EventSystem then
	EventSystem.OnClient("ChangeFrameTypeResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ChangeFrameTypeResult")
end

-- Обработка результата смены стенда
if EventSystem then
	EventSystem.OnClient("ChangeStandTypeResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ChangeStandTypeResult")
end

-- Обработка результата смены цвета стены
if EventSystem then
	EventSystem.OnClient("ChangeWallColorResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ChangeWallColorResult")
end

-- Обработка результата смены материала стены
if EventSystem then
	EventSystem.OnClient("ChangeWallMaterialResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ChangeWallMaterialResult")
end

-- Обработка результата запрета покупки
if EventSystem then
	EventSystem.OnClient("BanPurchaseResult", function(success, message, banEndTime)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
			-- Обновляем данные диорамы
			if currentDioramaId then
				local data = requestDioramaData(currentDioramaId)
				if data then
					currentDioramaData = data
					updateDioramaGUI(data)
				end
			end
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки BanPurchaseResult")
end

-- Обработка результата увеличения времени запрета
if EventSystem then
	EventSystem.OnClient("ExtendBanResult", function(success, message, newBanEndTime)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
			-- Обновляем данные диорамы
			if currentDioramaId then
				local data = requestDioramaData(currentDioramaId)
				if data then
					currentDioramaData = data
					updateDioramaGUI(data)
				end
			end
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки ExtendBanResult")
end

-- Обработка результата добавления билетов
if EventSystem then
	EventSystem.OnClient("AddBanTicketsResult", function(success, message)
		if success then
			statusText.Text = "✓ " .. message
			statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
			-- Обновляем данные диорамы
			if currentDioramaId then
				local data = requestDioramaData(currentDioramaId)
				if data then
					currentDioramaData = data
					updateDioramaGUI(data)
				end
			end
		else
			statusText.Text = "✗ " .. message
			statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end)
else
	warn("EventSystem недоступен для обработки AddBanTicketsResult")
end

-- Открытие GUI при взаимодействии с диорамой
if EventSystem then
	EventSystem.OnClient("ShowDioramaGUI", function(dioramaId, data)
		currentDioramaId = dioramaId
		currentDioramaData = data

		-- Подписываемся на обновления
		EventSystem.FireServer("SubscribeToDiorama", dioramaId)

		updateDioramaGUI(data)
		setupButtons()

		-- Показываем GUI
		purchaseGui.Enabled = true
	end)
else
	warn("EventSystem недоступен для обработки ShowDioramaGUI")
end

-- Обработка обновления данных диорамы
if EventSystem then
	EventSystem.OnClient("DioramaDataUpdated", function(dioramaId, data)
		print(string.format("[DioramaClient] DioramaDataUpdated получено для %s, OwnerId: %s", 
			tostring(dioramaId), tostring(data.OwnerId)))
		
		if currentDioramaId == dioramaId and purchaseGui.Enabled then
			-- Обновляем данные с добавлением информации о доступном золоте
			local goldData = EventSystem.CallRPC("GetPlayerGold")
			data.AvailableGold = goldData or 0
			data.IsOwner = (data.OwnerId == player.UserId)
			
			-- Проверяем, изменился ли владелец
			local wasOwner = isOwner
			local nowOwner = data.IsOwner
			
			print(string.format("[DioramaClient] wasOwner: %s, nowOwner: %s", tostring(wasOwner), tostring(nowOwner)))
			
			-- Обновляем все данные
			for key, value in pairs(data) do
                currentDioramaData[key] = value
            end
			
			-- Обновляем GUI с новыми данными
			updateDioramaGUI(data)
			
			-- Если изменился статус владельца, перенастраиваем кнопки
			if wasOwner ~= nowOwner then
				print(string.format("[DioramaClient] Статус владельца изменился, перенастраиваем кнопки"))
				setupButtons()
			end

			-- Краткое уведомление
			statusText.Text = "✓ Данные обновлены"
			statusText.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.wait(1)
			if purchaseGui.Enabled then
				statusText.Text = ""
			end
		end
	end)
else
	warn("EventSystem недоступен для обработки DioramaDataUpdated")
end

-- Закрытие GUI
local function closeGUI()
    if currentDioramaId then
        EventSystem.FireServer("UnsubscribeFromDiorama", currentDioramaId)
        currentDioramaId = nil
        currentDioramaData = {}
    end
    purchaseGui.Enabled = false
    statusText.Text = ""
    -- Очищаем все подключения при закрытии GUI
    clearAllConnections()
end

closeButton.MouseButton1Click:Connect(closeGUI)

-- Обработка потери владения диорамой (покупка другим игроком)
if EventSystem then
	EventSystem.OnClient("DioramaOwnershipLost", function(dioramaId)
		print(string.format("[DioramaClient] DioramaOwnershipLost для %s", tostring(dioramaId)))
		
		-- Если это текущая открытая диорама, закрываем GUI
		if currentDioramaId == dioramaId and purchaseGui.Enabled then
			print("[DioramaClient] Закрываем GUI из-за потери владения")
			closeGUI()
			
			-- Показываем уведомление
			statusText.Text = "⚠ Диорама была продана другому игроку"
			statusText.TextColor3 = Color3.fromRGB(255, 150, 50)
			purchaseGui.Enabled = true
			task.wait(3)
			purchaseGui.Enabled = false
			statusText.Text = ""
		end
	end)
else
	warn("EventSystem недоступен для обработки DioramaOwnershipLost")
end

-- Закрытие по нажатию ESC
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.Escape and purchaseGui.Enabled then
            closeGUI()
        end
    end
end)

-- Закрытие при клике вне окна
mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = game:GetService("Players").LocalPlayer:GetMouse()
        local x, y = mouse.X, mouse.Y
        
        if x < mainFrame.AbsolutePosition.X or 
           x > mainFrame.AbsolutePosition.X + mainFrame.AbsoluteSize.X or
           y < mainFrame.AbsolutePosition.Y or 
           y > mainFrame.AbsolutePosition.Y + mainFrame.AbsoluteSize.Y then
            closeGUI()
        end
    end
end)

-- Запускаем таймер
task.spawn(startBanTimer)

-- Запрос начального золота через RPC
if EventSystem then
	local initialGold = EventSystem.CallRPC("GetPlayerGold")
	if initialGold then
        -- Золото получено, но не используется в этом скрипте
	end
else
	warn("EventSystem недоступен для получения начального золота")
end

-- Обработка покупки GamePass
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased and currentDioramaId and currentDioramaData.GamePassId == gamePassId then
		if EventSystem then
			EventSystem.FireServer("PurchaseDioramaWithGamePass", currentDioramaId)
		else
			warn("EventSystem недоступен для обработки покупки GamePass")
		end
	end
end)