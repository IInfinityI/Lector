while not _G.AssetService or not _G.AssetService:IsLoaded() do
    wait(1)
    print("Ожидание завершения загрузки ассетов...")
end

print("\n=== Начало тестирования AssetService ===")

-- Результаты тестов
local testResults = {
    passed = 0,
    failed = 0,
    total = 0
}

local function runTest(testName, testFunc)
    testResults.total = testResults.total + 1
    local success, message = pcall(testFunc)
    if success then
        testResults.passed = testResults.passed + 1
        print("✅ ТЕСТ ПРОЙДЕН: " .. testName)
    else
        testResults.failed = testResults.failed + 1
        print("❌ ТЕСТ ПРОВАЛЕН: " .. testName)
        print("   Ошибка: " .. tostring(message))
    end
end

-- Тест 1: Проверка базовой загрузки
runTest("Базовая загрузка ассетов", function()
    assert(_G.AssetService:IsLoaded(), "AssetService не загружен")
    
    local stats = _G.AssetService:GetOverallStats()
    assert(stats.total > 0, "Нет загруженных ассетов")
    assert(stats.loaded == 3, "Не все ассеты загружены")
    assert(stats.successRate == 75, "Процент успеха не 75%, один не загружен для тестов")
end)

-- Тест 2: Проверка существования модулей в ServerStorage
runTest("Существование модулей в ServerStorage", function()
    local dataManager = game.ServerStorage:FindFirstChild("DataManager")
    local eventSystem = game.ServerStorage:FindFirstChild("EventSystem")
    local sharedLibrary = game.ServerStorage:FindFirstChild("SharedLibrary")
    
    assert(dataManager ~= nil, "DataManager не найден в ServerStorage")
    assert(eventSystem ~= nil, "EventSystem не найден в ServerStorage")
    assert(sharedLibrary ~= nil, "SharedLibrary не найден в ServerStorage")
    assert(dataManager:IsA("ModuleScript"), "DataManager не является ModuleScript")
    assert(eventSystem:IsA("ModuleScript"), "EventSystem не является ModuleScript")
    assert(sharedLibrary:IsA("ModuleScript"), "SharedLibrary не является ModuleScript")
end)

-- Тест 3: Проверка репликации SharedLibrary на клиента
runTest("Репликация SharedLibrary на клиента", function()
    local sharedLibraryClient = game.ReplicatedStorage:FindFirstChild("SharedLibrary")
    assert(sharedLibraryClient ~= nil, "SharedLibrary не найден в ReplicatedStorage")
    assert(sharedLibraryClient:IsA("ModuleScript"), "SharedLibrary в ReplicatedStorage не является ModuleScript")
    
    -- Проверяем что другие модули НЕ реплицированы
    local dataManagerClient = game.ReplicatedStorage:FindFirstChild("DataManager")
    local eventSystemClient = game.ReplicatedStorage:FindFirstChild("EventSystem")
    assert(dataManagerClient == nil, "DataManager не должен быть в ReplicatedStorage")
    assert(eventSystemClient == nil, "EventSystem не должен быть в ReplicatedStorage")
end)

-- Тест 4: Проверка статусов отдельных ассетов
runTest("Статусы отдельных ассетов", function()
    local dataManagerStatus = _G.AssetService:GetAssetStatus("DataManager")
    local eventSystemStatus = _G.AssetService:GetAssetStatus("EventSystem")
    local sharedLibraryStatus = _G.AssetService:GetAssetStatus("SharedLibrary")
    
    assert(dataManagerStatus ~= nil, "Статус DataManager не найден")
    assert(eventSystemStatus ~= nil, "Статус EventSystem не найден")
    assert(sharedLibraryStatus ~= nil, "Статус SharedLibrary не найден")
    
    assert(dataManagerStatus.loaded, "DataManager не загружен")
    assert(eventSystemStatus.loaded, "EventSystem не загружен")
    assert(sharedLibraryStatus.loaded, "SharedLibrary не загружен")
end)

-- Тест 5: Проверка загрузки конфига из файла
runTest("Загрузка конфига из файла", function()
    local dataManagerInfo = _G.AssetService:GetModuleInfo("DataManager")
    assert(dataManagerInfo ~= nil, "Информация о DataManager не найдена")
    assert(dataManagerInfo.hasConfig, "DataManager должен иметь конфиг")
end)

