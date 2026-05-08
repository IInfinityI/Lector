local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local AssetConfig = require(ServerStorage:WaitForChild("AssetConfig"))

-- Создаем метатаблицу для API
local AssetServiceAPI = {}
AssetServiceAPI.__index = AssetServiceAPI

-- Внутренние переменные
local statusFolder = nil
local assetsLoaded = false
local loadedModules = {} -- Таблица для хранения загруженных модулей

-- Создаем папку для отслеживания статусов
local function createStatusFolder()
	local folder = Instance.new("Folder")
	folder.Name = "AssetStatus"
	folder.Parent = ReplicatedStorage
	return folder
end

-- Создаем папку для конкретного ассета с его статусами
local function createAssetStatus(assetInfo)
	if not statusFolder then
		statusFolder = createStatusFolder()
	end
	
	if statusFolder:FindFirstChild(assetInfo.instanceName) then
		return statusFolder:FindFirstChild(assetInfo.instanceName)
	end
	
	local assetFolder = Instance.new("Folder")
	assetFolder.Name = assetInfo.instanceName
	assetFolder.Parent = statusFolder
	
	-- Создаем значения статусов
	local loaded = Instance.new("BoolValue")
	loaded.Name = "Loaded"
	loaded.Value = false
	loaded.Parent = assetFolder
	
	local initialized = Instance.new("BoolValue")
	initialized.Name = "Initialized"
	initialized.Value = false
	initialized.Parent = assetFolder
	
	local globalVarCreated = Instance.new("BoolValue")
	globalVarCreated.Name = "GlobalVariableCreated"
	globalVarCreated.Value = false
	globalVarCreated.Parent = assetFolder
	
	-- Добавляем информацию об ассете
	local assetId = Instance.new("NumberValue")
	assetId.Name = "AssetId"
	assetId.Value = assetInfo.assetId
	assetId.Parent = assetFolder
	
	local assetType = Instance.new("StringValue")
	assetType.Name = "AssetType"
	assetType.Value = assetInfo.assetType
	assetType.Parent = assetFolder
	
	if assetInfo.configModule then
		local configModule = Instance.new("ObjectValue")
		configModule.Name = "ConfigModule"
		configModule.Value = assetInfo.configModule
		configModule.Parent = assetFolder
	end
	
	if assetInfo.configAssetId then
		local configAssetId = Instance.new("NumberValue")
		configAssetId.Name = "ConfigAssetId"
		configAssetId.Value = assetInfo.configAssetId
		configAssetId.Parent = assetFolder
	end
	
	if assetInfo.globalVariableName then
		local globalVarName = Instance.new("StringValue")
		globalVarName.Name = "GlobalVariableName"
		globalVarName.Value = assetInfo.globalVariableName
		globalVarName.Parent = assetFolder
	end
	
	local loadTime = Instance.new("StringValue")
	loadTime.Name = "LoadTime"
	loadTime.Value = ""
	loadTime.Parent = assetFolder
	
	local errorLog = Instance.new("StringValue")
	errorLog.Name = "LastError"
	errorLog.Value = ""
	errorLog.Parent = assetFolder
	
	return assetFolder
end

-- Обновляем статус ассета
local function updateAssetStatus(instanceName, status, value)
	if not statusFolder then return false end
	
	local assetFolder = statusFolder:FindFirstChild(instanceName)
	if not assetFolder then return false end
	
	local statusValue = assetFolder:FindFirstChild(status)
	if statusValue then
		statusValue.Value = value
		return true
	end
	return false
end

-- Записываем ошибку
local function logError(instanceName, errorMessage)
	if not statusFolder then return false end
	
	local assetFolder = statusFolder:FindFirstChild(instanceName)
	if not assetFolder then return false end
	
	local errorLog = assetFolder:FindFirstChild("LastError")
	if errorLog then
		errorLog.Value = errorMessage
	end
	
	local loadTime = assetFolder:FindFirstChild("LoadTime")
	if loadTime then
		loadTime.Value = os.date("%X")
	end
end

-- Записываем время загрузки
local function logLoadTime(instanceName)
	if not statusFolder then return false end
	
	local assetFolder = statusFolder:FindFirstChild(instanceName)
	if not assetFolder then return false end
	
	local loadTime = assetFolder:FindFirstChild("LoadTime")
	if loadTime then
		loadTime.Value = os.date("%X")
	end
end

-- Получаем ссылку на модуль из внутренней таблицы
local function getModuleReference(instanceName)
	return loadedModules[instanceName]
end

-- Устанавливаем ссылку на модуль во внутренней таблице
local function setModuleReference(instanceName, module)
	loadedModules[instanceName] = module
	return true
