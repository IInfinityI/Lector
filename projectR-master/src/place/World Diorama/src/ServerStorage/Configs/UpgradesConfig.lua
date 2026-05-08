return {
    GoldPerMinute = {
        name = "Ускорение добычи",
        cost = { base = 10, multiplier = 1.2 },
        effect = { base = 1, multiplier = 1.1 },
        maxLevel = 50,
        skillPointCost = 1,
        description = "Увеличивает доход золота в минуту"
    },
    StorageCapacity = {
        name = "Вместимость хранилища",
        cost = { base = 15, multiplier = 1.3 },
        effect = { base = 100, multiplier = 1.15 },
        maxLevel = 40,
        skillPointCost = 1,
        description = "Увеличивает максимальное хранимое золото"
    },
    DoubleChance = {
        name = "Шанс удвоения",
        cost = { base = 20, multiplier = 1.4 },
        effect = { base = 0.01, multiplier = 1.05 },
        maxLevel = 30,
        skillPointCost = 1,
        description = "Шанс получить двойное золото при сборе"
    },
    QuestBonus = {
        name = "Бонус к заданиям",
        cost = { base = 25, multiplier = 1.5 },
        effect = { base = 0.05, multiplier = 1.08 },
        maxLevel = 25,
        skillPointCost = 1,
        description = "Увеличивает награду золотом за квесты"
    },
    AutoCollect = {
        name = "Автосбор",
        cost = { base = 500, multiplier = 2.0 },
        effect = "unlock",
        maxLevel = 1,
        skillPointCost = 5,
        description = "Автоматический сбор золота каждую минуту"
    }
}