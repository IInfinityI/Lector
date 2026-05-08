-- PlayerDataConfig.lua (путь может быть любым, например: ReplicatedStorage/GameConfig/PlayerDataConfig)
return {
    -- Начальные данные для нового игрока
    DefaultData = {
        coins = 100,
        gems = 10,
        level = 1,
        experience = 0,
        inventory = {},
        settings = {music = true, sfx = true}
    },
    
    -- Настройки DataStore
    DataStoreOptions = {
        Name = "PlayerData_v1",
        Scope = "global",
        SaveInterval = 60, -- секунд
        Retries = 5,
        WriteTimeout = 3,
        QueueTimeout = 30 -- максимальное время ожидания очереди
    },
    
    -- Поля для репликации на клиент
    ReplicatedFields = {"coins", "gems", "level", "experience"}
}