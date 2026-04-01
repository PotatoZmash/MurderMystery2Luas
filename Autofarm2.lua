-- LocalScript in StarterPlayerScripts

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- Toggle
local isRunning = Instance.new("BoolValue")
isRunning.Name = "CoinCollectorRunning"
isRunning.Value = false
isRunning.Parent = LP

-- Stats
local totalCoins = 0
local startTime = os.clock()
local statsLabel = nil
local cachedMap = nil

-- Character (respawn safe)
local function getCharacter()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char,
        char:WaitForChild("HumanoidRootPart"),
        char:WaitForChild("Humanoid")
end

-- Noclip
local function setNoclip(char, state)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
end

-- UI
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CoinCollectorUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = LP.PlayerGui

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 220, 0, 185)
    Frame.Position = UDim2.new(0.5, -110, 0.1, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 25, 10)
    Frame.BackgroundTransparency = 0.3
    Frame.BorderSizePixel = 3
    Frame.BorderColor3 = Color3.fromRGB(255, 185, 0)
    Frame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner", Frame)
    UICorner.CornerRadius = UDim.new(0, 12)

    -- Gold outline stroke via UIStroke
    local UIStroke = Instance.new("UIStroke", Frame)
    UIStroke.Color = Color3.fromRGB(255, 195, 0)
    UIStroke.Thickness = 2.5
    UIStroke.LineJoinMode = Enum.LineJoinMode.Round

    -- Hub Title Label
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, 0, 0, 36)
    TitleLabel.Position = UDim2.new(0, 0, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Norqueloid Hub"
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 18
    TitleLabel.TextColor3 = Color3.fromRGB(255, 210, 40)
    TitleLabel.TextStrokeTransparency = 0.2
    TitleLabel.TextStrokeColor3 = Color3.fromRGB(180, 120, 0)
    TitleLabel.Parent = Frame

    -- Divider line under title
    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(0.85, 0, 0, 1)
    Divider.Position = UDim2.new(0.075, 0, 0, 38)
    Divider.BackgroundColor3 = Color3.fromRGB(255, 185, 0)
    Divider.BackgroundTransparency = 0.4
    Divider.BorderSizePixel = 0
    Divider.Parent = Frame

    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 130, 0, 32)
    ToggleButton.Position = UDim2.new(0.5, -65, 0, 48)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ToggleButton.TextColor3 = Color3.new(1,1,1)
    ToggleButton.Text = "Toggle: OFF"
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 16
    ToggleButton.Parent = Frame

    Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)

    statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(0, 190, 0, 70)
    statsLabel.Position = UDim2.new(0.5, -95, 0, 95)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(240, 215, 120)
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.TextSize = 15
    statsLabel.Text = "Total Coins: 0\nTotal Time: 0m 0s"
    statsLabel.TextWrapped = true
    statsLabel.Parent = Frame

    -- Drag
    local dragging, dragInput, dragStart, startPos

    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
        if input.UserInputType == Enum.UserInputType.MouseMovement then
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

    local function updateButton()
        ToggleButton.BackgroundColor3 = isRunning.Value and Color3.fromRGB(0,200,0) or Color3.fromRGB(100,100,100)
        ToggleButton.Text = "Toggle: " .. (isRunning.Value and "ON" or "OFF")
    end

    ToggleButton.MouseButton1Click:Connect(function()
        isRunning.Value = not isRunning.Value
        updateButton()
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.T then
            isRunning.Value = not isRunning.Value
            updateButton()
        end
    end)

    updateButton()
end

-- Map cache
local function GetMap()
    if cachedMap and cachedMap.Parent then
        return cachedMap
    end

    local mapNames = {"Manor","Farmhouse","Spaceship","Barn","Mineshaft"}

    for i = 1, 30 do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:GetAttribute("MapID") or table.find(mapNames, obj.Name) then
                if obj:FindFirstChild("CoinContainer") or obj:FindFirstChild("Coins") then
                    cachedMap = obj
                    return obj
                end
            end
        end
        task.wait(1)
    end
end

-- Nearest coin
local function getNearest(HRP)
    local map = GetMap()
    if not map then return nil end

    local container = map:FindFirstChild("CoinContainer") or map:FindFirstChild("Coins")
    if not container then return nil end

    local closest, dist = nil, math.huge

    for _, coin in ipairs(container:GetChildren()) do
        local v = coin:FindFirstChild("CoinVisual")
        if v and v:GetAttribute("Collected") ~= true then
            local d = (HRP.Position - coin.Position).Magnitude
            if d < dist then
                closest = coin
                dist = d
            end
        end
    end

    return closest
end

-- SAFE TWEEN TP
local function tp(coin, HRP, Humanoid)
    if not coin then return end

    local distance = (HRP.Position - coin.Position).Magnitude
    if distance < 2 then return end

    local offset = Vector3.new(0, 2.5, 0)
    local targetCF = coin.CFrame + offset

    local speed = math.random(22, 32)
    local time = math.clamp(distance / speed, 0.15, 1.2)

    Humanoid:ChangeState(Enum.HumanoidStateType.Running)

    local tween = TweenService:Create(
        HRP,
        TweenInfo.new(time, Enum.EasingStyle.Linear),
        {CFrame = targetCF}
    )

    tween:Play()
    tween.Completed:Wait()
end

-- Stats loop
task.spawn(function()
    while true do
        if statsLabel then
            local t = os.clock() - startTime
            statsLabel.Text = string.format(
                "Total Coins: %d\nTotal Time: %dm %ds",
                totalCoins,
                math.floor(t/60),
                math.floor(t%60)
            )
        end
        task.wait(1)
    end
end)

-- Start UI
createUI()

-- Main loop
task.spawn(function()
    while true do
        if isRunning.Value then
            local Char, HRP, Humanoid = getCharacter()

            setNoclip(Char, true)

            local target = getNearest(HRP)
            if target then
                tp(target, HRP, Humanoid)

                local v = target:FindFirstChild("CoinVisual")
                local collected = false

                for i = 1, 10 do
                    if not v or not v.Parent then
                        collected = true
                        break
                    end

                    if v:GetAttribute("Collected") == true then
                        collected = true
                        break
                    end

                    task.wait(0.1)
                end

                if collected then
                    totalCoins += 1
                end
            else
                task.wait(0.3)
            end
        else
            local Char = LP.Character
            if Char then
                setNoclip(Char, false)
            end
            task.wait(0.1)
        end
    end
end)

-- Force noclip
task.spawn(function()
    while true do
        if isRunning.Value then
            local Char = LP.Character
            if Char then
                for _, part in ipairs(Char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Respawn safety
LP.CharacterAdded:Connect(function()
    task.wait(1)
end)
