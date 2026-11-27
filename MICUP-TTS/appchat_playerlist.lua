--!nocheck
local AppChatPlayerList = {}
AppChatPlayerList.__index = AppChatPlayerList

local function loadM(envKey, path)
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
    if not loader then
        return nil
    end
    local okRun, mod = pcall(loader)
    return okRun and mod or nil
end

function AppChatPlayerList.new(opts)
    opts = opts or {}
    local self = setmetatable({}, AppChatPlayerList)
    self.players = game:GetService("Players")
    self.lp = self.players.LocalPlayer
    self.transport = opts.transport
    self.cbOnJoin = nil
    self.cbOnLeave = nil
    self.entries = {}
    if self.transport == nil then
        return nil, "transport_missing"
    end
    self.transport.spy.onMessage = function(uid, kind, data)
        if kind == "U" and data then
            local ok, msg = pcall(function()
                return AppChatPlayerList:parsePayload(data)
            end)
            if ok and msg then
                self:onMessage(uid, msg)
            end
        end
    end
    self.transport:start()
    self:buildGui()
    self.players.PlayerAdded:Connect(function(player)
        self:onJoin(player)
    end)
    self.players.PlayerRemoving:Connect(function(player)
        self:onLeave(player)
    end)
    return self
end

function AppChatPlayerList:onJoin(player)
    if not player or player.UserId == self.lp.UserId then
        return
    end
    local entry = self:entry(player)
    entry.name = player.Name
    entry.display = player.DisplayName
    entry.time = os.time()
    self.entries[#self.entries + 1] = entry
    self:appendRow(entry)
end

function AppChatPlayerList:onLeave(player)
    for i, e in ipairs(self.entries) do
        if e.uid == player.UserId then
            table.remove(self.entries, i)
            local row = e.row
            if row then
                row:Destroy()
            end
            break
        end
    end
end

function AppChatPlayerList:entry(player)
    for _, e in ipairs(self.entries) do
        if e.uid == player.UserId then
            return e
        end
    end
    local e = { uid = player.UserId, name = player.Name, display = player.DisplayName, time = os.time(), stats = {} }
    self.entries[#self.entries + 1] = e
    return e
end

function AppChatPlayerList:stats()
    local ok, ls = pcall(function() return workspace:FindFirstChild("leaderstats") end)
    if not ok or not ls then
        return nil
    end
    local out = {}
    for _, c in ipairs(ls:GetChildren()) do
        out[c.Name] = c.Value
    end
    return out
end

function AppChatPlayerList:buildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlayerList"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui").RobloxGui

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.Position = UDim2.new(1, -280, 0.3, 0)
    frame.Size = UDim2.fromOffset(280, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    frame.BorderSizePixel = 1
    frame.BorderColor3 = Color3.fromRGB(50, 50, 56)
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Text = "Players (" .. tostring(#self.entries) .. ")"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(220, 220, 240)
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 8)
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Parent = frame

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.Position = UDim2.fromOffset(10, 34)
    list.Size = UDim2.fromOffset(260, 0)
    list.Size = UDim2.fromOffset(260, 200)
    list.BackgroundTransparency = 1
    list.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    self.gui = gui
    self.frame = frame
    self.list = list
end

function AppChatPlayerList:appendRow(entry)
    local row = Instance.new("TextLabel")
    row.Name = "Player_" .. tostring(entry.uid)
    row.Position = UDim2.fromOffset(0, 0)
    row.Size = UDim2.fromOffset(260, 20)
    row.Text = (entry.display or entry.name or "?") .. " - " .. os.date("%H:%M", entry.time)
    row.Font = Enum.Font.Gotham
    row.TextSize = 11
    row.TextColor3 = Color3.fromRGB(200, 200, 220)
    row.BackgroundTransparency = 0.9
    row.Parent = self.list
    entry.row = row
    entry.stats = self:stats() or entry.stats
    local w = row:GetTextBounds().X
    if w > 230 then
        row.TextSize = math.max(8, math.floor(230 / #row.Text * row.TextSize))
    end
end

function AppChatPlayerList:parsePayload(payload)
    if type(payload) ~= "string" then
        return nil
    end
    local a = string.match(payload, "^U\0(.-)\0(.-)\0(%d+)")
    if a then
        return { sender = a }
    end
    local b = string.match(payload, "^UI\0(.-)\0(.-)\0(%d+)")
    if b then
        return { sender = b }
    end
    return nil
end

function AppChatPlayerList:onMessage(uid, msg)
    if not msg or type(msg.sender) ~= "string" then
        return
    end
end

return AppChatPlayerList
