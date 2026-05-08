return {
    -- Конфигурация хранения
    Storage = {
        Remotes = "EventSystemRemotes",  -- Имя папки для событий
    },

    -- Клиент -> Сервер
    ClientToServer = {
        GetPlayerData = {
            SecurityCheck = function(player) return true end,
        },
        UpdatePlayerData = {
            SecurityCheck = function(player) return true end,
        },
        GetPlayerDataField = {
            SecurityCheck = function(player) return true end,
        },
    },

    -- Сервер -> Клиент
    ServerToClient = {
        PlayerMoneyChanged = {},
        NewQuestAvailable = {},
        BlockTouchedConfirmed = {},
    },

    -- Клиент -> Клиент
    ClientToClient = {
        ButtonClicked = {},
    },
}