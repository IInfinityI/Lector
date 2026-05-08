return {
	assets = {
		{
			assetId = 98961204214026,
			targetLocation = game.ServerStorage,
			instanceName = "DataManager",
			assetType = "ModuleScript",
			configModule = game.ServerStorage:WaitForChild("DataManagerConfig"),
			globalVariableName = "DataManager"
		},
		{
			assetId = 89804882508202,
			targetLocation = game.ServerStorage,
			instanceName = "EventSystem",
			assetType = "ModuleScript",
			configModule = game.ServerStorage:WaitForChild("EventConfig"),
			globalVariableName = "EventSystem"
		},
		{
			assetId = 89804882508203,
			targetLocation = game.ServerStorage,
			instanceName = "TestErrorModule",
			assetType = "ModuleScript"
		},
		{
			assetId = 85505509266935,
			targetLocation = game.ServerStorage,
			instanceName = "SharedLibrary",
			assetType = "ModuleScript",
			loadOnClient = true,
			globalVariableName = "SharedLibrary"
		}
	},

	options = {
		maxRetryAttempts = 1,
		retryDelay = 1,
		enableLogging = true
	}
}