end

-- Функция логирования
local function log(message, level)
	if not AssetConfig.options.enableLogging then return end
	level = level or "INFO"
	print(string.format("[%s] %s: %s", os.date("%X"), level, message))
end

-- Функция загрузки конфига из ModuleScript объекта
local function loadConfigFromModule(configModule)
	log(string.format("Конфиг модуль %s подготовлен для передачи", configModule.Name))
	-- Возвращаем сам ModuleScript объект, а не результат require
	return configModule
end

-- Функция загрузки конфига из ассета
local function loadConfigFromAsset(configAssetId)
	local success, configAsset = pcall(function()
		local asset = InsertService:LoadAsset(configAssetId)
		local configScript = asset:FindFirstChildWhichIsA("ModuleScript")
		if configScript then
			return configScript
		end
		return nil
	end)

	if success and configAsset then
		log(string.format("Конфиг из ассета %d успешно загружен", configAssetId))
		return configAsset
	else
		log(string.format("Ошибка загрузки конфига из ассета %d", configAssetId), "ERROR")
		return nil
	end
end

-- Функция загрузки конфига
local function loadConfig(assetInfo)
	-- Приоритет: configModule > configAssetId
	if assetInfo.configModule then
		return loadConfigFromModule(assetInfo.configModule)
	elseif assetInfo.configAssetId then
		return loadConfigFromAsset(assetInfo.configAssetId)
	end
	return nil
end

-- Функция инициализации модуля с конфигом
local function initializeModuleWithConfig(module, assetInfo)
	local config = loadConfig(assetInfo)
	if not config then
		if assetInfo.configModule or assetInfo.configAssetId then
			log(string.format("Не удалось загрузить конфиг для модуля %s", assetInfo.instanceName), "WARN")
		end
		return module, false
	end

	-- Проверяем что config является ModuleScript
	if not config:IsA("ModuleScript") then
		logError(assetInfo.instanceName, "Config is not a ModuleScript")
		return module, false
	end

	local success, result = pcall(function()
		if type(module.Init) == "function" then
			-- Передаем ModuleScript объект напрямую в Init
			return module.Init(config)
		else
			log(string.format("Модуль %s не имеет метода Init", assetInfo.instanceName), "WARN")
			return module, false
		end
	end)
	
	if success then
		-- Проверяем, что результат - таблица (корректный модуль)
		if type(result) == "table" then
			log(string.format("Модуль %s успешно инициализирован с конфигом", assetInfo.instanceName))
			return result, true
		else
			-- Если модуль возвращает не таблицу (например, boolean), используем исходный модуль
			log(string.format("Модуль %s вернул не таблицу после инициализации, используется исходный модуль", assetInfo.instanceName), "WARN")
			return module, true
		end
	else
		logError(assetInfo.instanceName, string.format("Ошибка инициализации: %s", tostring(result)))
		log(string.format("Ошибка инициализации модуля %s: %s", assetInfo.instanceName, tostring(result)), "ERROR")
		return module, false
	end
end

-- Функция создания глобальной переменной
local function createGlobalVariable(module, assetInfo)
	if assetInfo.globalVariableName then
		local success, result = pcall(function()
			_G[assetInfo.globalVariableName] = module
			return true
		end)
		
		if success then
			log(string.format("Глобальная переменная %s создана для %s", assetInfo.globalVariableName, assetInfo.instanceName))
			updateAssetStatus(assetInfo.instanceName, "GlobalVariableCreated", true)
			return true
		else
			logError(assetInfo.instanceName, string.format("Ошибка создания глобальной переменной: %s", tostring(result)))
			log(string.format("Ошибка создания глобальной переменной %s: %s", assetInfo.globalVariableName, tostring(result)), "ERROR")
			return false
		end
	end
	return true
end

