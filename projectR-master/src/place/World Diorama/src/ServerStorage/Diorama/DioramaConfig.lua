local DioramaConfig = {}

DioramaConfig.DIORAMA_ECONOMY = {
    RARITY_MULTIPLIERS = {
        Common = 1.1,
        Uncommon = 1.15,
        Rare = 1.2,
        Epic = 1.25,
        Legendary = 1.3
    },
    BASE_PRICE_INCREASE = 1.0,
    INCOME_RATES = {
        Common = 100,
        Uncommon = 250,
        Rare = 600,
        Epic = 1500,
        Legendary = 4000
    },
    MAX_ACCUMULATION_TIME = 8 * 3600,
    RESALE_COMMISSION = 0.5,
    MINIMUM_PRICE = 10,
    QUICK_SELL_COMMISSION = 0.1,
    VOTE_SETTINGS = {
        VOTE_PRICE = {
            Common = 50,
            Uncommon = 75,
            Rare = 100,
            Epic = 150,
            Legendary = 200
        },
        MAX_RATING_INFLUENCE = 0.9,
        RATING_INFLUENCE_FACTOR = {
            Common = 0.5,
            Uncommon = 0.6,
            Rare = 0.7,
            Epic = 0.8,
            Legendary = 1.0
        },
    }
}

DioramaConfig.PREDEFINED_COLORS = {
    White = Color3.new(1, 1, 1),
    Black = Color3.new(0, 0, 0),
    Red = Color3.new(1, 0, 0),
    Green = Color3.new(0, 1, 0),
    Blue = Color3.new(0, 0, 1),
    Yellow = Color3.new(1, 1, 0),
    Cyan = Color3.new(0, 1, 1),
    Magenta = Color3.new(1, 0, 1),
    Gray = Color3.new(0.5, 0.5, 0.5),
}

DioramaConfig.RARITY_COLORS = {
    Common = { Color1 = Color3.fromRGB(150, 150, 150), Color2 = Color3.fromRGB(200, 200, 200) },
    Uncommon = { Color1 = Color3.fromRGB(30, 255, 0), Color2 = Color3.fromRGB(140, 255, 150) },
    Rare = { Color1 = Color3.fromRGB(0, 100, 255), Color2 = Color3.fromRGB(100, 150, 255) },
    Epic = { Color1 = Color3.fromRGB(180, 0, 255), Color2 = Color3.fromRGB(220, 100, 255) },
    Legendary = { Color1 = Color3.fromRGB(255, 215, 0), Color2 = Color3.fromRGB(255, 255, 150) }
}

DioramaConfig.RARITY_NAMES = {
    Common = "Обычная",
    Uncommon = "Необычная",
    Rare = "Редкая",
    Epic = "Эпическая",
    Legendary = "Легендарная"
}

DioramaConfig.DIORAMA_UPDATES_TOPIC = "DioramaUpdates"
DioramaConfig.DIORAMA_CRITICAL_UPDATES_TOPIC = "DioramaCriticalUpdates"
DioramaConfig.PENDING_GOLD_PAYMENTS_TOPIC = "PendingGold"
DioramaConfig.SYNC_CHECK_INTERVAL = 30
DioramaConfig.CUSTOMIZATION_SYNC_INTERVAL = 60  -- Увеличен интервал для кастомизации
DioramaConfig.CACHE_TTL = 3600
DioramaConfig.LOCK_TTL = 15  -- Увеличен для сложных транзакций
DioramaConfig.CUSTOMIZATION_SAVE_DELAY = 30  -- Увеличена задержка для снижения нагрузки
DioramaConfig.TRANSACTION_TIMEOUT = 10  -- Таймаут транзакции в секундах

-- Rate Limiting настройки
DioramaConfig.DATASTORE_RATE_LIMITS = {
    MIN_SAVE_INTERVAL = 3,          -- Минимальный интервал между сохранениями (секунды)
    BATCH_DELAY = 2,               -- Задержка для батчинга изменений (секунды)
    MAX_RETRIES = 3,               -- Максимальное количество повторных попыток
    RETRY_BASE_DELAY = 1,        -- Базовая задержка для retry (секунды)
    RETRY_MAX_DELAY = 10,           -- Максимальная задержка для retry (секунды)
    LOCK_RETRY_COUNT = 5,          -- Количество попыток захвата блокировки
    LOCK_RETRY_DELAY = 0.5,       -- Задержка между попытками захвата блокировки
}

-- Приоритеты сохранения
DioramaConfig.SAVE_PRIORITY = {
    CRITICAL = 1,    -- Покупка, продажа, голосование
    HIGH = 2,       -- Изменение GamePass, смена владельца
    NORMAL = 3,     -- Смена позиции, сбор дохода
    LOW = 4         -- Кастомизация
}

-- Критические поля для синхронизации (только те, что влияют на экономику)
DioramaConfig.CRITICAL_FIELDS = {
    "OwnerId",
    "OwnerName",
    "PurchaseCount", 
    "PurchaseDate",
    "LastCollectTime",
    "CurrentSpot",
    "GamePassId",
    "Rating",
    "Upvotes",
    "Downvotes",
    "CriticalVersion"
}

-- Поля кастомизации (периодическая синхронизация)
DioramaConfig.CUSTOMIZATION_FIELDS = {
    "FrameType",
    "StandType", 
    "WallColor",
    "WallMaterial",
    "CustomizationVersion"
}

-- Статические поля (никогда не синхронизируются)
DioramaConfig.STATIC_FIELDS = {
    "BasePrice",
    "Rarity",
    "SceneName",
    "DefaultSpot",
    "Collection",
    "Season"
}

DioramaConfig.DATASTORE_USED_GAMEPASSES = "UsedGamePassIds"
DioramaConfig.MEMORYSTORE_USED_GAMEPASSES = "UsedGamePassCache"
DioramaConfig.USED_GAMEPASS_CACHE_TTL = 86400

DioramaConfig.DEFAULT_CUSTOMIZATION = {
    WallColor = Color3.fromRGB(163, 162, 165),
    WallMaterial = "SmoothPlastic",
    StandType = "DefaultStand",
    FrameType = "DefaultFrame",
}

return DioramaConfig