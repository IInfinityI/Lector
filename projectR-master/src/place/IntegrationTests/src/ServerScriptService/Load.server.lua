local AssetsFolder = game.ServerStorage:WaitForChild("Assets")
local ConfigsFolder = game.ServerStorage:WaitForChild("Configs")

local DataManager = require(AssetsFolder:WaitForChild("DataManager"))
local TestSystem = require(AssetsFolder:WaitForChild("TestSystem"))
local TagBehaviorSystem = require(AssetsFolder:WaitForChild("TagBehaviorSystem"))
local EventSystem = require(AssetsFolder:WaitForChild("EventSystem"))
local ToolsSystem = require(AssetsFolder:WaitForChild("ToolsSystem"))

DataManager.Init(ConfigsFolder.DataConfig)
TagBehaviorSystem.Init(ConfigsFolder.TagConfig)
EventSystem.Init(ConfigsFolder.EventConfig)
ToolsSystem.Init(ConfigsFolder.ToolConfig)
local tester = TestSystem.new()

local TestSystemAsset = AssetsFolder.TestSystem
local DataManagerAsset = AssetsFolder.DataManager
local TagBehaviorSystemAsset = AssetsFolder.TagBehaviorSystem
local EventSystemAsset = AssetsFolder.EventSystem

tester:describe("Загрузка ассетов", function()
    it("Загрузка TestSystem", function()
		  expect(TestSystemAsset).toBeNotNil()
    end)
    it("Загрузка DataManager", function()
		  expect(DataManagerAsset).toBeNotNil()
    end)
    it("Загрузка TagBehaviorSystem", function()
		  expect(TagBehaviorSystemAsset).toBeNotNil()
    end)
    it("Загрузка EventSystem", function()
		  expect(EventSystemAsset).toBeNotNil()
    end)
end)

local ServerEventsFolder = game.ServerStorage:WaitForChild("EventSystemRemotes")
local ClientEventsFolder = game.ReplicatedStorage:WaitForChild("EventSystemRemotes")
local ServerEvent = ServerEventsFolder.GetPlayerData
local ClientEvent = ClientEventsFolder.BlockTouchedConfirmed

tester:describe("Создание эвнтов", function()
    it("Создана папка с эвентами на сервере", function()
		  expect(ServerEventsFolder).toBeNotNil()
    end)
    it("Создана папка с эвентами на клиенте", function()
		  expect(ClientEventsFolder).toBeNotNil()
    end)
    it("Проверка создания серверного эвента", function()
		  expect(ServerEvent).toBeNotNil()
    end)
    it("Проверка создания клиентского эвента", function()
		  expect(ClientEvent).toBeNotNil()
    end)
end)

-- Запускаем все тесты
tester:runAll()

EventSystem.OnServer("GetPlayerData", function(player)
    return DataManager.GetData(player)
end)

EventSystem.OnServer("UpdatePlayerData", function(player, updateFunction)
    if type(updateFunction) == "function" then
        DataManager.UpdateData(player, updateFunction)
        return true
    end
    return false
end)

EventSystem.OnServer("GetPlayerDataField", function(player, fieldName)
    local data = DataManager.GetData(player)
    return data and data[fieldName]
end)

-- Функция для проверки загрузки данных игрока
local function onPlayerDataLoaded(player)
    -- Можно добавить логику, которая выполняется после загрузки данных
    print(`Данные игрока {player.Name} загружены`)
    
    EventSystem.FireClient(player, "PlayerDataLoaded", DataManager.GetData(player))
end

-- Подписываемся на загрузку данных через атрибуты
game:GetService("Players").PlayerAdded:Connect(function(player)
    player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
        if player:GetAttribute("DataLoaded") then
            onPlayerDataLoaded(player)
        end
    end)
end)