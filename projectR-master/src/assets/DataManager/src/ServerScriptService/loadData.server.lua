local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)
local TestSystem = require(game:GetService("ServerScriptService"):WaitForChild("TestSystem"))

local isInitialized = DataManager.Init(game.ServerStorage.ConfigModule)

-- Создаем первую часть для добавления случайных модификаторов
local addModifierPart = Instance.new("Part")
addModifierPart.Name = "AddRandomModifier"
addModifierPart.Size = Vector3.new(4, 1, 4)
addModifierPart.Position = Vector3.new(0, 0.5, 0)
addModifierPart.Anchored = true
addModifierPart.CanCollide = true
addModifierPart.BrickColor = BrickColor.new("Bright green")
addModifierPart.Material = Enum.Material.Neon
addModifierPart.Parent = workspace

-- Создаем текстовую метку для первой части
local addModifierLabel = Instance.new("BillboardGui")
addModifierLabel.Name = "Label"
addModifierLabel.Size = UDim2.new(0, 200, 0, 50)
addModifierLabel.StudsOffset = Vector3.new(0, 2, 0)
addModifierLabel.Adornee = addModifierPart

local addModifierText = Instance.new("TextLabel")
addModifierText.Size = UDim2.new(1, 0, 1, 0)
addModifierText.BackgroundTransparency = 1
addModifierText.Text = "Добавить случайный\nмодификатор"
addModifierText.TextColor3 = Color3.new(1, 1, 1)
addModifierText.TextScaled = true
addModifierText.Font = Enum.Font.GothamBold
addModifierText.Parent = addModifierLabel

addModifierLabel.Parent = addModifierPart

-- Создаем вторую часть для показа информации о модификаторах
local showModifiersPart = Instance.new("Part")
showModifiersPart.Name = "ShowModifiersInfo"
showModifiersPart.Size = Vector3.new(4, 1, 4)
showModifiersPart.Position = Vector3.new(8, 0.5, 0)
showModifiersPart.Anchored = true
showModifiersPart.CanCollide = true
showModifiersPart.BrickColor = BrickColor.new("Bright blue")
showModifiersPart.Material = Enum.Material.Neon
showModifiersPart.Parent = workspace

-- Создаем текстовую метку для второй части
local showModifiersLabel = Instance.new("BillboardGui")
showModifiersLabel.Name = "Label"
showModifiersLabel.Size = UDim2.new(0, 200, 0, 50)
showModifiersLabel.StudsOffset = Vector3.new(0, 2, 0)
showModifiersLabel.Adornee = showModifiersPart

local showModifiersText = Instance.new("TextLabel")
showModifiersText.Size = UDim2.new(1, 0, 1, 0)
showModifiersText.BackgroundTransparency = 1
showModifiersText.Text = "Показать информацию\nо модификаторах"
showModifiersText.TextColor3 = Color3.new(1, 1, 1)
showModifiersText.TextScaled = true
showModifiersText.Font = Enum.Font.GothamBold
showModifiersText.Parent = showModifiersLabel

showModifiersLabel.Parent = showModifiersPart

