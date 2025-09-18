local Library = loadstring(Game:HttpGet("https://raw.githubusercontent.com/bloodball/-back-ups-for-libs/main/wizard"))()
local PhantomForcesWindow = Library:NewWindow("2P Battle Tycoon")

local SpeedSection = PhantomForcesWindow:NewSection("WalkSpeed")
local AutoSection = PhantomForcesWindow:NewSection("Automatic E")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Speed setup
local tspeed = 0
local minSpeed = 0
local maxSpeed = 100
local tpwalking = true
local hum

local function isNumber(str)
    return tonumber(str) ~= nil or str == 'inf'
end

local function adjustSpeed(newSpeed)
    if isNumber(newSpeed) then
        local speedValue = tonumber(newSpeed)
        if speedValue < minSpeed then
            tspeed = minSpeed
        elseif speedValue > maxSpeed then
            tspeed = maxSpeed
        else
            tspeed = speedValue
        end
    end
end

local function setupCharacter()
    local chr = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    hum = chr:WaitForChild("Humanoid")

    -- Input speed
    SpeedSection:CreateTextbox("Speed", function(text)
        adjustSpeed(text)
    end)

    -- Movement loop
    spawn(function()
        while tpwalking and RunService.Heartbeat:Wait() and chr and hum and hum.Parent do
            if hum.MoveDirection.Magnitude > 0 then
                local adjustedSpeed = tspeed * 0.2
                chr:TranslateBy(hum.MoveDirection * adjustedSpeed)
            end
        end
    end)
end

setupCharacter()
LocalPlayer.CharacterAdded:Connect(function()
    wait(0.5)
    setupCharacter()
end)

-- AutoClick setup
local autoClicking = false
local AUTO_INTERVAL = 0.6 -- Detik interval auto click

AutoSection:CreateButton("AutoClick ON", function()
    if autoClicking then return end
    autoClicking = true

    -- Start auto click
    spawn(function()
        while autoClicking do
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            local t0 = tick()
            while tick() - t0 < AUTO_INTERVAL do
                if not autoClicking then break end
                RunService.Heartbeat:Wait()
            end
        end
    end)
end)

AutoSection:CreateButton("AutoClick OFF", function()
    autoClicking = false
end)
