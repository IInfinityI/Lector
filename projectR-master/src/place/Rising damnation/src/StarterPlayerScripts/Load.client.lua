wait(10)-- исправить

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local currentHumanoid = nil
local currentRootPart = nil
local maxJumps = 1
local currentJumps = maxJumps
local lastJumpTime = 0
local jumpCooldown = 0.3 -- Задержка между прыжками в секундах

-- Флаг для отслеживания нажатия пробела
local isJumping = false

-- Обработчик ввода с клавиатуры
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        if isJumping then return end -- Предотвращаем множественные вызовы
        isJumping = true
        
        if not currentHumanoid or not currentRootPart then
            isJumping = false
            return
        end
        
        -- Проверяем кулдаун
        local currentTime = tick()
        if currentTime - lastJumpTime < jumpCooldown then
            isJumping = false
            return
        end
        
        -- Проверяем, стоит ли персонаж на земле для сброса прыжков
        if currentHumanoid:GetState() == Enum.HumanoidStateType.Landed or currentHumanoid.FloorMaterial ~= Enum.Material.Air then
            currentJumps = maxJumps
        end
        
        if currentJumps > 0 then
            currentJumps = currentJumps - 1
            lastJumpTime = currentTime
            
            if currentJumps == maxJumps - 1 then
                -- Первый прыжок (со земли) обрабатывается автоматически
                currentHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            else
                local jumpPower = math.sqrt(2 * workspace.Gravity * currentHumanoid.JumpHeight)
                local currentVelocity = currentRootPart.Velocity
                currentRootPart.Velocity = Vector3.new(currentVelocity.X, jumpPower, currentVelocity.Z)
            end
        end
        
        isJumping = false
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        isJumping = false
    end
end)

-- Функция для настройки системы прыжков
local function setupJumpsSystem(humanoid, rootPart)
    currentHumanoid = humanoid
    currentRootPart = rootPart
    currentJumps = maxJumps

    local stateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            currentJumps = maxJumps
        end
    end)

    humanoid.Died:Connect(function()
        stateConnection:Disconnect()
        currentHumanoid = nil
        currentRootPart = nil
    end)
end

-- Остальной код скрипта
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventSystem = require(ReplicatedStorage.Assets:WaitForChild("EventSystem"))

-- Получаем элементы UI магазина
local shopUI = PlayerGui:WaitForChild("ShopGui")
local mainFrame = shopUI:WaitForChild("MainFrame")
local shopFrame = mainFrame:WaitForChild("Shop")
local tabButtons = shopFrame:WaitForChild("TabButtons")
local itemsScrollingFrame = shopFrame:WaitForChild("ItemsScrollingFrame")
local itemTemplate = itemsScrollingFrame:WaitForChild("ItemTemplate")
local detailFrame = shopFrame:WaitForChild("DetailFrame")
local detailTitle = detailFrame:WaitForChild("ItemTitle")
local detailDescription = detailFrame:WaitForChild("ItemDescription")
local actionButton = detailFrame:WaitForChild("ActionButton")
local closeButton = shopFrame:WaitForChild("CloseButton")

-- Получаем элементы UI улучшений
local upgradeUI = PlayerGui:WaitForChild("UpgradeGui")
local upgradeFrame = upgradeUI:WaitForChild("MainFrame"):WaitForChild("UpgradeFrame")
local upgradeItemTemplate = upgradeFrame:WaitForChild("ItemTemplate")
local upgradeCloseButton = upgradeUI:WaitForChild("MainFrame"):WaitForChild("CloseButton")

-- Кэш для фреймов предметов и текущее состояние
local itemFramesCache = {}
local upgradeFramesCache = {}
local currentTab = "Boots"
local selectedItem = nil

-- Функция для клонирования шаблона предмета
local function cloneItemTemplate()
    local newItem = itemTemplate:Clone()
    newItem.Visible = true
    return newItem
end

-- Функция для клонирования шаблона улучшения
local function cloneUpgradeTemplate()
    local newItem = upgradeItemTemplate:Clone()
    newItem.Visible = true
    return newItem