-- Функция загрузки одиночного ассета
local function loadAsset(assetInfo, attempt)
	attempt = attempt or 1

	log(string.format("Попытка загрузки ассета %d (%s)...", assetInfo.assetId, assetInfo.instanceName))

	-- Создаем папку статусов для ассета
	createAssetStatus(assetInfo)

	-- Проверяем существует ли уже объект
	if assetInfo.targetLocation:FindFirstChild(assetInfo.instanceName) then
		local existingInstance = assetInfo.targetLocation:FindFirstChild(assetInfo.instanceName)
		
		-- Если это ModuleScript и он уже загружен, получаем модуль
		if assetInfo.assetType == "ModuleScript" then
			local moduleSuccess, module = pcall(function()
				return require(existingInstance)
			end)
			
			if moduleSuccess and type(module) == "table" then
				setModuleReference(assetInfo.instanceName, module)
				updateAssetStatus(assetInfo.instanceName, "Loaded", true)
				logLoadTime(assetInfo.instanceName)
				
				-- Если есть конфиг, но модуль еще не инициализирован
				if (assetInfo.configModule or assetInfo.configAssetId) then
					local status = _G.AssetService:GetAssetStatus(assetInfo.instanceName)
					if not status or not status.initialized then
						local initializedModule, initSuccess = initializeModuleWithConfig(module, assetInfo)
						if initSuccess and type(initializedModule) == "table" then
							setModuleReference(assetInfo.instanceName, initializedModule)
							module = initializedModule
						end
						
						if initSuccess then
							updateAssetStatus(assetInfo.instanceName, "Initialized", true)
						end
					end
				end
				
				-- Создаем глобальную переменную
				createGlobalVariable(module, assetInfo)
			end
		end
		
		log(string.format("Ассет %s уже существует в %s", assetInfo.instanceName, assetInfo.targetLocation.Name))
		return true
	end

	local success, result = pcall(function()
		local loadedAsset = InsertService:LoadAsset(assetInfo.assetId)
		return loadedAsset
	end)

	if success and result then
		-- Поиск нужного объекта в загруженном ассете
		local foundInstance
		if assetInfo.assetType == "ModuleScript" then
			foundInstance = result:FindFirstChildWhichIsA("ModuleScript")
		elseif assetInfo.assetType == "Model" then
			foundInstance = result:FindFirstChildWhichIsA("Model")
		else
			foundInstance = result:FindFirstChild(assetInfo.instanceName) or result:GetChildren()[1]
		end

		if foundInstance then
			-- Клонирование в целевую локацию
			local clone = foundInstance:Clone()
			clone.Parent = assetInfo.targetLocation
			clone.Name = assetInfo.instanceName

			-- Обновляем статус загрузки и время
			updateAssetStatus(assetInfo.instanceName, "Loaded", true)
			logLoadTime(assetInfo.instanceName)

			-- Для ModuleScript выполняем дополнительную обработку
			if assetInfo.assetType == "ModuleScript" then
				local moduleSuccess, module = pcall(function()
					return require(clone)
				end)
				
				if moduleSuccess and type(module) == "table" then
					-- Сохраняем ссылку на модуль во внутренней таблице
					setModuleReference(assetInfo.instanceName, module)
					
					-- Если есть конфиг - инициализируем модуль с конфигом
					if assetInfo.configModule or assetInfo.configAssetId then
						local initializedModule, initSuccess = initializeModuleWithConfig(module, assetInfo)
						
						-- Обновляем ссылку на модуль только если это таблица
						if type(initializedModule) == "table" then
							setModuleReference(assetInfo.instanceName, initializedModule)
							module = initializedModule
						end
						
						if initSuccess then
							updateAssetStatus(assetInfo.instanceName, "Initialized", true)
						end
						
						-- Создаем глобальную переменную для модуля
						createGlobalVariable(module, assetInfo)
					else
						log(string.format("Модуль %s загружен без инициализации (конфиг не указан)", assetInfo.instanceName))
						-- Создаем глобальную переменную даже если нет конфига
						createGlobalVariable(module, assetInfo)
					end
					
					-- Предоставляем модулю API для обновления своего статуса только если это таблица
					if type(module) == "table" and type(module.SetAssetStatusAPI) == "function" then
						local statusAPI = {
							MarkAsInitialized = function()
								updateAssetStatus(assetInfo.instanceName, "Initialized", true)
								log(string.format("Модуль %s помечен как инициализированный", assetInfo.instanceName))
							end,
							MarkGlobalVariableCreated = function()
								updateAssetStatus(assetInfo.instanceName, "GlobalVariableCreated", true)
								log(string.format("Глобальная переменная для %s создана", assetInfo.instanceName))
							end,
							GetStatus = function()
								return _G.AssetService:GetAssetStatus(assetInfo.instanceName)
							end,
							LogError = function(errorMsg)
								logError(assetInfo.instanceName, errorMsg)
							end
						}
						module:SetAssetStatusAPI(statusAPI)
					end
				else
					local errorMsg = moduleSuccess and "Модуль не вернул таблицу" or tostring(module)
					logError(assetInfo.instanceName, string.format("Ошибка загрузки модуля: %s", errorMsg))
					log(string.format("Ошибка загрузки модуля %s: %s", assetInfo.instanceName, errorMsg), "ERROR")
				end
			end

			-- Если loadOnClient true и это ModuleScript, копируем в ReplicatedStorage
			local shouldLoadOnClient = assetInfo.loadOnClient == true
			if shouldLoadOnClient and assetInfo.assetType == "ModuleScript" and assetInfo.targetLocation ~= ReplicatedStorage then
				local clientClone = clone:Clone()
				clientClone.Parent = ReplicatedStorage
				log(string.format("Копия модуля %s создана в ReplicatedStorage для клиента", assetInfo.instanceName))
			end

			result:Destroy()
			log(string.format("Ассет %s успешно загружен в %s", assetInfo.instanceName, assetInfo.targetLocation.Name))
			return true
		else
			local errorMsg = string.format("Не удалось найти %s в ассете %d", assetInfo.assetType, assetInfo.assetId)
			logError(assetInfo.instanceName, errorMsg)
			warn(errorMsg)
			return false
		end
	else
		local errorMsg = string.format("Ошибка загрузки ассета %d: %s", assetInfo.assetId, tostring(result))
		logError(assetInfo.instanceName, errorMsg)
		log(errorMsg, "ERROR")

		if attempt < AssetConfig.options.maxRetryAttempts then
			task.wait(AssetConfig.options.retryDelay)
			return loadAsset(assetInfo, attempt + 1)
		else
			warn(string.format("Достигнуто максимальное количество попыток для ассета %d", assetInfo.assetId))
			return false
		end
	end