-- Тест 7: Проверка глобальных переменных
runTest("Глобальные переменные", function()
    assert(_G.DataManager ~= nil, "Глобальная переменная DataManager не создана")
    assert(_G.SharedLibrary ~= nil, "Глобальная переменная SharedLibrary не создана")
    
    local dataManagerStatus = _G.AssetService:GetAssetStatus("DataManager")
    local sharedLibraryStatus = _G.AssetService:GetAssetStatus("SharedLibrary")
    
    assert(dataManagerStatus.globalVariableCreated, "GlobalVariableCreated для DataManager не установлен")
    assert(sharedLibraryStatus.globalVariableCreated, "GlobalVariableCreated для SharedLibrary не установлен")
end)

-- Тест 8: Проверка получения всех статусов
runTest("Получение всех статусов", function()
    local allStatuses = _G.AssetService:GetAllAssetStatuses()
    
    assert(type(allStatuses) == "table", "GetAllAssetStatuses не вернул таблицу")
    assert(allStatuses.DataManager ~= nil, "DataManager отсутствует в общих статусах")
    assert(allStatuses.EventSystem ~= nil, "EventSystem отсутствует в общих статусах")
    assert(allStatuses.SharedLibrary ~= nil, "SharedLibrary отсутствует в общих статусах")
    
    local count = 0
    for _ in pairs(allStatuses) do count = count + 1 end
    assert(count >= 3, "Неверное количество ассетов в общих статусах")
end)

-- Тест 9: Проверка общей статистики
runTest("Общая статистика", function()
    local stats = _G.AssetService:GetOverallStats()
    
    assert(stats.total >= 3, "Неверное общее количество ассетов")
    assert(stats.loaded >= 3, "Неверное количество загруженных ассетов")
    assert(stats.globalVarsCreated >= 2, "Неверное количество созданных глобальных переменных")
    assert(stats.successRate == 75, "Процент успеха должен быть 75%")
end)

-- Тест 10: Проверка информации о модулях
runTest("Информация о модулях", function()
    local dataManagerInfo = _G.AssetService:GetModuleInfo("DataManager")
    local eventSystemInfo = _G.AssetService:GetModuleInfo("EventSystem")
    local sharedLibraryInfo = _G.AssetService:GetModuleInfo("SharedLibrary")
    
    assert(dataManagerInfo ~= nil, "Информация о DataManager не найдена")
    assert(eventSystemInfo ~= nil, "Информация о EventSystem не найдена")
    assert(sharedLibraryInfo ~= nil, "Информация о SharedLibrary не найдена")
    
    -- Проверяем готовность модулей
    assert(_G.AssetService:IsModuleReady("DataManager"), "DataManager не готов")
    assert(_G.AssetService:IsModuleReady("EventSystem"), "EventSystem не готов")
    assert(_G.AssetService:IsModuleReady("SharedLibrary"), "SharedLibrary не готов")
end)

-- Тест 11: Проверка получения всех модулей
runTest("Получение всех модулей", function()
    local allModules = _G.AssetService:GetAllModulesInfo()
    
    assert(type(allModules) == "table", "GetAllModulesInfo не вернул таблицу")
    assert(allModules.DataManager ~= nil, "DataManager отсутствует в информации о модулях")
    assert(allModules.EventSystem ~= nil, "EventSystem отсутствует в информации о модулях")
    assert(allModules.SharedLibrary ~= nil, "SharedLibrary отсутствует в информации о модулях")
end)

-- Тест 12: Проверка получения модулей по ссылке
runTest("Получение модулей по ссылке", function()
    local dataManagerModule = _G.AssetService:GetModule("DataManager")
    local eventSystemModule = _G.AssetService:GetModule("EventSystem")
    local sharedLibraryModule = _G.AssetService:GetModule("SharedLibrary")
    
    -- Модули могут быть nil если они не возвращают таблицу при require
    if dataManagerModule then
        assert(type(dataManagerModule) == "table", "DataManager модуль не является таблицей")
    end
    
    if eventSystemModule then
        assert(type(eventSystemModule) == "table", "EventSystem модуль не является таблицей")
    end
    
    if sharedLibraryModule then
        assert(type(sharedLibraryModule) == "table", "SharedLibrary модуль не является таблицей")
    end
end)

