local TestSystem = require(game:GetService("ServerScriptService"):WaitForChild("TestSystem"))
local PremiumContentManager = require(game.ServerStorage.PremiumContentSystem)
local ContentConfig = require(game.ServerStorage.PremiumContentConfig)

local Players = game:GetService("Players")

-- Инициализация системы
local initSuccess, initError = pcall(function()
    if not PremiumContentManager then
        error("Не удалось загрузить модуль PremiumContentManager")
    end
    if not ContentConfig then
        error("Не удалось загрузить конфигурацию ContentConfig")
    end
    
    local initResult, initMsg = PremiumContentManager.Init(ContentConfig)
    if not initResult then
        error(initMsg or "Неизвестная ошибка инициализации PremiumContentManager")
    end
end)

if not initSuccess then
    warn("Ошибка инициализации Premium системы:", initError)
end

-- Функция для выдачи достижения с проверкой
local function awardAchievementWithTracking(player, achievementName)
    if not player then
        return false, "Player is nil"
    end
    
    -- Проверяем, есть ли уже у игрока это достижение
    local hasAchievement, checkErr = PremiumContentManager.PlayerHasAchievement(player, achievementName)
    if checkErr then
        return false, "Failed to check achievement: " .. checkErr
    end
    
    if hasAchievement then
        return false, "Player already has this achievement"
    end
    
    -- Выдаем достижение через систему
    local awarded, rewards = PremiumContentManager.AwardAchievement(player, achievementName)
    if not awarded then
        return false, rewards -- В этом случае rewards содержит ошибку
    end
    
    return true, rewards
end

-- Обработчик входа игрока
local function onPlayerAdded(player)
    if not player then
        return
    end

    -- Ждем инициализации системы перед обработкой игрока
    local initSuccess = pcall(function()
        PremiumContentManager.WaitForInitialization()
    end)
    
    if not initSuccess then
        warn("Premium система не инициализирована для игрока " .. player.Name)
        return
    end

    -- Автоматически выдаем достижение "Первые шаги" при первом входе
    local hasFirstSteps, firstStepsErr = PremiumContentManager.PlayerHasAchievement(player, "FirstSteps")
    if not firstStepsErr and not hasFirstSteps then
        local awarded, result = awardAchievementWithTracking(player, "FirstSteps")
        if not awarded then
            warn("Не удалось выдать достижение 'Первые шаги':", result)
        end
    end
end

-- Обработчик выхода игрока
local function onPlayerRemoving(player)
    -- Очистка не требуется, так как данные сохраняются через DataManager
end

