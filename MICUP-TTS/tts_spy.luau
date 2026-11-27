--!nocheck
local Spy = {}
Spy.__index = Spy

function Spy.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Spy)
    if type(opts.protocol) ~= "table" then
        error("protocol_required", 2)
    end
    self.protocol = opts.protocol
    self.userId = opts.userId
    self.verbose = opts.verbose == true
    self.onMessage = opts.onMessage
    self.onFrame = opts.onFrame
    self.onForeign = opts.onForeign
    self.reassemblers = {}
    self.connections = {}
    self.stats = { frames = 0, messages = 0, crcFail = 0, foreign = 0, ignored = 0 }
    return self
end

function Spy:start()
    if #self.connections > 0 then
        return false
    end
    local rs = game:GetService("ReplicatedStorage")
    local broadcast = rs:WaitForChild("event_text_to_speech_dialog_broadcast")
    self.connections[#self.connections + 1] = broadcast.OnClientEvent:Connect(function(userId, text, voiceId, speed, pitch)
        self:ingest(userId, text, voiceId, speed, pitch)
    end)
    return true
end

function Spy:stop()
    for _, conn in ipairs(self.connections) do
        conn:Disconnect()
    end
    self.connections = {}
end

function Spy:ingest(userId, text, voiceId, speed, pitch)
    if type(text) ~= "string" then
        return
    end
    if self.userId ~= nil and userId ~= self.userId then
        self.stats.ignored = self.stats.ignored + 1
        return
    end
    local frame, err = self.protocol.parse(text)
    if frame == nil then
        if err == "bad_magic" then
            self.stats.foreign = self.stats.foreign + 1
            if self.onForeign then
                self.onForeign(userId, text, voiceId, speed, pitch)
            end
        else
            self.stats.crcFail = self.stats.crcFail + 1
            if self.verbose then
                print(string.format("[spy] bad frame err=%s len=%d", tostring(err), #text))
            end
        end
        return
    end
    self.stats.frames = self.stats.frames + 1
    if self.onFrame then
        self.onFrame(userId, frame, voiceId, speed, pitch)
    end
    local r = self.reassemblers[userId]
    if r == nil then
        r = self.protocol.newReassembler()
        self.reassemblers[userId] = r
    end
    local data, kind, done = self.protocol.push(r, frame)
    if done then
        self.stats.messages = self.stats.messages + 1
        if self.verbose then
            print(string.format("[spy] message type=%s sender=%s bytes=%d frames=%d", kind, tostring(userId), #data, frame.total))
        end
        if self.onMessage then
            self.onMessage(userId, kind, data)
        end
    end
end

return Spy
