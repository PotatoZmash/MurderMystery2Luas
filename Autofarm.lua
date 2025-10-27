-- LocalScript in StarterPlayerScripts
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP = Char:WaitForChild("HumanoidRootPart")
local Humanoid = Char:WaitForChild("Humanoid")

-- Create BoolValue to control script state
local isRunning = Instance.new("BoolValue")
isRunning.Name = "CoinCollectorRunning"
isRunning.Value = false
isRunning.Parent = LP

-- Statistics tracking
local totalCoins = 0
local startTime = os.clock()
local statsLabel = nil -- Will be set in createUI
local targetedCoin = nil -- Track the coin being collected

-- Create UI with rounded corners, transparent background, and draggable
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CoinCollectorUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LP.PlayerGui
    print("ScreenGui created")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 200, 0, 150)
    Frame.Position = UDim2.new(0.5, -100, 0.1, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Frame.BackgroundTransparency = 0.5 -- Semi-transparent
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12) -- Rounded corners
    UICorner.Parent = Frame

    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 120, 0, 30)
    ToggleButton.Position = UDim2.new(0.5, -60, 0.2, 0)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Text = "Toggle: OFF"
    ToggleButton.Font = Enum.Font.SourceSansBold
    ToggleButton.TextSize = 20
    ToggleButton.Parent = Frame

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    ButtonCorner.Parent = ToggleButton

    statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(0, 180, 0, 60)
    statsLabel.Position = UDim2.new(0.5, -90, 0.5, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statsLabel.Font = Enum.Font.SourceSans
    statsLabel.TextSize = 16
    statsLabel.Text = "Total Coins: 0\nTotal Time: 0m 0s"
    statsLabel.TextWrapped = true
    statsLabel.Parent = Frame
    print("UI elements created")

    -- Draggable functionality
    local dragging, dragInput, dragStart, startPos
    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    Frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    local function updateButtonAppearance()
        ToggleButton.BackgroundColor3 = isRunning.Value and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(100, 100, 100)
        ToggleButton.Text = "Toggle: " .. (isRunning.Value and "ON" or "OFF")
    end

    ToggleButton.MouseButton1Click:Connect(function()
        isRunning.Value = not isRunning.Value
        updateButtonAppearance()
        print("Toggle clicked: " .. (isRunning.Value and "ON" or "OFF"))
    end)

    -- Hotkey toggle (T key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.T then
            isRunning.Value = not isRunning.Value
            updateButtonAppearance()
            print("Hotkey toggled: " .. (isRunning.Value and "ON" or "OFF"))
        end
    end)

    updateButtonAppearance()
end

-- Cache map and coin container (optimized for MM2 Halloween 2025 maps)
local function GetMap()
    local mapNames = {"Manor", "Farmhouse", "Spaceship", "Barn", "Mineshaft"} -- Added from Oct 23, 2025
    for i = 1, 30 do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:GetAttribute("MapID") or table.find(mapNames, obj.Name) then
                if obj:FindFirstChild("CoinContainer") or obj:FindFirstChild("Coins") then
                    print("Found map: " .. obj.Name)
                    return obj
                end
            end
        end
        task.wait(1)
    end
    warn("No map found with MapID or CoinContainer")
    return nil
end

local function getNearest()
    local map = GetMap()
    if not map then return nil end
    local coinContainer = map:FindFirstChild("CoinContainer") or map:FindFirstChild("Coins")
    if not coinContainer then return nil end
    local closest, dist = nil, math.huge
    for _, coin in ipairs(coinContainer:GetChildren()) do
        local v = coin:FindFirstChild("CoinVisual")
        if v and not v:GetAttribute("Collected") then
            local d = (HRP.Position - coin.Position).Magnitude
            if d < dist then
                closest = coin
                dist = d
            end
        end
    end
    if closest then
        print("Nearest coin found at distance: " .. dist)
    else
        print("No valid coins found")
    end
    return closest
end

local function tp(hp)
    if not hp or not HRP or not Humanoid then return end
    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    local d = (HRP.Position - hp.Position).Magnitude
    local tweenInfo = TweenInfo.new(d / 25, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(HRP, tweenInfo, {CFrame = hp.CFrame})
    tween:Play()
    tween.Completed:Wait()
    Humanoid:ChangeState(Enum.HumanoidStateType.Running)
    print("Teleported to coin")
end

-- Update stats display
local function updateStats()
    spawn(function()
        while true do
            if statsLabel then
                local elapsed = os.clock() - startTime
                local minutes = math.floor(elapsed / 60)
                local seconds = math.floor(elapsed % 60)
                statsLabel.Text = string.format("Total Coins: %d\nTotal Time: %dm %ds", totalCoins, minutes, seconds)
            end
            task.wait(1)
        end
    end)
end

-- Create UI and start tracking
print("Script started")
createUI()
updateStats()

-- Main loop with toggle control and coin counting
spawn(function()
    while true do
        if isRunning.Value then
            if not LP:GetAttribute("Alive") then
                print("Player not alive, waiting")
                task.wait(1)
                continue
            end
            local target = getNearest()
            if target then
                targetedCoin = target -- Track the coin we're targeting
                tp(target)
                local v = target:FindFirstChild("CoinVisual")
                while v and v.Parent and not v:GetAttribute("Collected") and LP:GetAttribute("Alive") and isRunning.Value do
                    local newTarget = getNearest()
                    if newTarget and newTarget ~= target then break end
                    task.wait(0.1)
                end
                -- Check if the targeted coin was collected
                if v and v:GetAttribute("Collected") or not v.Parent then
                    totalCoins = totalCoins + 1
                    print("Coin collected by player, total: " .. totalCoins)
                    targetedCoin = nil -- Clear target to avoid double-counting
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.1)
        end
    end
end)

-- Handle character respawn
LP.CharacterAdded:Connect(function(newChar)
    Char = newChar
    HRP = Char:WaitForChild("HumanoidRootPart")
    Humanoid = Char:WaitForChild("Humanoid")
    print("Character respawned")
end)
