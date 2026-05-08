return {
    settings = {
        defaultMaxPetsEquipped = 33,
    },

    eggs = {
        BasicEgg = {
            pets = {
                Bear = 50,
                Bunny = 30,
                Fox = 20
            },
            price = 100,          -- Цена покупки яйца
            currency = "Coins"    -- Валюта для покупки яйца
        }
    },
    
    pets = {
        Bear = {
            modelPath = "ServerStorage/Pets/Bear",
            walks = true,
            price = 200,          -- Цена покупки питомца
            currency = "Coins",   -- Валюта для покупки
            sellPercentage = 0.5, -- Процент возврата при продаже (50%)
            level = {
                initial = 1,
                max = 4,
                upgradeCost = {60, 120, 180}
            },
            modifiers = {
                {
                    type = "JumpHeight",
                    operation = "Add",
                    value = {15, 25, 35, 45}
                },
                {
                    type = "MovementSpeed",
                    operation = "MultiplyBase",
                    value = {1.1, 1.15, 1.2, 1.25}
                }
            }
        },
        Bunny = {
            modelPath = "ServerStorage/Pets/Bunny",
            walks = true,
            price = 150,
            currency = "Coins",
            sellPercentage = 0.6, -- 60% возврата
            modifiers = {
                {
                    type = "Damage",
                    operation = "MultiplyBase",
                    value = {15, 25, 35},
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {100, 200}
                },
                {
                    type = "MovementSpeed",
                    operation = "Add",
                    value = {15, 35},
                    initial = 1,
                    maxLevel = 2,
                    upgradeCost = {100}
                }
            }
        },
        Fox = {
            modelPath = "ServerStorage/Pets/Fox",
            walks = false,
            price = 300,
            currency = "Gems",    -- Можно использовать разную валюту
            sellPercentage = 0.4, -- 40% возврата
            modifiers = {
                {
                    type = "MaxHealth",
                    operation = "Add",
                    value = 2.0
                }
            }
        }
    }
}