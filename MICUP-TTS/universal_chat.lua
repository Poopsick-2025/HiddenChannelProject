--!nocheck
local UniversalChat = {}
UniversalChat.__index = UniversalChat

local function loadM(envKey, path)
    local ok, src = pcall(httpget, "http://127.0.0.1:8766/" .. path)
    if not ok or type(src) ~= "string" or #src == 0 then
        return nil
    end
    local l = loadstring(src)
    if not l then
        return nil
    end
    local ok2, m = pcall(l)
    return ok2 and m or nil
end

function UniversalChat.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UniversalChat)
    self.players = game:GetService("Players")
    self.lp = self.players.LocalPlayer
    self.order = 0
    self.messages = {}
    self.transport = opts.transport
    if self.transport == nil then
        local Protocol = opts.protocol or loadM("PROTOCOL_SRC", "HiddenChannelProject/protocol.luau")
        local Sender = loadM("SENDER_SRC", "HiddenChannelProject/tts_sender.luau")
        local Spy = loadM("SPY_SRC", "HiddenChannelProject/tts_spy.luau")
        local Registry = loadM("REGISTRY_SRC", "HiddenChannelProject/codec_registry.luau")
        local Transport = loadM("TRANSPORT_SRC", "HiddenChannelProject/transport.luau")
        Registry.setup({
            lz4 = loadM("LZ4_SRC", "HiddenChannelProject/codec_lz4.luau"),
            huffman = loadM("HUFFMAN_SRC", "HiddenChannelProject/codec_huffman.luau"),
        })
        self.transport = Transport.new({ protocol = Protocol, senderClass = Sender, spyClass = Spy, registry = Registry })
    end
    self.imageStream = loadM("ISTREAM_SRC", "HiddenChannelProject/MICUP-TTS/image_stream.luau").new({ transport = self.transport, allowedUsers = opts.allowedUsers })
    self.transport.spy.onMessage = function(uid, kind, data)
        self:onMessage(uid, kind, data)
    end
    self.transport:start()
    self:buildGui()
    return self
end

function UniversalChat:start(opts)
    local self2 = UniversalChat.new(opts)
    return self2
end

function UniversalChat:create(t, p, x, y, w, h, c3)
    local i = Instance.new(t)
    if p then
        i.Parent = p
    end
    if x then
        i.Position = UDim2.fromOffset(x, y)
    end
    if w then
        i.Size = UDim2.fromOffset(w, h)
    end
    if c3 then
        i.BackgroundColor3 = c3
    end
    return i
end

