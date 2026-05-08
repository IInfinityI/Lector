-- DioramaClass
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local DioramaConfig = require(script.Parent:WaitForChild("DioramaConfig"))
local DioramaUtils = require(script.Parent:WaitForChild("DioramaUtils"))
local DioramaCustomization = require(script.Parent:WaitForChild("DioramaCustomization"))
local DioramaTemplates = require(script.Parent:WaitForChild("DioramaTemplates"))

local Diorama = {}
Diorama.__index = Diorama

-- Константы для DataStore
local DATASTORE_CRITICAL = "DioramasData"
local DATASTORE_CUSTOMIZATION = "DioramaCustomization"
local DATASTORE_PENDING_PAYMENTS = "PendingGoldPayments"
local DATASTORE_USED_GAMEPASSES = DioramaConfig.DATASTORE_USED_GAMEPASSES
local MEMORYSTORE_LOCKS = "DioramaLocks"
local MEMORYSTORE_CRITICAL_CACHE = "DioramaCriticalCache"
local MEMORYSTORE_CUST_CACHE = "DioramaCustCache"
local MEMORYSTORE_PENDING_CACHE = "PendingPaymentsCache"
local MEMORYSTORE_USED_GAMEPASSES = DioramaConfig.MEMORYSTORE_USED_GAMEPASSES
local MEMORYSTORE_ACTIVE_GAMEPASSES = "ActiveDioramaGamePasses" -- Новая константа для активных привязок
local CRITICAL_TOPIC = DioramaConfig.DIORAMA_CRITICAL_UPDATES_TOPIC
local PENDING_PAYMENTS_TOPIC = DioramaConfig.PENDING_GOLD_PAYMENTS_TOPIC
local ACTIVE_GAMEPASS_TOPIC = "ActiveGamePassUpdates" -- Топик для синхронизации активных GamePass

-- Уникальный идентификатор сервера (генерируется один раз при старте)
local SERVER_UUID = HttpService:GenerateGUID(false)
print(string.format("[DioramaClass] Сервер UUID: %s", SERVER_UUID))

-- Глобальный менеджер очереди сохранений
local SaveQueue = {
    pendingSaves = {},
    lastSaveTime = {},
    rateLimits = DioramaConfig.DATASTORE_RATE_LIMITS
}

-- Глобальный кеш для MessagingService подписок
local messagingSubscribed = false
local pendingPaymentsSubscribed = false
local activeGamePassSubscribed = false
local dioramaInstances = {}

-- DataStore для отложенных начислений (ленивая инициализация)
local pendingPaymentsStore = nil
local pendingPaymentsCache = nil

-- DataStore для отслеживания использованных GamePass (ленивая инициализация)
local usedGamePassStore = nil
local usedGamePassCache = nil
local activeGamePassStore = nil
local activeGamePassLocalCache = {}

-- Подписка на критические обновления от других серверов
local function ensureMessagingSubscription()
    if messagingSubscribed then 
        print("[DioramaClass] MessagingService уже подписан")
        return 
    end
    messagingSubscribed = true
    
    print("[DioramaClass] Установка подписки на MessagingService для топика:", CRITICAL_TOPIC)
    
    local success, err = pcall(function()
        MessagingService:SubscribeAsync(CRITICAL_TOPIC, function(message)
            local data = message.Data
            
            -- Игнорируем свои собственные сообщения
            if data.SourceServer == SERVER_UUID then 
                return 
            end
            
            local dioramaId = data.DioramaId
            local updateData = data.UpdateData
            
            print(string.format("[DioramaClass] ========== CROSS-SERVER UPDATE =========="))
            print(string.format("[DioramaClass] Диорама: %s, Сервер-источник: %s", 
                tostring(dioramaId), tostring(data.SourceServer)))
            print(string.format("[DioramaClass] Версия полученная: %d", updateData.CriticalVersion or 0))
            
            local diorama = dioramaInstances[dioramaId]
            if not diorama then
                print(string.format("[DioramaClass] Диорама %s не найдена в кеше, пропускаем", tostring(dioramaId)))
                return
            end
            
            print(string.format("[DioramaClass] Локальная версия: %d, Полученная версия: %d", 
                diorama.CriticalVersion, updateData.CriticalVersion))
            
            -- Проверяем версию - применяем только если новее
            if updateData.CriticalVersion <= diorama.CriticalVersion then
                print(string.format("[DioramaClass] Версия не новее, пропускаем"))
                return
            end
            
            -- Проверяем транзакцию - если занята, всё равно применяем обновление
            -- но не вызываем callback (чтобы не конфликтовать с локальной операцией)
            local wasInTransaction = diorama.transactionInProgress
            if wasInTransaction then
                print(string.format("[DioramaClass] Диорама занята транзакцией, применяем обновление без callback"))
            end
            
            -- Применяем обновление
            local applied, changeInfo = diorama:ApplyCriticalUpdate(updateData)
            
            if applied then
                print(string.format("[DioramaClass] Обновление успешно применено для %s", tostring(dioramaId)))
                
                -- Вызываем callback только если не было активной транзакции
                if not wasInTransaction and diorama.callbacks and diorama.callbacks.onRemoteUpdate then
                    print(string.format("[DioramaClass] Вызов onRemoteUpdate callback"))
                    diorama.callbacks.onRemoteUpdate(updateData, changeInfo)
                end
            else
                print(string.format("[DioramaClass] Обновление НЕ применено для %s", tostring(dioramaId)))
            end
            
            print(string.format("[DioramaClass] ========== END CROSS-SERVER UPDATE =========="))
        end)
    end)
    
    if success then
        print("[DioramaClass] ✓ MessagingService подписка успешно установлена")
    else
        warn("[DioramaClass] ✗ Ошибка подписки MessagingService:", err)
        messagingSubscribed = false -- Сбрасываем флаг чтобы можно было попробовать снова
    end
end

-- Публикация критического обновления на все серверы
local function publishCriticalUpdate(dioramaId, updateData)
    local messageData = {
        DioramaId = dioramaId,
        UpdateData = updateData,
        SourceServer = SERVER_UUID,
        Timestamp = os.time()
    }
    
    print(string.format("[DioramaClass] Публикация критического обновления для %s (версия %d) на все серверы", 
        tostring(dioramaId), updateData.CriticalVersion or 0))
    
    local success, err = pcall(function()
        MessagingService:PublishAsync(CRITICAL_TOPIC, messageData)
    end)
    
    if success then
        print(string.format("[DioramaClass] Успешно опубликовано обновление для %s", tostring(dioramaId)))
    else
        warn(string.format("[DioramaClass] Ошибка публикации для %s: %s", tostring(dioramaId), tostring(err)))
    end
end

-- Получение MemoryStore для активных GamePass
local function getActiveGamePassStore()
    if not activeGamePassStore then
        activeGamePassStore = MemoryStoreService:GetSortedMap(MEMORYSTORE_ACTIVE_GAMEPASSES)
    end
    return activeGamePassStore
end

-- Проверка, активен ли GamePass на другой диораме
local function isGamePassActiveOnOtherDiorama(gamePassId, currentDioramaId)
    if not gamePassId then return false end
    
    local store = getActiveGamePassStore()
    local passKey = tostring(gamePassId)
    
    -- Сначала проверяем локальный кеш (быстро)
    if activeGamePassLocalCache[passKey] then
        local cachedDioramaId = activeGamePassLocalCache[passKey]
        if cachedDioramaId ~= currentDioramaId then
            print(string.format("[DioramaClass] GamePass %d активен на другой диораме (локальный кеш): %s", 
                gamePassId, tostring(cachedDioramaId)))
            return true
        end
        return false
    end
    
    -- Проверяем MemoryStore
    local success, result = pcall(function()
        return store:GetAsync(passKey)
    end)
    
    if success and result then
        -- Обновляем локальный кеш
        activeGamePassLocalCache[passKey] = result.dioramaId
        if result.dioramaId ~= currentDioramaId then
            print(string.format("[DioramaClass] GamePass %d активен на другой диораме (MemoryStore): %s", 
                gamePassId, tostring(result.dioramaId)))
            return true
        end
    end
    
    return false
end

-- Публикация обновления активного GamePass на все серверы
local function publishActiveGamePassUpdate(gamePassId, dioramaId, ownerId, action)
    local messageData = {
        GamePassId = gamePassId,
        DioramaId = dioramaId,
        OwnerId = ownerId,
        Action = action, -- "register" или "unregister"
        SourceServer = SERVER_UUID,
        Timestamp = os.time()
    }
    
    local success, err = pcall(function()
        MessagingService:PublishAsync(ACTIVE_GAMEPASS_TOPIC, messageData)
    end)
    
    if not success then
        warn(string.format("[DioramaClass] Ошибка публикации обновления активного GamePass: %s", tostring(err)))
    end
end

-- Регистрация активного GamePass для диорамы
local function registerActiveGamePass(gamePassId, dioramaId, ownerId)
    if not gamePassId then return false end
    
    local store = getActiveGamePassStore()
    local passKey = tostring(gamePassId)
    
    local registrationData = {
        dioramaId = dioramaId,
        ownerId = ownerId,
        timestamp = os.time(),
        serverId = SERVER_UUID
    }
    
    -- Атомарная запись в MemoryStore
    local success, result = pcall(function()
        return store:UpdateAsync(passKey, function(oldValue)
            if oldValue ~= nil and oldValue.dioramaId ~= dioramaId then
                -- GamePass уже привязан к другой диораме
                return nil
            end
            return registrationData
        end, DioramaConfig.ACTIVE_GAMEPASS_TTL or 86400) -- TTL 24 часа по умолчанию
    end)
    
    if success and result then
        activeGamePassLocalCache[passKey] = dioramaId
        print(string.format("[DioramaClass] GamePass %d зарегистрирован для диорамы %s", gamePassId, tostring(dioramaId)))
        
        -- Публикуем обновление для других серверов
        publishActiveGamePassUpdate(gamePassId, dioramaId, ownerId, "register")
        return true
    end
    
    return false
end

-- Удаление регистрации активного GamePass
local function unregisterActiveGamePass(gamePassId, dioramaId)
    if not gamePassId then return false end
    
    local store = getActiveGamePassStore()
    local passKey = tostring(gamePassId)
    
    -- Проверяем, что GamePass принадлежит именно этой диораме
    local success, currentData = pcall(function()
        return store:GetAsync(passKey)
    end)
    
    if success and currentData and currentData.dioramaId == dioramaId then
        pcall(function()
            store:RemoveAsync(passKey)
        end)
        
        activeGamePassLocalCache[passKey] = nil
        print(string.format("[DioramaClass] GamePass %d удалён с диорамы %s", gamePassId, tostring(dioramaId)))
        
        -- Публикуем обновление для других серверов
        publishActiveGamePassUpdate(gamePassId, dioramaId, nil, "unregister")
        return true
    end
    
    return false
end

-- Подписка на обновления активных GamePass
local function ensureActiveGamePassSubscription()
    if activeGamePassSubscribed then 
        return 
    end
    activeGamePassSubscribed = true
    
    print("[DioramaClass] Установка подписки на ActiveGamePass обновления")
    
    local success, err = pcall(function()
        MessagingService:SubscribeAsync(ACTIVE_GAMEPASS_TOPIC, function(message)
            local data = message.Data
            
            -- Игнорируем свои сообщения
            if data.SourceServer == SERVER_UUID then 
                return 
            end
            
            local gamePassId = data.GamePassId
            local dioramaId = data.DioramaId
            local action = data.Action
            local passKey = tostring(gamePassId)
            
            if action == "register" then
                activeGamePassLocalCache[passKey] = dioramaId
                print(string.format("[DioramaClass] Кеш обновлён: GamePass %d -> диорама %s", gamePassId, tostring(dioramaId)))
            elseif action == "unregister" then
                if activeGamePassLocalCache[passKey] == dioramaId then
                    activeGamePassLocalCache[passKey] = nil
                    print(string.format("[DioramaClass] Кеш обновлён: GamePass %d удалён", gamePassId))
                end
            end
        end)
    end)
    
    if not success then
        warn("[DioramaClass] Ошибка подписки на ActiveGamePass обновления:", err)
        activeGamePassSubscribed = false
    end