-- Инициализация удаленных событий
local function setupRemoteEvents()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- Создаем папку для событий если ее нет
    local remoteEventsFolder = ReplicatedStorage:FindFirstChild("PremiumEvents")
    if not remoteEventsFolder then
        remoteEventsFolder = Instance.new("Folder")
        remoteEventsFolder.Name = "PremiumEvents"
        remoteEventsFolder.Parent = ReplicatedStorage
    end
    
    -- Создаем или находим RemoteEvent для покупок
    local purchaseEvent = remoteEventsFolder:FindFirstChild("PurchaseItem")
    if not purchaseEvent then
        purchaseEvent = Instance.new("RemoteEvent")
        purchaseEvent.Name = "PurchaseItem"
        purchaseEvent.Parent = remoteEventsFolder
    end
    
    -- Создаем RemoteEvent для достижений
    local achievementEvent = remoteEventsFolder:FindFirstChild("AchievementEvent")
    if not achievementEvent then
        achievementEvent = Instance.new("RemoteEvent")
        achievementEvent.Name = "AchievementEvent"
        achievementEvent.Parent = remoteEventsFolder
    end
    
    -- Создаем RemoteFunction для запроса данных достижений
    local achievementFunction = remoteEventsFolder:FindFirstChild("GetAchievements")
    if not achievementFunction then
        achievementFunction = Instance.new("RemoteFunction")
        achievementFunction.Name = "GetAchievements"
        achievementFunction.Parent = remoteEventsFolder
    end
    
    -- Создаем RemoteFunction для ежедневных наград
    local dailyRewardsFunction = remoteEventsFolder:FindFirstChild("DailyRewards")
    if not dailyRewardsFunction then
        dailyRewardsFunction = Instance.new("RemoteFunction")
        dailyRewardsFunction.Name = "DailyRewards"
        dailyRewardsFunction.Parent = remoteEventsFolder
    end
    
    -- Обработчик покупок
    purchaseEvent.OnServerEvent:Connect(function(player, itemType, itemName)
        if not player or not itemType or not itemName then
            return
        end

        if itemType == "GamePass" then
            local success, err = PremiumContentManager.PromptGamePassPurchase(player, itemName)
            if not success then
                warn("Ошибка при запросе покупки GamePass:", err)
                purchaseEvent:FireClient(player, "PurchaseError", err)
            end
        elseif itemType == "Product" then
            local success, err = PremiumContentManager.PromptProductPurchase(player, itemName)
            if not success then
                warn("Ошибка при запросе покупки продукта:", err)
                purchaseEvent:FireClient(player, "PurchaseError", err)
            end
        end
    end)
    
    -- Обработчик запроса данных достижений
    achievementFunction.OnServerInvoke = function(player, requestType, ...)
        if not player then return nil end
        
        if requestType == "GetPlayerAchievements" then
            local playerAchievements = PremiumContentManager.GetPlayerAchievements(player)
            local missingAchievements = PremiumContentManager.GetMissingAchievements(player)
            local earned, total = PremiumContentManager.GetAchievementProgress(player)
            
            return {
                PlayerAchievements = playerAchievements,
                MissingAchievements = missingAchievements,
                Progress = {Earned = earned, Total = total}
            }
            
        elseif requestType == "GetAchievementInfo" then
            local achievementName = ...
            local achievement = PremiumContentManager.GetAchievement(achievementName)
            if achievement then
                local badgeInfo = PremiumContentManager.GetBadgeInfo(achievement.BadgeId)
                return {
                    Achievement = achievement,
                    BadgeInfo = badgeInfo
                }
            end
            
        elseif requestType == "CheckAchievement" then
            local achievementName = ...
            return PremiumContentManager.PlayerHasAchievement(player, achievementName)
        end
        
        return nil
    end
    
    -- Обработчик ежедневных наград
    dailyRewardsFunction.OnServerInvoke = function(player, action, groupName)
        if not player then return nil end
        
        if action == "GetStatus" then
            local status = PremiumContentManager.GetDailyRewardStatus(player, groupName)
            local availableGroups = PremiumContentManager.GetAvailableRewardGroups(player)
            return {
                Status = status,
                AvailableGroups = availableGroups
            }
            
        elseif action == "ClaimReward" and groupName then
            local result, err = PremiumContentManager.ClaimDailyReward(player, groupName)
            if result then
                return {Success = true, Data = result}
            else
                return {Success = false, Error = err}
            end
        end
        
        return nil
    end
    
    -- Обработчик событий достижений
    achievementEvent.OnServerEvent:Connect(function(player, action, achievementName)
        if not player or not action then return end
        
        if action == "AwardAchievement" and achievementName then
            local awarded, result = awardAchievementWithTracking(player, achievementName)
            if awarded then
                -- Уведомляем клиент об успешной выдаче
                achievementEvent:FireClient(player, "AchievementAwarded", {
                    Name = achievementName,
                    Rewards = result
                })
            else
                achievementEvent:FireClient(player, "AchievementError", result)
            end
        end
    end)
end

-- Основная инициализация
local function initializeSystem()
    -- Настраиваем удаленные события
    local eventsSuccess, eventsError = pcall(setupRemoteEvents)
    if not eventsSuccess then
        warn("Ошибка настройки удаленных событий:", eventsError)
    end
    
    -- Подписываемся на события игроков
    if Players then
        Players.PlayerAdded:Connect(onPlayerAdded)
        Players.PlayerRemoving:Connect(onPlayerRemoving)
        
        -- Обрабатываем уже подключенных игроков
        for _, player in ipairs(Players:GetPlayers()) do
            task.defer(onPlayerAdded, player)
        end
    end
end

