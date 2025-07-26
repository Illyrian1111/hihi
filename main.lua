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
        SwitchKey   = Enum.KeyCode.E,
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
    ESPData     = {},  -- [player] = {box, nameText}
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

--// Initialize ESP (Box + Name)
local function initESP()
    local function makeFor(pl)
        local box = Drawing.new("Square")
        box.Color     = Settings.ESP.BoxColor
        box.Thickness = 2
        box.Filled    = false
        box.Visible   = false

        local nameText = Drawing.new("Text")
        nameText.Text       = pl.Name
        nameText.Size       = 14
        nameText.Center     = true
        nameText.Color      = Settings.ESP.BoxColor
        nameText.Visible    = false

        State.ESPData[pl] = { box = box, nameText = nameText }
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then makeFor(pl) end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl ~= LocalPlayer then makeFor(pl) end
    end)
    Players.PlayerRemoving:Connect(function(pl)
        local d = State.ESPData[pl]
        if d then
            d.box:Remove()
            d.nameText:Remove()
            State.ESPData[pl] = nil
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
    frame.Size = UDim2.new(0, 200, 0, 150)
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

    local aBtn = newBtn("Aimbot: OFF", 10, function(self)
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        if not Settings.Aimbot.Enabled then State.Target = nil end
        self.Text = "Aimbot: " .. (Settings.Aimbot.Enabled and "ON" or "OFF")
        targetLabel.Text = "Target: " .. (State.Target and State.Target.Name or "None")
    end)
    local eBtn = newBtn("ESP: OFF", 45, function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: " .. (Settings.ESP.Enabled and "ON" or "OFF")
    end)
    local pBtn = newBtn("Aim Part: Head", 80, function(self)
        Settings.Aimbot.AimPart = (Settings.Aimbot.AimPart == "Head") and "HumanoidRootPart" or "Head"
        self.Text = "Aim Part: " .. Settings.Aimbot.AimPart
    end)
    -- Target-Label
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -10, 0, 20)
    targetLabel.Position = UDim2.new(0, 5, 0, 115)
    targetLabel.BackgroundTransparency = 1
    targetLabel.TextColor3 = Color3.new(1,1,1)
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.TextSize = 14
    targetLabel.Text = "Target: None"
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = frame

    return screenGui, targetLabel
end

--// Create FOV circle with Drawing
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides     = 64
fovCircle.Radius       = Settings.Aimbot.FOV
fovCircle.Thickness    = 1
fovCircle.Transparency = 0.7
fovCircle.Color        = Color3.fromRGB(255,50,50)
fovCircle.Visible      = false

--// Setup
initESP()
local ui, targetLabel = buildUI()

--// Input Handling (toggles & switch target)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Aimbot.Key then
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        if not Settings.Aimbot.Enabled then State.Target = nil end
    elseif input.KeyCode == Settings.Aimbot.SwitchKey and Settings.Aimbot.Enabled then
        State.Target = getClosest()
    elseif input.KeyCode == Settings.UI.ToggleKey then
        State.UIVisible = not State.UIVisible
        ui.Enabled = State.UIVisible
    end
    targetLabel.Text = "Target: " .. (State.Target and State.Target.Name or "None")
end)

--// Main update loop
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    fovCircle.Radius  = Settings.Aimbot.FOV
    fovCircle.Position= Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Visible = Settings.Aimbot.Enabled

    -- Aimbot
    if Settings.Aimbot.Enabled and State.Target and State.Target.Character and State.Target.Character:FindFirstChild(Settings.Aimbot.AimPart) then
        local part = State.Target.Character[Settings.Aimbot.AimPart]
        smoothAim(part.Position + part.Velocity * Settings.Aimbot.Prediction)
    end

    -- ESP
    for pl, data in pairs(State.ESPData) do
        local box, nameText = data.box, data.nameText
        local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and root then
            local tl, v1 = worldToScreen(root.Position + Vector3.new(-1, 3, 0))
            local br, v2 = worldToScreen(root.Position + Vector3.new( 1,-1, 0))
            if v1 and v2 then
                local w,h = br.X - tl.X, br.Y - tl.Y
                box.Position = Vector2.new(tl.X, tl.Y)
                box.Size     = Vector2.new(w, h)
                box.Visible  = (root.Position - Camera.CFrame.Position).Magnitude <= Settings.ESP.Distance

                nameText.Position = Vector2.new(tl.X + w/2, tl.Y - 2)
                nameText.Visible  = box.Visible
            else
                box.Visible = false
                nameText.Visible = false
            end
        else
            box.Visible = false
            nameText.Visible = false
        end
    end
end)