-- Тест 13: Проверка получения модулей с ошибками
runTest("Модули с ошибками", function()
    local failedModules = _G.AssetService:GetFailedModules()
    
    assert(type(failedModules) == "table", "GetFailedModules не вернул таблицу")
    
    -- В идеале ошибок быть не должно
    if next(failedModules) ~= nil then
        print("   Предупреждение: найдены модули с ошибками:")
        for name, info in pairs(failedModules) do
            print("   - " .. name .. ": " .. tostring(info.status.lastError))
        end
    end
end)

-- Тест 14: Проверка структуры статуса ассета
runTest("Структура статуса ассета", function()
    local status = _G.AssetService:GetAssetStatus("DataManager")
    
    assert(status ~= nil, "Статус не найден")
    assert(type(status.loaded) == "boolean", "Поле loaded не boolean")
    assert(type(status.initialized) == "boolean", "Поле initialized не boolean")
    assert(type(status.globalVariableCreated) == "boolean", "Поле globalVariableCreated не boolean")
    assert(type(status.assetId) == "number", "Поле assetId не number")
    assert(type(status.assetType) == "string", "Поле assetType не string")
    assert(type(status.success) == "boolean", "Поле success не boolean")
end)

-- Тест 16: Проверка работы с несуществующими модулями
runTest("Работа с несуществующими модулями", function()
    local nonExistentStatus = _G.AssetService:GetAssetStatus("NonExistentModule")
    assert(nonExistentStatus == nil, "Статус несуществующего модуля не nil")
    
    local nonExistentInfo = _G.AssetService:GetModuleInfo("NonExistentModule")
    assert(nonExistentInfo == nil, "Информация о несуществующем модуле не nil")
    
    local nonExistentModule = _G.AssetService:GetModule("NonExistentModule")
    assert(nonExistentModule == nil, "Несуществующий модуль не nil")
    
    local nonExistentReady = _G.AssetService:IsModuleReady("NonExistentModule")
    assert(nonExistentReady == false, "Несуществующий модуль отмечен как готовый")
end)

-- Тест 17: Проверка папки статусов в ServerStorage
runTest("Папка статусов в ServerStorage", function()
    local statusFolder = game.ServerStorage:FindFirstChild("AssetStatus")
    assert(statusFolder ~= nil, "Папка AssetStatus не найдена")
    
    local dataManagerFolder = statusFolder:FindFirstChild("DataManager")
    local eventSystemFolder = statusFolder:FindFirstChild("EventSystem")
    local sharedLibraryFolder = statusFolder:FindFirstChild("SharedLibrary")
    
    assert(dataManagerFolder ~= nil, "Папка DataManager не найдена в статусах")
    assert(eventSystemFolder ~= nil, "Папка EventSystem не найдена в статусах")
    assert(sharedLibraryFolder ~= nil, "Папка SharedLibrary не найдена в статусах")
    
    -- Проверяем структуру папки статусов для DataManager
    local dataManagerLoaded = dataManagerFolder:FindFirstChild("Loaded")
    local dataManagerConfigModule = dataManagerFolder:FindFirstChild("ConfigModule")
    
    assert(dataManagerLoaded ~= nil, "Loaded значение не найдено")
    assert(dataManagerConfigModule ~= nil, "ConfigModule значение не найдено")
    assert(dataManagerLoaded:IsA("BoolValue"), "Loaded не BoolValue")
end)