-- Функция для создания части с достижением
local function createAchievementPart(achievementName, position, color, size)
    local part = Instance.new("Part")
    part.Name = "AchievementPart_" .. achievementName
    part.Size = size or Vector3.new(5, 1, 5)
    part.Position = position or Vector3.new(0, 5, 0)
    part.Anchored = true
    part.CanCollide = true
    part.Material = Enum.Material.Neon
    part.BrickColor = BrickColor.new(color or "Bright green")
    part.Parent = workspace
    
    -- Добавляем свечение
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = 2
    pointLight.Range = 10
    pointLight.Color = part.BrickColor.Color
    pointLight.Parent = part
    
    -- Добавляем искры
    local sparkles = Instance.new("Sparkles")
    sparkles.SparkleColor = part.BrickColor.Color
    sparkles.Parent = part
    
    -- Добавляем текстовый лейбл
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Top
    surfaceGui.AlwaysOnTop = true
    surfaceGui.Parent = part
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "ДОСТИЖЕНИЕ\n" .. achievementName
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = surfaceGui
    
    return part
end

-- Функция для настройки достижений через части
local function setupAchievementParts()
    local achievementParts = {
        {
            AchievementName = "Explorer",
            Position = Vector3.new(20, 5, 0),
            Color = "Bright blue",
            Size = Vector3.new(6, 1, 6)
        },
        {
            AchievementName = "RichPlayer", 
            Position = Vector3.new(-20, 5, 0),
            Color = "Bright yellow",
            Size = Vector3.new(6, 1, 6)
        },
        {
            AchievementName = "Socializer",
            Position = Vector3.new(0, 5, 20),
            Color = "Bright violet", 
            Size = Vector3.new(6, 1, 6)
        },
        {
            AchievementName = "Veteran",
            Position = Vector3.new(0, 5, -20),
            Color = "Bright orange",
            Size = Vector3.new(6, 1, 6)
        }
    }
    
    for _, achievementData in ipairs(achievementParts) do
        local part = createAchievementPart(
            achievementData.AchievementName,
            achievementData.Position,
            achievementData.Color,
            achievementData.Size
        )
        
        part.Touched:Connect(function(hit)
            local character = hit.Parent
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            if humanoid then
                local player = Players:GetPlayerFromCharacter(character)
                if player then
                    local awarded, result = awardAchievementWithTracking(player, achievementData.AchievementName)
                    if awarded then
                        part.Transparency = 0.8
                        part.CanCollide = false
                        
                        task.delay(30, function()
                            if part then
                                part.Transparency = 0
                                part.CanCollide = true
                            end
                        end)
                    end
                end
            end
        end)
    end
end

-- Функция для создания скрытого достижения
local function createSecretAchievementZone()
    local secretPart = Instance.new("Part")
    secretPart.Name = "SecretAchievementZone"
    secretPart.Size = Vector3.new(10, 10, 10)
    secretPart.Position = Vector3.new(50, 5, 50)
    secretPart.Anchored = true
    secretPart.CanCollide = false
    secretPart.Transparency = 1
    secretPart.Parent = workspace
    
    secretPart.Touched:Connect(function(hit)
        local character = hit.Parent
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                local hasAchievement = PremiumContentManager.PlayerHasAchievement(player, "Explorer")
                if not hasAchievement then
                    local awarded, result = awardAchievementWithTracking(player, "Explorer")
                    if awarded then
                        local effectPart = Instance.new("Part")
                        effectPart.Size = Vector3.new(8, 8, 8)
                        effectPart.Position = secretPart.Position
                        effectPart.Anchored = true
                        effectPart.CanCollide = false
                        effectPart.Material = Enum.Material.Neon
                        effectPart.BrickColor = BrickColor.new("Bright blue")
                        effectPart.Parent = workspace
                        
                        local explosion = Instance.new("Explosion")
                        explosion.Position = secretPart.Position
                        explosion.BlastPressure = 0
                        explosion.BlastRadius = 15
                        explosion.Parent = workspace
                        
                        task.delay(3, function()
                            effectPart:Destroy()
                        end)
                    end
                end
            end
        end
    end)
end

