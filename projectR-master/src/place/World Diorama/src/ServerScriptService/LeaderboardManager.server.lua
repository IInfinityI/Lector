-- LeaderboardManager (ServerScriptService) — Cross-Server Version
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

-- Константы
local UPDATE_INTERVAL = 30
local TOP_COUNT = 15
local DATA_LOAD_TIMEOUT = 30
local WRITE_DEBOUNCE = 60 -- минимальный интервал записи данных одного игрока в OrderedDataStore
local LEADERBOARD_TOPIC = "LeaderboardUpdate"
local LEADERSTATS_UPDATE_INTERVAL = 2 -- интервал обновления leaderstats (секунды)

-- Уникальный идентификатор сервера
local SERVER_UUID = HttpService:GenerateGUID(false)

-- DataStore'ы
local totalGoldEarnedStore = DataStoreService:GetOrderedDataStore("LeaderboardTotalGoldEarned")
local prestigeStore = DataStoreService:GetOrderedDataStore("LeaderboardPrestige")
local dioramaStore = DataStoreService:GetDataStore("LeaderboardDioramas")
local dioramaRatingStore = DataStoreService:GetDataStore("LeaderboardDioramaRatings")

-- Ссылки на доски
local boards = {}

-- Кеш имён игроков {[userId] = displayName}
local playerNameCache = {}

-- Кеш последних записанных значений для debounce {[userId] = {totalGoldEarned = n, prestige = n, time = t}}
local lastWrittenData = {}

-- Ссылки на leaderstats IntValue для каждого игрока {[userId] = {gold, dioramas, prestige}}
local playerLeaderstats = {}

-- Флаг подписки MessagingService
local messagingSubscribed = false

-- Флаг: нужно обновить доски при следующем цикле
local needsRefresh = false

--------------------------------------------------------------------------------
-- Ожидание загрузки AssetService
--------------------------------------------------------------------------------
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
            warn("[LeaderboardManager] Таймаут ожидания AssetService")
            return false
        end

        task.wait(1)
    end
end

if not waitForAssetService() then
    warn("[LeaderboardManager] Не удалось загрузить AssetService")
    return
end

local EventSystem = _G.AssetService:GetModule("EventSystem")
local DataManager = _G.AssetService:GetModule("DataManager")

if not EventSystem or not DataManager then
    warn("[LeaderboardManager] EventSystem или DataManager не найден")
    return
end

--------------------------------------------------------------------------------
-- Ожидание загрузки данных игрока
--------------------------------------------------------------------------------
local function waitForDataLoaded(player)
    local startTime = os.time()
    while not DataManager.IsDataLoaded(player) do
        if os.time() - startTime > DATA_LOAD_TIMEOUT then
            return false
        end
        task.wait(0.1)
    end
    return true
end

--------------------------------------------------------------------------------
-- Форматирование числа
--------------------------------------------------------------------------------
local function formatNumber(num)
    if num >= 1e9 then
        return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(math.floor(num))
    end
end

--------------------------------------------------------------------------------
-- Получение / кеширование имени игрока по UserId
--------------------------------------------------------------------------------
local function getPlayerName(userId)
    -- Проверяем кеш
    if playerNameCache[userId] then
        return playerNameCache[userId]
    end

    -- Игрок на текущем сервере?
    local player = Players:GetPlayerByUserId(userId)
    if player then
        playerNameCache[userId] = player.DisplayName
        return player.DisplayName
    end

    -- Запрос через API
    local success, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if success and name then
        playerNameCache[userId] = name
        return name
    end

    return "Player"
end

--------------------------------------------------------------------------------
-- 1. Исправленный findBoards — рекурсивный поиск SurfaceGui внутри Model
--------------------------------------------------------------------------------
local function findBoards()
    local lb = workspace:FindFirstChild("LeaderBoard")
    if not lb then
        warn("[LeaderboardManager] LeaderBoard not found")
        return false
    end

    local foundAny = false

    for _, boardName in ipairs({"PrestigeBoard", "TotalGoldEarnedBoard", "DioramaBoard", "DioramaRatingBoard"}) do
        local boardModel = lb:FindFirstChild(boardName)
        if boardModel then
            -- Рекурсивный поиск SurfaceGui внутри Model
            local sg = boardModel:FindFirstChild("SurfaceGui", true)
            if sg and sg:IsA("SurfaceGui") then
                local bg = sg:FindFirstChild("Background")
                if bg then
                    boards[boardName] = bg
                    foundAny = true
                end
            end
        end
    end

    return foundAny
