return {
	assets = {
		{
			assetId = 96833377091747,
			targetLocation = game.ServerScriptService.Assets,
			instanceName = "TagBehaviorSystem",
			assetType = "ModuleScript"
		},
				{
			assetId = 98961204214026,
			targetLocation = game.ServerScriptService.Assets,
			instanceName = "DataManager",
			assetType = "ModuleScript"
		},
				{
			assetId = 89804882508202,
			targetLocation = game.ReplicatedStorage.Assets,
			instanceName = "EventSystem",
			assetType = "ModuleScript"
		},
		{
			assetId = 115212539598414,
			targetLocation = game.ServerScriptService.Assets,
			instanceName = "ToolsSystem",
			assetType = "ModuleScript"
		},
		{
			assetId = 101879024498489,
			targetLocation = game.ServerScriptService.Assets,
			instanceName = "AccessorySystem",
			assetType = "ModuleScript"
		}
	},

	options = {
		maxRetryAttempts = 1,      -- Количество попыток при ошибке
		retryDelay = 1,           -- Задержка между попытками (сек)
		enableLogging = true       -- Включить логирование
	}
}