end

-- Функция для получения статуса ассета
function AssetServiceAPI:GetAssetStatus(instanceName)
	if not statusFolder then return nil end
	
	local assetFolder = statusFolder:FindFirstChild(instanceName)
	if not assetFolder then return nil end
	
	local configModuleValue = assetFolder:FindFirstChild("ConfigModule")
	local configAssetIdValue = assetFolder:FindFirstChild("ConfigAssetId")
	local globalVarNameValue = assetFolder:FindFirstChild("GlobalVariableName")
	local loadTimeValue = assetFolder:FindFirstChild("LoadTime")
	local errorValue = assetFolder:FindFirstChild("LastError")
	
	return {
		loaded = assetFolder:FindFirstChild("Loaded") and assetFolder.Loaded.Value or false,
		initialized = assetFolder:FindFirstChild("Initialized") and assetFolder.Initialized.Value or false,
		globalVariableCreated = assetFolder:FindFirstChild("GlobalVariableCreated") and assetFolder.GlobalVariableCreated.Value or false,
		assetId = assetFolder:FindFirstChild("AssetId") and assetFolder.AssetId.Value or nil,
		assetType = assetFolder:FindFirstChild("AssetType") and assetFolder.AssetType.Value or nil,
		configModule = configModuleValue and configModuleValue.Value or nil,
		configAssetId = configAssetIdValue and configAssetIdValue.Value or nil,
		globalVariableName = globalVarNameValue and globalVarNameValue.Value or nil,
		moduleReference = getModuleReference(instanceName),
		loadTime = loadTimeValue and loadTimeValue.Value or nil,
		lastError = errorValue and errorValue.Value or nil,
		success = (assetFolder:FindFirstChild("Loaded") and assetFolder.Loaded.Value) and 
		         (not assetFolder:FindFirstChild("LastError") or assetFolder.LastError.Value == "")
	}
end

-- Функция для проверки статусов всех ассетов
function AssetServiceAPI:GetAllAssetStatuses()
	if not statusFolder then return {} end
	
	local statuses = {}
	for _, assetFolder in ipairs(statusFolder:GetChildren()) do
		statuses[assetFolder.Name] = self:GetAssetStatus(assetFolder.Name)
	end
	
	return statuses
end

-- Функция для получения общей статистики
function AssetServiceAPI:GetOverallStats()
	local statuses = self:GetAllAssetStatuses()
	local stats = {
		total = 0,
		loaded = 0,
		initialized = 0,
		globalVarsCreated = 0,
		errors = 0,
		successRate = 0
	}
	
	for _, status in pairs(statuses) do
		stats.total = stats.total + 1
		if status.loaded then stats.loaded = stats.loaded + 1 end
		if status.initialized then stats.initialized = stats.initialized + 1 end
		if status.globalVariableCreated then stats.globalVarsCreated = stats.globalVarsCreated + 1 end
		if status.lastError and status.lastError ~= "" then stats.errors = stats.errors + 1 end
	end
	
	if stats.total > 0 then
		stats.successRate = math.floor((stats.loaded / stats.total) * 100)
	end
	
	return stats
end