end

-- ==================== СИСТЕМА ОТЛОЖЕННЫХ НАЧИСЛЕНИЙ ====================

-- Получение DataStore для отложенных начислений
local function getPendingPaymentsStore()
    if not pendingPaymentsStore then
        pendingPaymentsStore = DataStoreService:GetDataStore(DATASTORE_PENDING_PAYMENTS)
    end
    return pendingPaymentsStore
end

-- Получение MemoryStore кеша для отложенных начислений
local function getPendingPaymentsCache()
    if not pendingPaymentsCache then
        pendingPaymentsCache = MemoryStoreService:GetSortedMap(MEMORYSTORE_PENDING_CACHE)
    end
    return pendingPaymentsCache
end

-- Сохранение отложенного начисления
local function savePendingPayment(userId, amount, dioramaId, sceneName)
    if amount <= 0 then return true end
    
    local store = getPendingPaymentsStore()
    local key = tostring(userId)
    
    print(string.format("[DioramaClass] Сохранение отложенного начисления: UserId=%d, Amount=%d, DioramaId=%s", 
        userId, amount, tostring(dioramaId)))
    
    local success, err = pcall(function()
        store:UpdateAsync(key, function(oldData)
            local data = oldData or { payments = {}, totalAmount = 0 }
            
            -- Добавляем новое начисление
            table.insert(data.payments, {
                amount = amount,
                dioramaId = dioramaId,
                sceneName = sceneName,
                timestamp = os.time()
            })
            
            data.totalAmount = (data.totalAmount or 0) + amount
            
            return HttpService:JSONEncode(data)
        end)
    end)
    
    if success then
        -- Обновляем MemoryStore кеш
        local cache = getPendingPaymentsCache()
        pcall(function()
            cache:SetAsync(key, { totalAmount = amount, timestamp = os.time() }, DioramaConfig.CACHE_TTL)
        end)
        
        print(string.format("[DioramaClass] Отложенное начисление сохранено для UserId=%d", userId))
        return true
    else
        warn(string.format("[DioramaClass] Ошибка сохранения отложенного начисления: %s", tostring(err)))
        return false
    end
end

-- Публикация сообщения о отложенном начислении на все серверы
local function publishPendingPayment(userId, amount, dioramaId, sceneName)
    local messageData = {
        UserId = userId,
        Amount = amount,
        DioramaId = dioramaId,
        SceneName = sceneName,
        SourceServer = SERVER_UUID,
        Timestamp = os.time()
    }
    
    print(string.format("[DioramaClass] Публикация отложенного начисления для UserId=%d, Amount=%d", userId, amount))
    
    local success, err = pcall(function()
        MessagingService:PublishAsync(PENDING_PAYMENTS_TOPIC, messageData)
    end)
    
    if success then
        print(string.format("[DioramaClass] Успешно опубликовано отложенное начисление для UserId=%d", userId))
    else
        warn(string.format("[DioramaClass] Ошибка публикации отложенного начисления: %s", tostring(err)))
    end
    
    return success
end

-- Подписка на сообщения о отложенных начислениях
local function ensurePendingPaymentsSubscription()
    if pendingPaymentsSubscribed then 
        print("[DioramaClass] PendingPayments MessagingService уже подписан")
        return 
    end
    pendingPaymentsSubscribed = true
    
    print("[DioramaClass] Установка подписки на PendingPayments MessagingService для топика:", PENDING_PAYMENTS_TOPIC)
    
    local success, err = pcall(function()
        MessagingService:SubscribeAsync(PENDING_PAYMENTS_TOPIC, function(message)
            local data = message.Data
            
            -- Игнорируем свои собственные сообщения
            if data.SourceServer == SERVER_UUID then 
                return 
            end
            
            local userId = data.UserId
            local amount = data.Amount
            local dioramaId = data.DioramaId
            local sceneName = data.SceneName
            
            print(string.format("[DioramaClass] Получено сообщение о отложенном начислении: UserId=%d, Amount=%d, DioramaId=%s", 
                userId, amount, tostring(dioramaId)))
            
            -- Проверяем, есть ли игрок на этом сервере
            local player = Players:GetPlayerByUserId(userId)
            if player then
                print(string.format("[DioramaClass] Игрок %s найден на сервере, начисляем золото", player.Name))
                
                -- Начисляем золото
                local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
                if EventSystem then
                    local success, result = EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, amount)
                    if success then
                        -- Уведомляем игрока
                        EventSystem.FireClient(player, "PendingGoldReceived", {
                            amount = amount,
                            dioramaId = dioramaId,
                            sceneName = sceneName,
                            isAccumulatedIncome = true
                        })
                        
                        -- Удаляем запись о отложенном начислении для этой диорамы
                        local store = getPendingPaymentsStore()
                        pcall(function()
                            store:UpdateAsync(tostring(userId), function(oldData)
                                if not oldData then return nil end
                                
                                local decoded = type(oldData) == "string" and HttpService:JSONDecode(oldData) or oldData
                                if not decoded or not decoded.payments then return nil end
                                
                                -- Удаляем начисление для этой диорамы
                                local newPayments = {}
                                local newTotal = 0
                                for _, payment in ipairs(decoded.payments) do
                                    if payment.dioramaId ~= dioramaId then
                                        table.insert(newPayments, payment)
                                        newTotal = newTotal + payment.amount
                                    end
                                end
                                
                                if #newPayments == 0 then
                                    return nil -- Удаляем запись полностью
                                end
                                
                                decoded.payments = newPayments
                                decoded.totalAmount = newTotal
                                return HttpService:JSONEncode(decoded)
                            end)
                        end)
                        
                        -- Также очищаем MemoryStore кеш
                        local cache = getPendingPaymentsCache()
                        pcall(function()
                            cache:RemoveAsync(tostring(userId))
                        end)
                        
                        print(string.format("[DioramaClass] ✓ Золото начислено игроку %s: %d (накопленный доход с диорамы %s)", 
                            player.Name, amount, tostring(dioramaId)))
                    else
                        warn(string.format("[DioramaClass] Ошибка начисления золота: %s", tostring(result)))
                    end
                end
            else
                print(string.format("[DioramaClass] Игрок UserId=%d не найден на сервере, начисление останется в DataStore", userId))
            end
        end)
    end)
    
    if success then
        print("[DioramaClass] ✓ PendingPayments MessagingService подписка успешно установлена")
    else
        warn("[DioramaClass] ✗ Ошибка подписки PendingPayments MessagingService:", err)
        pendingPaymentsSubscribed = false
    end
end

