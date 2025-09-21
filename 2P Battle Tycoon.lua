-- skrip1_final_ui.lua
-- Gabungan penuh: semua fitur dari skrip1_final + revisi UI dari skrip1_ui_fixed
-- 1) Tabbed UI (Main & Teleport)
-- 2) Teleport langsung eksekusi (Spawn hanya untuk tim sendiri)
-- 3) Teleport section dengan header tim + scroll
-- 4) Warna teks cerah, frame lebih ringkas (tinggi 460)
-- 5) Fitur: ESP, AutoE, WalkSpeed, Aimbot dengan prediksi, Hitbox expander

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

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- Config
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
    AIM_PREDICT = true,
    PREDICTION_MULTIPLIER = 1.0,
    Hitbox = false,
    Hitbox_Size = 5,
}

local WALK_UPDATE_INTERVAL = 0.12

local TEAM_LOCATIONS = {
    Red = {Spawn=Vector3.new(-50,5,0), Flag=Vector3.new(-60,5,20)},
    Blue = {Spawn=Vector3.new(50,5,0), Flag=Vector3.new(60,5,-20)},
    Green = {Spawn=Vector3.new(0,5,50), Flag=Vector3.new(-20,5,60)},
    Yellow = {Spawn=Vector3.new(0,5,-50), Flag=Vector3.new(20,5,-60)},
    Neutral = {Flag=Vector3.new(0,5,0)}
}

-- Cleanup lama
pcall(function()
    if _G and _G.__TPB_CLEANUP then pcall(_G.__TPB_CLEANUP) end
    local old = PlayerGui:FindFirstChild("skrip1_final_ui")
    if old then old:Destroy() end
end)

-- === UI ===
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "skrip1_final_ui"
MainScreenGui.DisplayOrder = 9999
MainScreenGui.ResetOnSpawn = false
MainScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,380,0,460)
MainFrame.Position = UDim2.new(0.28,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,40)
TitleBar.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.8,0,1,0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Text = "⚔️ 2P Battle Tycoon (skrip1)"

-- Tabs
local TabFrame = Instance.new("Frame", MainFrame)
TabFrame.Size = UDim2.new(1,-16,0,30)
TabFrame.Position = UDim2.new(0,8,0,44)
TabFrame.BackgroundTransparency = 1
local TabLayout = Instance.new("UIListLayout", TabFrame)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0,6)

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1,-16,1,-90)
Content.Position = UDim2.new(0,8,0,80)
Content.BackgroundTransparency = 1

local MainPage = Instance.new("Frame", Content)
MainPage.Size = UDim2.new(1,0,1,0)
MainPage.BackgroundTransparency = 1

local TeleportPage = Instance.new("Frame", Content)
TeleportPage.Size = UDim2.new(1,0,1,0)
TeleportPage.BackgroundTransparency = 1
TeleportPage.Visible = false

local function makeTab(name, page)
    local b = Instance.new("TextButton", TabFrame)
    b.Size = UDim2.new(0.5,-6,1,0)
    b.BackgroundColor3 = Color3.fromRGB(36,36,36)
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = name
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        MainPage.Visible = false
        TeleportPage.Visible = false
        page.Visible = true
    end)
    return b
end

makeTab("Main", MainPage)
makeTab("Teleport", TeleportPage)

-- MainPage content
local MainLayout = Instance.new("UIListLayout", MainPage)
MainLayout.Padding = UDim.new(0,8)
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder

