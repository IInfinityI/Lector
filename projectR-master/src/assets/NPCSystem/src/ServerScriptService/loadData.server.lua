local NPCSystem = require(game:GetService("ServerStorage").NPCSystem)
NPCSystem.Init(game:GetService("ServerStorage").NPCConfig)

print(NPCSystem.getNPCsOfType("Man")[2])
wait(25)
print(NPCSystem.getNPCsOfType("Man")[2]:GetAttribute("NPCID"))
local orcs = NPCSystem.getNPCsOfType("Orc")
for _, orc in ipairs(orcs) do
    local orcID = orc:GetAttribute("NPCID")
    
    -- Изменим свойства орка
    NPCSystem.updateNPC(orcID, {
        properties = {
            WalkSpeed = 10,
            Health = 2000
        },
        customProperties = {
            Damage = 1,
            AttackRange = 6
        }
    })

end
_G.myGlobal = NPCSystem