local EventSystem = require(game:GetService("ReplicatedStorage").Assets.EventSystem)

return {
    ["Essence"] = {
        Events = {
            Touched = {
                Action = function(hit, object)
                    if not hit or not object then return end
                    local character
                    local humanoid
                    if hit.Parent then
                        character = hit.Parent
                        humanoid = character:FindFirstChild("Humanoid")
                        if not humanoid then
                            local current = hit
                            while current and current ~= game do
                                if current:FindFirstChild("Humanoid") then
                                    character = current
                                    humanoid = current:FindFirstChild("Humanoid")
                                    break
                                end
                                current = current.Parent
                            end
                        end
                    end
                    if not humanoid then return end
                    local player = game.Players:GetPlayerFromCharacter(character)
                    if not player then return end
                    if object.Parent == nil then return end
                    EventSystem.CallServerOnlyRPC("EssenceTouched", player, object)
                end
            }
        }
    }
}