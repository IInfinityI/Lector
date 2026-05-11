-- GoldAccumulationGui (LocalScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadingScreen = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingScreen"))
LoadingScreen.WaitForLoad()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Dialog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Dialog"))

local GoldAccumulationGui = PlayerGui:WaitForChild("GoldAccumulationGui")
GoldAccumulationGui.Enabled = false

-- Загрузка EventSystem
local EventSystem = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
EventSystem.Init()

-- Основные элементы GUI
local MainContainer = GoldAccumulationGui:WaitForChild("MainContainer")
local StoragePanel = MainContainer:WaitForChild("StoragePanel")
local DioramaList = MainContainer:WaitForChild("DioramaList")          -- ScrollingFrame со списком
local DioramaTemplate = DioramaList:WaitForChild("DioramaTemplate")    -- Template элемент
local TitleFrame = MainContainer:WaitForChild("Title")
local CloseButton = TitleFrame:WaitForChild("CloseButton")
local DioramaLimitLabel = TitleFrame:WaitForChild("DioramaLimit")

local isSubscribed = false
-- Элементы хранилища
local StorageProgressContainer = StoragePanel:WaitForChild("ProgressContainer")
local StorageProgressBarBg = StorageProgressContainer:WaitForChild("ProgressBarBg")
local StorageProgressBar = StorageProgressBarBg:WaitForChild("ProgressBarFill")
local StorageText = StorageProgressBarBg:WaitForChild("ProgressStats")
local StoragePercentage = StorageProgressBarBg:WaitForChild("ProgressPercent")
local StorageCollectButton = StorageProgressContainer:WaitForChild("CollectButton")
-- ================================================================

-- Локальные данные
local playerDioramas = {}          -- dioramaId -> { frame, data, updateProgress }
local dioramaSubscriptions = {}    -- dioramaId -> true
local playerData = {}              -- Хранит данные игрока (золото, накопленное, ёмкость и т.д.)
local dioramaLimitData = { current = 0, max = 6, canBuyMore = true }

-- Цвета для рамок в зависимости от редкости
local RarityColors = {
    Common = { Color1 = Color3.fromRGB(150, 150, 150), Color2 = Color3.fromRGB(200, 200, 200) },
    Uncommon = { Color1 = Color3.fromRGB(30, 255, 0), Color2 = Color3.fromRGB(140, 255, 150) },
    Rare = { Color1 = Color3.fromRGB(0, 100, 255), Color2 = Color3.fromRGB(100, 150, 255) },
    Epic = { Color1 = Color3.fromRGB(180, 0, 255), Color2 = Color3.fromRGB(220, 100, 255) },
    Legendary = { Color1 = Color3.fromRGB(255, 215, 0), Color2 = Color3.fromRGB(255, 255, 150) }
}

-- Обновление отображения лимита диорам
local function updateDioramaLimitDisplay()
    if not DioramaLimitLabel then return end
    local current = dioramaLimitData.current
    local max = dioramaLimitData.max
    DioramaLimitLabel.Text = string.format("%d/%d", current, max)
end

-- Запрос лимита диорам с сервера
local function fetchDioramaLimit()
    local result = EventSystem.CallRPC("GetDioramaLimit")
    if result then
        dioramaLimitData.current = result.current or 0
        dioramaLimitData.max = result.max or 6
        dioramaLimitData.canBuyMore = result.canBuyMore or false
        updateDioramaLimitDisplay()
    end
end

-- Функция для получения цвета рамки по редкости
local function getRarityStrokeColor(rarity)
    local rarityName = tostring(rarity or "Common")
    local colors = RarityColors[rarityName] or RarityColors.Common
    return colors.Color1
end

-- Функция для создания анимированной рамки (опционально)
local function setupRarityStroke(frame, rarity)
    local uiStroke = frame:FindFirstChild("UIStroke")
    if not uiStroke then
        uiStroke = Instance.new("UIStroke")
        uiStroke.Thickness = 2
        uiStroke.Parent = frame
    end
    
    -- Устанавливаем цвет в зависимости от редкости
    uiStroke.Color = getRarityStrokeColor(rarity)
end



-- Ссылка на GoldDisplay в TopBar
local TopBarGoldDisplay = PlayerGui:WaitForChild("TopBar"):WaitForChild("GoldDisplay")
local TopBarGoldText = TopBarGoldDisplay:WaitForChild("GoldText")

-- Ссылка на кнопку золота в TopBar
local TopBarLeftButtons = PlayerGui:WaitForChild("TopBar"):WaitForChild("LeftButtons")
local GoldTopBarButton = TopBarLeftButtons:WaitForChild("GoldButton")

-- Функция форматирования чисел для GoldDisplay
local function formatGoldNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(math.floor(num))
end

-- Подписка на изменение золота из SavedData
local function subscribeToSavedDataGold()
	task.spawn(function()
		local savedData = Player:FindFirstChild("SavedData")
		if not savedData then
			savedData = Player:WaitForChild("SavedData", 30)
		end

		if not savedData then
			warn("[GoldGUI] SavedData not found for gold subscription")
			return
		end

		local goldValue = savedData:FindFirstChild("Gold")
		if not goldValue then
			goldValue = savedData:WaitForChild("Gold", 30)
		end

		if not goldValue then
			warn("[GoldGUI] Gold not found in SavedData")
			return
		end

		-- Устанавливаем начальное значение
		if TopBarGoldText then
			TopBarGoldText.Text = formatGoldNumber(goldValue.Value)
		end

		-- Подписываемся на изменения
		goldValue.Changed:Connect(function(newValue)
			if TopBarGoldText then
				TopBarGoldText.Text = formatGoldNumber(newValue)
			end
		end)
	end)
end

-- Обновление прогресса накопления золота игрока
local function updateStorageProgress(accumulated, capacity)
    if not StorageProgressBar or not StorageText or not StoragePercentage then return end
    
    local percent = capacity > 0 and math.min(accumulated / capacity, 1) or 0
    StorageProgressBar.Size = UDim2.new(percent, 0, 1, 0)
    StorageText.Text = string.format("%d / %d", accumulated, capacity)
    StoragePercentage.Text = string.format("%.1f%%", percent * 100)
    
    -- Меняем цвет в зависимости от заполнения
    if percent >= 0.9 then
        StorageProgressBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Красный (почти полон)
    elseif percent >= 0.6 then
        StorageProgressBar.BackgroundColor3 = Color3.fromRGB(255, 170, 0) -- Оранжевый
    else
        StorageProgressBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255) -- Синий
    end
