if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    WalkEnabled = false,
    WalkValue = 30,
    Aimbot = false,
    AIM_FOV_DEG = 8,
    AIM_LERP = 0.4,
    AIM_HOLD = false,
    PredictiveAim = false,
    ProjectileSpeed = 100,
    PredictionLimit = 0.5,
}

local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
MainScreenGui.ResetOnSpawn = false
MainScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame", MainScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,400,0,700)
MainFrame.Position = UDim2.new(0.02,0,0.08,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,10)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,36)
TitleBar.BackgroundTransparency = 1

local DragHandle = Instance.new("TextLabel", TitleBar)
DragHandle.Size = UDim2.new(0,28,0,28)
DragHandle.Position = UDim2.new(0,8,0,4)
DragHandle.BackgroundTransparency = 1
DragHandle.Font = Enum.Font.Gotham
DragHandle.TextSize = 20
DragHandle.TextColor3 = Color3.fromRGB(200,200,200)
DragHandle.Text = "≡"
DragHandle.Active = true
DragHandle.Selectable = true

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1,-110,1,0)
TitleLabel.Position = UDim2.new(0.07,0,0,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextColor3 = Color3.fromRGB(245,245,245)
TitleLabel.Text = "⚔️2P Battle Tycoon"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0,36,0,28)
MinBtn.Position = UDim2.new(1,-42,0,4)
MinBtn.BackgroundColor3 = Color3.fromRGB(58,58,60)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = Color3.fromRGB(240,240,240)
MinBtn.Text = "-"
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

local Content = Instance.new("ScrollingFrame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1,-24,1,-64)
Content.Position = UDim2.new(0,12,0,52)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.ScrollBarThickness = 8
Content.CanvasSize = UDim2.new(0,0,0,0)
Content.VerticalScrollBarInset = Enum.ScrollBarInset.Always

local listLayout = Instance.new("UIListLayout", Content)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,8)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Content.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y + 12)
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- Utility Section
local function createSeparator(parent, text)
    local lab = Instance.new("TextLabel", parent)
    lab.Size = UDim2.new(1,0,0,18)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 12
    lab.TextColor3 = Color3.fromRGB(170,170,170)
    lab.Text = "─────────  " .. (text or "") .. "  ─────────"
    lab.TextXAlignment = Enum.TextXAlignment.Center
    return lab
end

createSeparator(Content, "Utility")

