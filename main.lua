-- UDHL-DaHood.lua mit Silent Aim
-- Einbinden via:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/uwu/main/main.lua"))()

--// Services
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

--// Find DaHood ShootEvent
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

--// Settings
local Settings = {
    SilentAim = {
        Enabled     = false,
        Key         = Enum.KeyCode.Q,
        SwitchKey   = Enum.KeyCode.E,
        FOV         = 50,
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

--// Is within FOV?
local function inFOV(pos)
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    local dir = (pos - camPos).Unit
    local ang = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
    return ang <= Settings.SilentAim.FOV
end

--// Get closest target in FOV
local function getClosest()
    local best, bestAng = nil, Settings.SilentAim.FOV
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild(Settings.SilentAim.AimPart) then
            local part = pl.Character[Settings.SilentAim.AimPart]
            local dir = (part.Position - camPos).Unit
            local ang = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
            if ang < bestAng then
                bestAng, best = ang, pl
            end
        end
    end
    return best
end

--// Silent‑Aim Hook (override hit position)
do
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller()
        and self == ShootEvent
        and method == "FireServer"
        and Settings.SilentAim.Enabled
        and State.Target
        and State.Target.Character
        and State.Target.Character:FindFirstChild(Settings.SilentAim.AimPart) then

            local pos = State.Target.Character[Settings.SilentAim.AimPart].Position
            if inFOV(pos) then
                args[1] = pos
            end
        end
        return old(self, unpack(args))
    end)
    setreadonly(mt, true)
end

--// Initialize ESP boxes (unchanged)
local function initESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer then
            local box = Drawing.new("Square")
            box.Color = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled = false
            box.Visible = false
            State.ESPBoxes[pl] = box
        end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl~=LocalPlayer then
            local box = Drawing.new("Square")
            box.Color = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled = false
            box.Visible = false
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

--// Build UI (unchanged)
local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UDHL_DaHood_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,200,0,120)
    frame.Position = UDim2.new(0,20,0,100)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    local function btn(txt,y,cb)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,-10,0,25)
        b.Position=UDim2.new(0,5,0,y)
        b.BackgroundTransparency=0.2
        b.BorderSizePixel=0
        b.Text=txt
        b.Font=Enum.Font.GothamBold
        b.TextSize=14
        b.TextColor3=Color3.new(1,1,1)
        b.Parent=frame
        b.MouseButton1Click:Connect(function() cb(b) end)
        return b
    end

    btn("SilentAim: OFF",10,function(self)
        Settings.SilentAim.Enabled = not Settings.SilentAim.Enabled
        self.Text = "SilentAim: "..(Settings.SilentAim.Enabled and "ON" or "OFF")
    end)
    btn("ESP: OFF",45,function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: "..(Settings.ESP.Enabled and "ON" or "OFF")
    end)
    btn("Aim Part: Head",80,function(self)
        Settings.SilentAim.AimPart = (Settings.SilentAim.AimPart=="Head") and "HumanoidRootPart" or "Head"
        self.Text = "Aim Part: "..Settings.SilentAim.AimPart
    end)

    return screenGui
end

--// FOV Circle (optional)
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides=64
fovCircle.Radius=Settings.SilentAim.FOV
fovCircle.Thickness=1
fovCircle.Transparency=0.7
fovCircle.Color=Color3.fromRGB(255,50,50)
fovCircle.Visible=false

--// Input handling
local ui = buildUI()
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Settings.SilentAim.Key then
        State.Target = getClosest()
    elseif input.KeyCode==Settings.SilentAim.SwitchKey then
        State.Target = getClosest()
    elseif input.KeyCode==Settings.UI.ToggleKey then
        State.UIVisible = not State.UIVisible
        ui.Enabled = State.UIVisible
    end
end)

--// Main loop: ESP + FOV circle update
RunService.RenderStepped:Connect(function()
    fovCircle.Radius = Settings.SilentAim.FOV
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Visible = Settings.SilentAim.Enabled

    for pl,box in pairs(State.ESPBoxes) do
        local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and hrp then
            local tl,v1=worldToScreen(hrp.Position+Vector3.new(-1,3,0))
            local br,v2=worldToScreen(hrp.Position+Vector3.new(1,-1,0))
            if v1 and v2 then
                box.Position=Vector2.new(tl.X,tl.Y)
                box.Size=Vector2.new(br.X-tl.X,br.Y-tl.Y)
                box.Visible=(hrp.Position-Camera.CFrame.Position).Magnitude<=Settings.ESP.Distance
            else box.Visible=false end
        else box.Visible=false end
    end
end)

--// Start ESP
initESP()