-- Функция для получения информации о конкретном модуле
function AssetServiceAPI:GetModuleInfo(instanceName)
	local status = self:GetAssetStatus(instanceName)
	if not status then return nil end
	
	-- Находим конфигурацию ассета
	local assetConfig
	for _, asset in ipairs(AssetConfig.assets) do
		if asset.instanceName == instanceName then
			assetConfig = asset
			break
		end
	end
	
	return {
		status = status,
		config = assetConfig,
		isReady = status.loaded and (status.initialized or not (status.configAssetId or status.configModule)),
		hasConfig = (status.configAssetId ~= nil) or (status.configModule ~= nil),
		hasGlobalVariable = status.globalVariableName ~= nil,
		module = status.moduleReference
	}
end

-- Функция для получения информации о всех модулях
function AssetServiceAPI:GetAllModulesInfo()
	local allStatuses = self:GetAllAssetStatuses()
	local modulesInfo = {}
	
	for instanceName, status in pairs(allStatuses) do
		modulesInfo[instanceName] = self:GetModuleInfo(instanceName)
	end
	
	return modulesInfo
end

-- Функция для проверки готовности модуля
function AssetServiceAPI:IsModuleReady(instanceName)
	local info = self:GetModuleInfo(instanceName)
	return info and info.isReady or false
end

-- Функция для получения модуля по имени
function AssetServiceAPI:GetModule(instanceName)
	return getModuleReference(instanceName)
end

-- Функция для получения списка модулей с ошибками
function AssetServiceAPI:GetFailedModules()
	local allInfo = self:GetAllModulesInfo()
	local failed = {}
	
	for instanceName, info in pairs(allInfo) do
		if info.status.lastError and info.status.lastError ~= "" then
			failed[instanceName] = info
		end
	end
	
	return failed
end

-- Функция для принудительной инициализации модуля
function AssetServiceAPI:InitializeModule(instanceName, config)
	local status = self:GetAssetStatus(instanceName)
	if not status or not status.loaded then
		log(string.format("Модуль %s не загружен, инициализация невозможна", instanceName), "ERROR")
		return false
	end
	
	if status.initialized then
		log(string.format("Модуль %s уже инициализирован", instanceName))
		return true
	end
	
	local module = getModuleReference(instanceName)
	if not module then
		log(string.format("Ссылка на модуль %s не найдена", instanceName), "ERROR")
		return false
	end
	
	local success, result = pcall(function()
		if type(module.Init) == "function" then
			return module:Init(config)
		else
			error("Модуль не имеет метода Init")
		end
	end)
	
	if success then
		updateAssetStatus(instanceName, "Initialized", true)
		-- Обновляем ссылку только если результат - таблица
		if type(result) == "table" then
			setModuleReference(instanceName, result)
		end
		log(string.format("Модуль %s успешно инициализирован", instanceName))
		return true
	else
		logError(instanceName, string.format("Ошибка инициализации: %s", tostring(result)))
		log(string.format("Ошибка инициализации модуля %s: %s", instanceName, tostring(result)), "ERROR")
		return false
	end
end

-- Функция для перезагрузки всех ассетов
function AssetServiceAPI:ReloadAssets()
	log("Перезагрузка всех ассетов...")
	
	-- Очищаем загруженные модули
	loadedModules = {}
	
	local successCount = 0
	for _, assetInfo in ipairs(AssetConfig.assets) do
		if loadAsset(assetInfo) then
			successCount = successCount + 1
		end
	end

	local stats = self:GetOverallStats()
	log(string.format("Перезагрузка завершена. Успешно загружено %d из %d ассетов (успех: %d%%)", 
		successCount, #AssetConfig.assets, stats.successRate))

	assetsLoaded = true
	return successCount == #AssetConfig.assets
end

-- Функция для проверки завершения загрузки
function AssetServiceAPI:IsLoaded()
	return assetsLoaded
end

-- Основная функция загрузки
local function loadAllAssets()
	log("Начало загрузки ассетов...")
	local successCount = 0

	for _, assetInfo in ipairs(AssetConfig.assets) do
		if loadAsset(assetInfo) then
			successCount = successCount + 1
		end
	end

	local stats = _G.AssetService:GetOverallStats()
	log(string.format("Завершено. Успешно загружено %d из %d ассетов (успех: %d%%)", 
		successCount, #AssetConfig.assets, stats.successRate))

	assetsLoaded = true
	return successCount == #AssetConfig.assets
end

-- Создаем глобальную переменную с API
_G.AssetService = setmetatable({}, AssetServiceAPI)

-- Запуск загрузки при старте игры
game:BindToClose(function()
	log("Остановка загрузчика ассетов...")
end)

-- Начинаем загрузку ассетов
loadAllAssets()

return AssetServiceAPI