-- Функция для генерации случайного модификатора
local function generateRandomModifier()
    local operations = {"Add", "MultiplyBase", "MultiplyTotal"}
    local sources = {"PowerUp", "Buff", "Magic", "Skill", "Item"}
    
    local value = math.random(1, 50)
    local operation = operations[math.random(1, #operations)]
    local source = sources[math.random(1, #sources)]
    local duration = math.random(1, 10) * 60 -- от 1 до 10 минут в секундах
    
    return value, operation, source, duration
end

-- Функция для форматирования времени
local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", minutes, secs)
end

-- Обработчик касания для добавления случайного модификатора
addModifierPart.Touched:Connect(function(hit)
    local character = hit.Parent
    local player = Players:GetPlayerFromCharacter(character)
    
    if player and DataManager.IsDataLoaded(player) then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            -- Генерируем случайные параметры модификатора
            local value, operation, source, duration = generateRandomModifier()
            local modifierId = "random_" .. os.time() .. "_" .. math.random(1000, 9999)
            
            -- Добавляем временный модификатор с сохранением
            local success = DataManager.AddTemporaryModifier(
                player,
                "testSave",
                modifierId,
                value,
                operation,
                source,
                duration,
                true -- сохранять при выходе
            )
            
            if success then
                -- Получаем информацию о добавленном модификаторе
                local modifierInfo = DataManager.GetModifierInfo(player, "testSave", modifierId)
                
                -- Показываем сообщение игроку
                local message = string.format(
                    "Добавлен модификатор!\n" ..
                    "Значение: %d\n" ..
                    "Операция: %s\n" ..
                    "Источник: %s\n" ..
                    "Время: %s",
                    value, operation, source, formatTime(duration)
                )
                
                -- Создаем всплывающее сообщение
                local billboardGui = Instance.new("BillboardGui")
                billboardGui.Size = UDim2.new(0, 300, 0, 150)
                billboardGui.StudsOffset = Vector3.new(0, 3, 0)
                billboardGui.Adornee = addModifierPart
                billboardGui.Parent = addModifierPart
                
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 0.5
                textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
                textLabel.Text = message
                textLabel.TextColor3 = Color3.new(1, 1, 1)
                textLabel.TextScaled = true
                textLabel.Font = Enum.Font.GothamBold
                textLabel.Parent = billboardGui
                
                -- Удаляем сообщение через 3 секунды
                task.delay(3, function()
                    billboardGui:Destroy()
                end)
                
                print(string.format("[AddModifier] Добавлен модификатор для %s: %s %d %s (%s)",
                    player.Name, operation, value, source, formatTime(duration)))
            else
                warn(string.format("[AddModifier] Не удалось добавить модификатор для %s", player.Name))
            end
        end
    end
end)

-- Обработчик касания для показа информации о модификаторах
showModifiersPart.Touched:Connect(function(hit)
    local character = hit.Parent
    local player = Players:GetPlayerFromCharacter(character)
    
    if player and DataManager.IsDataLoaded(player) then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            -- Получаем информацию о всех временных модификаторах
            local tempModifiersInfo = DataManager.GetTemporaryModifiersInfo(player)
            
            if next(tempModifiersInfo) then
                -- Создаем сообщение с информацией о модификаторах
                local message = "Временные модификаторы:\n\n"
                local count = 0
                
                for modifierId, info in pairs(tempModifiersInfo) do
                    count = count + 1
                    message = message .. string.format(
                        "%d. %s:\n" ..
                        "   Параметр: %s\n" ..
                        "   Значение: %d\n" ..
                        "   Операция: %s\n" ..
                        "   Осталось: %s\n\n",
                        count, modifierId, info.paramName, info.value, 
                        info.operation, formatTime(info.remainingTime)
                    )
                end
                
                -- Выводим в консоль
                print(string.format("[ShowModifiers] Информация для %s:", player.Name))
                for modifierId, info in pairs(tempModifiersInfo) do
                    print(string.format("  - %s: %s %d %s (%s осталось)",
                        modifierId, info.operation, info.value, info.paramName, 
                        formatTime(info.remainingTime)))
                end
                
                -- Показываем сообщение игроку
                local billboardGui = Instance.new("BillboardGui")
                billboardGui.Size = UDim2.new(0, 400, 0, 300)
                billboardGui.StudsOffset = Vector3.new(0, 4, 0)
                billboardGui.Adornee = showModifiersPart
                billboardGui.Parent = showModifiersPart
                
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 0.5
                textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
                textLabel.Text = message
                textLabel.TextColor3 = Color3.new(1, 1, 1)
                textLabel.TextScaled = true
                textLabel.Font = Enum.Font.Gotham
                textLabel.TextYAlignment = Enum.TextYAlignment.Top
                textLabel.Parent = billboardGui
                
                -- Удаляем сообщение через 5 секунд
                task.delay(5, function()
                    billboardGui:Destroy()
                end)
            else
                -- Нет временных модификаторов
                local billboardGui = Instance.new("BillboardGui")
                billboardGui.Size = UDim2.new(0, 300, 0, 100)
                billboardGui.StudsOffset = Vector3.new(0, 3, 0)
                billboardGui.Adornee = showModifiersPart
                billboardGui.Parent = showModifiersPart
                
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 0.5
                textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
                textLabel.Text = "Нет активных\nвременных модификаторов"
                textLabel.TextColor3 = Color3.new(1, 1, 1)
                textLabel.TextScaled = true
                textLabel.Font = Enum.Font.GothamBold
                textLabel.Parent = billboardGui
                
                task.delay(3, function()
                    billboardGui:Destroy()
                end)
                
                print(string.format("[ShowModifiers] У %s нет активных временных модификаторов", player.Name))
            end
        end
    end
end)

-- Дополнительная функция для автоматического показа информации при добавлении модификатора
local function setupPlayerModifierDisplay(player)
    -- Слушаем изменения в ComputedData для отображения информации о добавленных модификаторах
    local computedData = player:WaitForChild("ComputedData")
    if computedData then
        local testSaveFolder = computedData:WaitForChild("testSave")
        if testSaveFolder then
            local modifiers = testSaveFolder:WaitForChild("Modifiers")
            
            modifiers.ChildAdded:Connect(function(child)
                if child:IsA("NumberValue") then
                    -- Проверяем, является ли модификатор временным
                    local isTemporary = child:GetAttribute("IsTemporary")
                    if isTemporary then
                        local expireTime = child:GetAttribute("ExpireTime")
                        local currentTime = os.time()
                        local remainingTime = expireTime - currentTime
                        
                        if remainingTime > 0 then
                            -- Показываем информацию о добавленном модификаторе
                            local modifierInfo = DataManager.GetModifierInfo(player, "testSave", child.Name)
                            if modifierInfo then
                                player:SetAttribute("LastModifierAdded", os.time())
                                
                                -- Можно добавить дополнительную логику отображения здесь
                                -- Например, показать сообщение в UI игрока
                            end
                        end
                    end
                end
            end)
        end
    end
end

-- Настраиваем отображение для подключенных игроков
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        setupPlayerModifierDisplay(player)
    end)
    
    if player.Character then
        setupPlayerModifierDisplay(player)
    end
end)

-- Настраиваем для уже подключенных игроков
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        setupPlayerModifierDisplay(player)
    end
end

print("Modifier Parts initialized successfully!")

-- Функция для форматированного вывода данных
local function printPlayerData(playerName, player)
    print(string.format("=== %s PLAYER DATA ===", playerName))
    
    local savedData = player:FindFirstChild("SavedData")
    local playerData = DataManager.GetData(player)
    local playerComputedData = DataManager.GetComputedData(player)

    
    if savedData then
        print(string.format("Coins: %d", savedData.coins.Value))
        print(string.format("Gems: %d", savedData.gems.Value))
        print(string.format("Level: %d", savedData.level.Value))
        print(string.format("Experience: %d", savedData.experience.Value))
    end
    
    if playerData then
        print(string.format("Inventory: %d items", #playerData.inventory))
        print(string.format("Settings - Music: %s, SFX: %s", 
            tostring(playerData.settings.music), 
            tostring(playerData.settings.sfx)))
    end

    if playerComputedData then
        print(playerComputedData)
    end
    
    print("=========================")
end

----------------Тесты----------
local tester = TestSystem.new()

local function runDataManagerTests(player)
    tester:describe("DataManager Tests - " .. player.Name, function()
        
        it("DataManager инициализирован корректно", function()
            expect(DataManager).toBeNotNil()
            expect(isInitialized).toEqual(true)
        end)
        
        it("Данные игрока загружаются при подключении", function()
            expect(DataManager.IsDataLoaded(player)).toEqual(true)
            
            local data, err = DataManager.GetData(player)
            expect(data).toBeNotNil()
            expect(err).toBeNil()
            expect(data.test).toEqual(11)
            expect(data.test2).toEqual(22)
        end)
        
        it("Создаются папки SavedData и ComputedData", function()
            local savedData = player:FindFirstChild("SavedData")
            expect(savedData).toBeNotNil()
            
            local computedData = player:FindFirstChild("ComputedData")
            expect(computedData).toBeNotNil()
            
            -- Проверяем базовые значения в SavedData
            local coins = savedData:FindFirstChild("test")
            expect(coins).toBeNotNil()
            expect(coins.Value).toEqual(11)
            
            local gems = savedData:FindFirstChild("test2")
            expect(gems).toBeNotNil()
            expect(gems.Value).toEqual(22)
        end)
        
        it("Вычисляемые поля инициализируются корректно", function()
            local computedData = DataManager.GetComputedData(player)
            expect(computedData).toBeNotNil()
            
            expect(computedData.jumpHeight).toEqual(7)
            expect(computedData.moveSpeed).toEqual(16)
            expect(computedData.defense).toEqual(5)
        end)
        
        it("Модификаторы правильно влияют на вычисляемые поля", function()
            -- Добавляем модификаторы
            DataManager.AddModifier(player, "testAdd", "id", 10, "Add", "test")
            DataManager.AddModifier(player, "testMultiplyBase", "id", 10, "MultiplyBase", "test")
            DataManager.AddModifier(player, "testMultiplyTotal", "id", 10, "MultiplyTotal", "test")
            wait()
            local computedData = DataManager.GetComputedData(player)
            expect(computedData.testAdd).toEqual(11)
            expect(computedData.testMultiplyBase).toEqual(20)
            expect(computedData.testMultiplyTotal).toEqual(30)

            -- Добавляем сложный модификатор
            DataManager.AddModifier(player, "testAll", "complexMod", 1, "Add", "test")
            DataManager.AddModifier(player, "testAll", "totalMultiplier", 2, "MultiplyTotal", "test")
            DataManager.AddModifier(player, "testAll", "id", 5, "MultiplyBase", "test")
            wait()

            computedData = DataManager.GetComputedData(player)
            expect(computedData.testAll).toEqual(52) -- (5 * 5 + 1) * 2
        end)
        
        it("Удаление модификаторов работает корректно", function()
            -- Добавляем модификатор
            DataManager.AddModifier(player, "testRemove", "tempMod", 5, "Add", "test")
            wait()
            local computedData = DataManager.GetComputedData(player)
            expect(computedData.testRemove).toEqual(10) -- 17 (предыдущий) + 5
            
            -- Удаляем модификатор
            local removed = DataManager.RemoveModifier(player, "testRemove", "tempMod")
            expect(removed).toBeTrue()
            wait()
            computedData = DataManager.GetComputedData(player)
            expect(computedData.testRemove).toEqual(5) -- Возврат к предыдущему значению
        end)
        
        it("Временные модификаторы добавляются корректно", function()
            local success = DataManager.AddTemporaryModifier(
                player, 
                "testTemporary", 
                "tempTest", 
                15, 
                "Add", 
                "test", 
                50,  -- 50 секунд
                true -- сохранять в данные
            )
            expect(success).toBeTrue()
            
            wait()
            local computedData = DataManager.GetComputedData(player)
            expect(computedData.testTemporary).toEqual(20) -- 5 + 15
            
            -- Проверяем информацию о временных модификаторах
            local tempInfo = DataManager.GetTemporaryModifiersInfo(player)
            expect(tempInfo.tempTest).toBeNotNil()
            expect(tempInfo.tempTest.paramName).toEqual("testTemporary")
            expect(tempInfo.tempTest.value).toEqual(15)
            expect(tempInfo.tempTest.remainingTime).toBeLessThan(51)
        end)
        
        it("Временные модификаторы автоматически удаляются", function()
            local success = DataManager.AddTemporaryModifier(
                player, 
                "testAutoRemove", 
                "autoRemoveTest", 
                10, 
                "Add", 
                "test", 
                2,  -- 2 секунды
                false
            )
            expect(success).toBeTrue()
            
            wait()
            local computedData = DataManager.GetComputedData(player)
            expect(computedData.testAutoRemove).toEqual(15) -- 5 + 10
            
            -- Ждем истечения времени
            wait(3)
            
            computedData = DataManager.GetComputedData(player)
            expect(computedData.testAutoRemove).toEqual(5) -- Должен вернуться к базовому
            
            -- Проверяем, что модификатор удален из активных
            local tempInfo = DataManager.GetTemporaryModifiersInfo(player)
            expect(tempInfo.autoRemoveTest).toBeNil()
        end)
        
        it("Временные модификаторы сохраняются в данные", function()
            local success = DataManager.AddTemporaryModifier(
                player, 
                "testSave", 
                "saveTest", 
                25, 
                "MultiplyBase", 
                "test", 
                1000, -- 1000 секунд
                true -- сохранять
            )
            expect(success).toBeTrue()
            
            -- Проверяем, что данные обновились
            local playerData = DataManager.GetData(player)
            expect(playerData.temporaryModifiers).toBeNotNil()
            expect(playerData.temporaryModifiers.saveTest).toBeNotNil()
            expect(playerData.temporaryModifiers.saveTest.paramName).toEqual("testSave")
            expect(playerData.temporaryModifiers.saveTest.value).toEqual(25)
        end)
        
        it("Обновление данных через UpdateData работает корректно", function()
            local success, err = DataManager.UpdateData(player, function(data)
                data.coins = 500
                data.gems = 50
                data.level = 2
                return data
            end)
            wait()
            expect(success).toBeTrue()
            expect(err).toBeNil()
            
            local data = DataManager.GetData(player)
            expect(data.coins).toEqual(500)
            expect(data.gems).toEqual(50)
            expect(data.level).toEqual(2)
            
            -- Проверяем, что значения в SavedData тоже обновились
            local savedData = player:FindFirstChild("SavedData")
            local coins = savedData:FindFirstChild("coins")
            expect(coins.Value).toEqual(500)
        end)
        
        it("Обновление данных сохраняет неизмененные поля", function()
            local originalData = DataManager.GetData(player)
            
            local success, err = DataManager.UpdateData(player, function(data)
                data.coins = 1000
                return data
            end)
            wait()
            expect(success).toBeTrue()
            expect(err).toBeNil()
            
            local updatedData = DataManager.GetData(player)
            expect(updatedData.coins).toEqual(1000)
            expect(updatedData.gems).toEqual(originalData.gems)
            expect(updatedData.level).toEqual(originalData.level)
            expect(updatedData.settings.music).toEqual(originalData.settings.music)
        end)
        
        it("Сохранение данных игрока работает", function()
            local success, err = DataManager.SavePlayer(player)
            expect(success).toBeTrue()
            expect(err).toBeNil()
        end)
        
        it("Обработка ошибок при обновлении данных", function()
            -- Пытаемся обновить данные несуществующего игрока
            local fakePlayer = {UserId = 999999, Name = "FakePlayer"}
            local success, err = DataManager.UpdateData(fakePlayer, function(data) return data end)
            expect(success).toBeFalse()
            expect(err).toEqual("PlayerNotActive")
        end)
        
        it("Получение данных для несуществующего игрока", function()
            local fakePlayer = {UserId = 999999, Name = "FakePlayer"}
            local data, err = DataManager.GetData(fakePlayer)
            expect(data).toBeNil()
            expect(err).toEqual("PlayerDataNotLoaded")
        end)
        
        it("Добавление модификатора к несуществующему параметру", function()
            local success = DataManager.AddModifier(player, "nonExistentParam", "test", 10, "Add", "test")
            expect(success).toBeFalse()
        end)
        
        it("Удаление несуществующего модификатора", function()
            local removed = DataManager.RemoveModifier(player, "jumpHeight", "nonExistentModifier")
            expect(removed).toBeFalse()
        end)
        
    end)
    
    -- Запускаем все тесты
    tester:runAll()
end

-- Функция для запуска тестов при подключении игрока
local function setupPlayer(player)
    if not player then return end

    -- Ждем загрузки данных
    repeat task.wait() until DataManager.IsDataLoaded(player)
    
    -- Выводим данные
    printPlayerData(player.Name.." JOINED", player)

    local function setupCharacter(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping then
                DataManager.UpdateData(player, function(data)
                    print("gems +1")
                    data.gems += 1
                    return data
                end)

                local randomModifier = math.random(-2, 30)
                local modifierId = "jump_"..tick()
                
                local possibleModifiers = { "Add", "MultiplyBase", "MultiplyTotal" }
                local randomModifierType = possibleModifiers[math.random(1, #possibleModifiers)]
                
                -- Используем временный модификатор с сохранением
                DataManager.AddTemporaryModifier(
                    player,
                    "jumpHeight",
                    modifierId,
                    randomModifier,
                    randomModifierType,
                    "RandomJump",
                    60 -- секунд
                )
            end
        end)
    end

    -- Обрабатываем существующий персонаж сразу
    if player.Character then
        setupCharacter(player.Character)
    end
    
    -- Подключаемся для будущих персонажей
    player.CharacterAdded:Connect(setupCharacter)

    if player:GetAttribute("DataLoaded") then
        runDataManagerTests(player)
    else
        local connection
        connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            if player:GetAttribute("DataLoaded") then
                connection:Disconnect()
                runDataManagerTests(player)
            end
        end)
    end

    -- Система начисления монет
    while player:IsDescendantOf(game) do
        task.wait(5)
        DataManager.UpdateData(player, function(data)
            print("coins +10")
            data.coins += 10
            return data
        end)
    end
end

----------------------------------------------------------------

-- Обработчик входа игрока
Players.PlayerAdded:Connect(setupPlayer)

-- Обработчик выхода игрока
Players.PlayerRemoving:Connect(function(player)
    printPlayerData(player.Name.." LEFT", player)
end)

-- Обработка уже подключенных игроков
for _, player in ipairs(game.Players:GetPlayers()) do
    setupPlayer(player)
end
