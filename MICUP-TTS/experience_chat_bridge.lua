--!nocheck
local ExperienceChatBridge = {}
ExperienceChatBridge.__index = ExperienceChatBridge

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

function ExperienceChatBridge.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ExperienceChatBridge)
    self.ws = opts.ws
    self.cbOnClick = opts.onPlayerClick
    self.templates = {}
    self.count = 0
    self.root = nil
    self.scrollView = nil
    self:findUI()
    if self.ws then
        self.ws:listen("M", function(text)
            self:onMessage(text)
        end)
    end
    return self
end

function ExperienceChatBridge:findUI()
    local ok, ec = pcall(function()
        return game:GetService("CoreGui"):WaitForChild("ExperienceChat", 5)
    end)
    if not ok or not ec then
        return nil, "experience_chat_missing"
    end
    local ok2, sv = pcall(function()
        return ec:WaitForChild("appLayout", 5)
            :WaitForChild("chatWindow", 5)
            :WaitForChild("contentFrame", 5)
            :WaitForChild("scrollingView", 5)
            :WaitForChild("bottomLockedScrollView", 5)
            :WaitForChild("scrollView", 5)
    end)
    if not ok2 or not sv then
        return nil, "scroll_view_missing"
    end
    self.root = ec
    self.scrollView = sv
    for _, child in ipairs(sv:GetChildren()) do
        local tm = child:FindFirstChild("TextMessage")
        if tm then
            self.templates[#self.templates + 1] = child
        end
    end
    return self
end

function ExperienceChatBridge:postMessage(sender, text, color)
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
    local tm = clone:FindFirstChild("TextMessage")
    local prefix = tm and tm:FindFirstChild("PrefixText")
    local body = tm and tm:FindFirstChild("BodyText")
    local button = tm and tm:FindFirstChild("TextMessageButton")
    if prefix then
        prefix.RichText = true
        prefix.Text = '<font color="' .. (color or colorFor(sender)) .. '">' .. tostring(sender) .. ":</font>"
    end
    if body then
        body.RichText = true
        body.Text = tostring(text)
    end
    if button and self.cbOnClick then
        button.Activated:Connect(function()
            self.cbOnClick(sender)
        end)
    end
    clone.Parent = self.scrollView
    self.scrollView.CanvasPosition = Vector2.new(0, self.scrollView.AbsoluteCanvasSize.Y + 500)
    return true, clone
end

function ExperienceChatBridge:onMessage(payload)
    if type(payload) ~= "string" then
        return
    end
    local sender, text = string.match(payload, "^([^\0]+)\0(.*)$")
    if not sender then
        sender, text = "System", payload
    end
    self:postMessage(sender, text)
end

function ExperienceChatBridge:send(text)
    if not self.ws then
        return nil, "no_ws"
    end
    local name = game:GetService("Players").LocalPlayer.Name
    return self.ws:send("M\0" .. name .. "\0" .. tostring(text))
end

function ExperienceChatBridge:clear()
    if not self.scrollView then
        return
    end
    for _, child in ipairs(self.scrollView:GetChildren()) do
        if child:FindFirstChild("TextMessage") then
            child:Destroy()
        end
    end
end

return ExperienceChatBridge
