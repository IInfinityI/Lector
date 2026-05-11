local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local DEBOUNCE_TIME = 2

-- Ожидание загрузки PremiumContentSystem
local PremiumContentSystem = nil
task.spawn(function()
	local startTime = os.time()
	local timeout = 30
	while os.time() - startTime < timeout do
		if _G.AssetService and _G.AssetService:IsLoaded() then
			PremiumContentSystem = _G.AssetService:GetModule("PremiumContentSystem")
			if PremiumContentSystem then
				print("[BackroomsTeleport] PremiumContentSystem loaded")
				break
			end
		end
		task.wait(1)
	end
	if not PremiumContentSystem then
		warn("[BackroomsTeleport] PremiumContentSystem not loaded after timeout")
	end
end)

-- Get spawn location from workspace
local function getWorkspaceSpawn()
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	return spawnLocation
end

-- Get BackroomsLoop spawn
local function getBackroomsSpawn()
	local loopModel = workspace:FindFirstChild("BackroomsLoop")
	if not loopModel then return nil end
	local spawn = loopModel:FindFirstChild("Spawn")
	return spawn
end

-- Get Exit door
local function getExitDoor()
	local loopModel = workspace:FindFirstChild("BackroomsLoop")
	if not loopModel then return nil end
	local exitDoor = loopModel:FindFirstChild("Exit"):FindFirstChild("Part")
	return exitDoor
end

local debounce = {}

local function teleportToSpawn(character, spawnLocation)
	if not spawnLocation then return end

	-- Get the spawn CFrame
	local spawnCFrame = spawnLocation:IsA("BasePart") and spawnLocation.CFrame or spawnLocation

	-- Teleport the character to spawn
	character:PivotTo(spawnCFrame)
end

-- Teleport to workspace SpawnLocation
local function teleportToWorkspaceSpawn(character)
	local spawnLocation = getWorkspaceSpawn()
	if not spawnLocation then
		warn("[BackroomsTeleport] Workspace SpawnLocation not found!")
		return false
	end

	teleportToSpawn(character, spawnLocation)
	return true
end

-- Teleport to BackroomsLoop spawn
local function teleportToBackroomsSpawn(character)
	local spawnLocation = getBackroomsSpawn()
	if not spawnLocation then
		warn("[BackroomsTeleport] BackroomsLoop spawn not found!")
		return false
	end

	teleportToSpawn(character, spawnLocation)
	return true
end

local function onPlateTouched(otherPart, plate)
	local character = otherPart.Parent
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Debounce check
	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	teleportToBackroomsSpawn(character)
	
	-- Выдать достижение "Закулисье"
	if PremiumContentSystem then
		local success, err = PremiumContentSystem.AwardAchievement(player, "Backstage")
		if success then
			print(string.format("[BackroomsTeleport] Достижение 'Закулисье' выдано игроку %s", player.Name))
		elseif err and err ~= "Player already has this achievement" then
			warn(string.format("[BackroomsTeleport] Ошибка выдачи достижения: %s", tostring(err)))
		end
	end
end

local function onExitDoorTouched(otherPart)
	local character = otherPart.Parent
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Debounce check
	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	teleportToWorkspaceSpawn(character)

end

-- Set up all BackPlates
local function setupBackPlates()
	local backPlatesFolder = workspace:FindFirstChild("BackPlates")
	if not backPlatesFolder then
		warn("[BackroomsTeleport] BackPlates folder not found in workspace!")
		return
	end

	local backroomsSpawn = getBackroomsSpawn()
	if not backroomsSpawn then
		warn("[BackroomsTeleport] BackroomsLoop spawn not found!")
		return
	end

	local platesFound = 0
	local platesConnected = 0

	-- Iterate through all children in BackPlates folder
	for _, plate in ipairs(backPlatesFolder:GetChildren()) do
		platesFound = platesFound + 1

		-- Check if the object has a Touched event (must be a BasePart)
		if plate:IsA("BasePart") then
			plate.Touched:Connect(function(part)
				onPlateTouched(part, plate)
			end)
			platesConnected = platesConnected + 1
		else
			warn("[BackroomsTeleport] Skipping " .. plate.Name .. " - not a BasePart")
		end
	end
end

-- Set up Exit Door
local function setupExitDoor()
	local exitDoor = getExitDoor()
	if not exitDoor then
		warn("[BackroomsTeleport] Exit door not found in BackroomsLoop!")
		return
	end

	if not exitDoor:IsA("BasePart") then
		warn("[BackroomsTeleport] Exit is not a BasePart!")
		return
	end

	local workspaceSpawn = getWorkspaceSpawn()
	if not workspaceSpawn then
		warn("[BackroomsTeleport] Workspace SpawnLocation not found! Exit door will not work.")
		return
	end

	exitDoor.Touched:Connect(onExitDoorTouched)
