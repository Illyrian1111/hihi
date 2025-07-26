-- UDHL-DaHood-ESP.lua
-- Nur ESP mit einstellbaren Optionen

--// Services
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")

--// Settings
local Settings = {
    ESP = {
        Enabled     = true,
        Box         = true,
        Skeleton    = false,
        Circle      = false,
        Name        = true,
        Color       = Color3.fromRGB(255, 0, 0),
        Distance    = 1000,
        Thickness   = 2,
        FontSize    = 14,
    },
    UI = {
        ToggleKey   = Enum.KeyCode.T,
    }
}

--// State
local State = {
    ESPData = {},  -- [player] = {box, lines, circle, nameText}
    UIVisible = true,
}

--// Helper: World -> Screen
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

--// Initialize ESP-Drawing-Objects
local function initESP()
    local function makeFor(pl)
        local data = {}

        -- Box
        data.box = Drawing.new("Square")
        data.box.Thickness = Settings.ESP.Thickness
        data.box.Filled    = false
        data.box.Color     = Settings.ESP.Color
        data.box.Visible   = false

        -- Skeleton: 6 lines (head, torso, arms, legs)
        data.lines = {}
        for i = 1,6 do
            local line = Drawing.new("Line")
            line.Thickness = Settings.ESP.Thickness
            line.Color     = Settings.ESP.Color
            line.Visible   = false
            table.insert(data.lines, line)
        end

        -- Circle at root
        data.circle = Drawing.new("Circle")
        data.circle.Thickness = Settings.ESP.Thickness
        data.circle.Radius     = 20
        data.circle.Color      = Settings.ESP.Color
        data.circle.Filled     = false
        data.circle.Visible    = false

        -- Name
        data.nameText = Drawing.new("Text")
        data.nameText.Size    = Settings.ESP.FontSize
        data.nameText.Center  = true
        data.nameText.Color   = Settings.ESP.Color
        data.nameText.Visible = false
        data.nameText.Text    = pl.Name

        State.ESPData[pl] = data
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
            for _, l in ipairs(d.lines) do l:Remove() end
            d.circle:Remove()
            d.nameText:Remove()
            State.ESPData[pl] = nil
        end
    end)
end

--// Build simple UI zum Anpassen (Frame + Buttons)
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ESP_Config"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 220, 0, 180)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    frame.BackgroundTransparency = 0.2

    local function newToggle(label, y, settingKey)
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(1, -10, 0, 25)
        btn.Position = UDim2.new(0, 5, 0, y)
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        local function updateText()
            btn.Text = label..": "..(Settings.ESP[settingKey] and "ON" or "OFF")
        end
        updateText()
        btn.MouseButton1Click:Connect(function()
            Settings.ESP[settingKey] = not Settings.ESP[settingKey]
            updateText()
        end)
        return btn
    end

    newToggle("ESP",      10,  "Enabled")
    newToggle("Box",      45,  "Box")
    newToggle("Skeleton", 80,  "Skeleton")
    newToggle("Circle",  115,  "Circle")
    newToggle("Name",    150,  "Name")
    return gui
end

--// Update ESP every Frame
RunService.RenderStepped:Connect(function()
    for pl, data in pairs(State.ESPData) do
        local char = pl.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and root then
            local dist = (root.Position - Camera.CFrame.Position).Magnitude
            if dist <= Settings.ESP.Distance then
                -- Berechne Screen-Positions
                local topPos3D    = root.Position + Vector3.new(0, 3, 0)
                local bottomPos3D = root.Position + Vector3.new(0, -1, 0)
                local headPos3D   = char.Head and char.Head.Position or topPos3D

                local tl, vis1 = worldToScreen(topPos3D)
                local br, vis2 = worldToScreen(bottomPos3D)
                local head2d, vis3 = worldToScreen(headPos3D)

                if vis1 and vis2 then
                    -- Box
                    if Settings.ESP.Box then
                        data.box.Position = Vector2.new(tl.X, tl.Y)
                        data.box.Size     = Vector2.new(br.X - tl.X, br.Y - tl.Y)
                        data.box.Color    = Settings.ESP.Color
                        data.box.Visible  = true
                    else
                        data.box.Visible = false
                    end

                    -- Skeleton (einfach: Kopf-Torso und Arme/Beine)
                    if Settings.ESP.Skeleton then
                        local midNP = (topPos3D + bottomPos3D) / 2
                        local mid2d, _ = worldToScreen(midNP)
                        local root2d = Vector2.new((tl.X+br.X)/2, (tl.Y+br.Y)/2)
                        -- Kopf zu Torso
                        local segs = {
                            {head2d, mid2d},
                            {mid2d, root2d},
                            -- Beine
                            {root2d, Vector2.new(root2d.X - 10, br.Y)},
                            {root2d, Vector2.new(root2d.X + 10, br.Y)},
                            -- Arme
                            {mid2d, Vector2.new(mid2d.X - 15, mid2d.Y + 20)},
                            {mid2d, Vector2.new(mid2d.X + 15, mid2d.Y + 20)},
                        }
                        for i, seg in ipairs(segs) do
                            local l = data.lines[i]
                            l.From = seg[1]
                            l.To   = seg[2]
                            l.Color    = Settings.ESP.Color
                            l.Visible  = true
                        end
                    else
                        for _, l in ipairs(data.lines) do l.Visible = false end
                    end

                    -- Circle
                    if Settings.ESP.Circle then
                        data.circle.Position = Vector2.new((tl.X+br.X)/2, (tl.Y+br.Y)/2)
                        data.circle.Radius   = (br.Y - tl.Y)/2
                        data.circle.Color    = Settings.ESP.Color
                        data.circle.Visible  = true
                    else
                        data.circle.Visible = false
                    end

                    -- Name
                    if Settings.ESP.Name then
                        data.nameText.Position = Vector2.new((tl.X+br.X)/2, tl.Y - 10)
                        data.nameText.Color    = Settings.ESP.Color
                        data.nameText.Visible  = true
                    else
                        data.nameText.Visible = false
                    end
                else
                    -- Außerhalb des Bildschirms
                    data.box.Visible = false
                    for _, l in ipairs(data.lines) do l.Visible = false end
                    data.circle.Visible = false
                    data.nameText.Visible = false
                end
            else
                -- Zu weit weg
                data.box.Visible = false
                for _, l in ipairs(data.lines) do l.Visible = false end
                data.circle.Visible = false
                data.nameText.Visible = false
            end
        else
            -- ESP global deaktiviert oder kein HumanoidRootPart
            data.box.Visible = false
            for _, l in ipairs(data.lines) do l.Visible = false end
            data.circle.Visible = false
            data.nameText.Visible = false
        end
    end
end)

--// Setup
initESP()
local ui = buildUI()

-- UI Toggle
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Settings.UI.ToggleKey then
        ui.Enabled = not ui.Enabled
    end
end)