-- Обработка отложенных начислений при входе игрока
function Diorama.ProcessPendingPaymentsForPlayer(player)
    if not player then return end
    
    local userId = player.UserId
    local store = getPendingPaymentsStore()
    
    print(string.format("[DioramaClass] Проверка отложенных начислений для игрока %s (UserId=%d)", player.Name, userId))
    
    local success, dataJson = pcall(function()
        return store:GetAsync(tostring(userId))
    end)
    
    if not success then
        warn(string.format("[DioramaClass] Ошибка чтения отложенных начислений для игрока %s", player.Name))
        return
    end
    
    if not dataJson then
        print(string.format("[DioramaClass] Нет отложенных начислений для игрока %s", player.Name))
        return
    end
    
    local data = type(dataJson) == "string" and HttpService:JSONDecode(dataJson) or dataJson
    if not data or not data.payments or #data.payments == 0 then
        print(string.format("[DioramaClass] Нет отложенных начислений для игрока %s", player.Name))
        return
    end
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        warn("[DioramaClass] EventSystem не доступен для обработки отложенных начислений")
        return
    end
    
    local totalAmount = data.totalAmount or 0
    print(string.format("[DioramaClass] Найдено %d отложенных начислений для игрока %s, всего: %d золота", 
        #data.payments, player.Name, totalAmount))
    
    -- Начисляем общую сумму
    local goldSuccess, goldResult = EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, totalAmount)
    if goldSuccess then
        -- Отправляем детальную информацию о каждом начислении
        for _, payment in ipairs(data.payments) do
            EventSystem.FireClient(player, "PendingGoldReceived", {
                amount = payment.amount,
                dioramaId = payment.dioramaId,
                sceneName = payment.sceneName,
                isAccumulatedIncome = true,
                timestamp = payment.timestamp
            })
        end
        
        -- Удаляем запись о отложенных начислениях
        pcall(function()
            store:SetAsync(tostring(userId), nil)
        end)
        
        -- Также очищаем MemoryStore кеш
        local cache = getPendingPaymentsCache()
        pcall(function()
            cache:RemoveAsync(tostring(userId))
        end)
        
        print(string.format("[DioramaClass] ✓ Начислено %d золота игроку %s из отложенных платежей (%d начислений)", 
            totalAmount, player.Name, #data.payments))
    else
        warn(string.format("[DioramaClass] Ошибка начисления отложенного золота: %s", tostring(goldResult)))
    end
end

-- Получение DataStore для использованных GamePass
local function getUsedGamePassStore()
    if not usedGamePassStore then
        usedGamePassStore = DataStoreService:GetDataStore(DATASTORE_USED_GAMEPASSES)
    end
    return usedGamePassStore
end

-- Получение MemoryStore кеша для использованных GamePass
local function getUsedGamePassCache()
    if not usedGamePassCache then
        usedGamePassCache = MemoryStoreService:GetSortedMap(MEMORYSTORE_USED_GAMEPASSES)
    end
    return usedGamePassCache
end

-- Проверка, был ли GamePass уже использован для продажи
function Diorama.IsGamePassUsed(gamePassId)
    if not gamePassId then return false end
    
    local passKey = tostring(gamePassId)
    
    -- Сначала проверяем MemoryStore кеш (быстро)
    local cache = getUsedGamePassCache()
    local cacheSuccess, cacheResult = pcall(function()
        return cache:GetAsync(passKey)
    end)
    
    if cacheSuccess and cacheResult then
        return true
    end
    
    -- Если нет в кеше, проверяем DataStore
    local store = getUsedGamePassStore()
    local storeSuccess, storeResult = pcall(function()
        return store:GetAsync(passKey)
    end)
    
    if storeSuccess and storeResult then
        -- Нашли в DataStore — обновляем кеш для будущих проверок
        pcall(function()
            cache:SetAsync(passKey, storeResult, DioramaConfig.USED_GAMEPASS_CACHE_TTL)
        end)
        return true
    end
    
    return false
end

-- Атомарная маркировка GamePass как использованного
-- Возвращает true если успешно (пас не был использован ранее), false если уже использован
function Diorama.MarkGamePassAsUsed(gamePassId, dioramaId)
    if not gamePassId then return false end
    
    local passKey = tostring(gamePassId)
    local store = getUsedGamePassStore()
    local cache = getUsedGamePassCache()
    
    local usageData = {
        dioramaId = dioramaId,
        timestamp = os.time()
    }
    
    -- Атомарная запись через UpdateAsync
    local success, result = pcall(function()
        return store:UpdateAsync(passKey, function(oldValue)
            -- Если запись уже существует — кто-то уже использовал этот GamePass
            if oldValue ~= nil then
                return nil  -- Не перезаписываем, возвращаем nil чтобы UpdateAsync вернул старое значение
            end
            -- Записываем данные об использовании
            return HttpService:JSONEncode(usageData)
        end)
    end)
    
    if not success then
        warn(string.format("[DioramaClass] MarkGamePassAsUsed: ошибка DataStore для GamePass %s: %s", 
            tostring(gamePassId), tostring(result)))
        return false
    end
    
    -- Проверяем, что записали именно мы (а не вернулось старое значение)
    -- UpdateAsync возвращает то, что вернула callback-функция
    -- Если callback вернул nil (запись уже была), result будет nil
    if result == nil then
        -- GamePass уже был использован
        print(string.format("[DioramaClass] MarkGamePassAsUsed: GamePass %s уже был использован ранее", tostring(gamePassId)))
        return false
    end
    
    -- Успешно пометили как использованный — обновляем кеш
    pcall(function()
        cache:SetAsync(passKey, usageData, DioramaConfig.USED_GAMEPASS_CACHE_TTL)
    end)
    
    print(string.format("[DioramaClass] MarkGamePassAsUsed: GamePass %s помечен как использованный для диорамы %s", 
        tostring(gamePassId), tostring(dioramaId)))
    
    return true
end

-- Экспорт функций для использования в DioramaManager
Diorama.GetPendingPaymentsStore = getPendingPaymentsStore
Diorama.GetPendingPaymentsCache = getPendingPaymentsCache
Diorama.SavePendingPayment = savePendingPayment
Diorama.PublishPendingPayment = publishPendingPayment
Diorama.EnsurePendingPaymentsSubscription = ensurePendingPaymentsSubscription

-- Экспоненциальная задержка для retry
local function getRetryDelay(retryCount)
    local baseDelay = SaveQueue.rateLimits.RETRY_BASE_DELAY
    local maxDelay = SaveQueue.rateLimits.RETRY_MAX_DELAY
    local delay = baseDelay * math.pow(2, retryCount - 1)
    return math.min(delay, maxDelay)
end

-- Проверка, можно ли выполнять сохранение (rate limiting)
local function canSaveNow(dioramaId)
    local lastSave = SaveQueue.lastSaveTime[dioramaId] or 0
    local now = os.clock()
    return (now - lastSave) >= SaveQueue.rateLimits.MIN_SAVE_INTERVAL
end

function Diorama.new(model, dioramaId, initialData, callbacks)
    local self = setmetatable({}, Diorama)
    
    -- Основные ссылки
    self.Model = model
    self.DioramaId = dioramaId
    self.InfoPad = model:WaitForChild("InfoPad")
    self.AvatarSpots = model:WaitForChild("AvatarSpots")
    self.StandBase = model:WaitForChild("StandBase")
    
    -- GUI для InfoPad
    self.SurfaceGui = self.InfoPad:FindFirstChild("SurfaceGui")
    if not self.SurfaceGui then
        self.SurfaceGui = DioramaTemplates.createSurfaceGuiForInfoPad(self.InfoPad)
    end
    
    -- Визуальные компоненты
    self.Stand = nil
    self.Frame = nil
    self.PoseTracks = {}
    
    -- Callbacks
    self.callbacks = callbacks or {}
    
    -- Флаг транзакции - блокирует другие операции
    self.transactionInProgress = false
    self.transactionOwner = nil  -- UserId игрока, начавшего транзакцию
    self.transactionStartTime = 0
    
    -- Отслеживание изменённых полей
    self.changedFields = {}
    
    -- Инициализация данных из initialData или атрибутов
    self:InitializeData(initialData)
    
    -- Регистрируем экземпляр для cross-server синхронизации
    dioramaInstances[dioramaId] = self
    ensureMessagingSubscription()
    ensurePendingPaymentsSubscription()
    ensureActiveGamePassSubscription()
    
    if self.GamePassId then
        registerActiveGamePass(self.GamePassId, self.DioramaId, self.OwnerId)
    end
    
    -- Настройка диорамы
    self:Setup()
    
    return self
end

function Diorama:InitializeData(initialData)
    -- Статические данные (никогда не меняются, не синхронизируются)
    self.BasePrice = initialData.BasePrice or self.Model:GetAttribute("BasePrice") or 100
    self.Rarity = initialData.Rarity or self.Model:GetAttribute("Rarity") or "Common"
    self.SceneName = initialData.SceneName or self.Model:GetAttribute("SceneName") or "Неизвестная сцена"
    self.DefaultSpot = initialData.DefaultSpot or self.Model:GetAttribute("DefaultSpot") or 1
    self.Collection = initialData.Collection or self.Model:GetAttribute("Collection") or "Empty"
    self.Season = initialData.Season or self.Model:GetAttribute("Season") or 1
    
    -- Критические данные (требуют мгновенной синхронизации)
    self.OwnerId = initialData.OwnerId
    self.OwnerName = initialData.OwnerName
    self.PurchaseCount = initialData.PurchaseCount or 0
    self.PurchaseDate = initialData.PurchaseDate
    self.LastCollectTime = initialData.LastCollectTime
    self.CurrentSpot = initialData.CurrentSpot or self.DefaultSpot
    self.GamePassId = initialData.GamePassId
    self.GamePassInfo = initialData.GamePassInfo and DioramaUtils.getGamePassInfo(initialData.GamePassId) or nil
    
    -- Обратная совместимость: если GamePass уже был использован для продажи, сбрасываем
    if self.GamePassId and Diorama.IsGamePassUsed(self.GamePassId) then
        print(string.format("[DioramaClass] InitializeData: GamePass %d уже использован, сбрасываем для диорамы %s", 
            self.GamePassId, tostring(self.DioramaId)))
        self.GamePassId = nil
        self.GamePassInfo = nil
    end
    
    -- Дополнительная проверка: если GamePass активен на другой диораме, сбрасываем
    if self.GamePassId and isGamePassActiveOnOtherDiorama(self.GamePassId, self.DioramaId) then
        print(string.format("[DioramaClass] InitializeData: GamePass %d активен на другой диораме, сбрасываем для диорамы %s", 
            self.GamePassId, tostring(self.DioramaId)))
        self.GamePassId = nil
        self.GamePassInfo = nil
    end
    
    self.Rating = initialData.Rating or 0.0
    self.Upvotes = initialData.Upvotes or 0
    self.Downvotes = initialData.Downvotes or 0
    self.CriticalVersion = initialData.CriticalVersion or 0
    self.PurchaseBanEndTime = initialData.PurchaseBanEndTime or 0
    
    -- Данные кастомизации (периодическая синхронизация)
    self.FrameType = initialData.FrameType or self.Model:GetAttribute("FrameType") or "DefaultFrame"
    self.StandType = initialData.StandType or self.Model:GetAttribute("StandType") or "DefaultStand"
    self.WallColor = initialData.WallColor and DioramaUtils.tableToColor3(initialData.WallColor) or 
                    (self.Model:GetAttribute("WallColor") or Color3.new(1,1,1))
    self.WallMaterial = initialData.WallMaterial and DioramaUtils.nameToMaterial(initialData.WallMaterial) or 
                       (self.Model:GetAttribute("WallMaterial") or Enum.Material.SmoothPlastic)
    self.CustomizationVersion = initialData.CustomizationVersion or 0
    
    -- Вычисляемые поля
    self.CurrentPrice = self:CalculateCurrentPrice()
    
    -- Обратная совместимость: если OwnerName отсутствует, но OwnerId есть — разрешаем асинхронно
    if self.OwnerId and not self.OwnerName then
        task.spawn(function()
            self:ResolveOwnerName()
        end)
    end
    
    -- Флаги состояния
    self.dirtyCustomization = false
    self.lockOwner = nil
    self.customizationSaveTask = nil
    
    -- DataStore ссылки (ленивая инициализация)
    self.criticalStore = nil
    self.customizationStore = nil
    self.memoryLocks = nil
    self.memoryCriticalCache = nil
    self.memoryCustCache = nil
end

function Diorama:GetCriticalStore()
    if not self.criticalStore then
        self.criticalStore = DataStoreService:GetDataStore(DATASTORE_CRITICAL)
    end
    return self.criticalStore
end

function Diorama:GetCustomizationStore()
    if not self.customizationStore then
        self.customizationStore = DataStoreService:GetDataStore(DATASTORE_CUSTOMIZATION)
    end
    return self.customizationStore
end

function Diorama:GetMemoryLocks()
    if not self.memoryLocks then
        self.memoryLocks = MemoryStoreService:GetSortedMap(MEMORYSTORE_LOCKS)
    end
    return self.memoryLocks
end

function Diorama:GetMemoryCriticalCache()
    if not self.memoryCriticalCache then
        self.memoryCriticalCache = MemoryStoreService:GetSortedMap(MEMORYSTORE_CRITICAL_CACHE)
    end
    return self.memoryCriticalCache
end

function Diorama:GetMemoryCustCache()
    if not self.memoryCustCache then
        self.memoryCustCache = MemoryStoreService:GetSortedMap(MEMORYSTORE_CUST_CACHE)
    end
    return self.memoryCustCache
end

-- ==================== БЛОКИРОВКИ И ТРАНЗАКЦИИ ====================

-- Проверка, можно ли начать транзакцию для игрока
function Diorama:CanStartTransaction(player)
    -- Если транзакция не активна, можно начать
    if not self.transactionInProgress then
        return true
    end
    
    -- Если транзакция активна и принадлежит этому игроку, разрешаем
    if self.transactionOwner == player.UserId then
        return true
    end
    
    -- Проверяем таймаут транзакции
    local elapsed = os.time() - self.transactionStartTime
    if elapsed > DioramaConfig.TRANSACTION_TIMEOUT then
        -- Транзакция зависла, сбрасываем
        self.transactionInProgress = false
        self.transactionOwner = nil
        return true
    end
    
    return false
end

-- Начало транзакции для игрока
function Diorama:BeginPlayerTransaction(player)
    if not self:CanStartTransaction(player) then
        return false, "Диорама занята другим игроком"
    end
    
    self.transactionInProgress = true
    self.transactionOwner = player.UserId
    self.transactionStartTime = os.time()
    return true
end

-- Завершение транзакции игрока
function Diorama:EndPlayerTransaction(player)
    if self.transactionOwner == player.UserId then
        self.transactionInProgress = false
        self.transactionOwner = nil
    end
end

-- Блокировка для межсерверной синхронизации
function Diorama:BeginTransaction()
    -- Проверяем локальную транзакцию
    if self.lockOwner == SERVER_UUID then 
        return true 
    end
    
    local lockKey = "Lock_" .. self.DioramaId
    local memoryLocks = self:GetMemoryLocks()
    local rateLimits = DioramaConfig.DATASTORE_RATE_LIMITS
    
    -- Пытаемся атомарно установить блокировку с retry
    for attempt = 1, rateLimits.LOCK_RETRY_COUNT do
        local success, result = pcall(function()
            return memoryLocks:UpdateAsync(lockKey, function(oldValue)
                if oldValue == nil then
                    return SERVER_UUID
                end
                if oldValue == SERVER_UUID then
                    return SERVER_UUID
                end
                return nil
            end, DioramaConfig.LOCK_TTL)
        end)
        
        if success and result == SERVER_UUID then
            self.lockOwner = SERVER_UUID
            return true
        end
        
        if attempt < rateLimits.LOCK_RETRY_COUNT then
            task.wait(rateLimits.LOCK_RETRY_DELAY)
        end
    end
    
    return false
end

function Diorama:EndTransaction()
    if self.lockOwner == SERVER_UUID then
        local lockKey = "Lock_" .. self.DioramaId
        local memoryLocks = self:GetMemoryLocks()
        pcall(function()
            memoryLocks:RemoveAsync(lockKey)
        end)
        self.lockOwner = nil
    end
end

-- ==================== СОХРАНЕНИЕ В DATASTORE ====================

-- Отметить поле как изменённое
function Diorama:MarkFieldChanged(fieldName)
    self.changedFields[fieldName] = true
end

-- Сброс отслеживания изменений
function Diorama:ResetChangedFields()
    self.changedFields = {}
end

-- Публикация только критических данных на все серверы
function Diorama:PublishCriticalUpdate()
    -- Собираем только критические поля
    local syncData = {}
    for _, fieldName in ipairs(DioramaConfig.CRITICAL_FIELDS) do
        syncData[fieldName] = self[fieldName]
    end
    
    -- Обновляем MemoryStore кеш
    local cache = self:GetMemoryCriticalCache()
    pcall(function()
        cache:SetAsync(self.DioramaId, syncData, DioramaConfig.CACHE_TTL)
    end)
    
    -- Публикуем через MessagingService
    publishCriticalUpdate(self.DioramaId, syncData)
    
    print(string.format("[DioramaClass] PublishCriticalUpdate для %s: OwnerId=%s, Version=%d", 
        tostring(self.DioramaId), tostring(self.OwnerId), self.CriticalVersion))
    
    return syncData
end

-- Сохранение только изменённых критических полей
function Diorama:SaveCriticalChanges()
    if not self:BeginTransaction() then
        return false, "Не удалось захватить блокировку"
    end
    
    local success, err = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if success then
        self:ResetChangedFields()
        SaveQueue.lastSaveTime[self.DioramaId] = os.clock()
    end
    
    return success, err
end

function Diorama:_saveCriticalInternal()
    local store = self:GetCriticalStore()
    local key = self.DioramaId
    local maxRetries = SaveQueue.rateLimits.MAX_RETRIES
    
    for retry = 1, maxRetries do
        local updateSuccess, result = pcall(function()
            return store:UpdateAsync(key, function(oldDataJson)
                local oldData = oldDataJson and HttpService:JSONDecode(oldDataJson) or {}
                
                -- Проверяем версию
                local remoteVersion = oldData.CriticalVersion or 0
                if remoteVersion > self.CriticalVersion then
                    -- Удалённая версия новее - это нормально, просто обновляем нашу версию
                    self.CriticalVersion = remoteVersion
                end
                
                -- Создаём новые данные, сохраняя старые значения для неизменённых полей
                local newData = oldDataJson and HttpService:JSONDecode(oldDataJson) or {}
                
                -- Обновляем только критические поля
                newData.OwnerId = self.OwnerId
                newData.OwnerName = self.OwnerName
                newData.PurchaseCount = self.PurchaseCount
                newData.PurchaseDate = self.PurchaseDate
                newData.LastCollectTime = self.LastCollectTime
                newData.CurrentSpot = self.CurrentSpot
                newData.GamePassId = self.GamePassId
                newData.GamePassInfo = self.GamePassInfo
                newData.Rating = self.Rating
                newData.Upvotes = self.Upvotes
                newData.Downvotes = self.Downvotes
                newData.PurchaseBanEndTime = self.PurchaseBanEndTime
                newData.CriticalVersion = self.CriticalVersion + 1
                
                -- Сохраняем статические поля только если их нет (для новых записей)
                if not newData.BasePrice then
                    newData.BasePrice = self.BasePrice
                    newData.Rarity = self.Rarity
                    newData.SceneName = self.SceneName
                    newData.DefaultSpot = self.DefaultSpot
                    newData.Collection = self.Collection
                    newData.Season = self.Season
                end
                
                -- НЕ сохраняем кастомизацию здесь - она сохраняется отдельно
                
                return HttpService:JSONEncode(newData)
            end)
        end)
        
        if updateSuccess then
            self.CriticalVersion = self.CriticalVersion + 1
            
            -- Публикуем обновление на все серверы
            self:PublishCriticalUpdate()
            
            return true
        else
            warn(("[Diorama] Save error for %s, retry %d/%d: %s"):format(
                self.DioramaId, retry, maxRetries, tostring(result)))
            
            if retry == maxRetries then
                return false, "Превышено количество попыток сохранения: " .. tostring(result)
            end
            
            local delay = getRetryDelay(retry)
            task.wait(delay)
        end
    end
    
    return false, "Ошибка сохранения"
end

function Diorama:ReloadCriticalFromStore()
    local store = self:GetCriticalStore()
    local success, dataJson = pcall(function()
        return store:GetAsync(self.DioramaId)
    end)
    
    if success and dataJson then
        local data = HttpService:JSONDecode(dataJson)
        self.OwnerId = data.OwnerId
        self.OwnerName = data.OwnerName
        self.PurchaseCount = data.PurchaseCount or 0
        self.PurchaseDate = data.PurchaseDate
        self.LastCollectTime = data.LastCollectTime
        self.CurrentSpot = data.CurrentSpot or self.DefaultSpot
        self.GamePassId = data.GamePassId
        self.GamePassInfo = data.GamePassInfo and DioramaUtils.getGamePassInfo(data.GamePassId) or nil
        self.Rating = data.Rating or 0
        self.Upvotes = data.Upvotes or 0
        self.Downvotes = data.Downvotes or 0
        self.PurchaseBanEndTime = data.PurchaseBanEndTime or 0
        self.CriticalVersion = data.CriticalVersion or 0
        
        -- Обновляем кастомизацию, если есть
        if data.FrameType then self.FrameType = data.FrameType end
        if data.StandType then self.StandType = data.StandType end
        if data.WallColor then self.WallColor = DioramaUtils.tableToColor3(data.WallColor) end
        if data.WallMaterial then self.WallMaterial = DioramaUtils.nameToMaterial(data.WallMaterial) end
        if data.CustomizationVersion then self.CustomizationVersion = data.CustomizationVersion end
        
        self.CurrentPrice = self:CalculateCurrentPrice()
        return true
    end
    
    return false
end

function Diorama:MarkCustomizationDirty()
    if self.dirtyCustomization then return end
    
    self.dirtyCustomization = true
    self.CustomizationVersion = self.CustomizationVersion + 1
    
    -- Отменяем предыдущую задачу сохранения
    if self.customizationSaveTask then
        self.customizationSaveTask:Cancel()
    end
    
    -- Планируем новое сохранение
    self.customizationSaveTask = task.delay(DioramaConfig.CUSTOMIZATION_SAVE_DELAY, function()
        if self.dirtyCustomization then
            self:SaveCustomization()
        end
    end)
end

function Diorama:SaveCustomization()
    if not self.dirtyCustomization then return end
    
    local custData = {
        FrameType = self.FrameType,
        StandType = self.StandType,
        WallColor = DioramaUtils.color3ToTable(self.WallColor),
        WallMaterial = DioramaUtils.materialToName(self.WallMaterial),
        CustomizationVersion = self.CustomizationVersion
    }
    
    -- Сохраняем в DataStore
    local store = self:GetCustomizationStore()
    pcall(function()
        store:SetAsync(self.DioramaId, HttpService:JSONEncode(custData))
    end)
    
    -- Обновляем MemoryStore кеш
    local cache = self:GetMemoryCustCache()
    pcall(function()
        cache:SetAsync(self.DioramaId, custData, DioramaConfig.CACHE_TTL)
    end)
    
    self.dirtyCustomization = false
    self.customizationSaveTask = nil
end

-- ==================== ПРИМЕНЕНИЕ ОБНОВЛЕНИЙ ====================

-- Применение только критических обновлений от других серверов
function Diorama:ApplyCriticalUpdate(updateData)
    if updateData.CriticalVersion <= self.CriticalVersion then
        print(string.format("[DioramaClass] ApplyCriticalUpdate: версия %d не новее локальной %d", 
            updateData.CriticalVersion, self.CriticalVersion))
        return false, nil
    end
    
    -- Сохраняем старого владельца для уведомления
    local oldOwnerId = self.OwnerId
    local newOwnerId = updateData.OwnerId
    local ownerChanged = oldOwnerId ~= newOwnerId
    
    -- Сохраняем старый GamePassId для проверки активности
    local oldGamePassId = self.GamePassId
    
    print(string.format("[DioramaClass] ApplyCriticalUpdate для %s: версия %d -> %d, OwnerId: %s -> %s", 
        tostring(self.DioramaId), self.CriticalVersion, updateData.CriticalVersion, 
        tostring(oldOwnerId), tostring(newOwnerId)))
    
    -- Применяем только критические поля
    self.OwnerId = updateData.OwnerId
    self.OwnerName = updateData.OwnerName
    self.PurchaseCount = updateData.PurchaseCount
    self.PurchaseDate = updateData.PurchaseDate
    self.LastCollectTime = updateData.LastCollectTime
    self.CurrentSpot = updateData.CurrentSpot or self.DefaultSpot
    self.GamePassId = updateData.GamePassId
    self.GamePassInfo = updateData.GamePassInfo and DioramaUtils.getGamePassInfo(updateData.GamePassId) or nil
    self.Rating = updateData.Rating or 0
    self.Upvotes = updateData.Upvotes or 0
    self.Downvotes = updateData.Downvotes or 0
    self.PurchaseBanEndTime = updateData.PurchaseBanEndTime or 0
    self.CriticalVersion = updateData.CriticalVersion
    
    -- Управление регистрацией активного GamePass
    if oldGamePassId ~= self.GamePassId then
        -- Если был старый GamePass, удаляем его регистрацию
        if oldGamePassId then
            unregisterActiveGamePass(oldGamePassId, self.DioramaId)
        end
        -- Если появился новый GamePass, регистрируем его
        if self.GamePassId then
            registerActiveGamePass(self.GamePassId, self.DioramaId, self.OwnerId)
        end
    end
    
    -- Пересчитываем цену
    self.CurrentPrice = self:CalculateCurrentPrice()
    
    -- Обновляем визуал
    self:UpdateInfoPad()
    self:LoadOwnerAvatar()
    
    print(string.format("[DioramaClass] ApplyCriticalUpdate завершён для %s", tostring(self.DioramaId)))
    
    -- Возвращаем информацию о смене владельца
    return true, {
        ownerChanged = ownerChanged,
        oldOwnerId = oldOwnerId,
        newOwnerId = newOwnerId
    }
end

-- Применение обновлений кастомизации (только при периодической проверке)
function Diorama:ApplyCustomizationUpdate(custData)
    if custData.CustomizationVersion <= self.CustomizationVersion then
        return false
    end
    
    local frameChanged = custData.FrameType ~= self.FrameType
    local standChanged = custData.StandType ~= self.StandType
    local colorChanged = custData.WallColor and DioramaUtils.tableToColor3(custData.WallColor) ~= self.WallColor
    local materialChanged = custData.WallMaterial and DioramaUtils.nameToMaterial(custData.WallMaterial) ~= self.WallMaterial
    
    self.FrameType = custData.FrameType or self.FrameType
    self.StandType = custData.StandType or self.StandType
    if custData.WallColor then
        self.WallColor = DioramaUtils.tableToColor3(custData.WallColor)
    end
    if custData.WallMaterial then
        self.WallMaterial = DioramaUtils.nameToMaterial(custData.WallMaterial)
    end
    self.CustomizationVersion = custData.CustomizationVersion
    
    -- Применяем визуальные изменения
    if frameChanged then
        self:UpdateFrame(self.FrameType)
    end
    if standChanged then
        self:UpdateStand(self.StandType)
    end
    if colorChanged or materialChanged then
        self:ApplyWallProperties()
    end
    
    self:UpdateInfoPad()
    
    return true
end

-- ==================== ПОЛУЧЕНИЕ ДАННЫХ ====================

-- Только критические данные для синхронизации
function Diorama:GetCriticalSyncData()
    return {
        OwnerId = self.OwnerId,
        OwnerName = self.OwnerName,
        PurchaseCount = self.PurchaseCount,
        PurchaseDate = self.PurchaseDate,
        LastCollectTime = self.LastCollectTime,
        CurrentSpot = self.CurrentSpot,
        GamePassId = self.GamePassId,
        GamePassInfo = self.GamePassInfo,
        Rating = self.Rating,
        Upvotes = self.Upvotes,
        Downvotes = self.Downvotes,
        PurchaseBanEndTime = self.PurchaseBanEndTime,
        CriticalVersion = self.CriticalVersion
    }
end

-- Данные кастомизации (для периодической проверки)
function Diorama:GetCustomizationData()
    return {
        FrameType = self.FrameType,
        StandType = self.StandType,
        WallColor = DioramaUtils.color3ToTable(self.WallColor),
        WallMaterial = DioramaUtils.materialToName(self.WallMaterial),
        CustomizationVersion = self.CustomizationVersion
    }
end

function Diorama:GetData()
    local currentSpot = self:GetCurrentAvatarSpot()
    local poseName = currentSpot and currentSpot:GetAttribute("PoseName") or ""
    local nextBasePrice = self:CalculateBasePriceForPurchaseCount(self.PurchaseCount + 1)
    local priceIncrease = nextBasePrice - self:CalculateBasePrice()
    local votePrice = DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.VOTE_PRICE[self.Rarity] or 
                      DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.VOTE_PRICE.Common
    local influenceFactor = DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.RATING_INFLUENCE_FACTOR[self.Rarity] or 
                           DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.RATING_INFLUENCE_FACTOR.Common
    local accumulatedIncome = self:CalculateAccumulatedIncome()
    local maxAccumulatedIncome = self:GetMaxAccumulatedIncome()
    
    return {
        -- Статические поля
        CurrentPrice = self.CurrentPrice,
        BasePrice = self:CalculateBasePrice(),
        Rarity = self.Rarity,
        RarityName = DioramaConfig.RARITY_NAMES[self.Rarity] or self.Rarity,
        SceneName = self.SceneName,
        Collection = self.Collection,
        Season = self.Season,
        
        -- Поля состояния
        OwnerId = self.OwnerId,
        OwnerName = self.OwnerName,
        PoseName = poseName,
        CurrentSpot = self.CurrentSpot,
        DefaultSpot = self.DefaultSpot,
        AvailableSpots = #self.AvatarSpots:GetChildren(),
        IncomeRate = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[self.Rarity] or 10,
        PurchaseCount = self.PurchaseCount,
        LastCollectTime = self.LastCollectTime,
        GamePassId = self.GamePassId,
        GamePassInfo = self.GamePassInfo,
        
        -- Рейтинг
        Rating = self.Rating,
        Upvotes = self.Upvotes,
        Downvotes = self.Downvotes,
        RatingEffect = self:GetRatingEffect(),
        VotePrice = votePrice,
        InfluenceFactor = influenceFactor,
        MaxRatingInfluence = DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.MAX_RATING_INFLUENCE,
        
        -- Доход
        AccumulatedIncome = accumulatedIncome,
        MaxAccumulatedIncome = maxAccumulatedIncome,
        
        -- Запрет покупки
        PurchaseBanEndTime = self.PurchaseBanEndTime or 0,
        IsPurchaseBanned = self:IsPurchaseBanned(),
        
        -- Экономика
        NextBasePrice = nextBasePrice,
        PriceIncrease = priceIncrease,
        QuickSellAmount = math.floor(self.CurrentPrice * DioramaConfig.DIORAMA_ECONOMY.QUICK_SELL_COMMISSION),
        PurchaseDate = self.PurchaseDate,
        
        -- Кастомизация
        FrameType = self.FrameType,
        StandType = self.StandType,
        WallColor = DioramaUtils.color3ToTable(self.WallColor),
        WallMaterial = DioramaUtils.materialToName(self.WallMaterial),
        
        -- Версии
        CriticalVersion = self.CriticalVersion,
        CustomizationVersion = self.CustomizationVersion
    }
end

-- ==================== ЭКОНОМИЧЕСКИЕ РАСЧЁТЫ ====================

function Diorama:CalculateBasePrice()
    local rarityMultiplier = DioramaConfig.DIORAMA_ECONOMY.RARITY_MULTIPLIERS[self.Rarity] or 
                            DioramaConfig.DIORAMA_ECONOMY.RARITY_MULTIPLIERS.Common
    local priceMultiplier = math.pow(self.PurchaseCount + 1, rarityMultiplier)
    local basePrice = self.BasePrice * priceMultiplier
    basePrice = math.max(DioramaConfig.DIORAMA_ECONOMY.MINIMUM_PRICE, basePrice)
    return math.floor(basePrice)
end

function Diorama:CalculateCurrentPrice()
    local basePrice = self:CalculateBasePrice()
    local voteSettings = DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS
    local voteDifference = (self.Upvotes or 0) - (self.Downvotes or 0)
    local votePrice = voteSettings.VOTE_PRICE[self.Rarity] or voteSettings.VOTE_PRICE.Common
    local influenceFactor = voteSettings.RATING_INFLUENCE_FACTOR[self.Rarity] or 
                           voteSettings.RATING_INFLUENCE_FACTOR.Common
    
    local ratingInfluence = voteDifference * votePrice * influenceFactor
    local maxInfluence = basePrice * voteSettings.MAX_RATING_INFLUENCE
    
    if ratingInfluence > 0 then
        ratingInfluence = math.min(ratingInfluence, maxInfluence)
    else
        ratingInfluence = math.max(ratingInfluence, -maxInfluence)
    end
    
    local newPrice = basePrice + ratingInfluence
    newPrice = math.max(DioramaConfig.DIORAMA_ECONOMY.MINIMUM_PRICE, newPrice)
    
    return math.floor(newPrice)
end

function Diorama:UpdateRating()
    local totalVotes = self.Upvotes + self.Downvotes
    if totalVotes == 0 then
        self.Rating = 0.0
    else
        self.Rating = 5.0 + 5.0 * (self.Upvotes - self.Downvotes) / totalVotes
    end
    self.CurrentPrice = self:CalculateCurrentPrice()
    return self.Rating
end

function Diorama:CalculateBasePriceForPurchaseCount(purchaseCount)
    local rarityMultiplier = DioramaConfig.DIORAMA_ECONOMY.RARITY_MULTIPLIERS[self.Rarity] or 
                            DioramaConfig.DIORAMA_ECONOMY.RARITY_MULTIPLIERS.Common
    local priceMultiplier = math.pow(purchaseCount + 1, rarityMultiplier)
    local basePrice = self.BasePrice * priceMultiplier
    return math.max(DioramaConfig.DIORAMA_ECONOMY.MINIMUM_PRICE, basePrice)
end

function Diorama:CalculateAccumulatedIncome()
    if not self.OwnerId or not self.LastCollectTime then
        return 0
    end
    local now = os.time()
    local timePassed = now - self.LastCollectTime
    if timePassed > DioramaConfig.DIORAMA_ECONOMY.MAX_ACCUMULATION_TIME then
        timePassed = DioramaConfig.DIORAMA_ECONOMY.MAX_ACCUMULATION_TIME
    end
    local incomePerHour = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[self.Rarity] or 10
    local incomePerSecond = incomePerHour / 3600
    local accumulated = timePassed * incomePerSecond
    return math.floor(accumulated)
end

function Diorama:GetMaxAccumulatedIncome()
    local incomePerHour = DioramaConfig.DIORAMA_ECONOMY.INCOME_RATES[self.Rarity] or 10
    return math.floor(incomePerHour * 12)
end

-- Вычисляет накопленный доход с учетом множителя игрока
function Diorama:CalculateAccumulatedIncomeForPlayer(player)
    local baseIncome = self:CalculateAccumulatedIncome()
    if baseIncome == 0 then return 0 end
    
    local DataManager = _G.AssetService and _G.AssetService:GetModule("DataManager")
    if DataManager then
        local computedData = DataManager.GetComputedData(player)
        if computedData then
            local dioramaMultiplier = computedData.DioramaGoldMultiplier or 1
            return math.floor(baseIncome * dioramaMultiplier)
        end
    end
    
    return baseIncome
end

-- Возвращает максимальный накопленный доход с учетом множителя игрока
function Diorama:GetMaxAccumulatedIncomeForPlayer(player)
    local baseMax = self:GetMaxAccumulatedIncome()
    
    local DataManager = _G.AssetService and _G.AssetService:GetModule("DataManager")
    if DataManager then
        local computedData = DataManager.GetComputedData(player)
        if computedData then
            local dioramaMultiplier = computedData.DioramaGoldMultiplier or 1
            return math.floor(baseMax * dioramaMultiplier)
        end
    end
    
    return baseMax
end

function Diorama:GetRatingEffect()
    local basePrice = self:CalculateBasePrice()
    local currentPrice = self.CurrentPrice
    local priceDifference = currentPrice - basePrice
    if basePrice == 0 then return 0 end
    return priceDifference / basePrice
end

-- ==================== ОПЕРАЦИИ С ДИОРАМОЙ ====================

function Diorama:CollectIncome(player)
    print(string.format("[DioramaClass] CollectIncome начат для %s игроком %s", 
        tostring(self.DioramaId), player.Name))
    
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    -- Проверяем блокировку транзакции
    if not self:BeginPlayerTransaction(player) then
        return false, "Диорама временно занята другим игроком"
    end
    
    if not self:BeginTransaction() then
        self:EndPlayerTransaction(player)
        return false, "Диорама временно занята"
    end
    
    local accumulated = self:CalculateAccumulatedIncome()
    if accumulated < 1 then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Накоплено менее 1 золота"
    end
    
    -- Применяем множитель золота с диорам от перерождений
    local DataManager = _G.AssetService and _G.AssetService:GetModule("DataManager")
    if DataManager then
        local computedData = DataManager.GetComputedData(player)
        if computedData then
            local dioramaMultiplier = computedData.DioramaGoldMultiplier or 1
            accumulated = math.floor(accumulated * dioramaMultiplier)
        end
    end
    
    if accumulated < 1 then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Накоплено менее 1 золота после множителя"
    end
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "EventSystem не доступен"
    end
    
    local success, result = EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, accumulated)
    if not success then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Ошибка начисления дохода: " .. tostring(result)
    end
    
    self.LastCollectTime = os.time()
    self:MarkFieldChanged("LastCollectTime")
    
    print(string.format("[DioramaClass] CollectIncome: сохранение для %s, накоплено %d", 
        tostring(self.DioramaId), accumulated))
    
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    self:EndPlayerTransaction(player)
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    return true, string.format("Получено %d золота", accumulated)
end

function Diorama:Vote(player, voteType)
    print(string.format("[DioramaClass] Vote начат для %s игроком %s, тип: %s", 
        tostring(self.DioramaId), player.Name, voteType))
    
    if not player then 
        return false, "Игрок не найден" 
    end
    
    -- Проверяем блокировку транзакции
    if not self:BeginPlayerTransaction(player) then
        return false, "Диорама временно занята другим игроком"
    end
    
    if not self:BeginTransaction() then
        self:EndPlayerTransaction(player)
        return false, "Диорама временно занята"
    end
    
    local votePrice = DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.VOTE_PRICE[self.Rarity] or 
                      DioramaConfig.DIORAMA_ECONOMY.VOTE_SETTINGS.VOTE_PRICE.Common
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "EventSystem не доступен"
    end
    
    local playerGold = EventSystem.CallServerOnlyRPC("GetPlayerGold", player) or 0
    if playerGold < votePrice then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, string.format("Недостаточно золота для голосования. Нужно: %d", votePrice)
    end
    
    local success, result = EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, -votePrice)
    if not success then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Ошибка списания золота: " .. tostring(result)
    end
    
    if voteType == "up" then
        self.Upvotes = self.Upvotes + 1
        self:MarkFieldChanged("Upvotes")
    elseif voteType == "down" then
        self.Downvotes = self.Downvotes + 1
        self:MarkFieldChanged("Downvotes")
    else
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Неверный тип голоса"
    end
    
    self:UpdateRating()
    self:MarkFieldChanged("Rating")
    
    print(string.format("[DioramaClass] Vote: сохранение для %s, рейтинг: %.2f", 
        tostring(self.DioramaId), self.Rating))
    
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    self:EndPlayerTransaction(player)
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    return true, string.format("Ваш голос учтен! Текущий рейтинг: %.2f", self.Rating)
end

function Diorama:Purchase(player)
    print(string.format("[DioramaClass] Purchase начат для %s игроком %s (UserId: %d)", 
        tostring(self.DioramaId), player.Name, player.UserId))
    
    if self.OwnerId == player.UserId then
        return self:CollectIncome(player)
    end
    
    -- Проверяем запрет покупки
    if self:IsPurchaseBanned() then
        local remainingTime = self.PurchaseBanEndTime - os.time()
        local minutes = math.floor(remainingTime / 60)
        local seconds = remainingTime % 60
        return false, string.format("Покупка запрещена. Осталось: %d мин %d сек", minutes, seconds)
    end
    
    -- Проверяем блокировку транзакции
    if not self:BeginPlayerTransaction(player) then
        return false, "Диорама временно занята другим игроком"
    end
    
    if not self:BeginTransaction() then
        self:EndPlayerTransaction(player)
        return false, "Диорама временно занята другим игроком"
    end
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "EventSystem не доступен"
    end
    
    -- Проверяем актуальную цену
    local currentPrice = self:CalculateCurrentPrice()
    local playerGold = EventSystem.CallServerOnlyRPC("GetPlayerGold", player) or 0
    if playerGold < currentPrice then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        local needed = currentPrice - playerGold
        return false, string.format("Недостаточно золота. Нужно ещё: %d", needed)
    end
    
    -- Сохраняем данные старого владельца для обработки накопленного дохода
    local oldOwnerId = self.OwnerId
    local accumulatedIncomeForOldOwner = 0
    
    if oldOwnerId then
        -- Вычисляем накопленный доход старого владельца ПЕРЕД сменой владельца
        accumulatedIncomeForOldOwner = self:CalculateAccumulatedIncome()
        
        local oldOwner = Players:GetPlayerByUserId(oldOwnerId)
        if oldOwner then
            -- Старый владелец онлайн - начисляем комиссию и накопленный доход
            local resaleAmount = math.floor(currentPrice * DioramaConfig.DIORAMA_ECONOMY.RESALE_COMMISSION)
            EventSystem.CallServerOnlyRPC("UpdatePlayerGold", oldOwner, resaleAmount)
            
            -- Начисляем накопленный доход с уведомлением
            if accumulatedIncomeForOldOwner > 0 then
                EventSystem.CallServerOnlyRPC("UpdatePlayerGold", oldOwner, accumulatedIncomeForOldOwner)
                EventSystem.FireClient(oldOwner, "PendingGoldReceived", {
                    amount = accumulatedIncomeForOldOwner,
                    dioramaId = self.DioramaId,
                    sceneName = self.SceneName,
                    isAccumulatedIncome = true
                })
                print(string.format("[DioramaClass] Purchase: начислен накопленный доход %d игроку %s", 
                    accumulatedIncomeForOldOwner, oldOwner.Name))
            end
        else
            -- Старый владелец не онлайн - сохраняем накопленный доход как отложенное начисление
            if accumulatedIncomeForOldOwner > 0 then
                print(string.format("[DioramaClass] Purchase: старый владелец UserId=%d не онлайн, сохраняем накопленный доход %d", 
                    oldOwnerId, accumulatedIncomeForOldOwner))
                
                -- Сохраняем в DataStore
                savePendingPayment(oldOwnerId, accumulatedIncomeForOldOwner, self.DioramaId, self.SceneName)
                
                -- Публикуем сообщение для всех серверов
                publishPendingPayment(oldOwnerId, accumulatedIncomeForOldOwner, self.DioramaId, self.SceneName)
            end
            
            -- Комиссия не начисляется оффлайн игроку (только при следующем входе если нужно)
        end
    end
    
    -- Сохраняем старый GamePassId для очистки регистрации
    local oldGamePassId = self.GamePassId
    
    -- Списываем золото у покупателя
    local success, result = EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, -currentPrice)
    if not success then
        self:EndTransaction()
        self:EndPlayerTransaction(player)
        return false, "Ошибка обновления данных: " .. tostring(result)
    end
    
    -- Обновляем данные диорамы
    self.OwnerId = player.UserId
    self.OwnerName = player.Name
    self.PurchaseCount = self.PurchaseCount + 1
    self.PurchaseDate = os.time()
    self.CurrentSpot = self.DefaultSpot
    self.LastCollectTime = os.time()
    
    -- Если был GamePass, удаляем его регистрацию
    if oldGamePassId then
        unregisterActiveGamePass(oldGamePassId, self.DioramaId)
    end
    
    self.GamePassId = nil
    self.GamePassInfo = nil
    self.CurrentPrice = self:CalculateCurrentPrice()
    
    -- Сбрасываем кастомизацию на дефолтные значения
    self:ResetCustomization()
    
    -- Отмечаем изменённые поля
    self:MarkFieldChanged("OwnerId")
    self:MarkFieldChanged("OwnerName")
    self:MarkFieldChanged("PurchaseCount")
    self:MarkFieldChanged("PurchaseDate")
    self:MarkFieldChanged("CurrentSpot")
    self:MarkFieldChanged("LastCollectTime")
    self:MarkFieldChanged("GamePassId")
    
    print(string.format("[DioramaClass] Purchase: сохранение данных для %s, новый владелец: %d", 
        tostring(self.DioramaId), self.OwnerId))
    
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    self:EndPlayerTransaction(player)
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    print(string.format("[DioramaClass] Purchase: данные сохранены, вызов callback для %s", tostring(self.DioramaId)))
    
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    task.spawn(function()
        task.wait(0.5)
        self:LoadOwnerAvatar()
        self:UpdateInfoPad()
    end)
    
    return true, "Поздравляем с покупкой!"