local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    btn.Parent = Content
    btn.MouseButton1Click:Connect(function()
        FEATURE[featureKey] = not FEATURE[featureKey]
        btn.Text = displayName .. " [" .. (FEATURE[featureKey] and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = FEATURE[featureKey] and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        if type(onChange) == "function" then pcall(onChange, FEATURE[featureKey]) end
    end)
    return btn
end

registerToggle("ESP", "ESP")
registerToggle("Auto Press E", "AutoE")
registerToggle("WalkSpeed", "WalkEnabled")

-- Auto Teleport UI
createSeparator(Content, "Auto Teleport")
local autoTP_Frame = Instance.new("Frame", Content)
autoTP_Frame.Size = UDim2.new(1,0,0,36)
autoTP_Frame.BackgroundTransparency = 1
autoTP_Frame.ClipsDescendants = true

local autoTP_Label = Instance.new("TextLabel", autoTP_Frame)
autoTP_Label.Size = UDim2.new(0.5,0,1,0)
autoTP_Label.BackgroundTransparency = 1
autoTP_Label.Font = Enum.Font.Gotham
autoTP_Label.TextSize = 13
autoTP_Label.TextColor3 = Color3.fromRGB(230,230,230)
autoTP_Label.Text = "Target Musuh:"
autoTP_Label.TextXAlignment = Enum.TextXAlignment.Left

local autoTP_Dropdown = Instance.new("TextButton", autoTP_Frame)
autoTP_Dropdown.Size = UDim2.new(0.5,-6,1,0)
autoTP_Dropdown.Position = UDim2.new(0.5,6,0,0)
autoTP_Dropdown.BackgroundColor3 = Color3.fromRGB(36,36,36)
autoTP_Dropdown.TextColor3 = Color3.fromRGB(240,240,240)
autoTP_Dropdown.Font = Enum.Font.Gotham
autoTP_Dropdown.TextSize = 13
autoTP_Dropdown.Text = "Pilih Musuh"
Instance.new("UICorner", autoTP_Dropdown).CornerRadius = UDim.new(0,6)

local autoTP_ListFrame = Instance.new("Frame", autoTP_Frame)
autoTP_ListFrame.Size = UDim2.new(0.5,-6,0,100)
autoTP_ListFrame.Position = UDim2.new(0.5,6,1,0)
autoTP_ListFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
autoTP_ListFrame.Visible = false
autoTP_ListFrame.ClipsDescendants = true
autoTP_ListFrame.ZIndex = 10
Instance.new("UICorner", autoTP_ListFrame).CornerRadius = UDim.new(0,6)

local autoTP_ListLayout = Instance.new("UIListLayout", autoTP_ListFrame)
autoTP_ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
autoTP_ListLayout.Padding = UDim.new(0,2)

autoTP_ListFrame.Parent = autoTP_Frame

autoTP_Frame.Parent = Content

local autoTP_Enabled = false
local autoTP_SelectedEnemy = nil
local autoTP_Thread = nil

local function autoTP_RefreshEnemyList()
    for _, c in ipairs(autoTP_ListFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local btn = Instance.new("TextButton", autoTP_ListFrame)
            btn.Size = UDim2.new(1,0,0,24)
            btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
            btn.TextColor3 = Color3.fromRGB(235,235,235)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.Text = p.Name
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
            btn.MouseButton1Click:Connect(function()
                autoTP_SelectedEnemy = p
                autoTP_Dropdown.Text = "Target: "..p.Name
                autoTP_ListFrame.Visible = false
            end)
        end
    end
end

autoTP_Dropdown.MouseButton1Click:Connect(function()
    autoTP_RefreshEnemyList()
    autoTP_ListFrame.ZIndex = 10
    for _, c in ipairs(autoTP_ListFrame:GetChildren()) do
        if c:IsA("GuiObject") then c.ZIndex = 11 end
    end
    autoTP_ListFrame.Visible = not autoTP_ListFrame.Visible
end)

UIS.InputBegan:Connect(function(input, gp)
    if autoTP_ListFrame.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UIS:GetMouseLocation()
        local absPos = autoTP_ListFrame.AbsolutePosition
        local absSize = autoTP_ListFrame.AbsoluteSize
        if not (mousePos.X >= absPos.X and mousePos.X <= absPos.X+absSize.X and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y+absSize.Y) then
            autoTP_ListFrame.Visible = false
        end
    end
end)

local autoTP_ToggleBtn = Instance.new("TextButton", autoTP_Frame)
autoTP_ToggleBtn.Size = UDim2.new(1,0,0,32)
autoTP_ToggleBtn.Position = UDim2.new(0,0,1,8)
autoTP_ToggleBtn.BackgroundColor3 = Color3.fromRGB(36,36,36)
autoTP_ToggleBtn.TextColor3 = Color3.fromRGB(235,235,235)
autoTP_ToggleBtn.Font = Enum.Font.Gotham
autoTP_ToggleBtn.TextSize = 14
autoTP_ToggleBtn.Text = "Auto Teleport [OFF] (T)"
Instance.new("UICorner", autoTP_ToggleBtn).CornerRadius = UDim.new(0,6)

autoTP_ToggleBtn.MouseButton1Click:Connect(function()
    autoTP_Enabled = not autoTP_Enabled
    autoTP_ToggleBtn.Text = "Auto Teleport ["..(autoTP_Enabled and "ON" or "OFF").."] (T)"
    autoTP_ToggleBtn.BackgroundColor3 = autoTP_Enabled and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
    if autoTP_Enabled and autoTP_SelectedEnemy then
        if not autoTP_Thread then
            autoTP_Thread = task.spawn(function()
                while autoTP_Enabled and autoTP_SelectedEnemy and autoTP_SelectedEnemy.Character and autoTP_SelectedEnemy.Character:FindFirstChild("HumanoidRootPart") do
                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        local originalCF = myRoot.CFrame
                        local enemyRoot = autoTP_SelectedEnemy.Character:FindFirstChild("HumanoidRootPart")
                        if enemyRoot then
                            myRoot.CFrame = enemyRoot.CFrame + Vector3.new(0,2,0)
                            task.wait(0.25)
                            myRoot.CFrame = originalCF
                            task.wait(0.25)
                        else
                            break
                        end
                    else
                        break
                    end
                end
                autoTP_Thread = nil
            end)
        end
    else
        autoTP_Thread = nil
    end
end)

-- === LOGIKA ESP ===
local espObjects = setmetatable({}, { __mode = "k" })
local function clearESPForPlayer(p)
    if not p then return end
    local list = espObjects[p]
    if list then
        for _, v in pairs(list) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        espObjects[p] = nil
    end
end
local function getESPColor(p)
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then return Color3.fromRGB(0,200,0) else return Color3.fromRGB(200,40,40) end
end
local function createESPForPlayer(p)
    if not p or not FEATURE.ESP then return end
    if espObjects[p] then return end
    local char = p.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end
    local hl = Instance.new("Highlight")
    hl.Name = "TPB_BoxESP"
    hl.Adornee = char
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.OutlineTransparency = 0
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.7
    hl.FillColor = getESPColor(p)
    hl.Parent = char
    espObjects[p] = { hl }
end
local function refreshESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if FEATURE.ESP then createESPForPlayer(p) else clearESPForPlayer(p) end
        end
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        wait(0.2)
        refreshESP()
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    clearESPForPlayer(p)
end)
RunService.RenderStepped:Connect(refreshESP)

-- === LOGIKA AUTO PRESS E ===
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local autoEThread = nil
local function startAutoE()
    if autoEThread then return end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            if VIM then
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
            task.wait(FEATURE.AutoEInterval or 0.5)
        end
        autoEThread = nil
    end)
