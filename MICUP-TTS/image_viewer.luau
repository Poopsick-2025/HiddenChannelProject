--!nocheck
local ImageViewer = {}
ImageViewer.__index = ImageViewer

local function loadModule(envKey, path)
    local ok, src = pcall(function()
        return getgenv()[envKey]
    end)
    if not ok or type(src) ~= "string" or #src == 0 then
        src = nil
    end
    if src == nil and type(httpget) == "function" then
        local okGet, res = pcall(httpget, "http://127.0.0.1:8766/" .. path)
        if okGet and type(res) == "string" and #res > 0 then
            src = res
        end
    end
    if src == nil then
        return nil
    end
    local loader = loadstring(src)
    if loader == nil then
        return nil
    end
    local okRun, mod = pcall(loader)
    if not okRun or type(mod) ~= "table" then
        return nil
    end
    return mod
end

local Hex = loadModule("HEX_SRC", "HiddenChannelProject/hex.luau")
local UserInputService = game:GetService("UserInputService")

local TRANSPARENT_COLOR = "#00000000"

function ImageViewer.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ImageViewer)
    self.width = opts.width or 64
    self.height = opts.height or 64
    self.strip = opts.strip or 8
    self.palette = opts.palette or {}
    self.fontSize = opts.fontSize or 2
    self.parent = opts.parent or game:GetService("Players").LocalPlayer.PlayerGui
    self.double = opts.double ~= false
    self.forceWhiteBg = opts.forceWhiteBg == true
    self.forceBlackBg = opts.forceBlackBg == true
    self.onProgress = opts.onProgress
    self.rows = {}
    self.total = math.ceil(self.height / self.strip)
    self.gui = nil
    self.label = nil
    self.progressLabel = nil
    self:build()
    return self
end

function ImageViewer:build()
    local maxCanvasW = 420
    local maxCanvasH = 320
    local cellW = math.min(8, math.floor(maxCanvasW / math.max(1, self.width)))
    local cellH = math.min(8, math.floor(maxCanvasH / math.max(1, self.height)))
    local cell = math.max(1, math.min(cellW, cellH))
    local canvasW = self.width * cell
    local canvasH = self.height * cell

    local gui = Instance.new("ScreenGui")
    gui.Name = "TTS Image"
    gui.ResetOnSpawn = false
    gui.Parent = self.parent or gethui()

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(0, 0)
    frame.Size = UDim2.fromOffset(canvasW + 24, canvasH + 84)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local bar = Instance.new("Frame")
    bar.Name = "DragBar"
    bar.Size = UDim2.new(1, 0, 0, 28)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    bar.BorderSizePixel = 0
    bar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(220, 220, 230)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Text = "TTS Image"
    title.Parent = bar

    local progress = Instance.new("TextLabel")
    progress.Name = "Progress"
    progress.Size = UDim2.fromOffset(80, 28)
    progress.Position = UDim2.new(1, -110, 0, 0)
    progress.BackgroundTransparency = 1
    progress.TextColor3 = Color3.fromRGB(140, 200, 160)
    progress.Font = Enum.Font.GothamBold
    progress.TextSize = 14
    progress.Text = "0/" .. tostring(self.total)
    progress.Parent = bar

    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.Size = UDim2.fromOffset(26, 26)
    close.Position = UDim2.new(1, -28, 0, 1)
    close.BackgroundColor3 = Color3.fromRGB(200, 48, 48)
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.Text = "X"
    close.Parent = bar
    close.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:destroy()
        end
    end)

    local label = Instance.new("TextLabel")
    label.Name = "Canvas"
    label.Position = UDim2.fromOffset(12, 36)
    label.Size = UDim2.fromOffset(canvasW, canvasH)
    label.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.Code
    label.TextSize = math.max(4, cell * 0.85)
    label.RichText = true
    label.TextScaled = false
    label.TextWrapped = true
    label.ClipsDescendants = true
    label.LineHeight = 1.0
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = ""
    label.Parent = frame

    local dragging = false
    local dragStart = nil
    local startPos = nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    self.gui = gui
    self.frame = frame
    self.label = label
    self.progressLabel = progress
    self.cell = cell
end

function ImageViewer:getProgress()
    if self.progressLabel == nil then
        return "0/" .. tostring(self.total)
    end
    return self.progressLabel.Text
end

function ImageViewer:update(spec)
    self.width = spec.width
    self.height = spec.height
    self.strip = spec.strip
    self.palette = spec.palette
    self.rows = {}
    self.total = math.ceil(self.height / self.strip)
    self.label.Text = ""
    self.progressLabel.Text = "0/" .. tostring(self.total)
    for i, s in ipairs(spec.strips) do
        self:renderStrip(i - 1, s)
    end
end

local ALPHA_THRESHOLD = 128

function ImageViewer:hexForStrip(index)
    local color = self.palette[index + 1]
    if type(color) ~= "string" or color == "" then
        return nil
    end
    local hex = color
    if string.sub(hex, 1, 1) == "#" then
        hex = string.sub(hex, 2)
    end
    local alpha = nil
    if #hex == 8 then
        alpha = tonumber(string.sub(hex, 7, 8), 16)
        hex = string.sub(hex, 1, 6)
    end
    if alpha ~= nil and alpha < ALPHA_THRESHOLD then
        if self.forceBlackBg then
            return "#000000"
        end
        if self.forceWhiteBg then
            return "#ffffff"
        end
        return nil
    end
    if #hex ~= 6 then
        if #hex > 6 then
            hex = string.sub(hex, 1, 6)
        elseif #hex < 6 then
            hex = hex .. string.rep("0", 6 - #hex)
        end
    end
    if #hex ~= 6 then
        return nil
    end
    return "#" .. hex
end

function ImageViewer:renderStrip(index, hexData)
    if Hex == nil then
        return nil, "no_hex"
    end
    local bytes = Hex.decode(hexData)
    if bytes == nil then
        return nil, "bad_strip"
    end
    local stripH = self.strip
    local w = self.width
    local lines = {}
    for row = 0, stripH - 1 do
        local y = index * stripH + row
        if y >= self.height then
            break
        end
        local line = ""
        local current
        local buffer = ""
        for x = 0, w - 1 do
            local at = row * w + x + 1
            local idx = string.byte(bytes, at) or 0
            local col = self:hexForStrip(idx)
            if col ~= current then
                if current ~= nil then
                    line = line .. '<font color="' .. current .. '">' .. buffer .. "</font>"
                elseif buffer ~= "" then
                    line = line .. buffer
                end
                current = col
                buffer = ""
            end
            buffer = buffer .. (col and (self.double and "██" or "█") or (self.double and "  " or " "))
        end
        if current ~= nil then
            line = line .. '<font color="' .. current .. '">' .. buffer .. "</font>"
        elseif buffer ~= "" then
            line = line .. buffer
        end
        lines[#lines + 1] = line
    end
    self.rows[index + 1] = table.concat(lines, "\n")
    local joined = {}
    for i = 1, self.total do
        if self.rows[i] then
            joined[#joined + 1] = self.rows[i]
        end
    end
    self.label.Text = table.concat(joined, "\n")
    local done = 0
    for _ in pairs(self.rows) do
        done = done + 1
    end
    self.progressLabel.Text = tostring(done) .. "/" .. tostring(self.total)
    if self.onProgress then
        self.onProgress(done, self.total)
    end
    return done, self.total
end

function ImageViewer:reset()
    self.rows = {}
    self.label.Text = ""
    self.progressLabel.Text = "0/" .. tostring(self.total)
end

function ImageViewer:destroy()
    if self.gui then
        self.gui:Destroy()
    end
end

return ImageViewer