end

function Diorama:QuickSell(player)
    print(string.format("[DioramaClass] QuickSell начат для %s игроком %s", 
        tostring(self.DioramaId), player.Name))
    
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    local quickSellAmount = math.floor(self.CurrentPrice * DioramaConfig.DIORAMA_ECONOMY.QUICK_SELL_COMMISSION)
    if quickSellAmount < DioramaConfig.DIORAMA_ECONOMY.MINIMUM_PRICE then
        quickSellAmount = DioramaConfig.DIORAMA_ECONOMY.MINIMUM_PRICE
    end
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        self:EndTransaction()
        return false, "EventSystem не доступен"
    end
    
    EventSystem.CallServerOnlyRPC("UpdatePlayerGold", player, quickSellAmount)
    
    -- Сохраняем старый GamePassId для очистки регистрации
    local oldGamePassId = self.GamePassId
    
    self.OwnerId = nil
    self.OwnerName = nil
    self.LastCollectTime = nil
    self.CurrentSpot = self.DefaultSpot
    
    -- Если был GamePass, удаляем его регистрацию
    if oldGamePassId then
        unregisterActiveGamePass(oldGamePassId, self.DioramaId)
    end
    
    self.GamePassId = nil
    self.GamePassInfo = nil
    self.PurchaseDate = nil
    
    -- Сбрасываем кастомизацию на дефолтные значения
    self:ResetCustomization()
    
    print(string.format("[DioramaClass] QuickSell: сохранение для %s, OwnerId сброшен", 
        tostring(self.DioramaId)))
    
    -- Сохраняем критическое изменение с критическим приоритетом (продажа!)
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    -- Уведомляем о критическом изменении
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    task.spawn(function()
        task.wait(0.5)
        self:LoadOwnerAvatar()
        self:UpdateInfoPad()
    end)
    
    return true, string.format("Быстрая продажа выполнена. Вы получили %d золота (10%% от цены).", quickSellAmount)