end
local function stopAutoE()
    FEATURE.AutoE = false
end
-- Toggle handler
registerToggle("Auto Press E", "AutoE", function(state)
    if state then startAutoE() else stopAutoE() end
end)

-- === LOGIKA WALKSPEED ===
local OriginalWalkByCharacter = {}
local function setPlayerWalkSpeedForCharacter(char, value)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if OriginalWalkByCharacter[char] == nil then OriginalWalkByCharacter[char] = hum.WalkSpeed end
            if hum.WalkSpeed ~= value then hum.WalkSpeed = value end
        end
    end)
end
RunService.Heartbeat:Connect(function()
    if not FEATURE.WalkEnabled then return end
    local char = LocalPlayer.Character
    if char then setPlayerWalkSpeedForCharacter(char, FEATURE.WalkValue) end
end)

-- === LOGIKA AUTO TELEPORT ===
local autoTP_Thread = nil
local function startAutoTP()
    if autoTP_Thread then return end
    autoTP_Thread = task.spawn(function()
        while autoTP_Enabled and autoTP_SelectedEnemy and autoTP_SelectedEnemy.Character and autoTP_SelectedEnemy.Character:FindFirstChild("HumanoidRootPart") do
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local originalCF = myRoot.CFrame
                local enemyRoot = autoTP_SelectedEnemy.Character:FindFirstChild("HumanoidRootPart")
                if enemyRoot then
                    myRoot.CFrame = enemyRoot.CFrame + Vector3.new(0,2,0)
                    task.wait(0.25)
                    myRoot.CFrame = originalCF
                    task.wait(0.25)
                else
                    break
                end
            else
                break
            end
        end
        autoTP_Thread = nil
    end)
end
local function stopAutoTP()
    autoTP_Enabled = false
    autoTP_Thread = nil
end
autoTP_ToggleBtn.MouseButton1Click:Connect(function()
    autoTP_Enabled = not autoTP_Enabled
    autoTP_ToggleBtn.Text = "Auto Teleport ["..(autoTP_Enabled and "ON" or "OFF").."] (T)"
    autoTP_ToggleBtn.BackgroundColor3 = autoTP_Enabled and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
    if autoTP_Enabled and autoTP_SelectedEnemy then
        startAutoTP()
    else
        stopAutoTP()
    end
end)

-- Hotkey T tetap
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        autoTP_ToggleBtn:MouseButton1Click()
    end
end)

print("Script Loaded - Versi Final Fungsional")
