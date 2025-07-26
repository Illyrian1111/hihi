-- main.lua (SilentAim DaHood, Version hihi)

-- Einbinden via:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/hihi/main/main.lua"))()

--// Services
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")
local Camera            = workspace.CurrentCamera
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Kill alte GUIs
for _, child in ipairs(PlayerGui:GetChildren()) do
    if child:IsA("ScreenGui") and (child.Name:match("UDHL") or child.Name == "SilentAimUI") then
        child:Destroy()
    end
end

--// Find the DaHood shoot RemoteEvent
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

--// Settings
local Settings = {
    SilentAim = {
        Enabled     = false,
        FOV         = 50,
        AimPart     = "Head",
    },
    ESP = {
        Enabled     = false,
        BoxColor    = Color3.fromRGB(255,0,0),
        Distance    = 1000,
    },
    Keys = {
        ToggleUI     = Enum.KeyCode.T,
        SwitchTarget = Enum.KeyCode.E,
    },
}

--// State
local State = {
    Target    = nil,
    ESPData   = {},    -- [player] = {box, nameText}
    UIVisible = false, -- initial hidden
}

--// Helper Functions
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

local function inFOV(partPos)
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    local dir   = (partPos - camPos).Unit
    local angle = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1,1)))
    return angle <= Settings.SilentAim.FOV
end

local function getClosest()
    local best, bestAngle = nil, Settings.SilentAim.FOV
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild(Settings.SilentAim.AimPart) then
            local part = pl.Character[Settings.SilentAim.AimPart]
            local dir   = (part.Position - camPos).Unit
            local angle = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1,1)))
            if angle < bestAngle then
                bestAngle, best = angle, pl
            end
        end
    end
    return best
end

--// Silent‑Aim Hook
do
    local mt  = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt,false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args   = {...}
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
    setreadonly(mt,true)
end

--// ESP Initialization
local function initESP()
    local function makeFor(pl)
        local box = Drawing.new("Square")
        box.Color     = Settings.ESP.BoxColor
        box.Thickness = 2
        box.Filled    = false
        box.Visible   = false

        local nameText = Drawing.new("Text")
        nameText.Text    = pl.Name
        nameText.Size    = 14
        nameText.Center  = true
        nameText.Color   = Settings.ESP.BoxColor
        nameText.Visible = false

        State.ESPData[pl] = {box=box, nameText=nameText}
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer then makeFor(pl) end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl~=LocalPlayer then makeFor(pl) end
    end)
    Players.PlayerRemoving:Connect(function(pl)
        local d=State.ESPData[pl]
        if d then
            d.box:Remove()
            d.nameText:Remove()
            State.ESPData[pl]=nil
        end
    end)
end

--// Build Centered UI
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name         = "SilentAimUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Enabled      = State.UIVisible
    gui.Parent       = PlayerGui

    local frame = Instance.new("Frame", gui)
    frame.Size               = UDim2.new(0,220,0,160)
    frame.Position           = UDim2.new(0.4,0,0.3,0)
    frame.BackgroundColor3   = Color3.fromRGB(25,25,35)
    frame.BackgroundTransparency = 0.2
    frame.ZIndex             = 999

    local function newBtn(text,y,cb)
        local btn = Instance.new("TextButton", frame)
        btn.Size             = UDim2.new(1,-20,0,25)
        btn.Position         = UDim2.new(0,10,0,y)
        btn.BackgroundColor3 = Color3.fromRGB(40,40,50)
        btn.BorderSizePixel  = 0
        btn.Text             = text
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 14
        btn.TextColor3       = Color3.new(1,1,1)
        btn.ZIndex           = 1000
        btn.MouseButton1Click:Connect(function() cb(btn) end)
        return btn
    end

    local saBtn  = newBtn("Silent Aim: OFF", 10, function(self)
        Settings.SilentAim.Enabled = not Settings.SilentAim.Enabled
        self.Text = "Silent Aim: " .. (Settings.SilentAim.Enabled and "ON" or "OFF")
    end)
    local espBtn = newBtn("ESP: OFF",       45, function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: " .. (Settings.ESP.Enabled and "ON" or "OFF")
    end)
    local partBtn = newBtn("Aim Part: Head",80, function(self)
        Settings.SilentAim.AimPart = (Settings.SilentAim.AimPart=="Head")
            and "HumanoidRootPart" or "Head"
        self.Text = "Aim Part: " .. Settings.SilentAim.AimPart
    end)

    local fovLabel = Instance.new("TextLabel", frame)
    fovLabel.Size                = UDim2.new(1,-20,0,20)
    fovLabel.Position            = UDim2.new(0,10,0,115)
    fovLabel.BackgroundTransparency = 1
    fovLabel.TextColor3          = Color3.new(1,1,1)
    fovLabel.Font                = Enum.Font.GothamBold
    fovLabel.TextSize            = 14
    fovLabel.ZIndex              = 1000
    fovLabel.Text                = "FOV: " .. Settings.SilentAim.FOV

    return gui
end

--// Setup
initESP()
local ui = buildUI()

--// Input Handling
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Keys.ToggleUI then
        State.UIVisible = not State.UIVisible
        ui.Enabled      = State.UIVisible
    elseif input.KeyCode == Settings.Keys.SwitchTarget then
        State.Target = getClosest()
    end
end)

--// ESP Update Loop
RunService.RenderStepped:Connect(function()
    for pl, data in pairs(State.ESPData) do
        local box, nameText = data.box, data.nameText
        local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and hrp then
            local tl,v1 = worldToScreen(hrp.Position + Vector3.new(-1,3,0))
            local br,v2 = worldToScreen(hrp.Position + Vector3.new( 1,-1,0))
            if v1 and v2 then
                local w,h = br.X-tl.X, br.Y-tl.Y
                box.Position = Vector2.new(tl.X,tl.Y)
                box.Size     = Vector2.new(w,h)
                box.Visible  = (hrp.Position-Camera.CFrame.Position).Magnitude<=Settings.ESP.Distance

                nameText.Position = Vector2.new(tl.X+w/2, tl.Y-2)
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