end

function Diorama:ChangeSpot(spotNumber)
    print(string.format("[DioramaClass] ChangeSpot начат для %s, новый спот: %d", 
        tostring(self.DioramaId), spotNumber))
    
    local spot = self.AvatarSpots:FindFirstChild(tostring(spotNumber))
    if not spot then
        return false, "Место не найдено"
    end
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    self.CurrentSpot = spotNumber
    
    print(string.format("[DioramaClass] ChangeSpot: сохранение для %s", tostring(self.DioramaId)))
    
    -- Сохраняем критическое изменение с нормальным приоритетом
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    self:LoadOwnerAvatar()
    self:UpdateInfoPad()
    
    -- Уведомляем о критическом изменении
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    return true, "Место изменено"
end

function Diorama:ChangeFrameType(player, newFrameType)
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not DioramaCustomization.playerHasCustomization(player, "Frames", newFrameType) then
        return false, "У вас нет такой рамки"
    end
    
    local success, message = self:UpdateFrame(newFrameType)
    if not success then
        return false, message
    end
    
    self.FrameType = newFrameType
    self:MarkCustomizationDirty()
    self:UpdateInfoPad()
    
    return true, "Тип рамки изменен"
end

function Diorama:ChangeStandType(player, newStandType)
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not DioramaCustomization.playerHasCustomization(player, "Stands", newStandType) then
        return false, "У вас нет такого стенда"
    end
    
    local success, message = self:UpdateStand(newStandType)
    if not success then
        return false, message
    end
    
    self:SetupInteraction()
    self.StandType = newStandType
    self:MarkCustomizationDirty()
    self:UpdateInfoPad()
    
    return true, "Тип стенда изменен"