-- Тест 18: Основные проверки EventSystem
runTest("Основные проверки EventSystem", function()
-- Проверяем, что EventSystem доступен в глобальном пространстве
    assert(_G.EventSystem ~= nil, "EventSystem не найден в _G")
    
    local EventSystem = _G.EventSystem
    
    -- Проверяем базовую структуру EventSystem
    assert(type(EventSystem) == "table", "EventSystem не является таблицей")
    assert(type(EventSystem.Init) == "function", "EventSystem.Init не является функцией")
    assert(type(EventSystem.FireClient) == "function", "EventSystem.FireClient не является функцией")
    assert(type(EventSystem.FireAllClients) == "function", "EventSystem.FireAllClients не является функцией")
    assert(type(EventSystem.CallRPC) == "function", "EventSystem.CallRPC не является функцией")
    assert(type(EventSystem.RegisterRPC) == "function", "EventSystem.RegisterRPC не является функцией")
    assert(type(EventSystem.RegisterServerOnlyRPC) == "function", "EventSystem.RegisterServerOnlyRPC не является функцией")
    
    -- Проверяем внутренние поля
    assert(type(EventSystem._remotes) == "table", "EventSystem._remotes не является таблицей")
    assert(type(EventSystem._bindables) == "table", "EventSystem._bindables не является таблицей")
    assert(type(EventSystem._serverHandlers) == "table", "EventSystem._serverHandlers не является таблицей")
    assert(type(EventSystem._serverRPCs) == "table", "EventSystem._serverRPCs не является таблицей")
    assert(type(EventSystem._serverOnlyRPCs) == "table", "EventSystem._serverOnlyRPCs не является таблицей")

    assert(EventSystem._initialized == true, "EventSystem не помечен как инициализированный")
    assert(EventSystem._config ~= nil, "Конфиг не загружен в EventSystem")
    
    -- Проверяем создание папок в ReplicatedStorage и ServerStorage
    local rs = game:GetService("ReplicatedStorage")
    local ss = game:GetService("ServerStorage")
    
    local remoteFolder = rs:FindFirstChild("EventSystemRemotes")
    assert(remoteFolder ~= nil, "Папка EventSystemRemotes не найдена в ReplicatedStorage")
    
    local serverOnlyFolder = ss:FindFirstChild("EventSystemRemotes")
    assert(serverOnlyFolder ~= nil, "Папка EventSystemRemotes не найдена в ServerStorage")
end)

-- Дополнительные проверки
print("\n=== Дополнительная информация ===")
local stats = _G.AssetService:GetOverallStats()
print(string.format("Всего ассетов: %d", stats.total))
print(string.format("Успешно загружено: %d", stats.loaded))
print(string.format("Инициализировано: %d", stats.initialized))
print(string.format("Создано глобальных переменных: %d", stats.globalVarsCreated))
print(string.format("Ошибок: %d", stats.errors))
print(string.format("Процент успеха: %d%%", stats.successRate))

local allModules = _G.AssetService:GetAllModulesInfo()
print("\n=== Статусы модулей ===")
for name, info in pairs(allModules) do
    local status = info.status
    print(string.format("Модуль %s:", name))
    print(string.format("  - Загружен: %s", tostring(status.loaded)))
    print(string.format("  - Инициализирован: %s", tostring(status.initialized)))
    print(string.format("  - Глобальная переменная: %s", tostring(status.globalVariableCreated)))
    print(string.format("  - Тип: %s", status.assetType))
    print(string.format("  - ID ассета: %d", status.assetId))
    print(string.format("  - ConfigModule: %s", status.ConfigModule or "нет"))
    print(string.format("  - ConfigAssetId: %s", status.configAssetId or "нет"))
    print(string.format("  - LoadOnClient: %s", tostring(info.config and info.config.loadOnClient or false)))
    print(string.format("  - Готов: %s", tostring(info.isReady)))
    if status.lastError and status.lastError ~= "" then
        print(string.format("  - Последняя ошибка: %s", status.lastError))
    end
    if status.loadTime and status.loadTime ~= "" then
        print(string.format("  - Время загрузки: %s", status.loadTime))
    end
end

-- Итоги тестирования
print("\n=== ИТОГИ ТЕСТИРОВАНИЯ ===")
print(string.format("Всего тестов: %d", testResults.total))
print(string.format("Пройдено: %d", testResults.passed))
print(string.format("Провалено: %d", testResults.failed))
print(string.format("Успешность: %.1f%%", (testResults.passed / testResults.total) * 100))

if testResults.failed == 0 then
    print("🎉 ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ!")
else
    print("⚠️  Некоторые тесты провалены. Проверьте вывод выше.")
end

return testResults