-- Функция для создания достижения за сбор монет
local function createCoinCollectionSystem()
    local coinPositions = {
        Vector3.new(10, 5, 10),
        Vector3.new(15, 5, -5),
        Vector3.new(-10, 5, 15),
        Vector3.new(-15, 5, -10),
        Vector3.new(25, 5, 0)
    }
    
    local coinsCollected = {}
    
    for i, position in ipairs(coinPositions) do
        local coin = Instance.new("Part")
        coin.Name = "Coin_" .. i
        coin.Size = Vector3.new(2, 2, 2)
        coin.Position = position
        coin.Anchored = true
        coin.CanCollide = false
        coin.Shape = Enum.PartType.Ball
        coin.Material = Enum.Material.Neon
        coin.BrickColor = BrickColor.new("Bright yellow")
        coin.Parent = workspace
        
        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
        bodyGyro.P = 1000
        bodyGyro.Parent = coin
        
        local pointLight = Instance.new("PointLight")
        pointLight.Brightness = 3
        pointLight.Range = 8
        pointLight.Color = Color3.new(1, 1, 0)
        pointLight.Parent = coin
        
        coin.Touched:Connect(function(hit)
            local character = hit.Parent
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            if humanoid then
                local player = Players:GetPlayerFromCharacter(character)
                if player then
                    if not coinsCollected[player] then
                        coinsCollected[player] = {}
                    end
                    
                    if not coinsCollected[player][i] then
                        coinsCollected[player][i] = true
                        coin.Transparency = 0.8
                        
                        local collectedCount = 0
                        for _ in pairs(coinsCollected[player]) do
                            collectedCount = collectedCount + 1
                        end
                        
                        if collectedCount >= #coinPositions then
                            local awarded, result = awardAchievementWithTracking(player, "RichPlayer")
                            if awarded then
                                task.delay(60, function()
                                    for j = 1, #coinPositions do
                                        local coinToReset = workspace:FindFirstChild("Coin_" .. j)
                                        if coinToReset then
                                            coinToReset.Transparency = 0
                                            coinsCollected[player][j] = nil
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Функция для создания достижения за время пребывания в игре
local function createTimeBasedAchievements()
    local playerJoinTimes = {}
    
    Players.PlayerAdded:Connect(function(player)
        playerJoinTimes[player] = os.time()
        
        while player and player.Parent do
            task.wait(60)
            
            local joinTime = playerJoinTimes[player]
            if joinTime then
                local timeInGame = os.time() - joinTime
                local minutesInGame = math.floor(timeInGame / 60)
                
                if minutesInGame >= 30 then
                    local hasAchievement = PremiumContentManager.PlayerHasAchievement(player, "Veteran")
                    if not hasAchievement then
                        local awarded, result = awardAchievementWithTracking(player, "Veteran")
                    end
                end
            end
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        playerJoinTimes[player] = nil
    end)
end

-- Инициализация системы достижений через части
local function initializeAchievementParts()
    local success, err = pcall(function()
        setupAchievementParts()
        createSecretAchievementZone()
        createCoinCollectionSystem()
        createTimeBasedAchievements()
    end)
    
    if not success then
        warn("Ошибка инициализации системы достижений:", err)
    end
end

-- Запускаем систему
local mainSuccess, mainError = pcall(function()
    initializeSystem()
    initializeAchievementParts()
end)

if not mainSuccess then
    warn("Критическая ошибка инициализации системы:", mainError)
end

-------------------- Тесты Premium Content System -----------------------------------------------------
local tester = TestSystem.new()

local function runPremiumTests(player)
    tester:describe("Premium Content System Tests - " .. player.Name, function()
        
        it("Система Premium Content инициализирована корректно", function()
            expect(PremiumContentManager).toBeNotNil()
            expect(initSuccess).toBeTrue()
            expect(initError).toBeNil()
        end)
        
        it("Конфигурация Premium системы загружена корректно", function()
            expect(ContentConfig).toBeNotNil()
            expect(ContentConfig.Achievements).toBeNotNil()
            expect(ContentConfig.DailyRewards).toBeNotNil()
            expect(ContentConfig.PremiumBonuses).toBeNotNil()
            expect(ContentConfig.DeveloperProducts).toBeNotNil()
            expect(ContentConfig.GamePasses).toBeNotNil()
        end)
        
        it("Получение доступных продуктов", function()
            local products, productsErr = PremiumContentManager.GetAvailableProducts()
            
            expect(products).toBeNotNil()
            expect(productsErr).toBeNil()
            expect(products).toEqual(ContentConfig.DeveloperProducts)
            expect(products[1].Name).toEqual("Money")
            expect(products[1].DisplayName).toEqual("Набор монет (1000)")
            expect(products[1].Id).toEqual(3344347083)
            expect(products[1].Price).toEqual(100)
            expect(products[1].Bonus).toBeNotNil()
        end)
        
        it("Получение доступных GamePass", function()
            local gamePasses, passesErr = PremiumContentManager.GetAvailableGamePasses()
            
            expect(gamePasses).toBeNotNil()
            expect(passesErr).toBeNil()
            expect(gamePasses).toEqual(ContentConfig.GamePasses)
            expect(gamePasses[1].Name).toEqual("Test")
            expect(gamePasses[1].DisplayName).toEqual("VIP Статус")
            expect(gamePasses[1].Id).toEqual(1339362482)
            expect(gamePasses[1].Price).toEqual(52)
            expect(gamePasses[1].Bonus).toBeNotNil()
        end)
        
        it("Получение списка достижений", function()
            local allAchievements, allAchievementsErr = PremiumContentManager.GetAllAchievements()
            
            expect(allAchievements).toBeNotNil()
            expect(allAchievementsErr).toBeNil()
            expect(allAchievements).toEqual(ContentConfig.Achievements)
            expect(allAchievements[1].Name).toEqual("FirstSteps")
            expect(allAchievements[1].DisplayName).toEqual("Первые шаги")
            expect(allAchievements[1].BadgeId).toEqual(285695783016936)
            expect(allAchievements[1].Description).toEqual("Войдите в игру впервые")
            expect(allAchievements[1].Rewards).toBeNotNil()
        end)
        
        it("Проверка Premium статуса игрока (у запускающего не должно быть)", function()
            local isPremium, premiumErr = PremiumContentManager.IsPremium(player)
            
            expect(premiumErr).toBeNil()
            expect(isPremium).toBeFalse()
            expect(isPremium).toBeType("boolean")
        end)
        
        it("Проверка наличия GamePass у игрока", function()
            local gamePasses, passesErr = PremiumContentManager.GetAvailableGamePasses()
            expect(gamePasses).toBeNotNil()
            expect(passesErr).toBeNil()
            
            if gamePasses and #gamePasses > 0 then
                local hasPass, passErr = PremiumContentManager.HasGamePass(player, gamePasses[1].Name)
                expect(passErr).toBeNil()
                expect(hasPass).toBeTrue()
                hasPass, passErr = PremiumContentManager.HasGamePass(player, gamePasses[2].Name)
                expect(passErr).toBeNil()
                expect(hasPass).toBeFalse()
                expect(hasPass).toBeType("boolean")
                
                -- Проверка несуществующего GamePass
                local hasNonExistent, nonExistentErr = PremiumContentManager.HasGamePass(player, "NonExistentPass")
                expect(nonExistentErr).toBeNotNil()
                expect(hasNonExistent).toBeNil()
            end
        end)
        
        it("Проверка наличия достижения у игрока", function()
            local hasAchievement, checkErr = PremiumContentManager.PlayerHasAchievement(player, "FirstSteps")
            expect(checkErr).toBeNil()
            expect(hasAchievement).toBeType("boolean")
            
            hasAchievement, checkErr = PremiumContentManager.PlayerHasAchievement(player, "NonExistent")
            expect(checkErr).toBeNotNil()
            expect(hasAchievement).toBeNil()
        end)
        
        it("Получение достижений игрока", function()
            local playerAchievements, error = PremiumContentManager.GetPlayerAchievements(player)
            expect(error).toBeNil()
            expect(playerAchievements).toBeNotNil()
            expect(playerAchievements[2].Name).toEqual("Explorer")
            expect(playerAchievements[2].DisplayName).toEqual("Исследователь")
            expect(playerAchievements[2].BadgeId).toEqual(709619331891711)
            expect(playerAchievements[2].Description).toEqual("Посетите все локации на карте")
            expect(playerAchievements[2].Rewards).toBeNotNil()
            expect(playerAchievements).toBeType("table")
        end)
        
        it("Получение прогресса по достижениям", function()
            local earned, total = PremiumContentManager.GetAchievementProgress(player)
            
            expect(earned).toBeNotNil()
            expect(total).toBeNotNil()
            expect(earned).toEqual(2)
            expect(total).toEqual(3)
            expect(earned).toBeType("number")
            expect(total).toBeType("number")
        end)
        
        it("Получение недостающих достижений", function()
            local missingAchievements, error = PremiumContentManager.GetMissingAchievements(player)
            expect(error).toBeNil()
            expect(missingAchievements).toBeNotNil()
            expect(#missingAchievements).toEqual(1)

            expect(missingAchievements).toBeType("table")
        end)
        
        it("Получение информации о бэйдже", function()
            local badgeInfo = PremiumContentManager.GetBadgeInfo(709619331891711)
            expect(badgeInfo).toBeNotNil()
            expect(badgeInfo.Name).toEqual("Повезло Повезло ")
            expect(badgeInfo.Description).toEqual("Повезло Повезло Повезло Повезло Повезло Повезло ")
            expect(badgeInfo.IsEnabled).toBeTrue()
            expect(badgeInfo).toBeType("table")
        end)
        
        it("Получение Premium бонусов", function()
            local premiumBonuses, bonusesErr = PremiumContentManager.GetPremiumBonuses(player)
            
            expect(bonusesErr).toBeNil()
            expect(premiumBonuses).toBeNotNil()
            expect(premiumBonuses).toBeType("table")
        end)
        
        it("Получение GamePass бонусов", function()
            local gamePassBonuses, bonusesErr = PremiumContentManager.GetGamePassBonuses(player)
            
            expect(bonusesErr).toBeNil()
            expect(gamePassBonuses).toBeNotNil()
            expect(gamePassBonuses).toBeType("table")
        end)
        
        -- Тесты для Daily Rewards
        it("Получение настроек ежедневных наград", function()
            local settings, err = PremiumContentManager.GetDailyRewardSettings()
            expect(err).toBeNil()
            expect(settings).toBeNotNil()
            expect(settings.Enabled).toBeTrue()
            expect(settings.EnablePostCompletionRewards).toBeTrue()
        end)
        
        it("Получение всех групп наград", function()
            local groups, err = PremiumContentManager.GetAllRewardGroups()
            expect(err).toBeNil()
            expect(groups).toBeNotNil()
            expect(groups.Default).toBeNotNil()
            expect(groups.VIP).toBeNotNil()
            expect(groups.Premium).toBeNotNil()
        end)
        
        it("Получение конкретной группы наград", function()
            local group, err = PremiumContentManager.GetRewardGroup("Default")
            expect(err).toBeNil()
            expect(group).toBeNotNil()
            expect(group.AccessType).toEqual("All")
            expect(group.CycleLength).toEqual(7)
            expect(group.Rewards).toBeNotNil()
        end)
        
        it("Проверка доступа к группе наград", function()
            local hasAccess, err = PremiumContentManager.HasAccessToRewardGroup(player, "Default")
            expect(err).toBeNil()
            expect(hasAccess).toBeTrue()
            
            hasAccess, err = PremiumContentManager.HasAccessToRewardGroup(player, "Premium")
            expect(err).toBeNil()
            expect(hasAccess).toBeFalse() -- Игрок не Premium
        end)
        
        it("Получение доступных групп наград для игрока", function()
            local availableGroups, err = PremiumContentManager.GetAvailableRewardGroups(player)
            expect(err).toBeNil()
            expect(availableGroups).toBeNotNil()
            expect(availableGroups.Default).toBeNotNil()
        end)
        
        it("Получение награды за определенный день", function()
            local reward, err = PremiumContentManager.GetRewardForDay("Default", 1)
            expect(err).toBeNil()
            expect(reward).toBeNotNil()
            expect(reward.Currency).toEqual(100)
            expect(reward.XP).toEqual(51)
            
            -- Неверный день
            reward, err = PremiumContentManager.GetRewardForDay("Default", 0)
            expect(err).toBeNotNil()
            expect(reward).toBeNil()
        end)
        
        it("Получение награды после завершения цикла", function()
            local reward, err = PremiumContentManager.GetPostCompletionReward("Default")
            expect(err).toBeNil()
            expect(reward).toBeNotNil()
            expect(reward.Currency).toEqual(100)
        end)
        
        it("Получение длины цикла группы", function()
            local length, err = PremiumContentManager.GetGroupCycleLength("Default")
            expect(err).toBeNil()
            expect(length).toEqual(7)
        end)
        
        it("Получение отображаемого имени группы", function()
            local displayName, err = PremiumContentManager.GetGroupDisplayName("Default")
            expect(err).toBeNil()
            expect(displayName).toEqual("Default")
        end)
        
        it("Получение типа доступа группы", function()
            local accessType, err = PremiumContentManager.GetGroupAccessType("Default")
            expect(err).toBeNil()
            expect(accessType).toEqual("All")
        end)
        
        it("Получение требуемого GamePass для группы", function()
            local gamePass, err = PremiumContentManager.GetRequiredGamePassForGroup("VIP")
            if err then
                -- Ожидаем ошибку, если группа не требует GamePass
                expect(err).toBeNotNil()
            else
                expect(gamePass).toBeType("string")
            end
        end)
        
        it("Проверка возможности получения ежедневной награды", function()
            local canClaim, err = PremiumContentManager.CanClaimDailyReward(player, "Default")
            expect(err).toBeNil()
            expect(canClaim).toBeType("boolean")
        end)
        
        it("Получение статуса ежедневных наград", function()
            local status = PremiumContentManager.GetDailyRewardStatus(player, "Default")
            expect(status).toBeNotNil()
            expect(status).toBeType("table")
        end)
        
        it("Применение модификаторов из награды", function()
            local reward = {
                Modifiers = {
                    {
                        Type = "MovementSpeed",
                        Operation = "MultiplyBase",
                        Value = 1.15
                    }
                }
            }
            local modifiers, err = PremiumContentManager.ApplyRewardModifiers(player, reward, "Test", "TestSource")
            expect(err).toBeNil()
            expect(modifiers).toBeNotNil()
            expect(#modifiers).toBeGreaterThan(0)
            expect(modifiers).toBeType("table")
        end)
        
        it("Получение активных модификаторов", function()
            local activeModifiers = PremiumContentManager.GetActiveModifiers(player)
            expect(activeModifiers).toBeNotNil()
            expect(activeModifiers).toBeType("table")
        end)
        
        it("Проверка наличия активного модификатора", function()
            local hasModifier = PremiumContentManager.HasActiveModifier(player, "MovementSpeed")
            expect(hasModifier).toBeType("boolean")
        end)
        
        it("Удаление модификаторов по источнику", function()
            local success, err = PremiumContentManager.RemoveAllModifiersBySource(player, "Test", "TestSource")
            expect(err).toBeNil()
            expect(success).toBeTrue()
        end)
        
        it("Получение оставшегося времени модификатора", function()
            local remainingTime, err = PremiumContentManager.GetRemainingModifierTime(player, "non_existent_modifier")
            expect(err).toBeNotNil()
            expect(remainingTime).toBeNil()
        end)
        
        -- Тесты обработки ошибок
        it("Обработка неверных параметров в функциях", function()
            local result, err = PremiumContentManager.HasGamePass(nil, "Test")
            expect(err).toEqual("Player cannot be nil")
            expect(result).toBeNil()
            
            result, err = PremiumContentManager.IsPremium(nil)
            expect(err).toEqual("Player cannot be nil")
            expect(result).toBeNil()
            
            result, err = PremiumContentManager.PromptGamePassPurchase(nil, "Test")
            expect(err).toEqual("Player cannot be nil")
            expect(result).toBeNil()
            
            result, err = PremiumContentManager.PromptProductPurchase(player, "NonExistentProduct")
            expect(err).toBeNotNil()
            expect(result).toBeNil()
        end)
        
        it("Получение информации о конкретном достижении", function()
            local achievement, err = PremiumContentManager.GetAchievement("FirstSteps")
            expect(err).toBeNil()
            expect(achievement).toBeNotNil()
            expect(achievement.Name).toEqual("FirstSteps")
            expect(achievement.DisplayName).toEqual("Первые шаги")
            
            achievement, err = PremiumContentManager.GetAchievement("NonExistent")
            expect(err).toEqual("Achievement 'NonExistent' not found")
            expect(err).toBeNotNil()
            expect(achievement).toBeNil()
        end)
        
        it("Тестирование граничных случаев", function()
            -- Тест с максимальным днем в цикле
            local group, err = PremiumContentManager.GetRewardGroup("Default")
            if group then
                local reward, err = PremiumContentManager.GetRewardForDay("Default", group.CycleLength)
                expect(err).toBeNil()
                expect(reward).toBeNotNil()
            end
            
            -- Тест получения вычисляемого значения для несуществующего параметра
            local value = PremiumContentManager.GetComputedValue(player, "NonExistentParam")
            expect(value).toBeNil()
        end)
        
        it("Тестирование типов возвращаемых значений", function()
            local achievements = PremiumContentManager.GetAllAchievements()
            expect(achievements).toBeType("table")
            
            local products = PremiumContentManager.GetAvailableProducts()
            expect(products).toBeType("table")
            
            local gamePasses = PremiumContentManager.GetAvailableGamePasses()
            expect(gamePasses).toBeType("table")
            
            local settings = PremiumContentManager.GetDailyRewardSettings()
            expect(settings).toBeType("table")
            
            local groups = PremiumContentManager.GetAllRewardGroups()
            expect(groups).toBeType("table")
        end)
        
        it("Тестирование структуры конфигурации", function()
            if ContentConfig.GamePasses and #ContentConfig.GamePasses > 0 then
                expect(ContentConfig.GamePasses[1].Bonus).toBeNotNil()
                if ContentConfig.GamePasses[1].Bonus.Modifiers then
                    expect(ContentConfig.GamePasses[1].Bonus.Modifiers).toBeType("table")
                end
            end
            
            if ContentConfig.DeveloperProducts and #ContentConfig.DeveloperProducts > 0 then
                expect(ContentConfig.DeveloperProducts[1].Bonus).toBeNotNil()
            end
            
            if ContentConfig.DailyRewards and ContentConfig.DailyRewards.RewardGroups then
                expect(ContentConfig.DailyRewards.RewardGroups.Default).toBeNotNil()
            end
        end)
        
        -- Новые тесты для улучшенной системы
        it("Тестирование принудительной обработки покупки", function()
            if ContentConfig.DeveloperProducts and #ContentConfig.DeveloperProducts > 0 then
                local success, result = PremiumContentManager.ForceProcessPurchase(
                    player, 
                    ContentConfig.DeveloperProducts[1].Id, 
                    "test"
                )
                expect(success).toBeType("boolean")
            end
        end)
        
        it("Тестирование выдачи наград продукта", function()
            if ContentConfig.DeveloperProducts and #ContentConfig.DeveloperProducts > 0 then
                local success, result = PremiumContentManager.GrantProductReward(player, ContentConfig.DeveloperProducts[1].Name)
                expect(success).toBeType("boolean")
            end
        end)
        
        it("Тестирование применения наград", function()
            local testReward = {
                Currency = 100,
                XP = 50
            }
            local result, err = PremiumContentManager.ApplyReward(player, testReward, "Test", "TestSource")
            expect(err).toBeNil()
            expect(result).toBeNotNil()
            expect(result.savedDataApplied).toBeTrue()
        end)
    end)
    
    tester:runAll()
end

-- Функция для запуска тестов при подключении игрока
local function setupPremiumTests(player)
    if not player then return end

    -- Ждем инициализации системы PremiumContent
    local initSuccess = pcall(function()
        PremiumContentManager.WaitForInitialization()
    end)
    
    if not initSuccess then
        warn("Premium система не инициализирована для тестов игрока " .. player.Name)
        return
    end

    -- Ждем загрузки данных игрока
    if player:GetAttribute("DataLoaded") then
        task.defer(runPremiumTests, player)
    else
        local connection
        connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            if player:GetAttribute("DataLoaded") then
                connection:Disconnect()
                task.defer(runPremiumTests, player)
            end
        end)
    end
end

-- Обработчик подключения игрока
game:GetService("Players").PlayerAdded:Connect(function(player)
    task.delay(1, function()
        setupPremiumTests(player)
    end)
end)

-- Обработка уже подключенных игроков
for _, player in ipairs(game.Players:GetPlayers()) do
    task.delay(1, function()
        setupPremiumTests(player)
    end)
end
