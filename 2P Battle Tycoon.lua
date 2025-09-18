-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- UI CREATION (Simple Drag + Minimize + Light Theme)
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "CustomUI"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 320)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 245) -- terang
MainFrame.BorderSizePixel = 2
MainFrame.Active = true
MainFrame.Draggable = true

local TitleBar = Instance.new("TextLabel", MainFrame)
TitleBar.Size = UDim2.new(1, -30, 0, 30)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
TitleBar.Text = "Utility Hub"
TitleBar.TextColor3 = Color3.fromRGB(0, 0, 0)
TitleBar.TextSize = 18
TitleBar.Font = Enum.Font.SourceSansBold

local MinimizeBtn = Instance.new("TextButton", MainFrame)
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 0)
MinimizeBtn.Text = "-"
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
MinimizeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -10, 1, -40)
ContentFrame.Position = UDim2.new(0, 5, 0, 35)
ContentFrame.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", ContentFrame)
UIList.Padding = UDim.new(0, 5)

local function createToggle(name, callback)
    local button = Instance.new("TextButton", ContentFrame)
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Text = "[ ] " .. name
    button.TextColor3 = Color3.fromRGB(0, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(230, 230, 230)

    local state = false
    button.MouseButton1Click:Connect(function()
        state = not state
        button.Text = (state and "[X] " or "[ ] ") .. name
        callback(state)
    end)
end

local function createTextbox(name, callback)
    local frame = Instance.new("Frame", ContentFrame)
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Text = name
    label.TextColor3 = Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.5, 0, 1, 0)
    box.Position = UDim2.new(0.5, 0, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    box.TextColor3 = Color3.fromRGB(0, 0, 0)
    box.PlaceholderText = "Enter number"

    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

local minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    ContentFrame.Visible = not minimized
    MinimizeBtn.Text = minimized and "+" or "-"
end)

----------------------------------------------------------------
-- ESP (Highlight badan player)
----------------------------------------------------------------
local espEnabled = false
local friendColor = Color3.fromRGB(13,71,21)  -- hijau gelap
local enemyColor = Color3.fromRGB(76,75,22)  -- emas kecoklatan

local function applyESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if char:FindFirstChild("ESP_HL") then char.ESP_HL:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP_HL"
    hl.Adornee = char
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Parent = char

    if player.Team == LocalPlayer.Team then
        hl.FillColor = friendColor
        hl.OutlineColor = friendColor
    else
        hl.FillColor = enemyColor
        hl.OutlineColor = enemyColor
    end
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if espEnabled then
                applyESP(plr)
            else
                if plr.Character and plr.Character:FindFirstChild("ESP_HL") then
                    plr.Character.ESP_HL:Destroy()
                end
            end
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if espEnabled then task.wait(1) applyESP(plr) end
    end)
end)

----------------------------------------------------------------
-- Auto Press E
----------------------------------------------------------------
local autoE = false
task.spawn(function()
    while true do
        if autoE then
            keypress(0x45) -- key E
            task.wait(0.05)
            keyrelease(0x45)
            task.wait(0.5)
        else
            task.wait(0.2)
        end
    end
end)

----------------------------------------------------------------
-- Auto Grab Weapon
----------------------------------------------------------------
local grabbing = false
local TycoonsFolder = Workspace:WaitForChild("Tycoons")

local toolGiverNames = {"ToolGiver1P1","ToolGiver1P2","ToolGiver2P1"} -- potong contoh, tambahkan sesuai daftar

local function grabWeapons()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, tycoon in ipairs(TycoonsFolder:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        if purchased then
            for _, name in ipairs(toolGiverNames) do
                local giver = purchased:FindFirstChild(name)
                if giver and giver:FindFirstChild("Touch") then
                    pcall(function()
                        firetouchinterest(root, giver.Touch, 0)
                        firetouchinterest(root, giver.Touch, 1)
                    end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if grabbing then grabWeapons() end
        task.wait(1)
    end
end)

----------------------------------------------------------------
-- Walkspeed Control
----------------------------------------------------------------
local wsEnabled = false
local wsValue = 16

task.spawn(function()
    while true do
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and wsEnabled then
            hum.WalkSpeed = wsValue
        end
        task.wait(0.1)
    end
end)

----------------------------------------------------------------
-- Aimbot (toggle + hotkey F1 + threshold + lerp smooth)
----------------------------------------------------------------
local aimbotEnabled = false
local aimLerp = 0.15
local aimFOV = 45 -- derajat threshold

local Camera = Workspace.CurrentCamera

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end

    local closest, shortest = nil, math.huge
    local myPos = myChar.HumanoidRootPart.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = plr.Character.HumanoidRootPart
            local dist = (hrp.Position - myPos).Magnitude
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 and dist < shortest then
                shortest = dist
                closest = plr
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if not aimbotEnabled then return end
    local target = getClosestEnemy()
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local targetPos = target.Character.HumanoidRootPart.Position
        local camPos = Camera.CFrame.Position
        local dir = (targetPos - camPos).Unit
        local currentDir = Camera.CFrame.LookVector
        local angle = math.deg(math.acos(math.clamp(currentDir:Dot(dir), -1, 1)))

        if angle < aimFOV then
            local newCFrame = CFrame.new(camPos, camPos + currentDir:Lerp(dir, aimLerp))
            Camera.CFrame = newCFrame
        end
    end
end)

-- Hotkey F1
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        aimbotEnabled = not aimbotEnabled
        warn("Aimbot:", aimbotEnabled)
    end
end)

----------------------------------------------------------------
-- UI Buttons
----------------------------------------------------------------
createToggle("ESP", function(state)
    espEnabled = state
    refreshESP()
end)

createToggle("Auto Press E", function(state)
    autoE = state
end)

createToggle("Auto Grab Weapon", function(state)
    grabbing = state
end)

createToggle("Toggle Walkspeed", function(state)
    wsEnabled = state
end)

createTextbox("Input Walkspeed", function(text)
    local val = tonumber(text)
    if val then wsValue = val end
end)

createToggle("Aimbot (F1 Hotkey)", function(state)
    aimbotEnabled = state
end)