end

-- Watch for new objects added to BackPlates folder
local function setupBackPlatesWatcher()
	local backPlatesFolder = workspace:FindFirstChild("BackPlates")
	if not backPlatesFolder then return end

	backPlatesFolder.ChildAdded:Connect(function(newPlate)
		task.wait(0.1) -- Small delay to ensure the object is fully loaded

		if newPlate:IsA("BasePart") then
			newPlate.Touched:Connect(function(part)
				onPlateTouched(part, newPlate)
			end)
		end
	end)
end

-- Find teleport zones
local function getTeleportZones()
	local loopModel = workspace:FindFirstChild("BackroomsLoop")
	if not loopModel then return nil, nil, nil, nil, nil, nil end
	local teleportFolder = loopModel:FindFirstChild("TeleportZones")
	if not teleportFolder then return nil, nil, nil, nil, nil, nil end

	local exitZone1 = teleportFolder:FindFirstChild("TeleportExit")
	local entryZone1 = teleportFolder:FindFirstChild("TeleportEntry")

	local exitZone2 = teleportFolder:FindFirstChild("TeleportExit2")
	local entryZone2 = teleportFolder:FindFirstChild("TeleportEntry2")

	local exitZone3 = teleportFolder:FindFirstChild("TeleportExit3")
	local entryZone3 = teleportFolder:FindFirstChild("TeleportEntry3")

	return exitZone1, entryZone1, exitZone2, entryZone2, exitZone3, entryZone3
end

local function teleportCharacter(character, exitZone, entryZone)
	if not exitZone or not entryZone then return end

	-- Calculate the offset from the exit zone
	local characterPivot = character:GetPivot()
	local offset = exitZone.CFrame:ToObjectSpace(characterPivot)

	-- Apply the same offset relative to the entry zone
	local newPivot = entryZone.CFrame:ToWorldSpace(offset)

	-- Teleport the character
	character:PivotTo(newPivot)
end

local function onTeleportExitTouched(otherPart, exitZone, entryZone)
	local character = otherPart.Parent
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Debounce check
	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	teleportCharacter(character, exitZone, entryZone)
end

-- Set up the touch connections for teleport zones
local function setupTeleportZones()
	local exitZone1, entryZone1, exitZone2, entryZone2, exitZone3, entryZone3 = getTeleportZones()

	local teleportCount = 0

	if exitZone1 and entryZone1 then
		exitZone1.Touched:Connect(function(part)
			onTeleportExitTouched(part, exitZone1, entryZone1)
		end)
		teleportCount = teleportCount + 1
	else
		warn("[BackroomsTeleport] Teleport 1 not found (TeleportExit/TeleportEntry)")
	end

	if exitZone2 and entryZone2 then
		exitZone2.Touched:Connect(function(part)
			onTeleportExitTouched(part, exitZone2, entryZone2)
		end)
		teleportCount = teleportCount + 1
	else
		warn("[BackroomsTeleport] Teleport 2 not found (TeleportExit2/TeleportEntry2)")
	end

	if exitZone3 and entryZone3 then
		exitZone3.Touched:Connect(function(part)
			onTeleportExitTouched(part, exitZone3, entryZone3)
		end)
		teleportCount = teleportCount + 1
	else
		warn("[BackroomsTeleport] Teleport 3 not found (TeleportExit3/TeleportEntry3)")
	end
end

-- Watch for new teleport zones added dynamically
local function setupTeleportZonesWatcher()
	local loopModel = workspace:FindFirstChild("BackroomsLoop")
	if not loopModel then return end

	local teleportFolder = loopModel:FindFirstChild("TeleportZones")
	if not teleportFolder then return end

	teleportFolder.ChildAdded:Connect(function(newZone)
		task.wait(0.1)

		-- Check if this is an exit zone and find matching entry zone
		local zoneName = newZone.Name
		if string.match(zoneName, "^TeleportExit") then
			local number = string.match(zoneName, "(%d+)$") or ""
			local entryZoneName = "TeleportEntry" .. number
			local entryZone = teleportFolder:FindFirstChild(entryZoneName)

			if entryZone and newZone:IsA("BasePart") and entryZone:IsA("BasePart") then
				newZone.Touched:Connect(function(part)
					onTeleportExitTouched(part, newZone, entryZone)
				end)
			end
		end
	end)
end

-- Initialize everything
local function initialize()
	setupBackPlates()
	setupBackPlatesWatcher()
	setupExitDoor()
	setupTeleportZones()
	setupTeleportZonesWatcher()

end

-- Start the system
initialize()