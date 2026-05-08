return {
    -- Только событие Touched
    ["EVT_Touched"] = {
        Events = {
            Touched = {
                Action = function(hit, object)
                    if hit.Parent:FindFirstChild("Humanoid") then
                        print("Игрок коснулся")
                    end
                end,
            }
        }
    },

    -- Touched с условием
    ["EVT_TouchedCondition"] = {
        Events = {
            Touched = {
                Condition = function(hit, object)
                    local humanoid = hit.Parent:FindFirstChild("Humanoid")
                    return humanoid and humanoid.Health > 90
                end,
                Action = function(hit, object)
                    print("Касанулся HP > 90")
                end
            }
        }
    },

    -- ClickDetector - проверка нажатием мышки
    ["EVT_ClickDetector"] = {
        Events = {
            ClickDetector = {
                RightMouseClick = {
                    Action = function(player, object)
                        print("Правый клик")
                    end
                },
                MouseClick = {
                    Action = function(player, object)
                        print("Левый клик")
                    end
                }
            }
        }
    },

    -- ClickDetector - наведение
    ["EVT_MouseHover"] = {
        Events = {
            ClickDetector = {
                MouseHoverEnter = {
                    Action = function(player, object)
                        print("Навел курсор")
                    end
                },
                MouseHoverLeave = {
                    Action = function(player, object)
                        print("Убрал курсор")
                    end
                }
            }
        }
    },

    -- ProximityPrompt - основное взаимодействие
    ["EVT_ProximityPrompt"] = {
        Events = {
            ProximityPrompt = {
                ObjectText = "123",
                ActionText = "Жми",
                HoldDuration = 5,
                Triggered = {
                    Action = function(player, object)
                        print("Активировал")
                    end
                }
            }
        }
    },

    -- Событие уничтожения
    ["EVT_Destroying"] = {
        Events = {
            Touched = {
                Action = function(hit, object)
                    if hit.Parent:FindFirstChild("Humanoid") then
                        object:Destroy();
                        print("Уничтожаю")
                    end
                end,
            },
            Destroying = {
                Action = function(object)
                    print("Уничтожен")
                end
            }
        }
    },

    -- Тест атрибутов
    ["Attributes_Test"] = {
        Attributes = {
            ClickCount = 0
        },
        Events = {
            ClickDetector = {
                MouseClick = {
                    Action = function(player, object)
                        local count = object:GetAttribute("ClickCount") + 1
                        object:SetAttribute("ClickCount", count)
                        print("Кликов:", count)
                    end
                }
            }
        }
    },

    -- Тест коолдауна
    ["TEST_Cooldown_1"] = {
        Attributes = {
            LastActivation = 0
        },
        Events = {
            Touched = {
                Condition = function(player, object)
                    local last = object:GetAttribute("LastActivation")
                    return os.time() - last > 3 -- 3 секунды коолдаун
                end,
                Action = function(player, object)
                    if player.Parent:FindFirstChild("Humanoid") then
                        object:SetAttribute("LastActivation", os.time())
                        print("коолдаун 3с")
                    end
                end
            }
        }
    },

    -- Тест коолдауна
    ["TEST_Cooldown_2"] = {
        Events = {
            Touched = {
                Action = function(hit, object)
                    if hit.Parent:FindFirstChild("Humanoid") then
                        print("коолдаун 5с")
                    end
                end,
                Cooldown = 5
            }
        }
    }
}