end

-- Полное обновление GUI игрока (золото + хранилище + статистика)
local function updateGoldGUI(guiData)
    if not guiData then return end
        
    playerData = guiData
    updateStorageProgress(guiData.accumulatedGold or 0, guiData.storageCapacity or 1000)

end
-- ================================================================

-- Создание элемента для одной диорамы
local function createDioramaElement(dioramaId, data)
    local frame = DioramaTemplate:Clone()
    frame.Name = dioramaId
    frame.Visible = true
    frame.Parent = DioramaList

    -- Поиск дочерних элементов по новой структуре
    local topBlock = frame:FindFirstChild("TopBlock")
    local middleBlock = frame:FindFirstChild("MiddleBlock")
    
    local dioramaName = topBlock and topBlock:FindFirstChild("DioramaName")
    local collectionName = topBlock and topBlock:FindFirstChild("CollectionName")
    
    local progressBarBg = middleBlock and middleBlock:FindFirstChild("ProgressBarBg")
    local progressFill = progressBarBg and progressBarBg:FindFirstChild("ProgressBarFill")
    local progressStats = progressBarBg and progressBarBg:FindFirstChild("ProgressStats")
    local progressPercent = progressBarBg and progressBarBg:FindFirstChild("ProgressPercent")
    local collectButton = middleBlock and middleBlock:FindFirstChild("CollectButton")

    -- Установка названия диорамы
    if dioramaName then
        dioramaName.Text = data.SceneName or "Diorama"
    end

    -- Установка названия коллекции
    if collectionName then
        collectionName.Text = data.CollectionName or "Collection"
    end

    -- Установка цвета рамки в зависимости от редкости
    setupRarityStroke(frame, data.Rarity)

    -- Создаём запись для диорамы
    local entry = {
        frame = frame,
        data = data,
    }

    -- Функция обновления прогресса, использующая актуальные данные из entry.data
    function entry.updateProgress()
        local accumulated = entry.data.AccumulatedIncome or 0
        local maxCapacity = entry.data.MaxAccumulatedIncome or 1
        local percent = math.min(accumulated / maxCapacity, 1)

        if progressFill then
            progressFill.Size = UDim2.new(percent, 0, 1, 0)
        end
        if progressStats then
            progressStats.Text = string.format("%d / %d", accumulated, maxCapacity)
        end
        if progressPercent then
            progressPercent.Text = string.format("%.1f%%", percent * 100)
        end
    end
    entry.updateProgress()

    -- Кнопка сбора
    if collectButton then
        collectButton.MouseButton1Click:Connect(function()
            EventSystem.FireServer("CollectIncome", dioramaId, "AccumGui")
        end)
    end

    -- Сохраняем элемент
    playerDioramas[dioramaId] = entry

    return frame
end