end

-- Очистка всех созданных фреймов магазина
local function clearItems()
    for _, frame in ipairs(itemFramesCache) do
        frame:Destroy()
    end
    itemFramesCache = {}
end

-- Очистка всех созданных фреймов улучшений
local function clearUpgradeItems()
    for _, frame in ipairs(upgradeFramesCache) do
        frame:Destroy()
    end
    upgradeFramesCache = {}
end

-- Обновление состояния кнопки действия
local function updateActionButton(itemState)
    actionButton.Visible = true
    
    if itemState == "not_owned" then
        actionButton.Text = "Купить ("..(selectedItem and selectedItem.cost or 0)..")"
        actionButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0) -- Зеленый для покупки
    elseif itemState == "can_equip" then
        actionButton.Text = "Экипировать"
        actionButton.BackgroundColor3 = Color3.fromRGB(0, 100, 255) -- Синий для экипировки
    else
        actionButton.Text = "Снять"
        actionButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0) -- Красный для снятия
    end
end

-- Обновление списка предметов магазина
local function updateItemsList(shopData)
    clearItems() -- Очищаем предыдущие предметы
    
    local items = shopData[currentTab] or {}
    
    for i, item in ipairs(items) do
        local itemFrame = cloneItemTemplate()
        itemFrame.Name = "Item_"..i
        
        -- Заполняем данные
        itemFrame.ItemImage.Image = item.imageId or ""
        itemFrame.ItemName.Text = item.name or "No name"
        itemFrame.ItemPrice.Text = "Цена: "..(item.cost or 0)
        
        -- Обработчик клика
        itemFrame.ItemButton.MouseButton1Click:Connect(function()
            selectedItem = item
            detailTitle.Text = item.name
            detailDescription.Text = item.description or "Описание отсутствует"
            
            -- Запрашиваем состояние предмета у сервера
            local itemState = EventSystem.CallRPC("GetAccessoryState", item.name)
            updateActionButton(itemState)
        end)
        
        itemFrame.Parent = itemsScrollingFrame
        table.insert(itemFramesCache, itemFrame)
    end
end

