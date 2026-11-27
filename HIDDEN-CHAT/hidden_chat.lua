--!nocheck
local HiddenChat = {}
HiddenChat.__index = HiddenChat

local function loadM(envKey, path)
    local ok, src = pcall(function()
        return getgenv()[envKey]
    end)
    if not ok or type(src) ~= "string" or #src == 0 then
        src = nil
    end
    if src == nil and type(game.HttpGet) == "function" then
        local okGet, res = pcall(function()
            return game:HttpGet("http://127.0.0.1:8767/" .. path, false)
        end)
        if okGet and type(res) == "string" and #res > 0 then
            src = res
        end
    end
    if src == nil then
        return nil
    end
    local loader = loadstring(src)
    if not loader then
        return nil
    end
    local okRun, mod = pcall(loader)
    return okRun and mod or nil
end

local COLORS = {
    "#da8541", "#02b857", "#e8bac8", "#d7c59a", "#f5cd30", "#fd2943",
    "#5b9bd5", "#c678dd", "#61afef", "#98c379", "#e5c07b", "#56b6c2",
}

local function colorFor(name)
    local h = 0
    for i = 1, #name do
        h = (h * 31 + string.byte(name, i)) % 1000003
    end
    return COLORS[(h % #COLORS) + 1]
end

function HiddenChat.new(opts)
    opts = opts or {}
    local self = setmetatable({}, HiddenChat)
    self.ws = opts.ws
    self.cbOnClick = opts.onPlayerClick
    self.channel = opts.channel or "TTS"
    self.templates = {}
    self.count = 0
    self.root = nil
    self.scrollView = nil
    self.nativeScroll = nil
    self.tab = nil
    self.anim = opts.anim
    self.animConn = nil
    self.lastSource = {}
    self.seen = {}
    self.lastText = {}
    if self.anim then
        local ok, conn = pcall(function() return self.anim:connect() end)
        if ok and conn then
            self.animConn = conn
            conn.OnMessage:Connect(function(player, text)
                if player ~= self.lp then
                    self:onMessage(text, "anim", player)
                end
            end)
        end
    end
    self:findUI()
    self:setupChannel()
    self:attachButton()
    if self.ws then
        self.ws:listen("M", function(text)
            self:onMessage(text, "ws")
        end)
        self.ws:listen("I", function(text)
            self:onImage(text)
        end)
        self.ws:listen("R", function(text)
            self:onImageUrl(text)
        end)
        self.ws.onZip = function(id, data)
            if tostring(id):sub(1, 4) == "img_" then
                self:onImage(tostring(id):sub(5) .. "\0" .. data)
            end
        end
    end
    return self
end

function HiddenChat:attachButton()
    if self._attachBound then
        return
    end
    self._attachBound = true
    local ok, row = pcall(function()
        return self.root:FindFirstChild("appLayout"):FindFirstChild("chatInputRow")
    end)
    if not ok or not row then
        return
    end
    pcall(function() row.ClipsDescendants = false end)
    if group then
        for _, c in ipairs(group:GetDescendants()) do
            if c:IsA("ImageButton") and (c.Name:lower():find("mic") or c.Name:lower():find("voice")) then
                pcall(function() c.Visible = false end)
            end
        end
    end
    local group = row:FindFirstChild("fillArea")
    group = group and group:FindFirstChild("chatInputBar")
    group = group and group:FindFirstChild("ChatInputBarV2")
    group = group and group:FindFirstChild("Container")
    group = group and group:FindFirstChild("InputGroup")

    for _, name in ipairs({ "HiddenChatAttach", "HiddenChatInput", "HiddenChatSend" }) do
        local found = {}
        for _, c in ipairs(row:GetChildren()) do
            if c.Name == name then found[#found + 1] = c end
        end
        for i = 2, #found do
            found[i]:Destroy()
        end
    end
    local btn = row:FindFirstChild("HiddenChatAttach")
    if not btn then
        btn = Instance.new("TextButton")
        btn.Name = "HiddenChatAttach"
        btn.Size = UDim2.fromOffset(26, 24)
        btn.Position = UDim2.new(1, -30, 0, 6)
        btn.Text = "📎"
        btn.TextColor3 = Color3.fromRGB(234, 234, 240)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = row
    end
    if group then
        local function follow()
            btn.BackgroundTransparency = group.BackgroundTransparency
            btn.BackgroundColor3 = group.BackgroundColor3
            btn.Position = UDim2.new(1, -68, 0, 6)
        end
        pcall(follow)
        group:GetPropertyChangedSignal("BackgroundTransparency"):Connect(follow)
        group:GetPropertyChangedSignal("BackgroundColor3"):Connect(follow)
        row:GetPropertyChangedSignal("AbsoluteSize"):Connect(follow)
    else
        btn.BackgroundTransparency = 0.5
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
    end
    btn.Visible = false

    local box = row:FindFirstChild("HiddenChatInput")
    if not box then
        box = Instance.new("TextBox")
        box.Name = "HiddenChatInput"
        box.Size = UDim2.new(1, -100, 0, 32)
        box.Position = UDim2.fromOffset(8, 4)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
        box.BackgroundTransparency = 0.2
        box.BorderSizePixel = 0
        box.Text = ""
        box.PlaceholderText = "Hidden message..."
        box.Font = Enum.Font.Gotham
        box.TextSize = 13
        box.TextColor3 = Color3.fromRGB(235, 235, 240)
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.TextWrapped = true
        box.ClipsDescendants = true
        box.Visible = false
        box.Parent = row
        box.Focused:Connect(function()
            pcall(function()
                box.TextTransparency = 0
                btn.TextTransparency = 0
                sendBtn.TextTransparency = 0
            end)
        end)
        box.FocusLost:Connect(function(enter)
            pcall(function()
                local native = nil
                if group then
                    for _, c in ipairs(group:GetDescendants()) do
                        if c:IsA("TextLabel") then native = c break end
                    end
                end
                if native then
                    box.TextTransparency = native.TextTransparency
                    btn.TextTransparency = native.TextTransparency
                    sendBtn.TextTransparency = native.TextTransparency
                end
            end)
            local text = box.Text
            if enter and text ~= "" then
                box.Text = ""
                self:send(text)
            end
        end)
    end
    local function followText(label, nativeLabel)
        if not label or not nativeLabel then return end
        local function apply()
            pcall(function()
                label.TextTransparency = nativeLabel.TextTransparency
                label.TextStrokeTransparency = nativeLabel.TextStrokeTransparency
            end)
        end
        apply()
        nativeLabel:GetPropertyChangedSignal("TextTransparency"):Connect(apply)
        nativeLabel:GetPropertyChangedSignal("TextStrokeTransparency"):Connect(apply)
    end    local nativeText = nil
    if group then
        for _, c in ipairs(group:GetDescendants()) do
            if c:IsA("TextLabel") and nativeText == nil then nativeText = c end
        end
    end
    followText(btn, nativeText)
    followText(box, nativeText)
    followText(sendBtn, nativeText)
    if group then
        local native = nil
        for _, c in ipairs(group:GetDescendants()) do
            if c:IsA("TextBox") then native = c break end
        end
        local function followBox()
            box.BackgroundTransparency = group.BackgroundTransparency
            box.BackgroundColor3 = group.BackgroundColor3
            if native then
                pcall(function()
                    box.Font = native.Font
                    box.FontFace = native.FontFace
                    box.TextSize = native.TextSize
                    box.TextColor3 = native.TextColor3
                    box.PlaceholderColor3 = native.TextColor3
                    box.TextXAlignment = native.TextXAlignment
                    box.TextYAlignment = native.TextYAlignment
                end)
            end
        end
        pcall(followBox)
        group:GetPropertyChangedSignal("BackgroundTransparency"):Connect(followBox)
        group:GetPropertyChangedSignal("BackgroundColor3"):Connect(followBox)
    end
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if #box.Text > 120 then
            box.Text = box.Text:sub(1, 120)
        end
    end)
    box.TextWrapped = true
    box.ClipsDescendants = true
    self.hiddenInput = box

    local sendBtn = row:FindFirstChild("HiddenChatSend")
    if not sendBtn then
        sendBtn = Instance.new("TextButton")
        sendBtn.Name = "HiddenChatSend"
        sendBtn.Size = UDim2.fromOffset(40, 24)
        sendBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        sendBtn.Text = "Send"
        sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        sendBtn.Font = Enum.Font.GothamBold
        sendBtn.TextSize = 11
        sendBtn.BorderSizePixel = 0
        sendBtn.Visible = false
        sendBtn.Parent = row
    end
    sendBtn.AnchorPoint = Vector2.new(1, 0)
    sendBtn.Size = UDim2.fromOffset(40, 24)
    sendBtn.Position = UDim2.new(1, -90, 0, 6)
    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        sendBtn.Position = UDim2.new(1, -90, 0, 6)
    end)
    sendBtn.Activated:Connect(function()
        local text = box.Text
        if text ~= "" then
            box.Text = ""
            self:send(text)
        end
    end)
    if group then
        local function followSend()
            sendBtn.BackgroundTransparency = group.BackgroundTransparency
            sendBtn.BackgroundColor3 = group.BackgroundColor3
        end
        pcall(followSend)
        group:GetPropertyChangedSignal("BackgroundTransparency"):Connect(followSend)
        group:GetPropertyChangedSignal("BackgroundColor3"):Connect(followSend)
    end

    self.hiddenSend = sendBtn

    btn.Activated:Connect(function()
        if self.dialog then
            local alive = self.dialog.gui ~= nil
            self.dialog:close()
            self.dialog = nil
            if alive then
                return
            end
        end
        self:openFileDialog()
    end)
end

function HiddenChat:openFileDialog()
    local F = loadM("FILE_EXPLORER_SRC", "HiddenChannelProject/HIDDEN-CHAT/file_explorer.luau")
    if not F then
        return nil, "explorer_missing"
    end
    if F.active and F.active.gui then
        self.dialog = F.active
        return self.dialog
    end
    if self.dialog and self.dialog.gui then
        self.dialog:close()
    end
    self.dialog = F.OpenFileDialog({ "All", ".luau", ".txt", ".json", ".png" }, function(path)
        self.dialog = nil
        self:attachFile(path)
    end)
    return self.dialog
end

function HiddenChat:attachFile(path)
    if type(path) == "string" and path:sub(1, 4) == "URL:" then
        return self:attachUrl(path:sub(5))
    end
    local ok, src = pcall(readfile, path)
    if not ok or type(src) ~= "string" then
        self:postMessage("System", "read failed: " .. tostring(path))
        return nil, "read_failed"
    end
    local loader = loadstring(src)
    if not loader then
        self:postMessage("System", "compile failed: " .. tostring(path))
        return nil, "compile_failed"
    end
    local ok2, spec = pcall(loader)
    if not ok2 or type(spec) ~= "table" or type(spec.strips) ~= "table" then
        self:postMessage("System", "bad spec: " .. tostring(path))
        return nil, "bad_spec"
    end
    if not self.ws then
        return nil, "no_ws"
    end
    local header = string.format("%d;%d;%d;%d;%s",
        spec.width or 0, spec.height or 0, spec.strip or 8,
        #(spec.palette or {}), table.concat(spec.palette or {}, ","))
    local strips = table.concat(spec.strips or {}, "|")
    local name = game:GetService("Players").LocalPlayer.Name
    local serialized = header .. "\0" .. strips
    self:postMessage(name, "[image zip] " .. tostring(spec.width or 0) .. "x" .. tostring(spec.height or 0))
    return self.ws:sendZip("img_" .. name, serialized)
end

function HiddenChat:attachUrl(url)
    if type(url) ~= "string" or not url:match("^https?://") then
        return nil, "bad_url"
    end
    if not self.ws then
        return nil, "no_ws"
    end
    local name = game:GetService("Players").LocalPlayer.Name
    self:postMessage(name, "[image url] " .. url)
    local frame = self:renderImageUrl(name, url)
    return self.ws:send("R\0" .. name .. "\0" .. url), frame
end

function HiddenChat:onImageUrl(payload)
    local name, url = string.match(payload, "^([^\0]*)\0(.*)$")
    if url then
        self:renderImageUrl(name, url)
    end
end

function HiddenChat:renderImageUrl(name, url)
    local A = cloneref(game:GetService("AssetService"))
    local ok, editable = pcall(function()
        return A:CreateEditableImageFromDownloadAsync(url)
    end)
    if not ok or not editable then
        self:postMessage(name or "System", "[image] download failed")
        return nil
    end
    local frame = Instance.new("Frame")
    frame.Name = "HiddenChatImageUrl"
    frame.Size = UDim2.new(1, 0, 0, 206)
    frame.BackgroundTransparency = 1
    frame.Parent = self.scrollView
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = "[image] " .. tostring(name or "?")
    title.TextColor3 = Color3.fromRGB(160, 160, 180)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    local img = Instance.new("ImageLabel")
    img.Name = "Image"
    local sz = editable.Size
    local scale = math.min(180 / math.max(1, sz.X), 180 / math.max(1, sz.Y))
    img.Size = UDim2.fromOffset(math.max(1, sz.X * scale), math.max(1, sz.Y * scale))
    img.Position = UDim2.fromOffset(8, 20)
    img.BackgroundTransparency = 1
    img.ScaleType = Enum.ScaleType.Fit
    pcall(function() img.ImageContent = Content.fromObject(editable) end)
    img.Parent = frame
    frame.Size = UDim2.new(1, 0, 0, 26 + img.Size.Y.Offset)
    self.scrollView.CanvasPosition = Vector2.new(0, self.scrollView.AbsoluteCanvasSize.Y + 500)
    return frame
end
function HiddenChat:onImage(payload)
    if type(payload) ~= "string" then
        return
    end
    local name, header, stripData = string.match(payload, "^([^\0]*)\0([^\0]*)\0(.*)$")
    if not header then
        return
    end
    local w, h, s, palN, colors = string.match(header, "^(%d+);(%d+);(%d+);(%d+);(.*)$")
    if not w then
        return
    end
    local palette = {}
    for c in string.gmatch(colors or "", "[^,]+") do
        palette[#palette + 1] = c
    end
    local strips = {}
    for piece in string.gmatch(stripData or "", "[^|]+") do
        strips[#strips + 1] = piece
    end
    local Viewer = loadM("VIEWER_SRC", "HiddenChannelProject/MICUP-TTS/image_viewer.luau")
    if not Viewer then
        self:postMessage(name or "System", "[image] viewer missing")
        return
    end
    local frame = Instance.new("Frame")
    frame.Name = "HiddenChatImage"
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundTransparency = 1
    frame.Parent = self.scrollView
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = "[image] " .. tostring(name or "?")
    title.TextColor3 = Color3.fromRGB(160, 160, 180)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    local v = Viewer.new({
        width = tonumber(w), height = tonumber(h), strip = tonumber(s),
        palette = palette, forceWhiteBg = true, parent = frame,
    })
    v.frame.Position = UDim2.fromOffset(8, 20)
    v.frame.Parent = frame
    for i, strip in ipairs(strips) do
        v:renderStrip(i - 1, strip)
    end
    frame.Size = UDim2.new(1, 0, 0, v.frame.AbsoluteSize.Y + 26)
    self.scrollView.CanvasPosition = Vector2.new(0, self.scrollView.AbsoluteCanvasSize.Y + 500)
end

function HiddenChat:findUI()
    local ok, ec = pcall(function()
        return game:GetService("CoreGui"):WaitForChild("ExperienceChat", 5)
    end)
    if not ok or not ec then
        return nil, "experience_chat_missing"
    end
    local ok2, native = pcall(function()
        return ec:WaitForChild("appLayout", 5)
            :WaitForChild("chatWindow", 5)
            :WaitForChild("contentFrame", 5)
            :WaitForChild("scrollingView", 5)
            :WaitForChild("bottomLockedScrollView", 5)
            :WaitForChild("scrollView", 5)
    end)
    if not ok2 or not native then
        return nil, "scroll_view_missing"
    end
    self.root = ec
    self.nativeScroll = native

    local ok3, tts = pcall(function()
        local clone = native:Clone()
        clone.Name = "ttsScrollView"
        clone:ClearAllChildren()
        clone.Visible = false
        clone.Parent = native.Parent
        return clone
    end)
    if not ok3 or not tts then
        return nil, "tts_scroll_failed"
    end
    local list = Instance.new("UIListLayout")
    list.Name = "MessageLayout"
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = tts
    self.listLayout = list
    pcall(function()
        tts.ScrollBarThickness = 6
        tts.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 88)
        tts.ScrollBarImageTransparency = 0.1
    end)
    self.scrollView = tts

    for _, child in ipairs(native:GetChildren()) do
        if child:FindFirstChild("TextMessage") then
            self.templates[#self.templates + 1] = child
        end
    end
    if #self.templates == 0 then
        for _, child in ipairs(native:GetChildren()) do
            if child.ClassName == "Frame" then
                self.templates[#self.templates + 1] = child
            end
        end
    end
    return self
end

function HiddenChat:setupChannel()
    local ok, cc = pcall(function()
        return self.root:FindFirstChild("appLayout")
            :FindFirstChild("channelBar")
            :FindFirstChild("HorizontalBar")
            :FindFirstChild("ContentContainer")
    end)
    if not ok or not cc then
        return
    end
    local base = nil
    for _, child in ipairs(cc:GetChildren()) do
        local tab = child:FindFirstChild("ChannelTab")
        local label = tab and tab:FindFirstChild("TextLabel")
        if label and label.Text == "Global" then
            base = child
            break
        end
    end
    local existing = cc:FindFirstChild("Hidden") or cc:FindFirstChild("TTS")
    if not existing and base then
        local ok2, tab = pcall(function()
            local c = base:Clone()
            c.Name = "Hidden"
            local t = c:FindFirstChild("ChannelTab")
            local label = t and t:FindFirstChild("TextLabel")
            if label then
                label.Text = "Hidden"
                label.RichText = false
            end
            local hl = t and t:FindFirstChild("Highlight")
            if not hl and t then
                hl = Instance.new("Frame")
                hl.Name = "Highlight"
                hl.Size = UDim2.new(1, 0, 0, 2)
                hl.Position = UDim2.new(0, 0, 1, -2)
                hl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                hl.BorderSizePixel = 0
                hl.Visible = false
                hl.Parent = t
            end
            c.Parent = cc
            return c
        end)
        if ok2 and tab then
            existing = tab
        end
    end
    if not existing then
        return
    end
    self.tab = existing
    local own = existing:FindFirstChild("HiddenHighlight")
    if not own then
        own = Instance.new("Frame")
        own.Name = "HiddenHighlight"
        own.Size = UDim2.new(1.02547765, 0, 0, 4)
        own.Position = UDim2.new(0, 0, 1, -4)
        own.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        own.BackgroundTransparency = 0
        own.BorderSizePixel = 0
        own.Visible = false
        own.Parent = existing
    end
    pcall(function()
        own.Size = UDim2.new(1.02547765, 0, 0, 4)
        own.Position = UDim2.new(0, 0, 1, -4)
        own.BackgroundTransparency = 0
    end)
    self.ownHighlight = own
    pcall(function() existing.Name = "Hidden" end)
    local t0 = existing:FindFirstChild("ChannelTab")
    local l0 = t0 and t0:FindFirstChild("TextLabel")
    if l0 and l0.Text ~= "Hidden" then
        l0.Text = "Hidden"
        l0.RichText = false
    end
    local srcDot = cc:FindFirstChild("2")
    srcDot = srcDot and srcDot:FindFirstChild("ChannelTab")
    srcDot = srcDot and srcDot:FindFirstChild("TextLabel")
    srcDot = srcDot and srcDot:FindFirstChild("UnreadDot")
    local srcCorner = srcDot and srcDot:FindFirstChild("UICorner")
    if l0 and not l0:FindFirstChild("UnreadDot") then
        local dot = Instance.new("Frame")
        dot.Name = "UnreadDot"
        dot.Size = UDim2.fromOffset(6, 6)
        dot.Position = UDim2.new(1, -2, 0, 2)
        dot.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        dot.Visible = false
        dot.Parent = l0
        if srcCorner then
            local corner = srcCorner:Clone()
            corner.Parent = dot
        else
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = dot
        end
        self.ownUnread = dot
    end
    local layout = cc:FindFirstChild("UIListLayout") or cc:FindFirstChild("$layout")
    if layout then
        pcall(function() layout.Enabled = false end)
    end
    local function arrange()
        local tabs = {}
        for _, child in ipairs(cc:GetChildren()) do
            if child:IsA("Frame") and child:FindFirstChild("ChannelTab") then
                tabs[#tabs + 1] = child
            end
        end
        local w = cc.AbsoluteSize.X / math.max(1, #tabs)
        for i, tab in ipairs(tabs) do
            pcall(function()
                tab.Position = UDim2.fromOffset((i - 1) * w, 0)
                tab.Size = UDim2.new(0, w - 1, 1, 0)
            end)
        end
    end
    pcall(arrange)
    cc:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
    if not self._ccWatcher then
        self._ccWatcher = cc.ChildAdded:Connect(function(child)
            task.defer(function()
                if not self.tab or not self.tab.Parent then
                    self:setupChannel()
                    self:setChannel(self.channel)
                end
            end)
        end)
    end
    local button = existing:FindFirstChild("ChannelTab")
    local hl = button and button:FindFirstChild("Highlight")
    if button and not hl then
        hl = Instance.new("Frame")
        hl.Name = "Highlight"
        hl.Size = UDim2.new(1, 0, 0, 2)
        hl.Position = UDim2.new(0, 0, 1, -2)
        hl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hl.BorderSizePixel = 0
        hl.Visible = false
        hl.Parent = button
    end
    if button then
        button.Activated:Connect(function()
            self:setChannel("TTS")
        end)
    end
    for _, child in ipairs(cc:GetChildren()) do
        if child ~= existing then
            local b = child:FindFirstChild("ChannelTab")
            if b then
                b.Activated:Connect(function()
                    self:setChannel("Here")
                end)
            end
        end
    end
end

function HiddenChat:setChannel(name)
    if not self.tab or not self.tab.Parent then
        self:setupChannel()
    end
    self.channel = name
    local isTTS = (name == "Hidden") or (name == "TTS")
    if self.scrollView then
        self.scrollView.Visible = isTTS
    end
    if self.nativeScroll then
        self.nativeScroll.Visible = not isTTS
    end
    local cc = self.root and self.root:FindFirstChild("appLayout")
        and self.root.appLayout:FindFirstChild("channelBar")
        and self.root.appLayout.channelBar:FindFirstChild("HorizontalBar")
        and self.root.appLayout.channelBar.HorizontalBar:FindFirstChild("ContentContainer")
    if cc then
        for _, child in ipairs(cc:GetChildren()) do
            local t = child:FindFirstChild("ChannelTab")
            local hl = t and t:FindFirstChild("Highlight")
            if hl then
                hl.Visible = isTTS and (child == self.tab)
            end
        end
    end
    local app = self.root and self.root:FindFirstChild("appLayout")
    local row = app and app:FindFirstChild("chatInputRow")
    local fill = row and row:FindFirstChild("fillArea")
    local bar = fill and fill:FindFirstChild("chatInputBar")
    if bar then
        bar.Visible = not isTTS
    end
    local top = app and app:FindFirstChild("chatWindow")
    top = top and top:FindFirstChild("contentFrame")
    top = top and top:FindFirstChild("TopBanner")
    local dots = top and top:FindFirstChild("DotMenu")
    if dots then
        dots.Visible = not isTTS
    end
    if row then
        local fly = row:FindFirstChild("presetFlyOutWrapper")
        if fly then
            pcall(function() fly.Visible = not isTTS end)
        end
    end
    for _, c in ipairs(game:GetService("CoreGui"):GetChildren()) do
        local n = c.Name:lower()
        if n:find("quickword") or n:find("quick_word") or n:find("presetflyout") then
            pcall(function() c.Visible = not isTTS end)
        end
    end
    local function fade(target)
        local elements = { self.hiddenInput, self.hiddenSend }
        local attach = row and row:FindFirstChild("HiddenChatAttach")
        if attach then elements[#elements + 1] = attach end
        for _, e in ipairs(elements) do
            if e then
                local tween = game:GetService("TweenService")
                pcall(function()
                    tween:Create(e, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = target,
                    }):Play()
                end)
            end
        end
    end
    if isTTS then
        fade(0)
    else
        fade(1)
    end
    if self.hiddenInput then
        self.hiddenInput.Visible = isTTS
        if isTTS then
            task.defer(function() self.hiddenInput:CaptureFocus() end)
        end
    end
    if self.hiddenSend then
        self.hiddenSend.Visible = isTTS
    end
    local attach = row and row:FindFirstChild("HiddenChatAttach")
    if attach then
        attach.Parent = row
        attach.Visible = isTTS
        pcall(function()
            attach.Position = UDim2.new(1, -68, 0, 6)
        end)
    end
    if self.hiddenSend and row then
        self.hiddenSend.Parent = row
        self.hiddenSend.Position = UDim2.new(1, -90, 0, 6)
    end
    if self.hiddenInput and row then
        self.hiddenInput.Parent = row
    end
    if self.ownHighlight then
        self.ownHighlight.Visible = isTTS
        pcall(function()
            self.ownHighlight.Size = UDim2.new(1.02547765, 0, 0, 4)
            self.ownHighlight.Position = UDim2.new(0, 0, 1, -4)
            self.ownHighlight.BackgroundTransparency = 0
        end)
    end
    task.defer(function()
        if attach and attach.Parent then
            local current = self.root and self.root:FindFirstChild("appLayout")
            current = current and current:FindFirstChild("chatInputRow")
            if current and current ~= row then
                attach.Parent = current
                if self.hiddenSend then self.hiddenSend.Parent = current end
                if self.hiddenInput then self.hiddenInput.Parent = current end
            end
        end
    end)
end

function HiddenChat:postMessage(sender, text, color)
    if not self.scrollView or #self.templates == 0 then
        return nil, "no_template"
    end
    local tmpl = self.templates[(self.count % #self.templates) + 1]
    local ok, clone = pcall(function()
        return tmpl:Clone()
    end)
    if not ok or not clone then
        return nil, "clone_failed"
    end
    self.count = self.count + 1
    clone.Name = tostring(sender) .. "-" .. tostring(self.count)
    clone.LayoutOrder = self.count

    local tm = clone:FindFirstChild("TextMessage")
    local prefix = tm and tm:FindFirstChild("PrefixText")
    local body = tm and tm:FindFirstChild("BodyText")
    local button = tm and tm:FindFirstChild("TextMessageButton")

    local line = '<font color="' .. (color or colorFor(sender)) .. '">' .. tostring(sender) .. ':</font> ' .. tostring(text)
    if body then
        body.RichText = true
        body.Font = Enum.Font.Gotham
        body.TextSize = 14
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextColor3 = Color3.fromRGB(235, 235, 240)
        body.BackgroundTransparency = 1
        body.LineHeight = 1.2
        body.TextStrokeTransparency = 0.7
        body.Text = line
        body.Position = UDim2.new(0, 6, 0, 0)
    end
    if prefix then
        prefix.Visible = false
    end
    if button and self.cbOnClick then
        button.Activated:Connect(function()
            self.cbOnClick(sender)
        end)
    end
    local full = tostring(sender) .. ": " .. tostring(text)
    local wrapped = math.max(1, math.ceil((#full * 8) / math.max(1, (self.scrollView and self.scrollView.AbsoluteSize.X or 260) - 16)))
    clone.Size = UDim2.new(1, 0, 0, math.max(28, 18 * wrapped + 10))
    clone.Parent = self.scrollView
    if body then
        body.Size = UDim2.new(1, -12, 0, math.max(18, 18 * wrapped))
    end
    self.scrollView.CanvasPosition = Vector2.new(0, self.scrollView.AbsoluteCanvasSize.Y + 500)
    return true, clone
end
function HiddenChat:onMessage(payload, source, player)
    if type(payload) ~= "string" then
        return
    end
    local sender, text
    if payload:sub(1, 2) == "1|" then
        sender, text = string.match(payload, "^1%|([^|]+)%|(.*)$")
    else
        sender, text = string.match(payload, "^([^\0]+)\0(.*)$")
    end
    if not sender then
        sender, text = "System", payload
    end
    source = source or "ws"
    local key = sender .. "\0" .. text
    local now = os.clock()
    if self.seen[key] and now - self.seen[key] < 1.5 then
        return
    end
    self.seen[key] = now
    if player and player.Name then
        sender = player.Name
    end
    self.lastSource[sender] = source
    self:postMessage(sender, text)
end

function HiddenChat:reply(text)
    local name = game:GetService("Players").LocalPlayer.Name
    local source = self.lastSource[name] or (self.ws and "ws") or (self.anim and "anim") or "ws"
    return self:send(text, source)
end

function HiddenChat:send(text, preferred)
    local name = game:GetService("Players").LocalPlayer.Name
    self:postMessage(name, tostring(text))
    local order = {}
    if preferred == "anim" then
        order = { "anim", "ws" }
    else
        order = { "ws", "anim" }
    end
    for _, channel in ipairs(order) do
        if channel == "ws" and self.ws then
            local ok = self.ws:send("M\0" .. name .. "\0" .. tostring(text))
            if ok then
                return ok
            end
        elseif channel == "anim" and self.anim then
            return self.anim:sendAsync(tostring(text))
        end
    end
    return nil, "no_channel"
end

function HiddenChat:clear()
    if not self.scrollView then
        return
    end
    for _, child in ipairs(self.scrollView:GetChildren()) do
        if child:FindFirstChild("TextMessage") then
            child:Destroy()
        end
    end
end

return HiddenChat
