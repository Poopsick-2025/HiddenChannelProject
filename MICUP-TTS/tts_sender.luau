--!nocheck
local Sender = {}
Sender.__index = Sender

function Sender.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Sender)
    if type(opts.protocol) ~= "table" then
        error("protocol_required", 2)
    end
    self.protocol = opts.protocol
    self.interval = tonumber(opts.interval) or 1.5
    self.repeatCount = math.max(1, math.floor(tonumber(opts.repeatCount) or 1))
    self.queue = {}
    self.sending = false
    self.remote = nil
    self.stats = { enqueued = 0, sent = 0, failed = 0 }
    return self
end

function Sender:start()
    local rs = game:GetService("ReplicatedStorage")
    self.remote = rs:WaitForChild("event_text_to_speech_dialog")
    return self.remote ~= nil
end

function Sender:enqueue(frameType, data)
    if type(data) ~= "string" then
        return nil, "bad_data"
    end
    if self.remote == nil then
        return nil, "not_started"
    end
    local maxPayload = self.protocol.MAX_FRAME - self.protocol.HEADER_LEN
    local total = math.max(1, math.ceil(#data / maxPayload))
    if total > self.protocol.MAX_SEQ + 1 then
        return nil, "too_large"
    end
    for seq = 0, total - 1 do
        local chunk = string.sub(data, seq * maxPayload + 1, (seq + 1) * maxPayload)
        local frame, err = self.protocol.build(frameType, seq, total, chunk)
        if frame == nil then
            return nil, err
        end
        self.queue[#self.queue + 1] = frame
        self.stats.enqueued = self.stats.enqueued + 1
    end
    self:pump()
    return total
end

function Sender:pump()
    if self.sending then
        return
    end
    self.sending = true
    task.spawn(function()
        while #self.queue > 0 do
            local frame = table.remove(self.queue, 1)
            for _ = 1, self.repeatCount do
                local ok = pcall(function()
                    self.remote:FireServer(frame)
                end)
                if ok then
                    self.stats.sent = self.stats.sent + 1
                else
                    self.stats.failed = self.stats.failed + 1
                end
                task.wait(self.interval)
            end
        end
        self.sending = false
    end)
end

function Sender:pending()
    return #self.queue
end

return Sender