-- Удаление элемента диорамы
local function removeDioramaElement(dioramaId)
    local entry = playerDioramas[dioramaId]
    if entry and entry.frame then
        -- Останавливаем анимацию, если она была
        local tween = entry.frame:GetAttribute("RarityTween")
        if tween then
            tween:Cancel()
        end
        entry.frame:Destroy()
    end
    playerDioramas[dioramaId] = nil

    -- Отписываемся от обновлений
    if dioramaSubscriptions[dioramaId] then
        EventSystem.FireServer("UnsubscribeFromDiorama", dioramaId)
        dioramaSubscriptions[dioramaId] = nil
    end
end

-- Функция подписки на обновления
local function subscribeToGoldGUI()
    if not isSubscribed then
        EventSystem.FireServer("SubscribeToGoldGUI")
        isSubscribed = true
        print("[GoldGUI] Subscribed to updates")
    end
end

-- Обновление существующего элемента
local function updateDioramaElement(dioramaId, data)
    local entry = playerDioramas[dioramaId]
    if entry then
        entry.data = data      -- заменяем данные на новые
        entry.updateProgress() -- обновляем отображение

        -- Обновляем названия, если изменились
        local topBlock = entry.frame and entry.frame:FindFirstChild("TopBlock")
        if topBlock then
            local dioramaName = topBlock:FindFirstChild("DioramaName")
            local collectionName = topBlock:FindFirstChild("CollectionName")
            
            if dioramaName and data.SceneName then
                dioramaName.Text = data.SceneName
            end
            if collectionName and data.CollectionName then
                collectionName.Text = data.CollectionName
            end
        end
        
        -- Обновляем цвет рамки, если изменилась редкость
        if data.Rarity then
            setupRarityStroke(entry.frame, data.Rarity)
        end
    end
end

-- Функция отписки от обновлений
local function unsubscribeFromGoldGUI()
    if isSubscribed then
        EventSystem.FireServer("UnsubscribeFromGoldGUI")
        isSubscribed = false
        GoldAccumulationGui.Enabled = false
        print("[GoldGUI] Unsubscribed from updates")
    end
end

-- Запрос списка диорам игрока с сервера
local function fetchPlayerDioramas()
    local result = EventSystem.CallRPC("GetPlayerDioramas")
    if result then
        -- Собираем множество актуальных ID (в числовом виде)
        local actualIds = {}
        for dioramaIdStr, data in pairs(result) do
            local dioramaId = tonumber(dioramaIdStr)
            actualIds[dioramaId] = true
            
            if playerDioramas[dioramaId] then
                updateDioramaElement(dioramaId, data)
            else
                createDioramaElement(dioramaId, data)
            end
            EventSystem.FireServer("SubscribeToDiorama", dioramaId)
            dioramaSubscriptions[dioramaId] = true
        end

        -- Удаляем диорамы, которых больше нет на сервере
        for dioramaId, _ in pairs(playerDioramas) do
            if not actualIds[dioramaId] then
                removeDioramaElement(dioramaId)
            end
        end
        
        -- Обновляем лимит диорам после обновления списка
        fetchDioramaLimit()
    else
        warn("[GoldGUI] Failed to get diorama list:", result)
    end
end

-- Отписка от всех диорам
local function unsubscribeFromAllDioramas()
    for dioramaId, _ in pairs(dioramaSubscriptions) do
        EventSystem.FireServer("UnsubscribeFromDiorama", dioramaId)
    end
    dioramaSubscriptions = {}
    
    -- Останавливаем все анимации при отписке
    for dioramaId, entry in pairs(playerDioramas) do
        local tween = entry.frame:GetAttribute("RarityTween")
        if tween then
            tween:Cancel()
        end
    end
end

-- Обработчики событий от сервера

-- Обновление золота (и других данных игрока)
EventSystem.OnClient("GoldGUIUpdate", function(guiData)
    updateGoldGUI(guiData)
end)

-- Начальные данные золота
EventSystem.OnClient("GoldGUIInitialData", function(guiData)
    GoldAccumulationGui.Enabled = true
    isSubscribed = true
    updateGoldGUI(guiData)
end)

-- Полное обновление данных диорамы
EventSystem.OnClient("DioramaDataUpdated", function(dioramaId, data)
    if data.OwnerId == Player.UserId then
        -- Диорама принадлежит игроку
        if playerDioramas[dioramaId] then
            updateDioramaElement(dioramaId, data)
        else
            createDioramaElement(dioramaId, data)
            EventSystem.FireServer("SubscribeToDiorama", dioramaId)
            dioramaSubscriptions[dioramaId] = true
        end
    else
        -- Диорама больше не принадлежит игроку
        if playerDioramas[dioramaId] then
            removeDioramaElement(dioramaId)
        end
    end
    -- Обновляем лимит диорам при любом изменении владения
    fetchDioramaLimit()
end)

