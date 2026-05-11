-- Модуль для управления загрузочным экраном
local LoadingScreen = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local loadingGui = nil
local progressBar = nil
local skipButton = nil
local progressText = nil
local loadingProgressFolder = nil
local totalAssets = 0
local loadedAssets = 0
local isSkipped = false
local isLoadComplete = false
local loadCompleteEvent = Instance.new("BindableEvent")
local connections = {}
local categoryConnections = {}

local function findUIElements(screenGui)
	local mainFrame = screenGui:FindFirstChild("MainContainer")
	if not mainFrame then
		warn("LoadingScreen: не найден основной Frame")
		return
	end
		
	progressBar = mainFrame:FindFirstChild("ProgressBarBackground"):FindFirstChild("ProgressBar")
	progressText = mainFrame:FindFirstChild("ProgressText")
	skipButton = mainFrame:FindFirstChild("SkipButton")
	
	if not progressBar or not progressText or not skipButton then
		warn("LoadingScreen: не удалось найти все элементы интерфейса")
	end
end

local function updateOverallProgress()
	totalAssets = 0
	loadedAssets = 0
	
	for _, category in ipairs(loadingProgressFolder:GetChildren()) do
		if category:IsA("Folder") then
			local totalValue = category:FindFirstChild("Total")
			local loadedValue = category:FindFirstChild("Loaded")
			if totalValue and loadedValue then
				totalAssets = totalAssets + totalValue.Value
				loadedAssets = loadedAssets + loadedValue.Value
			end
		end
	end
	
	local percent = totalAssets > 0 and (loadedAssets / totalAssets * 100) or 0
	if progressBar then
		progressBar.Size = UDim2.new(percent / 100, 0, 1, 0)
	end
	if progressText then
		progressText.Text = string.format("Loading resources... %.1f%% (%d/%d)", percent, loadedAssets, totalAssets)
	end
	
	if not isSkipped and percent >= 50 then
		if skipButton then
			skipButton.Visible = true
		end
	end
	
	if percent >= 100 then
		isLoadComplete = true
		loadCompleteEvent:Fire()
		if loadingGui and not isSkipped then
			loadingGui.Enabled = false
		end
	end
end

local function connectToCategory(category)
	local totalValue = category:FindFirstChild("Total")
	local loadedValue = category:FindFirstChild("Loaded")
	if not (totalValue and loadedValue) then
		return
	end
	
	local function onValueChanged()
		updateOverallProgress()
	end
	
	if not categoryConnections[category] then
		categoryConnections[category] = {}
	end
	
	local connTotal = totalValue.Changed:Connect(onValueChanged)
	local connLoaded = loadedValue.Changed:Connect(onValueChanged)
	table.insert(categoryConnections[category], connTotal)
	table.insert(categoryConnections[category], connLoaded)
end

local function trackLoadingProgress(folder)
	updateOverallProgress()
	
	for _, category in ipairs(folder:GetChildren()) do
		if category:IsA("Folder") then
			connectToCategory(category)
		end
	end
	
	local childConn = folder.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			connectToCategory(child)
			updateOverallProgress()
		end
	end)
	table.insert(connections, childConn)
	
	local childRemovedConn = folder.ChildRemoved:Connect(function(child)
		if child:IsA("Folder") and categoryConnections[child] then
			for _, conn in ipairs(categoryConnections[child]) do
				conn:Disconnect()
			end
			categoryConnections[child] = nil
		end
		updateOverallProgress()
	end)
	table.insert(connections, childRemovedConn)
end

function LoadingScreen.WaitForLoad()
	if isLoadComplete then
		return
	end
	loadCompleteEvent.Event:Wait()
end

function LoadingScreen.Start()
	loadingGui = PlayerGui:WaitForChild("LoadingScreen")
	if not loadingGui then
		warn("LoadingScreen: GUI 'LoadingScreen' не найден в PlayerGui")
		return
	end
	
	findUIElements(loadingGui)
	loadingGui.Enabled = true
	loadingProgressFolder = ReplicatedStorage:WaitForChild("LoadingProgress")
	trackLoadingProgress(loadingProgressFolder)
	
	if skipButton then
		skipButton.MouseButton1Click:Connect(function()
			isSkipped = true
			if skipButton then
				skipButton.Visible = false
			end
			if loadingGui then
				loadingGui.Enabled = false
			end
			loadCompleteEvent:Fire()
		end)
	end
	
	if totalAssets > 0 and loadedAssets >= totalAssets then
		isLoadComplete = true
		loadCompleteEvent:Fire()
		if loadingGui then
			loadingGui.Enabled = false
		end
	end
	
	loadingGui.AncestryChanged:Connect(function()
		if not loadingGui or loadingGui.Parent == nil then
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			for _, catConns in pairs(categoryConnections) do
				for _, conn in ipairs(catConns) do
					conn:Disconnect()
				end
			end
		end
	end)
end

return LoadingScreen