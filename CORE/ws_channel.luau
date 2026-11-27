local WSChannel = {}
WSChannel.__index = WSChannel

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

local Wire = loadM("WIRE_SRC", "HiddenChannelProject/CORE/p2p_wire.lua")
local Snapshots = loadM("SNAPSHOTS_SRC", "HiddenChannelProject/CORE/instance_snapshots.luau")
local ZipCodec = loadM("ZIP_SRC", "HiddenChannelProject/CORE/zip_codec.luau")
local Chunker = loadM("CHUNKER_SRC", "HiddenChannelProject/CORE/chunker.luau")

function WSChannel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, WSChannel)
    self.url = opts.url or "ws://127.0.0.1:8767"
    self.transport = opts.transport
    self.onMessage = opts.onMessage
    self.ws = nil
    self.running = false
    self.stats = { sent = 0, received = 0 }
    self.channels = {}
    self.listeners = {}
    self.prevOnMessage = nil
    self.zipBuffers = {}
    self.onZip = opts.onZip
    return self
end

function WSChannel:sendZip(id, data)
    if not ZipCodec or not Chunker then
        return nil, "zip_modules_missing"
    end
    local packed = ZipCodec.pack(data)
    local chunks = Chunker.split(packed, 180)
    local n = 0
    for _, c in ipairs(chunks) do
        local payload = "Z\0" .. tostring(id) .. "\0" .. tostring(c.idx) .. "\0"
            .. tostring(c.total) .. "\0" .. c.method .. "\0" .. c.data
        local ok = self:send(payload)
        if ok then
            n = n + 1
        end
    end
    return n == #chunks, n
end

function WSChannel:onZipFrame(payload)
    if not Chunker then
        return
    end
    local id, idxS, totalS, method, data = string.match(payload, "^([^\0]*)\0([^\0]*)\0([^\0]*)\0([^\0]*)\0(.*)$")
    if not id then
        return
    end
    local idx, total = tonumber(idxS), tonumber(totalS)
    if not idx or not total then
        return
    end
    local buf = self.zipBuffers[id]
    if not buf or buf.total ~= total then
        buf = { total = total, chunks = {} }
        self.zipBuffers[id] = buf
    end
    buf.chunks[idx] = { idx = idx, method = method, data = data }
    local complete = true
    for i = 0, total - 1 do
        if not buf.chunks[i] then
            complete = false
            break
        end
    end
    if not complete then
        return
    end
    local packed = Chunker.assemble(buf.chunks)
    self.zipBuffers[id] = nil
    if not packed then
        return
    end
    local out = ZipCodec.unpack(packed)
    if out and self.onZip then
        self.onZip(id, out)
    end
end

function WSChannel:start()
    if self.running then
        return self
    end
    local ok, ws = pcall(function()
        return WebSocket.connect(self.url)
    end)
    if not ok or not ws then
        return nil, "connect_failed:" .. tostring(ws)
    end
    self.ws = ws
    self.running = true
    ws.OnMessage:Connect(function(message)
        self.stats.received = self.stats.received + 1
        self:onFrame(message)
    end)
    ws.OnClose:Connect(function()
        self.running = false
    end)
    return self
end

function WSChannel:stop()
    if self.ws then
        pcall(function() self.ws:Close() end)
    end
    self.running = false
end

function WSChannel:echo(data)
    if not self.ws or not self.running then
        return nil, "not_connected"
    end
    local ok, err = pcall(function()
        self.ws:Send("ECHO:" .. tostring(data))
    end)
    return ok, ok and nil or tostring(err)
end

function WSChannel:send(data)
    if not self.ws or not self.running then
        return nil, "not_connected"
    end
    local ok, err = pcall(function()
        self.ws:Send(data)
    end)
    if ok then
        self.stats.sent = self.stats.sent + 1
    end
    return ok, ok and nil or tostring(err)
end

function WSChannel:connectChannel(id, cb)
    self.channels[tostring(id)] = cb
end

function WSChannel:onFrame(data)
    if type(data) ~= "string" then
        return
    end
    local kind = string.sub(data, 1, 1)
    if kind == "S" and Snapshots then
        local ok, inst = pcall(function()
            return Snapshots.deserialize(string.sub(data, 3), workspace)
        end)
        if ok and inst then
            for _, cb in pairs(self.channels) do
                cb(inst)
            end
        end
    elseif kind == "D" and Wire then
        local wire = Wire.new()
        local pos = 3
        while pos <= #data do
            local childData, np = wire:readStr(data, pos)
            if not childData then
                break
            end
            local ok, inst = pcall(function()
                return Snapshots.deserialize(childData, workspace)
            end)
            if ok and inst then
                for _, cb in pairs(self.channels) do
                    cb(inst)
                end
            end
            pos = np
        end
    elseif kind == "M" then
        if self.onMessage then
            self.onMessage(string.sub(data, 3))
        end
    elseif kind == "1" then
        if self.onMessage then
            self.onMessage("1|" .. string.sub(data, 3))
        end
    elseif kind == "2" then
        self:onFrame("I\0" .. string.sub(data, 3))
    elseif kind == "3" then
        self:onFrame("R\0" .. string.sub(data, 3))
    elseif kind == "Z" then
        self:onZipFrame(string.sub(data, 3))
    elseif kind == "E" then
        if self.listeners[kind] then
            for _, cb in ipairs(self.listeners[kind]) do cb(data) end
        end
    end
    if self.listeners[kind] then
        for _, cb in ipairs(self.listeners[kind]) do
            cb(string.sub(data, 3))
        end
    end
end

function WSChannel:listen(kind, cb)
    kind = tostring(kind)
    self.listeners[kind] = self.listeners[kind] or {}
    self.listeners[kind][#self.listeners[kind] + 1] = cb
end

function WSChannel:sendSnapshot(inst)
    if not Snapshots then
        return nil, "snapshots_missing"
    end
    local ok, data = pcall(function()
        return Snapshots.serialize(inst or workspace)
    end)
    if not ok or not data then
        return nil, "serialize_failed"
    end
    return self:send("S\0" .. data)
end

function WSChannel:sendDelta(inst)
    if not Snapshots then
        return nil, "snapshots_missing"
    end
    local ok, data = pcall(function()
        return Snapshots.serialize(inst)
    end)
    if not ok or not data then
        return nil, "serialize_failed"
    end
    return self:send("D\0" .. data)
end

return WSChannel