-- Обновление только накопленного дохода
EventSystem.OnClient("DioramaIncomeUpdated", function(dioramaId, incomeData)
    local entry = playerDioramas[dioramaId]
    if entry then
        entry.data.AccumulatedIncome = incomeData.AccumulatedIncome
        entry.data.MaxAccumulatedIncome = incomeData.MaxAccumulatedIncome
        entry.updateProgress()
    end
end)

-- Результат покупки диорамы
EventSystem.OnClient("PurchaseResult", function(success, message)
    if success then
        fetchDioramaLimit()
    end
end)

-- Результат сбора
EventSystem.OnClient("CollectResult", function(success, message)
    if not success then
        Dialog.show({type = "error", title = "Collection Error", message = message})
    end
end)

-- Результат сбора с бонусами (для обратной совместимости)
EventSystem.OnClient("GoldCollected", function(amount, bonuses)
    -- Gold collected successfully
end)

-- Результат быстрой продажи
EventSystem.OnClient("QuickSellResult", function(success, message)
    if success then
        fetchDioramaLimit()
    else
        Dialog.show({type = "error", title = "Quick Sell Error", message = message})
    end
end)

-- Результат установки GamePass
EventSystem.OnClient("SetGamePassResult", function(success, message)
    if not success then
        Dialog.show({type = "error", title = "GamePass Error", message = message})
    end
end)

-- Результат удаления GamePass
EventSystem.OnClient("RemoveGamePassResult", function(success, message)
    if not success then
        Dialog.show({type = "error", title = "Remove GamePass Error", message = message})
    end
end)

-- Результат покупки через GamePass
EventSystem.OnClient("PurchaseWithGamePassResult", function(success, message)
    if success then
        fetchDioramaLimit()
    else
        Dialog.show({type = "error", title = "Purchase Error", message = message})
    end
end)

-- Результат голосования
EventSystem.OnClient("VoteResult", function(success, message)
    if not success then
        Dialog.show({type = "error", title = "Vote Error", message = message})
    end
end)

-- Уведомление о продаже GamePass
EventSystem.OnClient("GamePassSaleCompleted", function(dioramaId, robuxAmount)
    -- GamePass sale completed successfully
end)

-- Уведомление о получении отложенного золота (накопленный доход с проданной диорамы)
EventSystem.OnClient("PendingGoldReceived", function(data)
    -- Обновляем список диорам, если GUI открыт
    if GoldAccumulationGui.Enabled then
        fetchPlayerDioramas()
    end
end)

-- Показ уведомление
EventSystem.OnClient("ShowDialogGUI", function(inType, inTitle, inMessage)
    Dialog:Show({
        type = inType,
        title = inTitle,
        message = inMessage
    })
end)

EventSystem.OnClient("GamepassOfferByName", function(inName, inMessage)
    Dialog:Show({
        type = "confirm",
        title = "Confirmation",
        message = inMessage,
        onConfirm = function()
            EventSystem.FireServer("PurchaseGamePass", inName)
        end
    })
end)

-- Кнопка сбора из хранилища
StorageCollectButton.MouseButton1Click:Connect(function()
    EventSystem.FireServer("CollectGold")
end)

-- Кнопка закрытия
CloseButton.MouseButton1Click:Connect(function()
    unsubscribeFromGoldGUI()
    unsubscribeFromAllDioramas()
    GoldAccumulationGui.Enabled = false
end)

-- Кнопка золота в TopBar
GoldTopBarButton.MouseButton1Click:Connect(function()
    if GoldAccumulationGui.Enabled then
        unsubscribeFromGoldGUI()
        unsubscribeFromAllDioramas()
        GoldAccumulationGui.Enabled = false
    else
        subscribeToGoldGUI()
        GoldAccumulationGui.Enabled = true
        fetchDioramaLimit()
        fetchPlayerDioramas()
    end
end)

-- Открытие/закрытие по клавише E
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        if GoldAccumulationGui.Enabled then
            unsubscribeFromGoldGUI()
            unsubscribeFromAllDioramas()
            GoldAccumulationGui.Enabled = false
        else
            subscribeToGoldGUI()
            GoldAccumulationGui.Enabled = true
            fetchDioramaLimit()
            fetchPlayerDioramas()
        end
    end
end)

-- Отписка при выходе
Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        unsubscribeFromGoldGUI()
        unsubscribeFromAllDioramas()
    end
end)

-- Инициализация подписки на золото из SavedData
subscribeToSavedDataGold()

print("[GoldGUI] Client script loaded")