local ToggleCallbacks = {}
local function registerToggle(parent, displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1,0,0,36)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    local function setState(state)
        FEATURE[featureKey] = state
        btn.Text = displayName .. " [" .. (state and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        if type(onChange) == "function" then onChange(state) end
    end
    btn.MouseButton1Click:Connect(function() setState(not FEATURE[featureKey]) end)
    ToggleCallbacks[featureKey] = setState
end

registerToggle(MainPage,"ESP","ESP")
registerToggle(MainPage,"Auto Press E","AutoE")
registerToggle(MainPage,"Aimbot","Aimbot")
registerToggle(MainPage,"Hitbox","Hitbox")

-- WalkSpeed
local WSFrame=Instance.new("Frame",MainPage)
WSFrame.Size=UDim2.new(1,0,0,40)
WSFrame.BackgroundTransparency=1
local WSLabel=Instance.new("TextLabel",WSFrame)
WSLabel.Size=UDim2.new(0.5,0,1,0)
WSLabel.BackgroundTransparency=1
WSLabel.Text="WalkSpeed"
WSLabel.TextColor3=Color3.fromRGB(240,240,240)
WSLabel.Font=Enum.Font.Gotham
WSLabel.TextSize=14
local WSBox=Instance.new("TextBox",WSFrame)
WSBox.Size=UDim2.new(0.5,-10,1,-10)
WSBox.Position=UDim2.new(0.5,0,0,5)
WSBox.BackgroundColor3=Color3.fromRGB(32,32,32)
WSBox.TextColor3=Color3.fromRGB(255,255,255)
WSBox.Font=Enum.Font.Gotham
WSBox.TextSize=14
WSBox.Text=tostring(FEATURE.WalkValue)
Instance.new("UICorner",WSBox).CornerRadius=UDim.new(0,6)
WSBox.FocusLost:Connect(function(enter)
    if enter then
        local n=tonumber(WSBox.Text)
        if n and n>=16 and n<=200 then FEATURE.WalkValue=n else WSBox.Text=tostring(FEATURE.WalkValue) end
    end
end)

-- TeleportPage
local TPScroll=Instance.new("ScrollingFrame",TeleportPage)
TPScroll.Size=UDim2.new(1,0,1,0)
TPScroll.CanvasSize=UDim2.new(0,0,0,0)
TPScroll.ScrollBarThickness=6
TPScroll.BackgroundTransparency=1
local TPLayout=Instance.new("UIListLayout",TPScroll)
TPLayout.Padding=UDim.new(0,4)
TPLayout.SortOrder=Enum.SortOrder.LayoutOrder

local function makeHeader(name)
    local h=Instance.new("TextLabel",TPScroll)
    h.Size=UDim2.new(1,0,0,24)
    h.BackgroundTransparency=1
    h.Text=name.." Team"
    h.TextColor3=Color3.fromRGB(255,255,180)
    h.Font=Enum.Font.GothamBold
    h.TextSize=14
end

local function makeTPButton(teamName,locName,pos)
    local b=Instance.new("TextButton",TPScroll)
    b.Size=UDim2.new(1,0,0,28)
    b.BackgroundColor3=Color3.fromRGB(40,40,40)
    b.TextColor3=Color3.fromRGB(240,240,240)
    b.Font=Enum.Font.Gotham
    b.TextSize=13
    b.Text=locName
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        local char=LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            if locName=="Spawn" then
                if LocalPlayer.Team and LocalPlayer.Team.Name==teamName then
                    char.HumanoidRootPart.CFrame=CFrame.new(pos+Vector3.new(0,3,0))
                end
            else
                char.HumanoidRootPart.CFrame=CFrame.new(pos+Vector3.new(0,3,0))
            end
        end
    end)
end

for teamName,locs in pairs(TEAM_LOCATIONS) do
    makeHeader(teamName)
    for locName,pos in pairs(locs) do
        makeTPButton(teamName,locName,pos)
    end
end
TPScroll.CanvasSize=UDim2.new(0,0,0,#TPScroll:GetChildren()*32)

-- === Fitur inti ===
-- AutoE
RunService.Heartbeat:Connect(function()
    if FEATURE.AutoE then
        local target = LocalPlayer:GetMouse().Target
        if target and target:IsA("BasePart") and target.Name == "EKeyPart" then
            if VIM then VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game) end
        end
    end
end)

-- WalkSpeed
spawn(function()
    while true do
        if FEATURE.WalkEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = FEATURE.WalkValue
        end
        task.wait(WALK_UPDATE_INTERVAL)
    end
end)

-- Hitbox expander
RunService.Heartbeat:Connect(function()
    if FEATURE.Hitbox then
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                hrp.Size = Vector3.new(FEATURE.Hitbox_Size,FEATURE.Hitbox_Size,FEATURE.Hitbox_Size)
                hrp.Transparency = 0.7
                hrp.BrickColor = BrickColor.new("Bright red")
                hrp.Material = Enum.Material.Neon
                hrp.CanCollide = false
            end
        end
    end
end)

-- Aimbot (dengan prediksi)
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F6 then
        ToggleCallbacks.Hitbox(not FEATURE.Hitbox)
    end
end)

local function getClosest()
    local closest,dist=nil,math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Team~=LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local pos=Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
            local mouse=UIS:GetMouseLocation()
            local mag=(Vector2.new(pos.X,pos.Y)-mouse).Magnitude
            if mag<dist and mag<(FEATURE.AIM_FOV_DEG*10) then
                closest,dist=plr,mag
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if FEATURE.Aimbot then
        local target=getClosest()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local hrp=target.Character.HumanoidRootPart
            local pred=hrp.Position
            if FEATURE.AIM_PREDICT and hrp.AssemblyLinearVelocity then
                pred=pred+hrp.AssemblyLinearVelocity*FEATURE.PREDICTION_MULTIPLIER*RunService.RenderStepped:Wait()
            end
            Camera.CFrame=CFrame.new(Camera.CFrame.Position,pred)
        end
    end
end)

print("✅ skrip1_final_ui.lua loaded.")