-- Обновление списка предметов для улучшения
local function updateUpgradeList(equippedUpgrades)
    clearUpgradeItems() -- Очищаем предыдущие предметы
    
    if #equippedUpgrades == 0 then
        local noItemsLabel = Instance.new("TextLabel")
        noItemsLabel.Size = UDim2.new(1, -20, 0, 50)
        noItemsLabel.BackgroundTransparency = 1
        noItemsLabel.Text = "Нет экипированных предметов для улучшения"
        noItemsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        noItemsLabel.TextSize = 18
        noItemsLabel.Parent = upgradeFrame
        table.insert(upgradeFramesCache, noItemsLabel)
        return
    end
    
    for i, item in ipairs(equippedUpgrades) do
        local itemFrame = cloneUpgradeTemplate()
        itemFrame.Name = "UpgradeItem_"..i
        itemFrame.LayoutOrder = i
        
        -- Заполняем заголовок
        itemFrame.ItemHeader.ItemImage.Image = item.imageId or ""
        itemFrame.ItemHeader.ItemName.Text = item.name or "No name"
        itemFrame.ItemHeader.ItemCategory.Text = item.category or "No category"
        
        -- Очищаем контейнер модификаторов
        local modifiersContainer = itemFrame.ModifiersFrame
        for _, child in ipairs(modifiersContainer:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "ModifierTemplate" then
                child:Destroy()
            end
        end
        
        -- Добавляем модификаторы
        if item.modifiers then
            for j, modifier in ipairs(item.modifiers) do
                local modifierFrame = modifiersContainer.ModifierTemplate:Clone()
                modifierFrame.Name = "Modifier_"..j
                modifierFrame.Visible = true
                
                -- Определяем текущий уровень и максимальный уровень
                local currentLevel = modifier.initial or 1
                local maxLevel = modifier.maxLevel or 1
                
                -- Форматируем значение в зависимости от типа операции
                local currentValue = modifier.values and modifier.values[currentLevel] or 0
                local maxValue = modifier.values and modifier.values[maxLevel] or 0
                
                local valueText = ""
                if modifier.operation == "Add" then
                    valueText = string.format("+%d / +%d", currentValue, maxValue)
                elseif modifier.operation == "MultiplyTotal" then
                    valueText = string.format("x%.2f / x%.2f", currentValue, maxValue)
                else
                    valueText = string.format("%d / %d", currentValue, maxValue)
                end
                
                -- Заполняем данные модификатора
                modifierFrame.ModifierName.Text = modifier.type .. ":"
                modifierFrame.ModifierValue.Text = valueText
                
                -- Настраиваем кнопку улучшения
                local upgradeButton = modifierFrame.UpgradeButton
                if currentLevel < maxLevel then
                    local upgradeCost = modifier.upgradeCost and modifier.upgradeCost[currentLevel] or 0
                    upgradeButton.Text = "Улучшить (" .. upgradeCost .. ")"
                    upgradeButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
                    
                    -- Обработчик клика на кнопку улучшения
                    upgradeButton.MouseButton1Click:Connect(function()
                        EventSystem.FireServer("UpgradeAccessory", item.name, modifier.type)
                        
                        -- Обновляем список после улучшения
                        task.wait(0.5) -- Ждем обновления на сервере
                        local newUpgrades = EventSystem.CallRPC("GetEquippedUpgradesInfo")
                        updateUpgradeList(newUpgrades)
                    end)
                else
                    upgradeButton.Text = "Макс. уровень"
                    upgradeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    upgradeButton.AutoButtonColor = false
                end
                
                modifierFrame.Parent = modifiersContainer
            end
        end
        
        itemFrame.Parent = upgradeFrame
        table.insert(upgradeFramesCache, itemFrame)
    end
end

-- Инициализация вкладок магазина
local function initTabs()
    for _, tabBtn in ipairs(tabButtons:GetChildren()) do
        if tabBtn:IsA("TextButton") then
            tabBtn.MouseButton1Click:Connect(function()
                currentTab = tabBtn.Name:gsub("Tab", "")
                -- Обновляем стиль кнопок
                for _, btn in ipairs(tabButtons:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = btn == tabBtn and Color3.fromRGB(80, 80, 80) 
                                               or Color3.fromRGB(60, 60, 60)
                    end
                end
                -- Обновляем список
                local shopData = EventSystem.CallRPC("GetShopData")
                updateItemsList(shopData)
            end)
        end
    end
end

-- Инициализация UI магазина
local function initShopUI()
    -- Настройка видимости
    shopUI.Enabled = false
    itemTemplate.Visible = false
    actionButton.Visible = false
    
    -- Активируем первую вкладку
    local firstTab = tabButtons:FindFirstChildOfClass("TextButton")
    if firstTab then
        firstTab.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    
    -- Инициализируем вкладки
    initTabs()
    
    -- Настройка кнопок магазина
    closeButton.MouseButton1Click:Connect(function()
        shopUI.Enabled = false
    end)
    
    actionButton.MouseButton1Click:Connect(function()
        if not selectedItem then return end
        
        -- Запрашиваем текущее состояние предмета
        local itemState = EventSystem.CallRPC("GetAccessoryState", selectedItem.name)
        
        if itemState == "not_owned" then
            -- Покупка предмета
            EventSystem.FireServer("BuyAccessory", selectedItem.name)
        elseif itemState == "can_equip" then
            -- Экипировка предмета
            EventSystem.FireServer("EquipAccessory", selectedItem.name)
        else
            -- Снятие предмета
            EventSystem.FireServer("UnequipAccessory", selectedItem.name)
        end
        
        -- Обновляем состояние кнопки после действия
        local newState = EventSystem.CallRPC("GetAccessoryState", selectedItem.name)
        updateActionButton(newState)
    end)
end

-- Инициализация UI улучшений
local function initUpgradeUI()
    -- Настройка видимости
    upgradeUI.Enabled = false
    upgradeItemTemplate.Visible = false
    
    -- Настройка кнопки закрытия улучшений
    upgradeCloseButton.MouseButton1Click:Connect(function()
        upgradeUI.Enabled = false
    end)
end

-- Функция для применения эффектов к гуманоиду игрока
local function setupCharacterStats(player)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local computedData = player:WaitForChild("ComputedData")
    
    if not computedData then
        warn("ComputedData не найден у игрока: " .. player.Name)
        return
    end

    local function getNestedValue(folderName, valueName)
        local folder = computedData:WaitForChild(folderName)
        if not folder then return nil end

        local valueObject = folder:WaitForChild(valueName)
        if valueObject and valueObject:IsA("NumberValue") then
            return valueObject.Value
        end
        return nil
    end

    local function connectNestedValue(folderName, valueName, callback)
        local folder = computedData:WaitForChild(folderName)
        if not folder then return nil end

        local valueObject = folder:WaitForChild(valueName)
        if valueObject and valueObject:IsA("NumberValue") then
            return valueObject.Changed:Connect(callback)
        end
        return nil
    end

    -- Функция для обновления количества прыжков
    local function updateJumpsNumber(newValue)
        maxJumps = newValue
        if humanoid:GetState() == Enum.HumanoidStateType.Landed then
            currentJumps = maxJumps
        end
    end

    -- Функция для обновления размера магнита
    local function updateSphereSize(newValue)
        -- Ищем аксессуар "magnet" в персонаже
        local magnetAccessory = character:FindFirstChild("Magnet")
        
        if magnetAccessory and magnetAccessory:IsA("Accessory") then
            local handle = magnetAccessory:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                -- Сохраняем оригинальный размер, если еще не сохранен
                if not handle:GetAttribute("OriginalSize") then
                    handle:SetAttribute("OriginalSize", handle.Size)
                end
                
                -- Устанавливаем новый размер
                local scale = newValue / 10 -- Предполагаем, что base=10 соответствует нормальному размеру
                local originalSize = handle:GetAttribute("OriginalSize") or Vector3.new(1, 1, 1)
                handle.Size = originalSize * scale
            end
        end
    end

    local function updateHumanoidStats()
        local jumpHeight = getNestedValue("JumpHeight", "CurrentValue")
        local movementSpeed = getNestedValue("MovementSpeed", "CurrentValue")
        local jumpsNumber = getNestedValue("JumpsNumber", "CurrentValue")
        local sphereSize = getNestedValue("SphereSize", "CurrentValue")

        if jumpHeight then
            humanoid.JumpHeight = jumpHeight
        end

        if movementSpeed then
            humanoid.WalkSpeed = movementSpeed
        end

        if jumpsNumber then
            updateJumpsNumber(jumpsNumber)
        end

        if sphereSize then
            updateSphereSize(sphereSize)
        end
    end

    local connections = {}

    -- Подключаем обработчики изменений для всех параметров
    local jumpHeightConnection = connectNestedValue("JumpHeight", "CurrentValue", function(newValue)
        humanoid.JumpHeight = newValue
    end)
    if jumpHeightConnection then
        table.insert(connections, jumpHeightConnection)
    end

    local movementSpeedConnection = connectNestedValue("MovementSpeed", "CurrentValue", function(newValue)
        humanoid.WalkSpeed = newValue
    end)
    if movementSpeedConnection then
        table.insert(connections, movementSpeedConnection)
    end

    local jumpsNumberConnection = connectNestedValue("JumpsNumber", "CurrentValue", function(newValue)
        updateJumpsNumber(newValue)
    end)
    if jumpsNumberConnection then
        table.insert(connections, jumpsNumberConnection)
    end

    local sphereSizeConnection = connectNestedValue("SphereSize", "CurrentValue", function(newValue)
        updateSphereSize(newValue)
    end)
    if sphereSizeConnection then
        table.insert(connections, sphereSizeConnection)
    end

    -- Настраиваем систему прыжков
    setupJumpsSystem(humanoid, rootPart)

    -- Инициализируем начальные значения
    updateHumanoidStats()

    -- Обработчик смерти персонажа
    humanoid.Died:Connect(function()
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        table.clear(connections)
    end)

    -- Обработчик появления нового персонажа
    player.CharacterAdded:Connect(function(newCharacter)
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        table.clear(connections)
        
        setupCharacterStats(player)
    end)
end

local function waitForDataLoaded(player)
    while not player:GetAttribute("DataLoaded") do
        player:GetAttributeChangedSignal("DataLoaded"):Wait()
    end
    return true
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        waitForDataLoaded(player)
        setupCharacterStats(player)
    end)

    if player.Character then
        waitForDataLoaded(player)
        setupCharacterStats(player)
    end
end

local function setupExistingPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(onPlayerAdded, player)
    end
end

-- Обработчик открытия магазина
EventSystem.OnClient("OpenShopUI", function()
    local shopData = EventSystem.CallRPC("GetShopData")
    if shopData then
        updateItemsList(shopData)
        shopUI.Enabled = true
    else
        warn("Не удалось получить данные магазина")
    end
end)

-- Обработчик открытия UI улучшений
EventSystem.OnClient("OpenUpgradeUI", function()
    local equippedUpgrades = EventSystem.CallRPC("GetEquippedUpgradesInfo")
    updateUpgradeList(equippedUpgrades)
    upgradeUI.Enabled = true
end)

-- Функция для получения случайной позиции в пределах экрана
function getRandomPosition(textLabel, parentFrame)
    local labelSize = textLabel.AbsoluteSize
    local parentSize = parentFrame.AbsoluteSize
    
    -- Вычисляем допустимые границы
    local maxX = math.max(0, parentSize.X - labelSize.X)
    local maxY = math.max(0, parentSize.Y - labelSize.Y)
    
    -- Генерируем случайные позиции
    local randomX = math.random(0, maxX)
    local randomY = math.random(0, maxY)
    
    return UDim2.new(0, randomX, 0, randomY)
end

EventSystem.OnClient("ShowEssenceCollection", function(rarityName, amount)
    local essenceGui = PlayerGui:WaitForChild("NewEssenceGui")
    local mainFrame = essenceGui:WaitForChild("MainFrame")
    local template = mainFrame:FindFirstChild("Template")

    local rarityColors = {
        Common = Color3.fromRGB(200, 200, 200),
        Incommon = Color3.fromRGB(100, 200, 100),
        Rare = Color3.fromRGB(100, 100, 255),
        Epic = Color3.fromRGB(170, 0, 255),
        Legendary = Color3.fromRGB(255, 128, 0),
        Mythical = Color3.fromRGB(255, 50, 50)
    }
    
    if not template then return end
    local textLabel = template:Clone()
    textLabel.Name = "EssenceText"
    textLabel.Text = "+" .. amount .. " " .. rarityName .. " Essence"
    textLabel.TextColor3 = rarityColors[rarityName] or Color3.fromRGB(255, 255, 255)
    textLabel.Rotation = math.random(-10, 10) -- Случайный небольшой наклон
    textLabel.Parent = mainFrame
    textLabel.Position = getRandomPosition(textLabel, mainFrame)
    textLabel.Visible = true

    local tweenService = game:GetService("TweenService")
    local appearInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local disappearInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    textLabel.TextTransparency = 1
    textLabel.Position = textLabel.Position + UDim2.new(0, 0, 0, -20)
    
    local appearTween = tweenService:Create(textLabel, appearInfo, {
        TextTransparency = 0,
        Position = textLabel.Position + UDim2.new(0, 0, 0, 20)
    })
    
    local disappearTween = tweenService:Create(textLabel, disappearInfo, {
        TextTransparency = 1,
        Position = textLabel.Position + UDim2.new(0, 0, 0, -40)
    })
    
    appearTween:Play()
    appearTween.Completed:Connect(function()
        wait(1)
        disappearTween:Play()
        disappearTween.Completed:Connect(function()
            textLabel:Destroy()
        end)
    end)
end)

-- Обработчик уведомлений о перегрузке
EventSystem.OnClient("ShowOverloadNotification", function(isOverloaded)
    local essenceGui = PlayerGui:WaitForChild("OverloadNotification")
    local mainFrame = essenceGui:WaitForChild("MainFrame")
    local textLabel = mainFrame:FindFirstChild("TextLabel")
    
    if isOverloaded then
        -- Анимация тряски при попытке сбора при перегрузке
        local shakeIntensity = 8
        local shakeDuration = 0.3
        local originalPosition = textLabel.Position
        
        -- Показываем сообщение
        textLabel.Visible = true
        
        -- Анимация тряски
        local tweenService = game:GetService("TweenService")
        local shakeInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        
        for i = 1, 6 do
            local offset = math.random(-shakeIntensity, shakeIntensity)
            tweenService:Create(textLabel, shakeInfo, {
                Position = originalPosition + UDim2.new(0, offset, 0, 0)
            }):Play()
            wait(0.05)
        end
        
        tweenService:Create(textLabel, shakeInfo, {
            Position = originalPosition
        }):Play()
    else
        -- Скрываем сообщение при нормализации веса
        textLabel.Visible = false
    end
end)

local function setupCurrencyUI(player)
    local PlayerGui = player:WaitForChild("PlayerGui")
    
    -- Получаем готовый GUI из StarterGui (предполагаем, что он уже там есть)
    local currencyGui = PlayerGui:WaitForChild("CurrencyGui")
    local mainFrame = currencyGui:WaitForChild("MainFrame")
    
    -- Таблица для хранения текстовых лейблов каждой валюты
    local currencyLabels = {}
    
    -- Список валют и соответствующих им лейблов
    local currencies = {
        CommonEssence = mainFrame:WaitForChild("CommonEssence"),
        IncommonEssence = mainFrame:WaitForChild("IncommonEssence"),
        RareEssence = mainFrame:WaitForChild("RareEssence"),
        EpicEssence = mainFrame:WaitForChild("EpicEssence"),
        LegendaryEssence = mainFrame:WaitForChild("LegendaryEssence"),
        MythicalEssence = mainFrame:WaitForChild("MythicalEssence"),
        Coins = mainFrame:WaitForChild("Coins")
    }
    
    -- Функция для обновления значения валюты
    local function updateCurrencyValue(currencyName, value)
        if currencies[currencyName] then
            currencies[currencyName]:FindFirstChild("Value").Text = tostring(value)
        end
    end
    
    -- Функция для подключения к изменениям значений
    local function connectToCurrencyChanges()
        local savedData = player:WaitForChild("SavedData")
        
        for currencyName, label in pairs(currencies) do
            local valueObject = savedData:FindFirstChild(currencyName)
            if valueObject then
                -- Обновляем начальное значение
                updateCurrencyValue(currencyName, valueObject.Value)
                
                -- Подписываемся на изменения
                valueObject.Changed:Connect(function(newValue)
                    updateCurrencyValue(currencyName, newValue)
                end)
            else
                warn("ValueObject not found for currency: " .. currencyName)
            end
        end
    end
    
    -- Подключаемся к изменениям
    if player:FindFirstChild("SavedData") then
        connectToCurrencyChanges()
    else
        -- Ждем создания SavedData
        player.ChildAdded:Connect(function(child)
            if child.Name == "SavedData" then
                connectToCurrencyChanges()
            end
        end)
    end
    
    -- Делаем GUI видимым
    currencyGui.Enabled = true
    
    return currencyGui
end

-- Основная инициализация
local function initialize()
    -- Инициализируем UI магазина и улучшений
    initShopUI()
    initUpgradeUI()
    
    -- Настраиваем интерфейс валют
    local player = Players.LocalPlayer
    if player:FindFirstChild("SavedData") then
        setupCurrencyUI(player)
    else
        player:WaitForChild("SavedData"):WaitForChild("Coins")
        setupCurrencyUI(player)
    end
    
    -- Настраиваем систему применения эффектов к игрокам
    Players.PlayerAdded:Connect(onPlayerAdded)
    
    -- Обрабатываем уже подключенных игроков
    setupExistingPlayers()
end

-- Запускаем инициализацию
task.delay(1, initialize)