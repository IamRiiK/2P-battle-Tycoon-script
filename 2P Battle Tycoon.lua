-------------------------
-- Services
-------------------------
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-------------------------
-- Feature Toggles
-------------------------
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoGrab = false,
    WalkEnabled = false,
    WalkValue = 16,
    Aimbot = false
}

-------------------------
-- UI Setup (Modern Dark Theme)
-------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Position = UDim2.new(0.3,0,0.2,0)
MainFrame.Size = UDim2.new(0,300,0,370)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

-- Rounded corners
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,10)

-- Border glow effect
local stroke = Instance.new("UIStroke", MainFrame)
stroke.Color = Color3.fromRGB(80,80,80)
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Title Bar
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,32)
local gradient = Instance.new("UIGradient", TitleBar)
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40,40,40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25,25,25))
}
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0,10)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.BackgroundTransparency = 1
Title.Text = "⚔️ 2P Battle Tycoon"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Position = UDim2.new(0,10,0,0)

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0,32,1,0)
MinBtn.Position = UDim2.new(1,-36,0,0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.4,-36,1,0)
HintLabel.Position = UDim2.new(0.6, 0, 0, 0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 13
HintLabel.TextColor3 = Color3.fromRGB(180,180,180)
HintLabel.TextXAlignment = Enum.TextXAlignment.Right
HintLabel.Text = "Press LeftAlt to toggle UI"

-- Content
local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -10, 1, -42)
Content.Position = UDim2.new(0,5,0,37)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0,8)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- Toggle show/hide UI with LeftAlt
UIS.InputBegan:Connect(function(input,gp)
    if not gp and input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-------------------------
-- Helper: Create Toggle (Modern Style)
-------------------------
local function createToggle(name, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(35,35,35)
    btn.TextColor3 = Color3.fromRGB(230,230,230)
    btn.TextSize = 15
    btn.Font = Enum.Font.Gotham
    btn.Text = name.." [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(70,70,70)
    stroke.Thickness = 1.2

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name.." ["..(state and "ON" or "OFF").."]"
        callback(state)
        btn.BackgroundColor3 = state and Color3.fromRGB(60,100,60) or Color3.fromRGB(35,35,35)
    end)
end

-------------------------
-- WalkSpeed Input (Modern Style)
-------------------------
do
    local frame=Instance.new("Frame",Content)
    frame.Size=UDim2.new(1,0,0,36)
    frame.BackgroundTransparency=1

    local label=Instance.new("TextLabel",frame)
    label.Size=UDim2.new(0.5,-8,1,0)
    label.BackgroundTransparency=1
    label.Font=Enum.Font.Gotham
    label.TextSize=15
    label.TextColor3=Color3.fromRGB(230,230,230)
    label.Text="WalkSpeed"

    local box=Instance.new("TextBox",frame)
    box.Size=UDim2.new(0.5,0,1,0)
    box.Position=UDim2.new(0.5,8,0,0)
    box.BackgroundColor3=Color3.fromRGB(30,30,30)
    box.TextColor3=Color3.fromRGB(255,255,255)
    box.Font=Enum.Font.Gotham
    box.TextSize=15
    box.Text=tostring(FEATURE.WalkValue)
    box.ClearTextOnFocus=false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)

    local stroke = Instance.new("UIStroke", box)
    stroke.Color = Color3.fromRGB(70,70,70)
    stroke.Thickness = 1.2

    local placeholder=Instance.new("TextLabel",box)
    placeholder.Size=UDim2.new(1,-6,1,0)
    placeholder.Position=UDim2.new(0,3,0,0)
    placeholder.BackgroundTransparency=1
    placeholder.Text="16–200 (Rekomendasi 25-40)"
    placeholder.Font=Enum.Font.Gotham
    placeholder.TextSize=13
    placeholder.TextColor3=Color3.fromRGB(150,150,150)
    placeholder.TextXAlignment=Enum.TextXAlignment.Left

    local function updatePlaceholder()
        placeholder.Visible=(box.Text=="")
    end
    box:GetPropertyChangedSignal("Text"):Connect(updatePlaceholder)
    box.Focused:Connect(updatePlaceholder)
    box.FocusLost:Connect(function(enter)
        updatePlaceholder()
        if enter then
            local n=tonumber(box.Text)
            if n and n>=16 and n<=200 then
                FEATURE.WalkValue=n
                box.Text=tostring(n)
            else
                FEATURE.WalkValue=16
                box.Text=tostring(FEATURE.WalkValue)
            end
        end
    end)
    updatePlaceholder()
end
