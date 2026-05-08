return {
    defaultTools = {"Sword"},
    remotesFolder = "WeaponRemotes",
    scriptTemplatePath = "ServerStorage/Template/ToolScriptTemplate",

    tools = {
        {
            name = "Sword",
            modelPath = "ServerStorage/Tools/Sword",
            canBeDropped = true,
            textureId = "rbxasset://Textures/Sword128.png",
            
            attributes = {
                Damage = 15,
                Cooldown = 0.5,
                AttackRange = 5
            },
            
            sounds = {
                Equip = "12222216", 
                Swing = "6241709963",
                Hit = "935843979",
                Use = "7545764969"
            },
            
            animations = {
                Attack = "522635514",  -- Реальные ID анимаций
                Special = "2441858691",
                Use = "522635514"
            },
            
            actions = {
                PrimaryAttack = {
                    inputs = {"MouseButton1"},
                    event = "PrimaryAttack",
                    animation = "Attack",
                    sound = "Swing",
                    cooldown = 3

                },
                SpecialAttack = {
                    inputs = {"F"},
                    event = "SpecialAttack",
                    animation = "Special",
                    sound = "Hit",
                    cooldown = 0.5
                }
            }
        }
    }
}