end

--------------------------------------------------------------------------------
-- Обновление строки таблицы (Prestige/TotalGoldEarned)
--------------------------------------------------------------------------------
local function updatePlayerRow(bg, rowIndex, playerName, value, valueSuffix)
    local rowFrame = bg:FindFirstChild("Row" .. rowIndex)
    if not rowFrame then return end

    local rankLabel = rowFrame:FindFirstChild("Rank")
    local nameLabel = rowFrame:FindFirstChild("PlayerName")
    local valueLabel = rowFrame:FindFirstChild("Value")

    if rankLabel then
        rankLabel.Text = rowIndex .. "."
    end
    if nameLabel then
        nameLabel.Text = playerName ~= "" and playerName or "---"
    end
    if valueLabel then
        valueLabel.Text = value > 0 and (formatNumber(value) .. (valueSuffix or "")) or "---"
    end
end

--------------------------------------------------------------------------------
-- Обновление строки таблицы диорам
--------------------------------------------------------------------------------
local function updateDioramaRow(bg, rowIndex, ownerName, dioramaName, price)
    local rowFrame = bg:FindFirstChild("Row" .. rowIndex)
    if not rowFrame then return end

    local topLine = rowFrame:FindFirstChild("TopLine")
    local bottomLine = rowFrame:FindFirstChild("BottomLine")

    if topLine then
        local rankLabel = topLine:FindFirstChild("Rank")
        local ownerLabel = topLine:FindFirstChild("OwnerName")
        if rankLabel then
            rankLabel.Text = rowIndex .. "."
        end
        if ownerLabel then
            ownerLabel.Text = ownerName ~= "" and ownerName or "---"
        end
    end

    if bottomLine then
        local dioramaLabel = bottomLine:FindFirstChild("DioramaName")
        local priceLabel = bottomLine:FindFirstChild("Price")
        if dioramaLabel then
            dioramaLabel.Text = dioramaName ~= "" and dioramaName or "---"
        end
        if priceLabel then
            priceLabel.Text = price > 0 and formatNumber(price) or "---"
        end
    end
end

--------------------------------------------------------------------------------
-- Очистка строки
--------------------------------------------------------------------------------
local function clearPlayerRow(bg, rowIndex)
    updatePlayerRow(bg, rowIndex, "", 0, "")
end

local function clearDioramaRow(bg, rowIndex)
    updateDioramaRow(bg, rowIndex, "", "", 0)
end

--------------------------------------------------------------------------------
-- Обновление строки таблицы рейтинговых диорам
--------------------------------------------------------------------------------
local function updateDioramaRatingRow(bg, rowIndex, ownerName, dioramaName, rating)
    local rowFrame = bg:FindFirstChild("Row" .. rowIndex)
    if not rowFrame then return end

    local topLine = rowFrame:FindFirstChild("TopLine")
    local bottomLine = rowFrame:FindFirstChild("BottomLine")

    if topLine then
        local rankLabel = topLine:FindFirstChild("Rank")
        local ownerLabel = topLine:FindFirstChild("OwnerName")
        if rankLabel then
            rankLabel.Text = rowIndex .. "."
        end
        if ownerLabel then
            ownerLabel.Text = ownerName ~= "" and ownerName or "---"
        end
    end

    if bottomLine then
        local dioramaLabel = bottomLine:FindFirstChild("DioramaName")
        local ratingLabel = bottomLine:FindFirstChild("Rating")
        if dioramaLabel then
            dioramaLabel.Text = dioramaName ~= "" and dioramaName or "---"
        end
        if ratingLabel then
            ratingLabel.Text = rating > 0 and string.format("%.1f/10", rating) or "---"
        end
    end
end

local function clearDioramaRatingRow(bg, rowIndex)
    updateDioramaRatingRow(bg, rowIndex, "", "", 0)
end

--------------------------------------------------------------------------------
-- Подсчёт количества диорам, принадлежащих игроку
--------------------------------------------------------------------------------
local function getPlayerDioramaCount(userId)
    local count = 0
    local cache = _G.DioramaCache
    if cache then
        for _, diorama in pairs(cache) do
            if diorama.OwnerId == userId then
                count = count + 1
            end
        end
    end
    return count
end

