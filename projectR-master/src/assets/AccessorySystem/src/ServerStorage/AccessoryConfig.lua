return {
    defaultAccessories = {"RunningBoots"},
    
    maxCategorySlots = {
        Helmet = 2,
        Chest = 1,
        Legs = 1,
        Boots = 2,
        Backpack = 1,
        Ring = 2,
        Amulet = 1
    },
    
    accessories = {
        {
            name = "BasicHelmet",
            modelPath = "ServerStorage/Accessories/Helmet",
            accessoryType = "Helmet",
            category = "Helmet",
            cost = 100,
            currency = "Coins",
            description = "Basic protective helmet",
            imageId = "rbxassetid://1234567890",
            purchaseLimit = 5,
            
            -- Глобальная прокачка с 3 уровнями
            level = {
                initial = 1,
                max = 3,
                upgradeCost = {50, 100}
            },
            
            -- Два модификатора с глобальной прокачкой
            modifiers = {
                {
                    type = "MaxHealth",
                    operation = "Add",
                    value = {10, 20, 30}  -- Уровни: 1, 2, 3
                },
                {
                    type = "Defense",
                    operation = "MultiplyBase",
                    value = {0.05, 0.10, 0.15}
                }
            },
            
            -- Настройки смерти
            deathSettings = {
                removeFromInventory = false,
                reequipOnRespawn = true
            }
        },
        {
            name = "Hat",
            modelPath = "ServerStorage/Accessories/Hat",
            accessoryType = "Helmet",
            category = "Helmet",
            cost = 150,
            currency = "Coins",
            description = "Stylish hat that increases movement",
            imageId = "rbxassetid://1234567891",
            purchaseLimit = 5,
            
            -- Глобальная прокачка с 3 уровнями
            level = {
                initial = 1,
                max = 3,
                upgradeCost = {75, 150}
            },
            
            -- Два модификатора с глобальной прокачкой
            modifiers = {
                {
                    type = "JumpHeight",
                    operation = "Add",
                    value = {7, 17, 70}
                },
                {
                    type = "MovementSpeed",
                    operation = "MultiplyTotal",
                    value = {2.16, 3.30, 4.50}
                }
            },
            
            deathSettings = {
                removeFromInventory = false,
                reequipOnRespawn = true
            }
        },
        {
            name = "BasicArmor",
            modelPath = "ServerStorage/Accessories/ChestArmor",
            accessoryType = "Armor",
            category = "Chest",
            cost = 200,
            currency = "Coins",
            description = "Basic protective armor",
            imageId = "rbxassetid://1234567892",
            purchaseLimit = 5,
            
            -- Глобальная прокачка с 4 уровнями
            level = {
                initial = 1,
                max = 4,
                upgradeCost = {60, 120, 180}
            },
            
            -- Один модификатор с глобальной прокачкой
            modifiers = {
                {
                    type = "MaxHealth",
                    operation = "Add",
                    value = {20, 35, 50, 65}
                }
            },
            
            deathSettings = {
                removeFromInventory = true,  -- Удаляется при смерти
                reequipOnRespawn = false    -- Не переэкипируется при возрождении
            }
        },
        {
            name = "RunningBoots",
            modelPath = {
                Left = "ServerStorage/Accessories/LeftBoot",
                Right = "ServerStorage/Accessories/RightBoot"
            },
            accessoryType = "Boots",
            category = "Boots",
            cost = 120,
            currency = "Coins",
            description = "Boots that increase movement speed",
            imageId = "rbxassetid://1234567893",
            purchaseLimit = 5,
            
            -- Без глобальной прокачки, только индивидуальная
            modifiers = {
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {40, 80},
                    type = "MovementSpeed",
                    operation = "MultiplyBase",
                    value = {2.15, 3.25, 4.35},
                    individualUpgrade = true  -- Индивидуальная прокачка
                }
            },
            
            deathSettings = {
                removeFromInventory = false,
                reequipOnRespawn = true
            }
        },
        {
            name = "AmuletOfPower",
            modelPath = "ServerStorage/Accessories/Amulet",
            accessoryType = "Jewelry",
            category = "Amulet",
            cost = 500,
            currency = "Gems",  -- Другая валюта для тестирования
            description = "Magical amulet that boosts all stats",
            imageId = "rbxassetid://1234567894",
            purchaseLimit = 5,
            
            -- Без прокачки, статические модификаторы
            modifiers = {
                {
                    type = "Damage",
                    operation = "MultiplyTotal",
                    value = 0.20
                },
                {
                    type = "Defense",
                    operation = "MultiplyTotal",
                    value = 0.15
                }
            },
            
            deathSettings = {
                removeFromInventory = true,  -- Удаляется при смерти (редкий предмет)
                reequipOnRespawn = false
            }
        }
    }
}