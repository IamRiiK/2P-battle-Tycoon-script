--// Variables
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--// States
local state = {
    aimlock = false,
    autograb = false,
    walkspeed = false,
    esp = false,
    walkspeedValue = 16
}

--// UI Setup
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
if PlayerGui:FindFirstChild("TycoonHackUI") then
    PlayerGui.TycoonHackUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TycoonHackUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Size = UDim2.new(0, 240, 0, 330)
MainFrame.Position = UDim2.new(0, 20, 0.3, 0)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Dragging
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

-- TitleBar
local TitleBar = Instance.new("TextLabel")
TitleBar.Parent = MainFrame
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TitleBar.Text = "2P Battle Tycoon Hack"
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.TextSize = 16
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Close/Open Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = TitleBar
ToggleBtn.Size = UDim2.new(0, 60, 1, 0)
ToggleBtn.Position = UDim2.new(1, -65, 0, 0)
ToggleBtn.Text = "Close"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    ToggleBtn.Text = MainFrame.Visible and "Close" or "Open"
end)

-- UI Layout
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = MainFrame
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local UIPadding = Instance.new("UIPadding")
UIPadding.Parent = MainFrame
UIPadding.PaddingTop = UDim.new(0, 40)

-- Utility: Checkbox
local function createCheckbox(name, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.Size = UDim2.new(0, 200, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = "[ ] " .. name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        btn.Text = (active and "[✔] " or "[ ] ") .. name
        callback(active)
    end)
end

-- Utility: TextBox + Checkbox
local function createSpeedControl()
    local container = Instance.new("Frame")
    container.Parent = MainFrame
    container.Size = UDim2.new(0, 200, 0, 30)
    container.BackgroundTransparency = 1

    local btn = Instance.new("TextButton")
    btn.Parent = container
    btn.Size = UDim2.new(0, 120, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = "[ ] WalkSpeed"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local box = Instance.new("TextBox")
    box.Parent = container
    box.Size = UDim2.new(0, 70, 1, 0)
    box.Position = UDim2.new(1, -70, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.Text = tostring(state.walkspeedValue)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 16
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        btn.Text = (active and "[✔] " or "[ ] ") .. "WalkSpeed"
        state.walkspeed = active
    end)

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num and num > 0 then
            state.walkspeedValue = num
        else
            box.Text = tostring(state.walkspeedValue)
        end
    end)
end

--// Features
-- Aimbot
RunService.RenderStepped:Connect(function()
    if state.aimlock and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local closest, dist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("Head") then
                local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(plr.Character.Head.Position)
                if onScreen then
                    local mag = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                    if mag < dist then
                        dist = mag
                        closest = plr
                    end
                end
            end
        end
        if closest then
            workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, closest.Character.Head.Position)
        end
    end
end)

-- Auto Grab
RunService.RenderStepped:Connect(function()
    if state.autograb then
        for _, tool in ipairs(workspace:GetChildren()) do
            if tool:IsA("Tool") then
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, tool.Handle, 0)
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, tool.Handle, 1)
            end
        end
    end
end)

-- WalkSpeed
RunService.RenderStepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        if state.walkspeed then
            LocalPlayer.Character.Humanoid.WalkSpeed = state.walkspeedValue
        else
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
        end
    end
end)

-- ESP
local function applyESP(plr)
    if plr == LocalPlayer then return end
    if not plr.Character then return end
    if plr.Character:FindFirstChild("ESP_Highlight") then return end

    local h = Instance.new("Highlight")
    h.Name = "ESP_Highlight"
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    if plr.Team == LocalPlayer.Team then
        h.FillColor = Color3.fromRGB(0, 255, 255) -- Cyan (teman)
        h.OutlineColor = Color3.fromRGB(0, 200, 200)
    else
        h.FillColor = Color3.fromRGB(255, 0, 255) -- Magenta (musuh)
        h.OutlineColor = Color3.fromRGB(200, 0, 200)
    end
    h.Parent = plr.Character
end

RunService.RenderStepped:Connect(function()
    if state.esp then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                applyESP(plr)
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and plr.Character:FindFirstChild("ESP_Highlight") then
                plr.Character.ESP_Highlight:Destroy()
            end
        end
    end
end)

--// Build UI Elements
createCheckbox("Aimbot", function(v) state.aimlock = v end)
createCheckbox("Auto Grab Weapon", function(v) state.autograb = v end)
createSpeedControl()
createCheckbox("ESP", function(v) state.esp = v end)
