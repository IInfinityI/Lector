return {
	assets = {
		{
			assetId = 98961204214026,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "DataManager",
			assetType = "ModuleScript",
			configModule = game.ServerStorage:WaitForChild("Configs"):WaitForChild("DataConfig"),
			globalVariableName = "DataManager"
		},
		{
			assetId = 89804882508202,
			targetLocation = game.ReplicatedStorage.Assets,
			instanceName = "EventSystem",
			assetType = "ModuleScript",
			configModule = game.ServerStorage:WaitForChild("Configs"):WaitForChild("EventConfig"),
			globalVariableName = "EventSystem"
		},
		{
			assetId = 118294031651441,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "PremiumContentSystem",
			assetType = "ModuleScript"	
		}
	},

	options = {
		maxRetryAttempts = 1,      -- Количество попыток при ошибке
		retryDelay = 1,            -- Задержка между попытками (сек)
		enableLogging = false      -- Включить логирование
	}
}