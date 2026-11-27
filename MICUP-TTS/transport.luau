--!nocheck
local Transport = {}
Transport.__index = Transport

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

function Transport.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Transport)
    self.protocol = opts.protocol or loadModule("PROTOCOL_SRC", "HiddenChannelProject/protocol.luau")
    self.senderClass = opts.senderClass or loadModule("SENDER_SRC", "HiddenChannelProject/tts_sender.luau")
    self.spyClass = opts.spyClass or loadModule("SPY_SRC", "HiddenChannelProject/tts_spy.luau")
    self.registry = opts.registry or loadModule("REGISTRY_SRC", "HiddenChannelProject/codec_registry.luau")
    if self.protocol == nil or self.senderClass == nil or self.spyClass == nil or self.registry == nil then
        return nil, "missing_modules"
    end
    self.method = opts.method
    self.auto = opts.auto == true or self.method == nil
    self.codecOpts = opts.codecOpts
    self.userId = opts.userId
    if self.userId == nil then
        local Players = game:GetService("Players")
        self.userId = Players.LocalPlayer.UserId
    end
    self.sender = self.senderClass.new({
        protocol = self.protocol,
        interval = opts.interval or 1.5,
        repeatCount = opts.repeatCount,
    })
    self.spy = self.spyClass.new({ protocol = self.protocol, userId = self.userId, verbose = opts.verbose == true })
    self.onMessage = opts.onMessage
    self.stats = { encoded = 0, decoded = 0 }
    return self
end

function Transport:start()
    if not self.sender:start() then
        return nil, "sender_start_failed"
    end
    self.spy.onMessage = function(userId, kind, data)
        self:onFrame(userId, kind, data)
    end
    self.spy:start()
    return true
end

function Transport:stop()
    self.spy:stop()
end

function Transport:encode(data)
    local method, blob, name
    if self.auto then
        method, blob, name = self.registry.auto(data, self.codecOpts)
    else
        method, _ = self.registry.resolve(self.method)
        blob, name = self.registry.compress(method, data, self.codecOpts)
    end
    if blob == nil then
        return nil, name
    end
    local tag = self.registry.tag(method)
    if tag == nil then
        return blob, name
    end
    return tag .. blob, name
end

function Transport:decode(blob)
    local tag = string.sub(blob, 1, 2)
    local method = self.registry.untag(tag)
    if method == nil then
        return blob, "raw"
    end
    local data, err = self.registry.decompress(method, string.sub(blob, 3), self.codecOpts)
    if data == nil then
        return nil, err
    end
    return data, "compressed"
end

function Transport:send(frameType, data, raw)
    local payload = data
    if raw ~= true then
        local encoded = self:encode(data)
        if encoded == nil then
            return nil, "encode_failed"
        end
        payload = encoded
    end
    self.stats.encoded = self.stats.encoded + 1
    return self.sender:enqueue(frameType, payload)
end

function Transport:onFrame(userId, kind, data)
    local decoded, err = self:decode(data)
    if decoded == nil then
        return
    end
    self.stats.decoded = self.stats.decoded + 1
    if self.onMessage then
        self.onMessage(userId, kind, decoded, err)
    end
end

return Transport
