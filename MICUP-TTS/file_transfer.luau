--!nocheck
local FileTransfer = {}
FileTransfer.__index = FileTransfer

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

function FileTransfer.new(opts)
    opts = opts or {}
    local self = setmetatable({}, FileTransfer)
    self.base64 = opts.base64 or loadModule("B64_SRC", "HiddenChannelProject/codec_base64.luau")
    if self.base64 == nil then
        return nil, "missing_base64"
    end
    self.transport = opts.transport
    if self.transport == nil then
        return nil, "missing_transport"
    end
    self.chunkSize = opts.chunkSize or 240
    self.incoming = {}
    self.onComplete = opts.onComplete
    self.stats = { sent = 0, received = 0 }
    return self
end

function FileTransfer:send(name, data, frameType)
    local encoded = self.base64.encode(data)
    if encoded == nil then
        return nil, "encode_failed"
    end
    local total = math.ceil(#encoded / self.chunkSize)
    local header = name .. "\0" .. tostring(#data) .. "\0" .. tostring(total) .. "\0"
    local stream = header .. encoded
    local frames = math.ceil(#stream / self.chunkSize)
    local sent = 0
    for seq = 0, frames - 1 do
        local chunk = string.sub(stream, seq * self.chunkSize + 1, (seq + 1) * self.chunkSize)
        local ok = self.transport:send(frameType or "F", chunk, true)
        if ok == nil then
            return nil, "send_failed:" .. tostring(seq)
        end
        sent = sent + 1
    end
    self.stats.sent = self.stats.sent + 1
    return sent
end

function FileTransfer:ingest(userId, kind, payload)
    if kind ~= "F" then
        return
    end
    local buf = self.incoming[userId]
    if buf == nil then
        buf = {}
        self.incoming[userId] = buf
    end
    buf[#buf + 1] = payload
    local joined = table.concat(buf)
    local p1 = string.find(joined, "\0", 1, true)
    if p1 == nil then
        return
    end
    local p2 = string.find(joined, "\0", p1 + 1, true)
    local p3 = string.find(joined, "\0", p2 + 1, true)
    if p2 == nil or p3 == nil then
        return
    end
    local name = string.sub(joined, 1, p1 - 1)
    local size = tonumber(string.sub(joined, p1 + 1, p2 - 1))
    local total = tonumber(string.sub(joined, p2 + 1, p3 - 1))
    if size == nil or total == nil then
        return
    end
    local b64 = string.sub(joined, p3 + 1)
    if #b64 < size * 4 / 3 - 4 then
        return
    end
    local data = self.base64.decode(string.sub(b64, 1, math.ceil(size * 4 / 3)))
    if data == nil or #data ~= size then
        return
    end
    self.incoming[userId] = nil
    self.stats.received = self.stats.received + 1
    if self.onComplete then
        self.onComplete(userId, name, data)
    end
end

return FileTransfer
