return {
    MaxDailyQuests = 5,
    RefreshHours = 24,
    Rarities = {
        Common = { chance = 0.5, multiplier = 1.0, name = "Обычный", color = Color3.fromRGB(200, 200, 200) },
        Uncommon = { chance = 0.3, multiplier = 1.5, name = "Необычный", color = Color3.fromRGB(100, 150, 255) },
        Rare = { chance = 0.15, multiplier = 2.0, name = "Редкий", color = Color3.fromRGB(200, 100, 255) },
        Epic = { chance = 0.04, multiplier = 3.0, name = "Эпический", color = Color3.fromRGB(255, 100, 100) },
        Legendary = { chance = 0.01, multiplier = 5.0, name = "Легендарный", color = Color3.fromRGB(255, 215, 0) }
    },
    Types = {
        {
            id = "collect_gold",
            name = "Собери золото",
            description = "Накопи {target} золота",
            targets = { 100, 500, 1000, 5000, 10000 },
            rewards = {
                { gold = 50, exp = 25 },
                { gold = 200, exp = 100 },
                { gold = 400, exp = 200 },
                { gold = 2000, exp = 1000 },
                { gold = 4000, exp = 2000 }
            }
        },
        {
            id = "complete_quests",
            name = "Выполни задания",
            description = "Заверши {target} заданий",
            targets = { 3, 5, 10, 20, 30 },
            rewards = {
                { gold = 100, exp = 50 },
                { gold = 200, exp = 100 },
                { gold = 400, exp = 200 },
                { gold = 800, exp = 400 },
                { gold = 1200, exp = 600 }
            }
        },
        {
            id = "reach_level",
            name = "Достигни уровня",
            description = "Достигни {target} уровня",
            targets = { 5, 10, 20, 30, 50 },
            rewards = {
                { gold = 200, exp = 100 },
                { gold = 500, exp = 250 },
                { gold = 1000, exp = 500 },
                { gold = 1500, exp = 750 },
                { gold = 2500, exp = 1250 }
            }
        },
        {
            id = "prestige",
            name = "Переродись",
            description = "Соверши {target} перерождений",
            targets = { 1, 3, 5, 10, 20 },
            rewards = {
                { gold = 1000, exp = 500 },
                { gold = 3000, exp = 1500 },
                { gold = 5000, exp = 2500 },
                { gold = 10000, exp = 5000 },
                { gold = 20000, exp = 10000 }
            }
        },
        {
            id = "upgrade",
            name = "Улучши способности",
            description = "Улучши способности {target} раз",
            targets = { 5, 10, 25, 50, 100 },
            rewards = {
                { gold = 150, exp = 75 },
                { gold = 300, exp = 150 },
                { gold = 750, exp = 375 },
                { gold = 1500, exp = 750 },
                { gold = 3000, exp = 1500 }
            }
        },
        {
            id = "collect_items",
            name = "Поиск предметов",
            description = "Предмет: {itemName}"
        }
    },
    ItemTypes = {
        {
            type = "crystal",
            name = "Кристалл",
            mechanic = "click",
            targets = { 1, 2, 3, 5, 7 },
            rewards = {
                { gold = 50, exp = 25 },
                { gold = 100, exp = 50 },
                { gold = 150, exp = 75 },
                { gold = 250, exp = 125 },
                { gold = 350, exp = 175 }
            }
        },
        {
            type = "flower",
            name = "Цветок",
            mechanic = "hold",
            holdTime = 2,
            targets = { 1, 2, 4, 6, 8 },
            rewards = {
                { gold = 40, exp = 20 },
                { gold = 80, exp = 40 },
                { gold = 160, exp = 80 },
                { gold = 240, exp = 120 },
                { gold = 320, exp = 160 }
            }
        },
        {
            type = "book",
            name = "Книга",
            mechanic = "touch",
            targets = { 1, 1, 2, 3, 4 },
            rewards = {
                { gold = 30, exp = 15 },
                { gold = 30, exp = 15 },
                { gold = 60, exp = 30 },
                { gold = 90, exp = 45 },
                { gold = 120, exp = 60 }
            }
        },
        {
            type = "scroll",
            name = "Свиток",
            mechanic = "click",
            targets = { 1, 2, 3, 4, 5 },
            rewards = {
                { gold = 45, exp = 22 },
                { gold = 90, exp = 45 },
                { gold = 135, exp = 67 },
                { gold = 180, exp = 90 },
                { gold = 225, exp = 112 }
            }
        },
        {
            type = "coin",
            name = "Монета",
            mechanic = "touch",
            targets = { 1, 2, 3, 5, 8 },
            rewards = {
                { gold = 20, exp = 10 },
                { gold = 40, exp = 20 },
                { gold = 60, exp = 30 },
                { gold = 100, exp = 50 },
                { gold = 160, exp = 80 }
            }
        },
        {
            type = "gem",
            name = "Самоцвет",
            mechanic = "click",
            targets = { 1, 1, 2, 2, 3 },
            rewards = {
                { gold = 100, exp = 50 },
                { gold = 100, exp = 50 },
                { gold = 200, exp = 100 },
                { gold = 200, exp = 100 },
                { gold = 300, exp = 150 }
            }
        },
        {
            type = "key",
            name = "Ключ",
            mechanic = "click",
            targets = { 1, 1, 1, 2, 2 },
            rewards = {
                { gold = 80, exp = 40 },
                { gold = 80, exp = 40 },
                { gold = 80, exp = 40 },
                { gold = 160, exp = 80 },
                { gold = 160, exp = 80 }
            }
        },
        {
            type = "potion",
            name = "Зелье",
            mechanic = "hold",
            holdTime = 1.5,
            targets = { 1, 2, 3, 4, 5 },
            rewards = {
                { gold = 60, exp = 30 },
                { gold = 120, exp = 60 },
                { gold = 180, exp = 90 },
                { gold = 240, exp = 120 },
                { gold = 300, exp = 150 }
            }
        }
    },
    GamePassBonusId = 12345678,
    GamePassBonusMultiplier = 1.5,
    SkipQuestGamePassId = 87654321,
    SkipQuestProductId = 11223344,
    SkipQuestCostRobux = 50
}