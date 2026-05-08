local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local AssetConfig = require(ServerScriptService:WaitForChild("AssetConfig"))
local logger = {}

-- Функция логирования
local function log(message, level)
	if not AssetConfig.options.enableLogging then return end
	level = level or "INFO"
	print(string.format("[%s] %s: %s", os.date("%X"), level, message))
end

-- Функция загрузки одиночного ассета
local function loadAsset(assetInfo, attempt)
	attempt = attempt or 1

	log(string.format("Попытка загрузки ассета %d (%s)...", assetInfo.assetId, assetInfo.instanceName))

	-- Проверяем существует ли уже объект
	if assetInfo.targetLocation:FindFirstChild(assetInfo.instanceName) then
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

			-- Если это модуль и нужен на клиенте, копируем в ReplicatedStorage
			if assetInfo.loadOnClient ~= nil and assetInfo.loadOnClient ~= false and assetInfo.assetType == "ModuleScript" and assetInfo.targetLocation ~= ReplicatedStorage then
				local clientClone = clone:Clone()
				clientClone.Parent = ReplicatedStorage
				log(string.format("Копия модуля %s создана в ReplicatedStorage", assetInfo.instanceName))
			end

			result:Destroy()
			log(string.format("Ассет %s успешно загружен в %s", assetInfo.instanceName, assetInfo.targetLocation.Name))
			return true
		else
			warn(string.format("Не удалось найти %s в ассете %d", assetInfo.assetType, assetInfo.assetId))
			return false
		end
	else
		log(string.format("Ошибка загрузки ассета %d: %s", assetInfo.assetId, tostring(result)), "ERROR")

		if attempt < AssetConfig.options.maxRetryAttempts then
			task.wait(AssetConfig.options.retryDelay)
			return loadAsset(assetInfo, attempt + 1)
		else
			warn(string.format("Достигнуто максимальное количество попыток для ассета %d", assetInfo.assetId))
			return false
		end
	end
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

	log(string.format("Завершено. Успешно загружено %d из %d ассетов", 
		successCount, #AssetConfig.assets))

	return successCount == #AssetConfig.assets
end

-- Запуск загрузки при старте игры
game:BindToClose(function()
	log("Остановка загрузчика ассетов...")
end)

loadAllAssets()

return {
	ReloadAssets = loadAllAssets
}