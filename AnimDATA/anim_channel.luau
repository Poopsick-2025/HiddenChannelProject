local AnimChannel = {}
AnimChannel.__index = AnimChannel

local CLEAR = "222222"
local SUBMIT = "333333"

local function encode(text)
    local bits = ""
    for _, code in utf8.codes(tostring(text)) do
        local n = code
        local cur = ""
        while n > 0 do
            cur = tostring(n % 2) .. cur
            n = math.modf(n / 2)
        end
        bits = bits .. string.format("%08d", cur)
    end
    return bits
end

local function decode(bits)
    local out = ""
    for i = 1, #bits - 7, 8 do
        local byte = tonumber(bits:sub(i, i + 7), 2)
        if byte then
            out = out .. utf8.char(byte)
        end
    end
    return out
end

local function split8(bits)
    local out = {}
    local i = 1
    while i <= #bits do
        local part = bits:sub(i, i + 7)
        if #part < 8 then
            part = string.rep("0", 8 - #part) .. part
        end
        out[#out + 1] = part
        i = i + 8
    end
    return out
end

local function packPairs(parts)
    local out = {}
    for _, p in ipairs(parts) do
        out[#out + 1] = { p:sub(1, 4), p:sub(5, 8) }
    end
    return out
end

function AnimChannel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, AnimChannel)
    self.delay = opts.delay or 0.2
    self.players = game:GetService("Players")
    self.lp = self.players.LocalPlayer
    self.id = 10
    self.connected = false
    self.byteCache = {}
    self.lastPacket = {}
    self.onMessage = opts.onMessage
    self.OnMessage = opts.onMessage
    self.OnMessageFinished = opts.onMessageFinished
    self.OnClose = opts.onClose
    self.bindableMessage = Instance.new("BindableEvent")
    self.bindableFinished = Instance.new("BindableEvent")
    self.bindableClose = Instance.new("BindableEvent")
    self.heartbeat = nil
    return self
end

function AnimChannel:setDelay(seconds)
    self.delay = seconds
end

function AnimChannel:charParts(player)
    local character = player.Character
    if not character then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end
    return humanoid, character:FindFirstChild("Animate")
end

function AnimChannel:speed(humanoid)
    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        return track.Speed
    end
    return nil
end

function AnimChannel:setSpeed(humanoid, value)
    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        track:AdjustSpeed(value)
    end
end

function AnimChannel:nextId()
    if self.id >= 99 then
        self.id = 10
    else
        self.id = self.id + 1
    end
    return tostring(self.id)
end

function AnimChannel:sendPacket(humanoid, packet)
    self:setSpeed(humanoid, tonumber(packet))
end

function AnimChannel:stream(text)
    local humanoid, animate = self:charParts(self.lp)
    if not humanoid then
        return nil, "no_humanoid"
    end
    local parts = packPairs(split8(encode(text)))
    local original = self:speed(humanoid) or 1
    if animate then
        animate.Enabled = false
    end
    task.wait(self.delay)
    self:setSpeed(humanoid, 0)
    task.wait()
    self:sendPacket(humanoid, CLEAR)
    task.wait(self.delay)
    for _, pair in ipairs(parts) do
        self:sendPacket(humanoid, self:nextId() .. pair[1])
        task.wait(self.delay)
        self:sendPacket(humanoid, self:nextId() .. pair[2])
        task.wait(self.delay)
    end
    task.wait(self.delay)
    self:sendPacket(humanoid, SUBMIT)
    task.wait(self.delay)
    self:setSpeed(humanoid, original)
    if animate then
        animate.Enabled = true
    end
    self.bindableFinished:Fire()
    return true
end

function AnimChannel:send(text)
    return self:stream(text)
end

function AnimChannel:sendAsync(text)
    return task.spawn(function()
        self:stream(text)
    end)
end

function AnimChannel:connect()
    if self.connected then
        return nil, "already_connected"
    end
    self.connected = true
    self.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
        if not self.connected then
            return
        end
        for _, player in pairs(self.players:GetPlayers()) do
            local humanoid = self:charParts(player)
            if humanoid then
                local speed = self:speed(humanoid)
                if speed then
                    local packet = tostring(math.floor(speed))
                    if #packet >= 6 and packet ~= "0" and packet ~= "1" then
                        local cache = self.byteCache[player.Name] or ""
                        local last = self.lastPacket[player.Name] or ""
                        if packet ~= last then
                            if packet == CLEAR then
                                cache = ""
                            elseif packet == SUBMIT then
                                local text = decode(cache)
                                self.byteCache[player.Name] = ""
                                self.lastPacket[player.Name] = packet
                                self.bindableMessage:Fire(player, text, split8(cache))
                            else
                                cache = cache .. packet:sub(3)
                            end
                            self.byteCache[player.Name] = cache
                            self.lastPacket[player.Name] = packet
                        end
                    end
                end
            end
        end
    end)
    return {
        OnMessage = self.bindableMessage.Event,
        OnMessageFinished = self.bindableFinished.Event,
        OnClose = self.bindableClose.Event,
        Send = function(_, text) return self:send(text) end,
        SendAsync = function(_, text) return self:sendAsync(text) end,
        Close = function() return self:close() end,
    }
end

function AnimChannel:close()
    self.connected = false
    if self.heartbeat then
        self.heartbeat:Disconnect()
        self.heartbeat = nil
    end
    self.bindableClose:Fire()
end

return AnimChannel