end

function Diorama:ResetCustomization()
    local defaults = DioramaConfig.DEFAULT_CUSTOMIZATION
    self.WallColor = defaults.WallColor
    self.WallMaterial = DioramaUtils.nameToMaterial(defaults.WallMaterial)
    self.StandType = defaults.StandType
    self.FrameType = defaults.FrameType
    
    -- Применяем визуальные изменения
    self:ApplyWallProperties()
    self:UpdateFrame(self.FrameType)
    self:UpdateStand(self.StandType)
    self:SetupInteraction()
    
    -- Отмечаем кастомизацию как изменённую
    self.dirtyCustomization = true
    self.CustomizationVersion = self.CustomizationVersion + 1
    
    self:SaveCustomization()
    
    self:UpdateInfoPad()
end

function Diorama:ChangeWallColor(player, colorName)
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not DioramaCustomization.playerHasCustomization(player, "Colors", colorName) then
        return false, "У вас нет такого цвета"
    end
    
    local newColor = DioramaCustomization.getColorFromName(colorName)
    if not newColor then
        return false, "Неизвестный цвет"
    end
    
    self.WallColor = newColor
    self:ApplyWallProperties()
    self:MarkCustomizationDirty()
    self:UpdateInfoPad()
    
    return true, "Цвет стены изменен"
end

function Diorama:ChangeWallMaterial(player, materialName)
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not DioramaCustomization.playerHasCustomization(player, "Materials", materialName) then
        return false, "У вас нет такого материала"
    end
    
    local newMaterial = DioramaUtils.nameToMaterial(materialName)
    if not newMaterial then
        return false, "Неизвестный материал"
    end
    
    self.WallMaterial = newMaterial
    self:ApplyWallProperties()
    self:MarkCustomizationDirty()
    self:UpdateInfoPad()
    
    return true, "Материал стены изменен"