--------------------------------------------------------------------------------
-- Создание leaderstats для игрока (Tab-список)
--------------------------------------------------------------------------------
local function createLeaderstats(player)
    -- Удаляем старые leaderstats если есть
    local existing = player:FindFirstChild("leaderstats")
    if existing then
        existing.Parent = nil
    end

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"

    local goldValue = Instance.new("IntValue")
    goldValue.Name = "Золото"
    goldValue.Value = 0
    goldValue.Parent = leaderstats

    local dioramasValue = Instance.new("IntValue")
    dioramasValue.Name = "Диорамы"
    dioramasValue.Value = 0
    dioramasValue.Parent = leaderstats

    local prestigeValue = Instance.new("IntValue")
    prestigeValue.Name = "Перерождения"
    prestigeValue.Value = 0
    prestigeValue.Parent = leaderstats

    leaderstats.Parent = player

    playerLeaderstats[player.UserId] = {
        gold = goldValue,
        dioramas = dioramasValue,
        prestige = prestigeValue,
    }

    -- Сразу обновляем значения если данные загружены
    if DataManager.IsDataLoaded(player) then
        local data = DataManager.GetData(player)
        if data then
            goldValue.Value = data.Gold or 0
            prestigeValue.Value = data.PrestigeLevel or 0
        end
    end
    dioramasValue.Value = getPlayerDioramaCount(player.UserId)

    print(string.format("[LeaderboardManager] Leaderstats созданы для %s", player.Name))
end

--------------------------------------------------------------------------------
-- Обновление значений leaderstats для всех игроков
--------------------------------------------------------------------------------
local function updateAllLeaderstats()
    for _, player in ipairs(Players:GetPlayers()) do
        local stats = playerLeaderstats[player.UserId]
        if stats and DataManager.IsDataLoaded(player) then
            local data = DataManager.GetData(player)
            if data then
                stats.gold.Value = data.Gold or 0
                stats.prestige.Value = data.PrestigeLevel or 0
            end
            stats.dioramas.Value = getPlayerDioramaCount(player.UserId)
        end
    end
end

