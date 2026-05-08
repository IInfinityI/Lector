return {
    defaultTools = {"Sword"},
    remotesFolder = "WeaponRemotes",
    scriptTemplatePath = "ReplicatedStorage/ToolScriptTemplate",

    tools = {
        {
            name = "Sword",
            modelPath = "ServerStorage/Weapons/SwordTool",
            canBeDropped = true,
            textureId = "rbxasset://Textures/Sword128.png",
            cost = 100,
            description = "A sharp sword that deals moderate damage",
            
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
                    value = {0.1, 0.15, 0.2, 0.25}
                }
            },
            
            sounds = {
                Equip = "12222216", 
                Swing = "6241709963",
                Hit = "935843979",
                Use = "7545764969"
            },
            
            animations = {
                Attack = "522635514",
                Special = "2441858691",
                Use = "522635514"
            },
            
            actions = {
                PrimaryAttack = {
                    inputs = {"MouseButton1"},
                    event = "PrimaryAttack",
                    animation = "Attack",
                    sound = "Equip",
                    cooldown = 3
                },
                SpecialAttack = {
                    inputs = {"F"},
                    event = "SpecialAttack",
                    animation = "Special",
                    cooldown = 0.5
                }
            }
        },
        {
            name = "MagicWand",
            modelPath = "ServerStorage/Weapons/MagicWandTool",
            canBeDropped = false,
            textureId = "rbxasset://Textures/MagicWand128.png",
            cost = 200,
            description = "A magical wand that casts spells",
            
            modifiers = {
                {
                    initial = 1,
                    maxLevel = 3,
                    upgradeCost = {40, 80},
                    type = "MagicPower",
                    operation = "MultiplyBase",
                    value = {1.5, 2.0, 2.5}
                },
                {
                    initial = 1,
                    maxLevel = 2,
                    upgradeCost = {50},
                    type = "ManaRegen",
                    operation = "Add",
                    value = {2, 4}
                }
            },
            
            sounds = {
                Cast = "7545764969",
                Charge = "6241709963"
            },
            
            animations = {
                Cast = "522635514",
                Charge = "2441858691"
            },
            
            actions = {
                CastSpell = {
                    inputs = {"MouseButton1"},
                    event = "CastSpell",
                    animation = "Cast",
                    sound = "Cast",
                    cooldown = 2
                },
                ChargeSpell = {
                    inputs = {"MouseButton2"},
                    event = "ChargeSpell",
                    animation = "Charge",
                    sound = "Charge",
                    cooldown = 5
                }
            }
        }
    }
}