end

function Diorama:SetGamePass(player, gamePassId)
    print(string.format("[DioramaClass] SetGamePass начат для %s игроком %s, GamePassId: %d", 
        tostring(self.DioramaId), player.Name, gamePassId))
    
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not gamePassId or type(gamePassId) ~= "number" then
        return false, "Некорректный ID GamePass"
    end
    
    -- Проверяем, не был ли этот GamePass уже использован для продажи
    if Diorama.IsGamePassUsed(gamePassId) then
        return false, "Этот GamePass уже был использован для продажи диорамы и не может быть применён повторно"
    end
    
    -- Проверяем, не активен ли этот GamePass на другой диораме
    if isGamePassActiveOnOtherDiorama(gamePassId, self.DioramaId) then
        return false, "Этот GamePass уже привязан к другой диораме"
    end
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    -- Повторная проверка внутри транзакции (защита от гонок)
    if Diorama.IsGamePassUsed(gamePassId) then
        self:EndTransaction()
        return false, "Этот GamePass уже был использован для продажи диорамы и не может быть применён повторно"
    end
    
    -- Повторная проверка активности на другой диораме внутри транзакции
    if isGamePassActiveOnOtherDiorama(gamePassId, self.DioramaId) then
        self:EndTransaction()
        return false, "Этот GamePass уже привязан к другой диораме"
    end
    
    local gamePassInfo = DioramaUtils.getGamePassInfo(gamePassId)
    if not gamePassInfo then
        self:EndTransaction()
        return false, "GamePass не найден"
    end
    
    -- Если у диорамы уже был GamePass, удаляем его регистрацию
    if self.GamePassId then
        unregisterActiveGamePass(self.GamePassId, self.DioramaId)
    end
    
    self.GamePassId = gamePassId
    self.GamePassInfo = gamePassInfo
    
    -- Регистрируем новый GamePass как активный
    if not registerActiveGamePass(gamePassId, self.DioramaId, self.OwnerId) then
        self.GamePassId = nil
        self.GamePassInfo = nil
        self:EndTransaction()
        return false, "Не удалось зарегистрировать GamePass (возможно, он уже используется на другом сервере)"
    end
    
    print(string.format("[DioramaClass] SetGamePass: сохранение для %s", tostring(self.DioramaId)))
    
    -- Сохраняем критическое изменение с высоким приоритетом
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        -- Если сохранение не удалось, откатываем регистрацию
        unregisterActiveGamePass(gamePassId, self.DioramaId)
        self.GamePassId = nil
        self.GamePassInfo = nil
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    -- Уведомляем о критическом изменении
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    self:UpdateInfoPad()
    
    return true, string.format("Диорама выставлена на продажу за %d Robux", gamePassInfo.PriceInRobux)
end

function Diorama:RemoveGamePass(player)
    print(string.format("[DioramaClass] RemoveGamePass начат для %s игроком %s", 
        tostring(self.DioramaId), player.Name))
    
    if self.OwnerId ~= player.UserId then
        return false, "Вы не владеете этой диорамой"
    end
    
    if not self.GamePassId then
        return false, "Диорама не выставлена на продажу за Robux"
    end
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    -- Удаляем регистрацию активного GamePass
    unregisterActiveGamePass(self.GamePassId, self.DioramaId)
    
    self.GamePassId = nil
    self.GamePassInfo = nil
    
    print(string.format("[DioramaClass] RemoveGamePass: сохранение для %s", tostring(self.DioramaId)))
    
    -- Сохраняем критическое изменение с высоким приоритетом
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    -- Уведомляем о критическом изменении
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    self:UpdateInfoPad()
    
    return true, "Диорама снята с продажи за Robux"
end

function Diorama:PurchaseWithGamePass(player)
    print(string.format("[DioramaClass] PurchaseWithGamePass начат для %s игроком %s", 
        tostring(self.DioramaId), player.Name))
    
    if not self.GamePassId then
        return false, "Диорама не продается за Robux"
    end
    
    if self.OwnerId == player.UserId then
        return false, "Вы уже владеете этой диорамой"
    end
    
    -- Атомарно маркируем GamePass как использованный ПЕРЕД началом транзакции
    -- Это защищает от гонок: если два игрока одновременно пытаются купить диорамы
    -- с одним и тем же GamePass, только один успешно пройдёт эту проверку
    if not Diorama.MarkGamePassAsUsed(self.GamePassId, self.DioramaId) then
        return false, "Этот GamePass уже был использован для покупки другой диорамы"
    end
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    if not DioramaUtils.hasGamePass(player, self.GamePassId) then
        self:EndTransaction()
        return false, "У вас нет этого GamePass"
    end
    
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    
    -- Сохраняем данные старого владельца для обработки накопленного дохода
    local oldOwnerId = self.OwnerId
    local accumulatedIncomeForOldOwner = 0
    
    if oldOwnerId then
        -- Вычисляем накопленный доход старого владельца ПЕРЕД сменой владельца
        accumulatedIncomeForOldOwner = self:CalculateAccumulatedIncome()
        
        local oldOwner = Players:GetPlayerByUserId(oldOwnerId)
        if oldOwner then
            -- Старый владелец онлайн - уведомляем о продаже и начисляем накопленный доход
            if EventSystem then
                EventSystem.FireClient(oldOwner, "GamePassSaleCompleted", self.DioramaId, self.GamePassInfo.PriceInRobux)
            end
            
            -- Начисляем накопленный доход с уведомлением
            if accumulatedIncomeForOldOwner > 0 then
                if EventSystem then
                    EventSystem.CallServerOnlyRPC("UpdatePlayerGold", oldOwner, accumulatedIncomeForOldOwner)
                    EventSystem.FireClient(oldOwner, "PendingGoldReceived", {
                        amount = accumulatedIncomeForOldOwner,
                        dioramaId = self.DioramaId,
                        sceneName = self.SceneName,
                        isAccumulatedIncome = true
                    })
                    print(string.format("[DioramaClass] PurchaseWithGamePass: начислен накопленный доход %d игроку %s", 
                        accumulatedIncomeForOldOwner, oldOwner.Name))
                end
            end
        else
            -- Старый владелец не онлайн - сохраняем накопленный доход как отложенное начисление
            if accumulatedIncomeForOldOwner > 0 then
                print(string.format("[DioramaClass] PurchaseWithGamePass: старый владелец UserId=%d не онлайн, сохраняем накопленный доход %d", 
                    oldOwnerId, accumulatedIncomeForOldOwner))
                
                -- Сохраняем в DataStore
                savePendingPayment(oldOwnerId, accumulatedIncomeForOldOwner, self.DioramaId, self.SceneName)
                
                -- Публикуем сообщение для всех серверов
                publishPendingPayment(oldOwnerId, accumulatedIncomeForOldOwner, self.DioramaId, self.SceneName)
            end
        end
    end
    
    -- Сохраняем старый GamePassId для очистки регистрации
    local oldGamePassId = self.GamePassId
    
    self.OwnerId = player.UserId
    self.OwnerName = player.Name
    self.PurchaseCount = self.PurchaseCount + 1
    self.PurchaseDate = os.time()
    self.CurrentSpot = self.DefaultSpot
    
    -- Удаляем регистрацию активного GamePass
    if oldGamePassId then
        unregisterActiveGamePass(oldGamePassId, self.DioramaId)
    end
    
    self.GamePassId = nil
    self.GamePassInfo = nil
    self.LastCollectTime = os.time()
    self.CurrentPrice = self:CalculateCurrentPrice()
    
    -- Сбрасываем кастомизацию на дефолтные значения
    self:ResetCustomization()
    
    print(string.format("[DioramaClass] PurchaseWithGamePass: сохранение для %s, новый владелец: %d", 
        tostring(self.DioramaId), self.OwnerId))
    
    -- Сохраняем критическое изменение с критическим приоритетом (покупка!)
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    -- Уведомляем о критическом изменении
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    task.spawn(function()
        task.wait(0.5)
        self:LoadOwnerAvatar()
        self:UpdateInfoPad()
    end)
    
    return true, "Вы приобрели диораму через GamePass!"
end

-- ==================== ЗАПРЕТ ПОКУПКИ ====================

-- Проверка, заблокирована ли покупка
function Diorama:IsPurchaseBanned()
    if not self.PurchaseBanEndTime or self.PurchaseBanEndTime == 0 then
        return false
    end
    return os.time() < self.PurchaseBanEndTime
end

-- Установка запрета покупки
function Diorama:SetPurchaseBan(banEndTime)
    print(string.format("[DioramaClass] SetPurchaseBan для %s, время окончания: %d", 
        tostring(self.DioramaId), banEndTime))
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    self.PurchaseBanEndTime = banEndTime
    self:MarkFieldChanged("PurchaseBanEndTime")
    
    print(string.format("[DioramaClass] SetPurchaseBan: сохранение для %s", tostring(self.DioramaId)))
    
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    return true, "Запрет установлен", banEndTime
end

-- Увеличение времени запрета покупки
function Diorama:ExtendPurchaseBan(additionalSeconds)
    print(string.format("[DioramaClass] ExtendPurchaseBan для %s, добавляем: %d сек", 
        tostring(self.DioramaId), additionalSeconds))
    
    if not self:BeginTransaction() then
        return false, "Диорама временно занята"
    end
    
    local currentTime = os.time()
    -- Если запрет уже истёк, начинаем с текущего времени
    if not self.PurchaseBanEndTime or self.PurchaseBanEndTime < currentTime then
        self.PurchaseBanEndTime = currentTime + additionalSeconds
    else
        -- Иначе добавляем к существующему времени
        self.PurchaseBanEndTime = self.PurchaseBanEndTime + additionalSeconds
    end
    
    self:MarkFieldChanged("PurchaseBanEndTime")
    
    print(string.format("[DioramaClass] ExtendPurchaseBan: сохранение для %s, новое время: %d", 
        tostring(self.DioramaId), self.PurchaseBanEndTime))
    
    local saveSuccess, saveErr = self:_saveCriticalInternal()
    self:EndTransaction()
    
    if not saveSuccess then
        return false, "Ошибка сохранения: " .. tostring(saveErr)
    end
    
    if self.callbacks.onCriticalDataChanged then
        self.callbacks.onCriticalDataChanged(self:GetCriticalSyncData())
    end
    
    return true, "Время запрета увеличено", self.PurchaseBanEndTime
end

-- ==================== ВИЗУАЛЬНЫЕ МЕТОДЫ ====================

function Diorama:GetCurrentAvatarSpot()
    return self.AvatarSpots:FindFirstChild(tostring(self.CurrentSpot))
end

function Diorama:Setup()
    self:ApplyWallProperties()
    self:SetupFrame()
    self:SetupStand()
    self:UpdateInfoPad()
    self:LoadOwnerAvatar()
    self:SetupInteraction()
    self:SetupGamePass()
end

function Diorama:ApplyWallProperties()
    local base = self.Model:FindFirstChild("Base")
    if not base then return end
    local wall = base:FindFirstChild("Wall")
    if wall and wall:IsA("BasePart") then
        wall.Color = self.WallColor
        wall.Material = self.WallMaterial
    end
end

function Diorama:SetupFrame()
    local existingFrame = self.InfoPad:FindFirstChild("Frame")
    if existingFrame then
        self.Frame = existingFrame
        return
    end
    self.Frame = DioramaTemplates.createFrameForInfoPad(self.InfoPad, self.FrameType)
end

