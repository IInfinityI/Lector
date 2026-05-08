return {
    -- Настройки системы
    System = {
        npcFolderName = "NPCs",
        damageIndicator = {
            enabled = true,
            color = Color3.fromRGB(255, 0, 0),
            duration = 0.5,
            tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        },
        dialogueSystem = {
            useDefault = true,
            customGuiPath = nil,
            defaultDuration = 4
        },
        debugMode = false
    },
    
    -- Конфигурации NPC
    Orc = {
        name = "Orc Warrior",
        model = game:GetService("ReplicatedStorage"):WaitForChild("Orc"),
        count = 5,
        spawnType = "Region",
        spawnRegion = {
            Min = Vector3.new(-100, 0, -50),
            Max = Vector3.new(120, 10, 70)
        },
        detectionRange = 30,
        respawnTime = 2,

        -- Скорости передвижения
        speeds = {
            Walk = 16,  -- Обычная скорость ходьбы
            Run = 25,   -- Скорость бега
            Sneak = 8   -- Скорость крадущегося движения
        },

        properties = {
            WalkSpeed = 16,
            JumpPower = 30,
            Health = 150,
            MaxHealth = 150
        },

        customProperties = {
            Damage = 10,
            AttackRange = 5,
            AttackCooldown = 1.5
        },

        pathfinding = {
            enabled = true,
            agentParams = {
                AgentRadius = 2.5,
                AgentHeight = 6,
                AgentCanJump = true,
                AgentCanClimb = false,
                WaypointSpacing = 3,
                Costs = {
                    Plastic = 1,
                    Rock = math.huge
                }
            },
        },

        animations = {
            idle = "rbxassetid://507766388",
            walk = "rbxassetid://11600249883",
            run = "rbxassetid://11600211410",
            attack = "rbxassetid://507770818",
            death = "rbxassetid://487293209"
        },

        script = {
            playerReaction = "attack",
            reactionSpeed = "Run", -- Скорость при реакции на игрока (Walk/Run/Sneak)
            targetLostTime = 1,

            {
                type = "MoveToTag",
                tag = "Orc_Patrol",
                selection = "random", -- "random" или "sequential"
                speed = "Walk" -- Walk/Run/Sneak
            },
            
            {
                type = "Wait",
                duration = 3
            },
            
            {
                type = "PlayAnimation",
                animation = "idle",
                duration = 3,
                priority = Enum.AnimationPriority.Idle
            },

            {
                type = "Loop"
            }
        }
    },
    
    Man = {
        name = "Man",
        model = game:GetService("ReplicatedStorage"):WaitForChild("Man"),
        count = 8,
        spawnType = "Point",
        spawnPoint = Vector3.new(-25, 3, -15),
        detectionRange = 20,
        respawnTime = 20,

        -- Скорости передвижения
        speeds = {
            Walk = 10,
            Run = 18,
            Sneak = 5
        },

        properties = {
            WalkSpeed = 10,
            JumpPower = 40,
            Health = 80,
            MaxHealth = 80
        },

        pathfinding = {
            enabled = true,
            agentParams = {
                AgentRadius = 2.5,
                AgentHeight = 6,
                AgentCanJump = false,
                AgentCanClimb = false,
                WaypointSpacing = 3,
                Costs = {
                    Plastic = 1,
                    Rock = math.huge
                }
            },
        },

        animations = {
            idle = "rbxassetid://507766388",
            walk = "rbxassetid://11600249883",
            run = "rbxassetid://11600211410",
            attack = "rbxassetid://507770818",
            death = "rbxassetid://487293209"
        },

        script = {
            playerReaction = "flee",
            reactionSpeed = "Run",
            targetLostTime = 1,
            {
                type = "MoveToTag",
                tag = "Man_Patrol",
                selection = "sequential",
                speed = "Walk"
            },
            {
                type = "Loop"
            }
        }
    },

    Bot = {
        name = "Bot",
        model = game:GetService("ReplicatedStorage"):WaitForChild("Bot"),
        count = 1,
        spawnType = "Triggered",
        triggerConfig = {
            triggerType = "PointRadius",
            point = Vector3.new(50, 0, 50),
            radius = 20
        },
        detectionRange = 20,
        respawnTime = 2,

        speeds = {
            Walk = 10,
            Run = 18,
            Sneak = 5
        },

        properties = {
            WalkSpeed = 10,
            JumpPower = 40,
            Health = 800,
            MaxHealth = 800
        },

        pathfinding = {
            enabled = true,
            agentParams = {
                AgentRadius = 2.5,
                AgentHeight = 6,
                AgentCanJump = false,
                AgentCanClimb = false,
                WaypointSpacing = 3,
                Costs = {
                    Plastic = 1,
                    Rock = math.huge
                }
            },
        },

        animations = {
            idle = "rbxassetid://507766388",
            walk = "rbxassetid://11600249883",
            run = "rbxassetid://11600211410",
            attack = "rbxassetid://507770818",
            death = "rbxassetid://487293209"
        },

        script = {
            playerReaction = "flee_on_damage",
            {
                type = "WanderInArea",
                area = {
                    Min = {X = -50, Y = 0, Z = -50},
                    Max = {X = 50, Y = 0, Z = 50} 
                },
                minWanderTime = 3,
                maxWanderTime = 7,
                minWaitTime = 1,
                maxWaitTime = 3,
                speed = "Walk",
                animations = {"idle1", "idle2"}
            },
            {
                type = "Loop"
            }
        }
    }
}