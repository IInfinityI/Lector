return {
	assets = {
		{
			assetId = 117878056761870,
			targetLocation = game.ServerScriptService,
			instanceName = "TestSystem",
			assetType = "ModuleScript",
			globalVariableName = "TestSystem"
		},
		{
			assetId = 98961204214026,
			targetLocation = game.ServerScriptService,
			instanceName = "DataManager",
			assetType = "ModuleScript",
			configModule = game.ServerScriptService:WaitForChild("ConfigModule"),
			globalVariableName = "DataManager"
		}
	},

	options = {
		maxRetryAttempts = 1,      -- Количество попыток при ошибке
		retryDelay = 1,           -- Задержка между попытками (сек)
		enableLogging = false       -- Включить логирование
	}
}