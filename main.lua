-- UDHL-DaHood.lua
-- Einbinden via:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/uwu/main/main.lua"))()

--// Services
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--// Settings
local Settings = {
    Aimbot = {
        Enabled     = false,
        Key         = Enum.KeyCode.Q,
        FOV         = 60,
        Smoothness  = 0.2,
        Prediction  = 0.15,
        AimPart     = "Head", -- "Head" oder "HumanoidRootPart"
    },
    ESP = {
        Enabled     = false,
        BoxColor    = Color3.fromRGB(255,0,0),
        Distance    = 1000,
    },
    UI = {
        ToggleKey   = Enum.KeyCode.T,
    }
}

--// State
local State = {
    Target      = nil,
    ESPBoxes    = {},
    UIVisible   = true,
}

--// Helper: World -> Screen
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

--// Find closest target within FOV
local function getClosest()
    local best, bestAngle = nil, math.rad(Settings.Aimbot.FOV)
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild(Settings.Aimbot.AimPart) then
            local part = pl.Character[Settings.Aimbot.AimPart]
            local predicted = part.Position + part.Velocity * Settings.Aimbot.Prediction
            local dir = (predicted - camPos).Unit
            local angle = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            if angle < bestAngle then
                bestAngle, best = angle, pl
            end
        end
    end
    return best
end

--// Smoothly aim the camera at position
local function smoothAim(pos)
    local camCF = Camera.CFrame
    local dir = (pos - camCF.Position).Unit
    local dot = math.clamp(camCF.LookVector:Dot(dir), -1, 1)
    local angle = math.acos(dot)
    local axis = camCF.LookVector:Cross(dir)
    local rot = CFrame.fromAxisAngle(axis, angle)
    Camera.CFrame = camCF:Lerp(camCF * rot, Settings.Aimbot.Smoothness)
end

--// Initialize ESP boxes
local function initESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Color     = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled    = false
            box.Visible   = false
            State.ESPBoxes[pl] = box
        end
    end

    Players.PlayerAdded:Connect(function(pl)
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Color     = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled    = false
            box.Visible   = false
            State.ESPBoxes[pl] = box
        end
    end)

    Players.PlayerRemoving:Connect(function(pl)
        if State.ESPBoxes[pl] then
            State.ESPBoxes[pl]:Remove()
            State.ESPBoxes[pl] = nil
        end
    end)
end

--// Build Configuration UI
local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UDHL_DaHood_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 120)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    local function newBtn(text, y, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 25)
        btn.Position = UDim2.new(0, 5, 0, y)
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = frame
        btn.MouseButton1Click:Connect(function()
            cb(btn)
        end)
        return btn
    end

    -- Aimbot toggle button
    newBtn("Aimbot: OFF", 10, function(self)
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        self.Text = "Aimbot: " .. (Settings.Aimbot.Enabled and "ON" or "OFF")
    end)
    -- ESP toggle button
    newBtn("ESP: OFF", 45, function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: " .. (Settings.ESP.Enabled and "ON" or "OFF")
    end)
    -- AimPart switch
    newBtn("Aim Part: Head", 80, function(self)
        Settings.Aimbot.AimPart = (Settings.Aimbot.AimPart == "Head") and "HumanoidRootPart" or "Head"
        self.Text = "Aim Part: " .. Settings.Aimbot.AimPart
    end)

    return screenGui
end

--// Create FOV circle with Drawing
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides   = 64
fovCircle.Radius     = Settings.Aimbot.FOV
fovCircle.Thickness  = 1
fovCircle.Transparency = 0.7
fovCircle.Color      = Color3.fromRGB(255,50,50)
fovCircle.Visible    = false

--// Input Handling (toggles)
local ui = buildUI()
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Aimbot.Key then
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
    elseif input.KeyCode == Settings.UI.ToggleKey then
        State.UIVisible = not State.UIVisible
        ui.Enabled = State.UIVisible
    end
end)

--// Main update loop
RunService.RenderStepped:Connect(function()
    -- Update FOV circle
    fovCircle.Radius    = Settings.Aimbot.FOV
    fovCircle.Position  = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Visible   = Settings.Aimbot.Enabled

    -- Aimbot
    if Settings.Aimbot.Enabled then
        if not State.Target
        or not State.Target.Character
        or not State.Target.Character:FindFirstChild(Settings.Aimbot.AimPart) then
            State.Target = getClosest()
        end
        if State.Target and State.Target.Character then
            local part = State.Target.Character[Settings.Aimbot.AimPart]
            smoothAim(part.Position + part.Velocity * Settings.Aimbot.Prediction)
        end
    else
        State.Target = nil
    end

    -- ESP
    for pl, box in pairs(State.ESPBoxes) do
        local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and root then
            local topLeft, vis1 = worldToScreen(root.Position + Vector3.new(-1, 3, 0))
            local botRight, vis2 = worldToScreen(root.Position + Vector3.new(1, -1, 0))
            if vis1 and vis2 then
                box.Position = Vector2.new(topLeft.X, topLeft.Y)
                box.Size     = Vector2.new(botRight.X - topLeft.X, botRight.Y - topLeft.Y)
                box.Visible  = (root.Position - Camera.CFrame.Position).Magnitude <= Settings.ESP.Distance
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end
end)

--// Start ESP setup
initESP()