function Diorama:UpdateFrame(newFrameType)
    local oldFrame = self.InfoPad:FindFirstChild("Frame")
    if oldFrame then
        oldFrame:Destroy()
    end
    self.Frame = DioramaTemplates.createFrameForInfoPad(self.InfoPad, newFrameType)
    if self.Frame then
        return true, "Рамка изменена"
    else
        return false, "Не удалось создать рамку"
    end
end

function Diorama:SetupStand()
    local existingStand = self.StandBase:FindFirstChild("Stand")
    if existingStand then
        self.Stand = existingStand
        return
    end
    self.Stand = DioramaTemplates.setupStandOnBase(self.Model, self.StandType)
end

function Diorama:UpdateStand(newStandType)
    local oldStand = self.StandBase:FindFirstChild("Stand")
    if oldStand then
        oldStand:Destroy()
    end
    self.Stand = DioramaTemplates.setupStandOnBase(self.Model, newStandType)
    if self.Stand then
        return true, "Стенд изменен"
    else
        return false, "Не удалось создать стенд"
    end
end

function Diorama:SetupGamePass()
    if self.GamePassId and self.GamePassInfo then
        print(string.format("[Diorama] Диорама %s выставлена на продажу за %d Robux", 
            self.DioramaId, self.GamePassInfo.PriceInRobux))
    end
end

function Diorama:UpdateInfoPad()
    if not self.SurfaceGui then return end
    
    local gui = self.SurfaceGui
    local ownerName = "Свободно"
    local colors = DioramaConfig.RARITY_COLORS[self.Rarity] or DioramaConfig.RARITY_COLORS.Common
    
    if self.OwnerId then
        ownerName = self.OwnerName or "Игрок " .. tostring(self.OwnerId)
        -- Если имя ещё не разрешено, пробуем получить его асинхронно
        if not self.OwnerName then
            task.spawn(function()
                self:ResolveOwnerName()
            end)
        end
    end
    
    local background = gui:FindFirstChild("Background")
    if not background then return end

    local infoFrame = background:FindFirstChild("InfoFrame")
    if infoFrame then
        local uiStroke = infoFrame:FindFirstChild("UIStroke")
        if uiStroke then uiStroke.Color = colors.Color1 end
        
        local nameLabel = infoFrame:FindFirstChild("3SceneNameItem")
        if nameLabel then
            local sceneNameValue = nameLabel:FindFirstChild("SceneNameValue")
            if sceneNameValue then sceneNameValue.Text = self.SceneName end
        end
        
        local collectionLabel = infoFrame:FindFirstChild("4SceneCollectionItem")
        if collectionLabel then
            local sceneCollectionValue = collectionLabel:FindFirstChild("SceneCollectionValue")
            if sceneCollectionValue then sceneCollectionValue.Text = self.Collection end
        end
        
        local seasonLabel = infoFrame:FindFirstChild("5SceneSeasonItem")
        if seasonLabel then
            local sceneSeasonValue = seasonLabel:FindFirstChild("SceneSeasonValue")
            if sceneSeasonValue then sceneSeasonValue.Text = self.Season end
        end
        
        local rarityItem = infoFrame:FindFirstChild("6SceneRareItem")
        if rarityItem then
            local rarityBadge = rarityItem:FindFirstChild("RarityBadge")
            if rarityBadge then
                local textLabel = rarityBadge:FindFirstChild("TextLabel")
                if textLabel then 
                    textLabel.Text = DioramaConfig.RARITY_NAMES[self.Rarity] or self.Rarity 
                end
                local uiGradient = rarityBadge:FindFirstChild("UIGradient")
                if uiGradient then
                    uiGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, colors.Color1), 
                        ColorSequenceKeypoint.new(1, colors.Color2)
                    })
                end
            end
        end
    end

    local ownerFrame = background:FindFirstChild("OwnerFrame")
    if ownerFrame then
        local ownerFrameStroke = ownerFrame:FindFirstChild("UIStroke")
        if ownerFrameStroke then ownerFrameStroke.Color = colors.Color1 end
        
        local ownerInfo = ownerFrame:FindFirstChild("OwnerInfo")
        if ownerInfo then
            local ownerNameValue = ownerInfo:FindFirstChild("OwnerNameValue")
            if ownerNameValue then
                ownerNameValue.Text = ownerName
                ownerNameValue.TextColor3 = colors.Color1
            end
            
            local purchaseDateLabel = ownerInfo:FindFirstChild("PurchaseDateLabel")
            if purchaseDateLabel then
                if self.PurchaseDate then
                    local day = os.date("%d", self.PurchaseDate)
                    local month = os.date("%m", self.PurchaseDate)
                    local year = os.date("%Y", self.PurchaseDate)
                    purchaseDateLabel.Visible = true
                    purchaseDateLabel.Text = string.format("Владеет сценой с %s.%s.%s", day, month, year)
                else
                    purchaseDateLabel.Visible = false
                end
            end
        end
    end

    local priceFrame = background:FindFirstChild("PriceFrame")
    if priceFrame then
        local priceFrameStroke = priceFrame:FindFirstChild("UIStroke")
        if priceFrameStroke then priceFrameStroke.Color = colors.Color1 end
        
        local priceContainer = priceFrame:FindFirstChild("PriceContainer")
        if priceContainer then
            local goldPriceBox = priceContainer:FindFirstChild("GoldPriceBox")
            if goldPriceBox then
                local priceTag = goldPriceBox:FindFirstChild("GoldPriceValue")
                if priceTag then priceTag.Text = DioramaUtils.formatNumber(self.CurrentPrice) end
            end
            
            local robuxPriceBox = priceContainer:FindFirstChild("RobuxPriceBox")
            if robuxPriceBox then
                if self.GamePassInfo then
                    robuxPriceBox.Visible = true
                    local robuxPriceLabel = robuxPriceBox:FindFirstChild("RobuxPriceLabel")
                    if robuxPriceLabel then 
                        robuxPriceLabel.Text = DioramaUtils.formatNumber(self.GamePassInfo.PriceInRobux) 
                    end
                else
                    robuxPriceBox.Visible = false
                end
            end
        end
    end

    local ratingFrame = background:FindFirstChild("RatingFrame")
    if ratingFrame then
        local ratingFrameStroke = ratingFrame:FindFirstChild("UIStroke")
        if ratingFrameStroke then ratingFrameStroke.Color = colors.Color1 end
        
        local ratingContainer = ratingFrame:FindFirstChild("RatingContainer")
        if ratingContainer then
            local ratingLabel = ratingContainer:FindFirstChild("RatingLabel")
            if ratingLabel then
                local starsCount = math.round(self.Rating)
                local starsString = string.rep("⭐", math.clamp(starsCount, 0, 10))
                ratingLabel.Text = starsString .. string.format("  %.1f", self.Rating)
            end
            
            local votesLabel = ratingContainer:FindFirstChild("VotesLabel")
            if votesLabel then
                votesLabel.Text = string.format("👍 %d | 👎 %d", self.Upvotes, self.Downvotes)
            end
        end
    end
end

function Diorama:RemoveAllPoses()
    for _, poseTrack in pairs(self.PoseTracks) do
        if poseTrack then poseTrack:Stop() end
    end
    self.PoseTracks = {}
end

function Diorama:LoadOwnerAvatar()
    self:RemoveAllPoses()
    
    -- Удаляем старые аватары
    for _, spot in ipairs(self.AvatarSpots:GetChildren()) do
        for _, child in ipairs(spot:GetChildren()) do
            child:Destroy()
        end
    end
    
    if not self.OwnerId then return end
    
    local currentSpot = self:GetCurrentAvatarSpot()
    if not currentSpot then return end
    
    local success, characterModel = pcall(function()
        local humanoidDescription = Players:GetHumanoidDescriptionFromUserIdAsync(self.OwnerId)
        return Players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Default)
    end)
    
    if not success or not characterModel then
        local templateCharacter = DioramaTemplates.getTemplateCharacter()
        if templateCharacter then 
            characterModel = templateCharacter:Clone() 
        else 
            return 
        end
    end
    
    local humanoid = characterModel:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    
    for _, child in ipairs(characterModel:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Tool") then 
            child:Destroy() 
        end
    end
    
    characterModel.Parent = currentSpot
    
    local primaryPart = characterModel.PrimaryPart or characterModel:FindFirstChild("HumanoidRootPart")
    if not primaryPart then
        for _, part in ipairs(characterModel:GetDescendants()) do
            if part:IsA("BasePart") then 
                primaryPart = part
                characterModel.PrimaryPart = part
                break 
            end
        end
    end
    
    if not primaryPart then 
        characterModel:Destroy() 
        return 
    end
    
    primaryPart.Anchored = true
    
    local spotRotation = currentSpot:GetAttribute("Rotation") or 0
    characterModel:SetPrimaryPartCFrame(CFrame.new())
    
    local minY = math.huge
    for _, part in ipairs(characterModel:GetDescendants()) do
        if part:IsA("BasePart") then
            local y = part.Position.Y - part.Size.Y/2
            if y < minY then minY = y end
        end
    end
    
    local platformPosition = currentSpot.Position
    local platformHeight = currentSpot.Size.Y / 2
    local heightOffsetFromBottom = primaryPart.Position.Y - minY
    local targetYPosition = platformPosition.Y + platformHeight + heightOffsetFromBottom
    
    characterModel:SetPrimaryPartCFrame(
        CFrame.new(platformPosition.X, targetYPosition, platformPosition.Z) *
        CFrame.Angles(0, math.rad(spotRotation), 0)
    )
    
    local poseName = currentSpot:GetAttribute("PoseName") or ""
    if poseName and poseName ~= "" then
        self.PoseTracks[self.CurrentSpot] = DioramaTemplates.applyPoseToDiorama(characterModel, poseName)
    end
end

function Diorama:SetupInteraction()
    local interactionPart = self.Model:FindFirstChild("Interaction") or self.StandBase
    if not interactionPart then return end
    
    local proximityPrompt = interactionPart:FindFirstChild("ProximityPrompt")
    if not proximityPrompt then
        if self.Stand then
            local button = self.Stand:FindFirstChild("Button")
            if button then proximityPrompt = button:FindFirstChild("ProximityPrompt") end
        end
        if not proximityPrompt then return end
    end
    
    proximityPrompt.Triggered:Connect(function(player)
        local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
        if EventSystem then
            EventSystem.CallServerOnlyRPC("DioramaInteraction", player, self.DioramaId)
        end
    end)
end

-- Асинхронное разрешение имени владельца по OwnerId
function Diorama:ResolveOwnerName()
    if not self.OwnerId then return end
    if self.OwnerName then return end
    
    -- Сначала проверяем, онлайн ли игрок на этом сервере
    local player = Players:GetPlayerByUserId(self.OwnerId)
    if player then
        self.OwnerName = player.Name
        self:UpdateInfoPad()
        return
    end
    
    -- Запрос через API
    local success, name = pcall(function()
        return Players:GetNameFromUserIdAsync(self.OwnerId)
    end)
    
    if success and name then
        self.OwnerName = name
        print(string.format("[DioramaClass] ResolveOwnerName: разрешено имя '%s' для OwnerId %d", name, self.OwnerId))
        self:UpdateInfoPad()
    else
        warn(string.format("[DioramaClass] ResolveOwnerName: не удалось разрешить имя для OwnerId %d", self.OwnerId))
    end
end

-- Экспорт SERVER_UUID для использования в других модулях
Diorama.GetServerUUID = function()
    return SERVER_UUID
end

Diorama.IsGamePassActiveOnOtherDiorama = isGamePassActiveOnOtherDiorama
Diorama.RegisterActiveGamePass = registerActiveGamePass
Diorama.UnregisterActiveGamePass = unregisterActiveGamePass

return Diorama