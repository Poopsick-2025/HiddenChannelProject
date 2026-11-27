--!nocheck
local ControlGUI = {}
ControlGUI.__index = ControlGUI

local function new(t, p)
    local i = Instance.new(t)
    i.Parent = p
    return i
end

function ControlGUI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ControlGUI)
    self.title = opts.title or "TTS Channel Sender"
    self.width = opts.width or 420
    self.parent = opts.parent or game:GetService("Players").LocalPlayer.PlayerGui
    self.onStart = opts.onStart
    self.gui = nil
    self.panel = nil
    self.textBox = nil
    self.startBtn = nil
    self.intervalBox = nil
    self.repeatBox = nil
    self.status = nil
    self.bar = nil
    self.closeBtn = nil
    self.dragBar = nil
    self.dragDet = nil
    self.spec = nil
    self.whiteBtn = nil
    self.blackBtn = nil
    self.mutedBtn = nil
    self.cbForceWhiteBgChecked = false
    self.cbForceBlackBgChecked = false
    self.cbMuted = false
    self.onCheck = opts.onCheck
    self.onClose = opts.onClose
    self.onPreview = opts.onPreview
    self:build()
    return self
end

function ControlGUI:build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TTSAgentControl"
    gui.ResetOnSpawn = false
    gui.Parent = gethui()

    local okOld, oldGui = pcall(function() return getgenv().TTSAgentGui end)
    if okOld and oldGui ~= nil then
        oldGui:destroy()
    end
    getgenv().TTSAgentGui = self

    local panel = new("Frame", gui)
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0, 0)
    panel.Position = UDim2.fromOffset(100, 120)
    panel.Size = UDim2.fromOffset(self.width, 330)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    panel.BorderColor3 = Color3.fromRGB(50, 50, 60)
    panel.BorderSizePixel = 1
    self.panel = panel

    local corner = new("UICorner", panel)
    corner.CornerRadius = UDim.new(0, 10)

    local bar = new("Frame", panel)
    bar.Name = "DragBar"
    bar.Size = UDim2.new(1, 0, 0, 42)
    bar.Position = UDim2.fromOffset(0, 0)
    bar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    bar.BorderSizePixel = 0
    self.bar = bar

    local barCorner = new("UICorner", bar)
    barCorner.CornerRadius = UDim.new(10, 10, 0, 0)

    local xBtn = new("TextButton", bar)
    xBtn.Name = "CloseBtn"
    xBtn.Text = "X"
    xBtn.Size = UDim2.fromOffset(42, 30)
    xBtn.Position = UDim2.new(1, -45, 0, 6)
    xBtn.AnchorPoint = Vector2.new(1, 0)
    xBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    xBtn.TextColor3 = Color3.fromRGB(250, 250, 250)
    xBtn.Font = Enum.Font.GothamBold
    xBtn.TextSize = 16
    xBtn.BorderSizePixel = 0
    self.closeBtn = xBtn

    local dragBar = new("TextLabel", bar)
    dragBar.Size = UDim2.new(0.88, 0, 1, 0)
    dragBar.Position = UDim2.fromOffset(0, 0)
    dragBar.BackgroundTransparency = 1
    self.dragBar = dragBar

    local title = new("TextLabel", dragBar)
    title.Text = self.title
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.fromOffset(10, 6)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(230, 230, 240)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 19

    local dragDet = new("UIDragDetector", panel)
    dragDet.Parent = panel
    dragDet.Enabled = true
    pcall(function() dragDet.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane end)
    pcall(function() dragDet.DragSpace = Enum.UIDragDetectorDragSpace.Parent end)
    self.dragDet = dragDet
    xBtn.Activated:Connect(function()
        if self.onClose then
            self.onClose(self)
        end
        self:destroy()
    end)

    local rowY = 62

    self.textBox = new("TextBox", panel)
    self.textBox.Name = "FileBox"
    self.textBox.Text = ""
    self.textBox.PlaceholderText = "lua_logo_test.luau"
    self.textBox.Size = UDim2.new(1, -20, 0, 32)
    self.textBox.Position = UDim2.fromOffset(10, rowY)
    self.textBox.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    self.textBox.TextColor3 = Color3.fromRGB(245, 245, 255)
    self.textBox.Font = Enum.Font.Code
    self.textBox.TextSize = 14
    self.textBox.BorderSizePixel = 1

    local y2 = rowY + 46
    local intervalLabel = new("TextLabel", panel)
    intervalLabel.Text = "Interval (s):"
    intervalLabel.Size = UDim2.new(1, -20, 0, 20)
    intervalLabel.Position = UDim2.fromOffset(10, y2)
    intervalLabel.BackgroundTransparency = 1
    intervalLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
    intervalLabel.Font = Enum.Font.Gotham
    intervalLabel.TextSize = 13
    self.intervalBox = new("TextBox", panel)
    self.intervalBox.Name = "IntervalBox"
    self.intervalBox.Text = "1.2"
    self.intervalBox.PlaceholderText = "1.2"
    self.intervalBox.Size = UDim2.fromOffset(120, 22)
    self.intervalBox.Position = UDim2.fromOffset(140, y2)
    self.intervalBox.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    self.intervalBox.TextColor3 = Color3.fromRGB(245, 245, 255)
    self.intervalBox.Font = Enum.Font.Code
    self.intervalBox.TextSize = 14
    self.intervalBox.BorderSizePixel = 1

    local y3 = y2 + 30
    local repeatLabel = new("TextLabel", panel)
    repeatLabel.Text = "Repeat:"
    repeatLabel.Size = UDim2.new(1, -20, 0, 20)
    repeatLabel.Position = UDim2.fromOffset(10, y3)
    repeatLabel.BackgroundTransparency = 1
    repeatLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
    repeatLabel.Font = Enum.Font.Gotham
    repeatLabel.TextSize = 13
    self.repeatBox = new("TextBox", panel)
    self.repeatBox.Name = "RepeatBox"
    self.repeatBox.Text = "3"
    self.repeatBox.PlaceholderText = "3"
    self.repeatBox.Size = UDim2.fromOffset(120, 22)
    self.repeatBox.Position = UDim2.fromOffset(140, y3)
    self.repeatBox.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    self.repeatBox.TextColor3 = Color3.fromRGB(245, 245, 255)
    self.repeatBox.Font = Enum.Font.Code
    self.repeatBox.TextSize = 14
    self.repeatBox.BorderSizePixel = 1

    self.startBtn = new("TextButton", panel)
    self.startBtn.Name = "StartBtn"
    self.startBtn.Text = "START SEND"
    self.startBtn.Size = UDim2.new(0.5, -10, 0, 32)
    self.startBtn.Position = UDim2.fromOffset(10, y3 + 30)
    self.startBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 210)
    self.startBtn.TextColor3 = Color3.fromRGB(250, 250, 250)
    self.startBtn.Font = Enum.Font.GothamBold
    self.startBtn.TextSize = 15
    self.startBtn.BorderSizePixel = 0

    self.previewBtn = new("TextButton", panel)
    self.previewBtn.Name = "PreviewBtn"
    self.previewBtn.Text = "PREVIEW"
    self.previewBtn.Size = UDim2.new(0.5, -10, 0, 32)
    self.previewBtn.Position = UDim2.new(0.5, 5, 0, y3 + 30)
    self.previewBtn.AnchorPoint = Vector2.new(0, 0)
    self.previewBtn.BackgroundColor3 = Color3.fromRGB(80, 110, 170)
    self.previewBtn.TextColor3 = Color3.fromRGB(250, 250, 250)
    self.previewBtn.Font = Enum.Font.GothamBold
    self.previewBtn.TextSize = 15
    self.previewBtn.BorderSizePixel = 0

    local function addCheckbox(y, name, label, checked, onSet)
        local fr = new("Frame", panel)
        fr.Size = UDim2.new(1, -20, 0, 18)
        fr.Position = UDim2.fromOffset(20, y)
        fr.BackgroundTransparency = 1
        fr.Parent = panel
        local cb = new("TextButton", fr)
        cb.Size = UDim2.new(1, -10, 0, 18)
        cb.BackgroundTransparency = 1
        cb.TextColor3 = Color3.fromRGB(210, 210, 220)
        cb.Font = Enum.Font.GothamBold
        cb.TextSize = 13
        cb.TextXAlignment = Enum.TextXAlignment.Left
        cb.RichText = true
        cb.Text = (checked and "☑" or "☐") .. " " .. label
        cb.Activated:Connect(function()
            checked = not checked
            cb.Text = (checked and "☑" or "☐") .. " " .. label
            self[name] = checked
            if onSet then onSet(name, checked) end
            if self.onCheck then self.onCheck(name, checked) end
        end)
        return cb
    end

    local y4 = y3 + 62
    self.whiteBtn = addCheckbox(y4, "cbForceWhiteBgChecked", "Force White BG", false)
    self.blackBtn = addCheckbox(y4 + 22, "cbForceBlackBgChecked", "Force Black BG", false)
    self.mutedBtn = addCheckbox(y4 + 44, "cbMuted", "Mute AudioTextToSpeech", false)

    local status = new("TextLabel", panel)
    status.Name = "Status"
    status.Size = UDim2.new(1, -20, 0, 30)
    status.Position = UDim2.fromOffset(10, panel.Size.Y.Offset - 50)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(200, 230, 200)
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    self.status = status

    local function hook(textBox)
        textBox.FocusLost:Connect(function(_, enterPressed)
            if enterPressed then
                self:doStart()
            end
        end)
    end
    hook(self.textBox)
    self.startBtn.Activated:Connect(function()
        self:doStart()
    end)
    self.previewBtn.Activated:Connect(function()
        self:doPreview()
    end)
    self.gui = gui
end

function ControlGUI:doPreview()
    if self.onPreview then
        self.onPreview(self:filename())
    end
end

function ControlGUI:doStart()
    if self.onStart then
        local f = self.onStart
        f(self:filename(), self:interval(), self:repeatN())
    end
end

function ControlGUI:filename()
    return self.textBox and self.textBox.Text or ""
end

function ControlGUI:interval()
    local t = self.intervalBox and self.intervalBox.Text or "1.2"
    local v = tonumber(t)
    return v and math.max(0.1, math.min(10, v)) or 1.2
end

function ControlGUI:repeatN()
    local t = self.repeatBox and self.repeatBox.Text or "3"
    local v = tonumber(t)
    return v and math.max(1, math.min(10, math.floor(v))) or 3
end

function ControlGUI:setStatus(text)
    if self.status then
        self.status.Text = text
    end
end

function ControlGUI:destroy()
    if self.gui then
        self.gui:Destroy()
    end
end

return ControlGUI