function UniversalChat:buildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "UniversalChat"
    gui.ResetOnSpawn = false
    gui.Parent = gethui()
    self.gui = gui

    
    local root = self:create("Frame", gui, 0, 0, 480, 560, Color3.fromRGB(8, 8, 12))
    root.Name = "ChatFrame"
    root.AnchorPoint = Vector2.new(1, 0.5)
    root.Position = UDim2.new(1, 0, 0.5, 0)
    root.BorderSizePixel = 1
    root.BorderColor3 = Color3.fromRGB(30, 30, 40)
    local corner = self:create("UICorner", root)
    corner.CornerRadius = UDim.new(0, 8)
    self.root = root

    local drag = self:create("UIDragDetector")
    drag.Name = "DragDetector"
    drag.Selectable = false
    drag.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
    drag.ResponseStyle = Enum.UIDragDetectorResponseStyle.Offset
    drag.DragRelativity = Enum.UIDragDetectorDragRelativity.Absolute
    drag.DragSpace = Enum.UIDragDetectorDragSpace.Parent
    drag.ReferenceUIInstance = root
    drag.Parent = self.gui
    self.dragDetector = drag
    self.dragging = false
    drag.DragEnd:Connect(function()
        self.dragging = false
    end)
    drag.DragStart:Connect(function()
        self.dragging = true
    end)

    local title = self:create("TextLabel", root, 12, 8, 456, 26, nil)
    title.Text = "Universal Chat"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(220, 220, 240)
    title.BackgroundTransparency = 1

    local scroll = self:create("ScrollingFrame", root, 12, 46, 456, 428, Color3.fromRGB(18, 18, 22))
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 60)
    scroll.CanvasSize = UDim2.new(1, -24, 0, 0)
    scroll.BottomImage = ""
    scroll.TopImage = ""
    scroll.BackgroundTransparency = 0.2
    scroll.Name = "List"
    scroll.Parent = root

    local ll = self:create("UIListLayout", scroll)
    ll.Padding = UDim.new(0, 4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder

    local inputRow = self:create("Frame", root, 12, 480, 456, 40, Color3.fromRGB(16, 16, 20))
    inputRow.Name = "InputRow"
    inputRow.Parent = root
    local cornerI = self:create("UICorner", inputRow)
    cornerI.CornerRadius = UDim.new(0, 8)

    self.input = self:create("TextBox", inputRow, 8, 6, 456 - 130, 28, nil)
    self.input.Name = "InputBox"
    pcall(function() self.input.TextEditable = true end)
    pcall(function() self.input.Editable = true end)
    self.input.ClearTextOnFocus = true
    self.input.PlaceholderText = "Type a message..."
    self.input.Font = Enum.Font.Code
    self.input.TextSize = 13
    self.input.TextColor3 = Color3.fromRGB(220, 220, 240)
    self.input.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    self.input.Parent = inputRow
    self.input.FocusLost:Connect(function(_, enterPressed)
        if enterPressed then self:sendFromInput() end
    end)

    self.sendBtn = self:create("TextButton", inputRow, 462 - 130, 7, 64, 26, Color3.fromRGB(90, 170, 80))
    self.sendBtn.Name = "SendBtn"
    self.sendBtn.Text = "Send"
    self.sendBtn.Font = Enum.Font.GothamBold
    self.sendBtn.TextSize = 12
    self.sendBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
    self.sendBtn.Activated:Connect(function()
        self:sendFromInput()
    end)
    self.sendBtn.Parent = inputRow

    local imgLine = self:create("Frame", root, 12, 562, 456, 34, Color3.fromRGB(40, 40, 50))
    imgLine.Name = "ImageLine"
    imgLine.BorderSizePixel = 1
    imgLine.BorderColor3 = Color3.fromRGB(60, 60, 72)
    imgLine.Parent = root

    local pathBox = self:create("TextBox", imgLine, 10, 6, 300, 22, nil)
    pathBox.Name = "ImagePathBox"
    pathBox.PlaceholderText = "image path..."
    pathBox.Font = Enum.Font.Code
    pathBox.TextSize = 12
    pathBox.TextColor3 = Color3.fromRGB(220, 220, 240)
    pathBox.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    pathBox.Parent = imgLine

    local chooseBtn = self:create("TextButton", imgLine, 318, 6, 60, 22, Color3.fromRGB(70, 70, 90))
    chooseBtn.Name = "AttachBtn"
    chooseBtn.Text = "Choose"
    chooseBtn.Font = Enum.Font.GothamBold
    chooseBtn.TextSize = 12
    chooseBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
    chooseBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    chooseBtn.Activated:Connect(function()
        self:renderImageAttach()
    end)
    chooseBtn.Parent = imgLine

    self.imagePathBox = pathBox
    self.imageAttachBtn = chooseBtn
    self.imgLine = imgLine

    self.status = self:create("TextLabel", root, 12, 598, 456, 18, nil)
    self.status.Name = "StatusLabel"
    self.status.Text = ""
    self.status.Font = Enum.Font.Gotham
    self.status.TextSize = 10
    self.status.TextColor3 = Color3.fromRGB(120, 120, 140)
    self.status.BackgroundTransparency = 1

    self.list = scroll
end

function UniversalChat:sendFromInput()
    local text = self.input.Text
    if #text > 0 then
        self:send(text)
        self.input.Text = ""
    end
end

function UniversalChat:send(text)
    if type(text) ~= "string" or #text == 0 then
        return nil, "empty"
    end
    local sender = self.lp
    local payload = "M\0" .. (sender.Name or "") .. "\0" .. (sender.DisplayName or "") .. "\0" .. tostring(os.time()) .. "\0" .. text
    local ok = self.transport:send("U", payload, true)
    if not ok then
        return nil, "send_failed"
    end
    self:appendText(text, sender.Name or "", sender.DisplayName or "", os.time())
    return true
end

function UniversalChat:sendImage(spec)
    if not spec or type(spec) ~= "table" then
        return nil, "bad_spec"
    end
    local sender = self.lp
    local payload = "I\0" .. (sender.Name or "") .. "\0" .. (sender.DisplayName or "") .. "\0" .. tostring(os.time()) .. "\0" .. self.specToSerialized(spec)
    local ok = self.transport:send("U", payload, true)
    if not ok then
        return nil, "send_failed"
    end
    self:showImage(spec, sender.Name or "", sender.DisplayName or "", os.time())
    return true
end

function UniversalChat:attach(path)
    local ok, src = pcall(isfile, path)
    if not ok or not src then
        self.status.Text = "file not found: " .. path
        return nil, "isfile_failed"
    end
    local ok2, src2 = pcall(readfile, path)
    if not ok2 or type(src2) ~= "string" or #src2 == 0 then
        self.status.Text = "readfile failed: " .. path
        return nil, "readfile_failed"
    end
    local loader = loadstring(src2)
    if not loader then
        self.status.Text = "bad luau: " .. path
        return nil, "compile_failed"
    end
    local ok3, spec = pcall(loader)
    if not ok3 or type(spec) ~= "table" then
        self.status.Text = "bad spec: " .. path
        return nil, "bad_spec"
    end
    local sender = self.lp
    self:sendImage(spec)
    self.status.Text = "sent image " .. spec.width .. "x" .. spec.height
    return true
end

function UniversalChat:appendText(text, name, display, time)
    local f = self:create("Frame", self.list, 8, 0, self.list.AbsoluteSize.X - 16, 0, Color3.fromRGB(34, 34, 42))
    f.Name = "Msg_" .. tostring(os.clock())
    f.BorderColor3 = Color3.fromRGB(60, 60, 72)
    f.BorderSizePixel = 1
    f.Parent = self.list
    self.order = self.order + 1
    f.LayoutOrder = self.order

    local body = self:create("TextLabel", f, 8, 6, self.list.AbsoluteSize.X - 30, 0, nil)
    body.Text = "(" .. (display or name or "?") .. ") " .. (name or "?") .. " - " .. os.date("%H:%M", time or os.time()) .. "\n" .. text
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextScaled = false
    body.TextWrapped = false
    body.RichText = true
    body.Font = Enum.Font.Code
    body.TextSize = 12
    body.TextColor3 = Color3.fromRGB(220, 220, 240)
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Parent = f

    local nlines = 1
    for _ in string.gmatch((text or ""), "\n") do
        nlines = nlines + 1
    end
    local bh = body.TextSize * nlines
    body.Size = UDim2.new(1, 0, 0, bh)
    f.Size = UDim2.new(1, 0, 0, bh + 12)
    self:scrollToBottom()
end

function UniversalChat:showImage(spec, name, display, time)
    if type(spec) ~= "table" or type(spec.strips) ~= "table" then
        return nil, "bad_spec"
    end
    local Viewer = loadM("VIEWER_SRC", "HiddenChannelProject/MICUP-TTS/image_viewer.luau")
    if not Viewer then
        return nil, "missing_viewer"
    end
    local viewerInstance = Viewer.new({
        width = spec.width or 0,
        height = spec.height or 0,
        strip = spec.strip or 8,
        palette = spec.palette or {},
        forceWhiteBg = true,
    })
    local okSet, errSet = pcall(UniversalChat.setViewer, self, viewerInstance, spec)
    if not okSet then
        return nil, errSet
    end

    local f = self:create("Frame", self.list, 8, 0, self.list.AbsoluteSize.X - 16, 0, Color3.fromRGB(34, 34, 42))
    f.Name = "MsgImage_" .. tostring(os.clock())
    f.BorderColor3 = Color3.fromRGB(60, 60, 72)
    f.BorderSizePixel = 1
    f.Parent = self.list
    self.order = self.order + 1
    f.LayoutOrder = self.order

    local title = self:create("TextLabel", f, 8, 6, 300, 16, nil)
    title.Text = "[image] " .. (display or name or "?") .. " - " .. os.date("%H:%M", time or os.time())
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(160, 160, 180)
    title.BackgroundTransparency = 1
    title.Parent = f

    local vframe = viewerInstance.frame
    local viewer = self:create("Frame", f, 8, 22, vframe.Size.X.Offset, vframe.Size.Y.Offset, Color3.fromRGB(0, 0, 0))
    viewer.BorderSizePixel = 0
    viewer.Parent = f
    vframe.Parent = viewer

    f.Size = UDim2.new(1, 0, 0, viewer.AbsoluteSize.Y + 10)
    self.viewer = viewerInstance
    self:scrollToBottom()
    return true
end

function UniversalChat:setViewer(viewerInstance, spec)
    local frame = viewerInstance and viewerInstance.frame
    if not frame then
        return false, "no_viewer_frame"
    end
    viewerInstance:reset()
    for i = 1, #spec.strips do
        viewerInstance:renderStrip(i - 1, spec.strips[i])
    end
    return true
end

function UniversalChat:readImage(path)
    local p = path or ""
    local ok, src = pcall(isfile, p)
    if not ok or not src then
        return nil, "isfile_failed: " .. p
    end
    local ok2, src2 = pcall(readfile, p)
    if not ok2 or type(src2) ~= "string" or #src2 == 0 then
        return nil, "readfile_failed: " .. p
    end
    local loader = loadstring(src2)
    if not loader then
        return nil, "compile_failed: " .. p
    end
    local ok3, spec = pcall(loader)
    if not ok3 or type(spec) ~= "table" or type(spec.strips) ~= "table" then
        return nil, "bad_spec: " .. p
    end
    return spec
end

function UniversalChat:renderImageAttach()
    local path = (self.imagePathBox and self.imagePathBox.Text or "")
    local spec, err = self:readImage(path)
    if not spec then
        self.status.Text = err
        return nil, "attach_failed"
    end
    if self.imagePathBox then
        self.imagePathBox.Text = ""
    end
    self.status.Text = "selected image: " .. tostring(spec.width or 0) .. "x" .. tostring(spec.height or 0)
    return self:sendImage(spec)
end

function UniversalChat:onMessage(uid, kind, data)
    if kind ~= "U" then
        return
    end
    local sender = self.players:GetPlayerByUserId(uid)
    if not sender then
        return
    end
    local msg = self:parsePayload(data)
    if not msg then
        return
    end
    if msg.kind == "text" and type(msg.text) == "string" and #msg.text > 0 then
        self:appendText(msg.text, msg.name, msg.display, msg.time or os.time())
    elseif msg.kind == "image" and msg.spec then
        self:showImage(msg.spec, msg.name, msg.display, msg.time or os.time())
    end
end

function UniversalChat:parsePayload(payload)
    local a, b, c, d = string.match(payload, "^M\0(.-)\0(.-)\0(%d+)\0(.*)$")
    if a then
        return { kind = "text", name = a, display = b, time = tonumber(c), text = d }
    end
    local a2, b2, c2, d2 = string.match(payload, "^I\0(.-)\0(.-)\0(%d+)\0(.*)$")
    if a2 then
        return { kind = "image", name = a2, display = b2, time = tonumber(c2), spec = self.specFromSerialized(d2) }
    end
    return nil
end

function UniversalChat:specToSerialized(spec)
    if not spec or type(spec) ~= "table" then
        return ""
    end
    local parts = {
        tostring(spec.width or 0),
        tostring(spec.height or 0),
        tostring(spec.strip or 0),
        tostring(#spec.palette or 0),
    }
    for _, c in ipairs(spec.palette or {}) do
        parts[#parts + 1] = string.gsub(tostring(c or ""), "#", "")
    end
    local strips = {}
    for _, s in ipairs(spec.strips or {}) do
        strips[#strips + 1] = tostring(s)
    end
    return table.concat(parts, "\0") .. "\0" .. table.concat(strips, "|")
end

function UniversalChat:specFromSerialized(payload)
    if type(payload) ~= "string" then
        return nil
    end
    local parts = {}
    local i = 1
    while true do
        local p = string.find(payload, "\0", i, true)
        if not p then
            parts[#parts + 1] = string.sub(payload, i)
            break
        end
        parts[#parts + 1] = string.sub(payload, i, p - 1)
        i = p + 1
    end
    if #parts < 4 then
        return nil
    end
    local width = tonumber(parts[1] or "0")
    local height = tonumber(parts[2] or "0")
    local strip = tonumber(parts[3] or "0")
    local palN = tonumber(parts[4] or "0")
    local palette = {}
    for j = 1, palN do
        palette[j] = "#" .. (parts[4 + j] or "000000")
    end
    local rest = parts[4 + palN + 1] or ""
    local strips = {}
    for piece in string.gmatch(rest, "[^|]+") do
        strips[#strips + 1] = piece
    end
    return { width = width, height = height, strip = strip, palette = palette, strips = strips }
end

function UniversalChat:scrollToBottom()
    if not self.list then
        return
    end
    local h = 0
    for _, c in ipairs(self.list:GetChildren()) do
        if c and (c.Name:sub(1, 4) == "Msg_" or c.Name:sub(1, 8) == "MsgImage_") then
            h = h + (c.AbsoluteSize.Y or 0)
        end
    end
    self.list.CanvasPosition = Vector2.new(0, h + 800)
end

return UniversalChat
