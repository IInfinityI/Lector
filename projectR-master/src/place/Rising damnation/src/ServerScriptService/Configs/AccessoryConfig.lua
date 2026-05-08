return {
    defaultAccessories = {},
    remotesFolder = "AccessoryRemotes",
    scriptTemplatePath = "ServerScriptService/Templates/AccessoryScriptTemplate",
    
    maxCategorySlots = {
        Helmet = 1,
        Chest = 1,
        Legs = 1,
        Boots = 1,
        Backpack = 1,
        Ring = 2,
        Amulet = 1
    },
    
    accessories = {
        {
            name = "BaseBoots",
            modelPath = {
                Left = "ServerStorage/Accessories/BaseBoots/BaseLeftBoot",
                Right = "ServerStorage/Accessories/BaseBoots/BaseRightBoot"
            },
            accessoryType = "Boots",
            category = "Boots",
            cost = 10,
            description = "Basic protective helmet",
            imageId = "rbxassetid://1234567890",
            purchaseLimit = 1,
            modifiers = {
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {5, 10},
                    type = "JumpHeight",
                    operation = "Add",
                    value = {7, 17, 70}
                },
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {5, 10},
                    type = "JumpsNumber",
                    operation = "Add",
                    value = {1, 2, 3}
                },
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {10, 120},
                    type = "MovementSpeed",
                    operation = "MultiplyTotal",
                    value = {2.16, 3.30, 4.50}
                }
            }
        },
        {
            name = "BaseBackpack",
            modelPath = "ServerStorage/Accessories/BaseBackpack",
            accessoryType = "Backpack",
            category = "Backpack",
            cost = 100,
            description = "Basic Backpack",
            imageId = "rbxassetid://1234567890",
            purchaseLimit = 1,
            modifiers = {
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {10, 120},
                    type = "MaxWeight",
                    operation = "Add",
                    value = {10, 40, 70}
                }
            }
        },
        {
            name = "Magnet",
            modelPath = "ServerStorage/Accessories/Magnet",
            accessoryType = "Amulet",
            category = "Amulet",
            cost = 10,
            description = "Magnet",
            imageId = "rbxassetid://1234567890",
            purchaseLimit = 1,
            modifiers = {
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {5, 10},
                    type = "SphereSize",
                    operation = "Add",
                    value = {10, 40, 70}
                }
            }
        },
    }
}