--------------------------------------------------------------------------------
-- 2. Запись данных текущих игроков сервера в OrderedDataStore
--------------------------------------------------------------------------------
local function writePlayerDataToStore()
    for _, player in ipairs(Players:GetPlayers()) do
        if waitForDataLoaded(player) then
            local data, err = DataManager.GetData(player)
            if data and data.Stats then
                local totalGoldEarned = data.Stats.TotalGoldEarned or 0
                local prestigeLevel = data.PrestigeLevel or 0
                local userId = player.UserId
                local now = os.time()

                -- Debounce: пропускаем если данные не изменились или прошло мало времени
                local last = lastWrittenData[userId]
                if last and (now - last.time) < WRITE_DEBOUNCE
                    and last.totalGoldEarned == totalGoldEarned and last.prestige == prestigeLevel then
                    -- продолжаем к следующему игроку
                else
                    -- Записываем TotalGoldEarned
                    if totalGoldEarned > 0 then
                        pcall(function()
                            totalGoldEarnedStore:SetAsync(tostring(userId), totalGoldEarned)
                        end)
                    end

                    -- Записываем Prestige
                    if prestigeLevel > 0 then
                        pcall(function()
                            prestigeStore:SetAsync(tostring(userId), prestigeLevel)
                        end)
                    end

                    lastWrittenData[userId] = { totalGoldEarned = totalGoldEarned, prestige = prestigeLevel, time = now }

                    -- Кешируем имя
                    playerNameCache[userId] = player.DisplayName
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 3. Запись данных диорам в DataStore
--------------------------------------------------------------------------------
local function writeDioramaDataToStore()
    local dioramaList = {}
    local cache = _G.DioramaCache

    if cache then
        for dioramaId, diorama in pairs(cache) do
            local currentPrice = diorama.CurrentPrice or 0
            local ownerId = diorama.OwnerId
            local sceneName = diorama.SceneName or "Unknown"

            if currentPrice > 0 and ownerId then
                table.insert(dioramaList, {
                    ownerId = ownerId,
                    ownerName = diorama.OwnerName or getPlayerName(ownerId),
                    dioramaName = sceneName,
                    price = currentPrice,
                })
            end
        end
    else
        -- Fallback: атрибуты моделей
        local dioramasFolder = workspace:FindFirstChild("Dioramas")
        if dioramasFolder then
            for _, dioramaModel in ipairs(dioramasFolder:GetChildren()) do
                if dioramaModel:IsA("Model") then
                    local price = dioramaModel:GetAttribute("CurrentPrice") or 0
                    local sceneName = dioramaModel:GetAttribute("SceneName") or "Unknown"
                    local ownerId = dioramaModel:GetAttribute("OwnerId") or 0
                    if price > 0 and ownerId > 0 then
                        table.insert(dioramaList, {
                            ownerId = ownerId,
                            ownerName = getPlayerName(ownerId),
                            dioramaName = sceneName,
                            price = price,
                        })
                    end
                end
            end
        end
    end

    -- Сортировка по цене
    table.sort(dioramaList, function(a, b) return a.price > b.price end)

    -- Берём топ
    local topDioramas = {}
    for i = 1, math.min(#dioramaList, TOP_COUNT) do
        table.insert(topDioramas, dioramaList[i])
    end

    -- Сохраняем в DataStore
    pcall(function()
        dioramaStore:SetAsync("TopDioramas", HttpService:JSONEncode(topDioramas))
    end)
end

--------------------------------------------------------------------------------
-- 3b. Запись данных рейтингов диорам в DataStore
--------------------------------------------------------------------------------
local function writeDioramaRatingDataToStore()
    local dioramaList = {}
    local cache = _G.DioramaCache

    if cache then
        for dioramaId, diorama in pairs(cache) do
            local rating = diorama.Rating or 0
            local upvotes = diorama.Upvotes or 0
            local downvotes = diorama.Downvotes or 0
            local ownerId = diorama.OwnerId
            local sceneName = diorama.SceneName or "Unknown"

            -- Только диорамы с хотя бы одним голосом
            if (upvotes + downvotes) > 0 and ownerId then
                table.insert(dioramaList, {
                    ownerId = ownerId,
                    ownerName = diorama.OwnerName or getPlayerName(ownerId),
                    dioramaName = sceneName,
                    rating = rating,
                    upvotes = upvotes,
                    downvotes = downvotes,
                })
            end
        end
    else
        -- Fallback: атрибуты моделей
        local dioramasFolder = workspace:FindFirstChild("Dioramas")
        if dioramasFolder then
            for _, dioramaModel in ipairs(dioramasFolder:GetChildren()) do
                if dioramaModel:IsA("Model") then
                    local rating = dioramaModel:GetAttribute("Rating") or 0
                    local upvotes = dioramaModel:GetAttribute("Upvotes") or 0
                    local downvotes = dioramaModel:GetAttribute("Downvotes") or 0
                    local sceneName = dioramaModel:GetAttribute("SceneName") or "Unknown"
                    local ownerId = dioramaModel:GetAttribute("OwnerId") or 0
                    if (upvotes + downvotes) > 0 and ownerId > 0 then
                        table.insert(dioramaList, {
                            ownerId = ownerId,
                            ownerName = getPlayerName(ownerId),
                            dioramaName = sceneName,
                            rating = rating,
                            upvotes = upvotes,
                            downvotes = downvotes,
                        })
                    end
                end
            end
        end
    end

    -- Сортировка по рейтингу (по убыванию)
    table.sort(dioramaList, function(a, b) return a.rating > b.rating end)

    -- Берём топ
    local topDioramas = {}
    for i = 1, math.min(#dioramaList, TOP_COUNT) do
        table.insert(topDioramas, dioramaList[i])
    end

    -- Сохраняем в DataStore
    pcall(function()
        dioramaRatingStore:SetAsync("TopRatedDioramas", HttpService:JSONEncode(topDioramas))
    end)
end

--------------------------------------------------------------------------------
-- 4. Чтение глобального топа из OrderedDataStore
--------------------------------------------------------------------------------
local function fetchGlobalLeaderboard(store, valueSuffix)
    local result = {}

    local success, pages = pcall(function()
        return store:GetSortedAsync(false, TOP_COUNT)
    end)

    if not success or not pages then
        warn("[LeaderboardManager] Ошибка чтения OrderedDataStore:", tostring(pages))
        return result
    end

    local rank = 1
    local currentPage = pages:GetCurrentPage()

    for _, entry in ipairs(currentPage) do
        local userId = tonumber(entry.key)
        local value = entry.value

        if userId and value and value > 0 and rank <= TOP_COUNT then
            table.insert(result, {
                name = getPlayerName(userId),
                value = value,
            })
            rank = rank + 1
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- 5. Чтение глобального топа диорам из DataStore
--------------------------------------------------------------------------------
local function fetchGlobalDioramaLeaderboard()
    local result = {}

    local success, raw = pcall(function()
        return dioramaStore:GetAsync("TopDioramas")
    end)

    if not success or not raw or type(raw) ~= "string" then
        return result
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not ok or type(data) ~= "table" then
        return result
    end

    for _, entry in ipairs(data) do
        table.insert(result, {
            ownerName = entry.ownerName or getPlayerName(entry.ownerId or 0),
            dioramaName = entry.dioramaName or "---",
            price = entry.price or 0,
        })
    end

    return result
end

--------------------------------------------------------------------------------
-- 5b. Чтение глобального топа рейтинговых диорам из DataStore
--------------------------------------------------------------------------------
local function fetchGlobalDioramaRatingLeaderboard()
    local result = {}

    local success, raw = pcall(function()
        return dioramaRatingStore:GetAsync("TopRatedDioramas")
    end)

    if not success or not raw or type(raw) ~= "string" then
        return result
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not ok or type(data) ~= "table" then
        return result
    end

    for _, entry in ipairs(data) do
        table.insert(result, {
            ownerName = entry.ownerName or getPlayerName(entry.ownerId or 0),
            dioramaName = entry.dioramaName or "---",
            rating = entry.rating or 0,
        })
    end

    return result
end

--------------------------------------------------------------------------------
-- Обновление всех таблиц (глобальные данные)
--------------------------------------------------------------------------------
local function updateLeaderboards()
    -- Prestige Board
    if boards.PrestigeBoard then
        local prestigeList = fetchGlobalLeaderboard(prestigeStore)
        for i = 1, TOP_COUNT do
            if i <= #prestigeList then
                updatePlayerRow(boards.PrestigeBoard, i, prestigeList[i].name, prestigeList[i].value, "")
            else
                clearPlayerRow(boards.PrestigeBoard, i)
            end
        end
    end

    -- Total Gold Earned Board
    if boards.TotalGoldEarnedBoard then
        local goldList = fetchGlobalLeaderboard(totalGoldEarnedStore)
        for i = 1, TOP_COUNT do
            if i <= #goldList then
                updatePlayerRow(boards.TotalGoldEarnedBoard, i, goldList[i].name, goldList[i].value, "")
            else
                clearPlayerRow(boards.TotalGoldEarnedBoard, i)
            end
        end
    end

    -- Diorama Board
    if boards.DioramaBoard then
        local dioramaList = fetchGlobalDioramaLeaderboard()
        for i = 1, TOP_COUNT do
            if i <= #dioramaList then
                updateDioramaRow(boards.DioramaBoard, i, dioramaList[i].ownerName, dioramaList[i].dioramaName, dioramaList[i].price)
            else
                clearDioramaRow(boards.DioramaBoard, i)
            end
        end
    end

    -- Diorama Rating Board
    if boards.DioramaRatingBoard then
        local ratingList = fetchGlobalDioramaRatingLeaderboard()
        for i = 1, TOP_COUNT do
            if i <= #ratingList then
                updateDioramaRatingRow(boards.DioramaRatingBoard, i, ratingList[i].ownerName, ratingList[i].dioramaName, ratingList[i].rating)
            else
                clearDioramaRatingRow(boards.DioramaRatingBoard, i)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 6. MessagingService — подписка и публикация
--------------------------------------------------------------------------------
local function ensureMessagingSubscription()
    if messagingSubscribed then return end
    messagingSubscribed = true

    local success, err = pcall(function()
        MessagingService:SubscribeAsync(LEADERBOARD_TOPIC, function(message)
            local data = message.Data

            -- Игнорируем собственные сообщения
            if data.SourceServer == SERVER_UUID then
                return
            end

            print("[LeaderboardManager] Получено межсерверное обновление от", tostring(data.SourceServer))
            needsRefresh = true
        end)
    end)

    if success then
        print("[LeaderboardManager] ✓ MessagingService подписка установлена")
    else
        warn("[LeaderboardManager] ✗ Ошибка подписки MessagingService:", err)
        messagingSubscribed = false
    end
end

local function publishLeaderboardUpdate(updateType)
    local messageData = {
        SourceServer = SERVER_UUID,
        UpdateType = updateType, -- "total_gold", "prestige", "diorama"
        Timestamp = os.time(),
    }

    pcall(function()
        MessagingService:PublishAsync(LEADERBOARD_TOPIC, messageData)
    end)
end

--------------------------------------------------------------------------------
-- Основной цикл обновления
--------------------------------------------------------------------------------
local function mainLoop()
    -- Ждём загрузки досок
    while not findBoards() do
        warn("[LeaderboardManager] Ожидание досок лидеров...")
        task.wait(5)
    end

    -- Ждём загрузки dioramaCache
    while not _G.DioramaCache do
        task.wait(2)
    end

    -- Подписываемся на MessagingService
    ensureMessagingSubscription()

    print("[LeaderboardManager] Доски найдены, запуск обновлений")

    -- Первоначальная запись данных текущих игроков в DataStore
    pcall(writePlayerDataToStore)
    pcall(writeDioramaDataToStore)
    pcall(writeDioramaRatingDataToStore)

    -- Первоначальное обновление UI
    pcall(updateLeaderboards)

    -- Периодический цикл
    local writeCycleCounter = 0
    local WRITE_CYCLE_EVERY = 2 -- записывать данные в DataStore каждые N циклов

    while true do
        task.wait(UPDATE_INTERVAL)

        -- Проверяем флаг мгновенного обновления от MessagingService
        local forceRefresh = needsRefresh
        needsRefresh = false

        writeCycleCounter = writeCycleCounter + 1

        -- Периодическая запись данных текущих игроков в DataStore
        if writeCycleCounter >= WRITE_CYCLE_EVERY then
            writeCycleCounter = 0
            pcall(writePlayerDataToStore)
            pcall(writeDioramaDataToStore)
            pcall(writeDioramaRatingDataToStore)
        end

        -- Обновление UI (всегда, т.к. данные могли измениться на других серверах)
        local success, err = pcall(updateLeaderboards)
        if not success then
            warn("[LeaderboardManager] Ошибка обновления:", tostring(err))
        end

        -- Если были межсерверные обновления — публикуем свои данные тоже
        if forceRefresh then
            pcall(writePlayerDataToStore)
            pcall(writeDioramaDataToStore)
            pcall(writeDioramaRatingDataToStore)
            pcall(updateLeaderboards)
        end
    end
end

--------------------------------------------------------------------------------
-- Подписка на события игроков
--------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    -- Создаём leaderstats сразу при входе
    task.spawn(function()
        if waitForDataLoaded(player) then
            createLeaderstats(player)
        end
    end)

    task.delay(10, function()
        -- Записываем данные нового игрока в DataStore
        pcall(writePlayerDataToStore)
        -- Обновляем UI
        pcall(updateLeaderboards)
        -- Уведомляем другие серверы
        publishLeaderboardUpdate("player_added")
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    -- Перед уходом — финальная запись данных
    local userId = player.UserId
    if waitForDataLoaded(player) then
        local data = DataManager.GetData(player)
        if data and data.Stats then
            local totalGoldEarned = data.Stats.TotalGoldEarned or 0
            local prestigeLevel = data.PrestigeLevel or 0
            if totalGoldEarned > 0 then
                pcall(function() totalGoldEarnedStore:SetAsync(tostring(userId), totalGoldEarned) end)
            end
            if prestigeLevel > 0 then
                pcall(function() prestigeStore:SetAsync(tostring(userId), prestigeLevel) end)
            end
        end
    end

    -- Очищаем debounce-кеш и leaderstats
    lastWrittenData[userId] = nil
    playerLeaderstats[userId] = nil

    task.delay(3, function()
        pcall(updateLeaderboards)
        publishLeaderboardUpdate("player_removed")
    end)
end)

--------------------------------------------------------------------------------
-- Цикл обновления leaderstats (Tab-список)
--------------------------------------------------------------------------------
local function leaderstatsLoop()
    -- Ждём загрузки AssetService и DioramaCache
    while not _G.DioramaCache do
        task.wait(2)
    end

    print("[LeaderboardManager] Запуск цикла обновления leaderstats")

    while true do
        task.wait(LEADERSTATS_UPDATE_INTERVAL)
        pcall(updateAllLeaderstats)
    end
end

--------------------------------------------------------------------------------
-- Создание leaderstats для уже подключённых игроков
--------------------------------------------------------------------------------
task.spawn(function()
    -- Ждём загрузки AssetService
    if not waitForAssetService() then return end
    -- Ждём загрузки DioramaCache
    while not _G.DioramaCache do
        task.wait(2)
    end
    -- Создаём leaderstats для всех текущих игроков
    for _, player in ipairs(Players:GetPlayers()) do
        if waitForDataLoaded(player) then
            createLeaderstats(player)
        end
    end
end)

task.spawn(mainLoop)
task.spawn(leaderstatsLoop)

print("[LeaderboardManager] Инициализация завершена (Cross-Server)")