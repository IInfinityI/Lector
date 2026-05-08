return {
	assets = {
		{
			assetId = 117878056761870,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "TestSystem",
			assetType = "ModuleScript"
		},
		{
			assetId = 96833377091747,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "TagBehaviorSystem",
			assetType = "ModuleScript"
		},
				{
			assetId = 98961204214026,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "DataManager",
			assetType = "ModuleScript"
		},
				{
			assetId = 89804882508202,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "EventSystem",
			assetType = "ModuleScript",
			loadOnClient = true
		},
		{
			assetId = 115212539598414,
			targetLocation = game.ServerStorage.Assets,
			instanceName = "ToolsSystem",
			assetType = "ModuleScript"
		}
	},

	options = {
		maxRetryAttempts = 1,      -- Количество попыток при ошибке
		retryDelay = 1,           -- Задержка между попытками (сек)
		enableLogging = true       -- Включить логирование
	}
}