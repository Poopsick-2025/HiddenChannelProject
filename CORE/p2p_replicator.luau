local Replicator = {}
Replicator.__index = Replicator

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

local Wire = loadM("WIRE_SRC", "HiddenChannelProject/CORE/p2p_wire.lua")
local Snapshots = loadM("SNAPSHOTS_SRC", "HiddenChannelProject/CORE/instance_snapshots.luau")

local REPLICABLE = {
    BasePart = true,
    Model = true,
    Folder = true,
    Decal = true,
    Texture = true,
    MeshPart = true,
    UnionOperation = true,
    SpawnLocation = true,
    Weld = true,
    WeldConstraint = true,
    Motor6D = true,
    Attachment = true,
    ParticleEmitter = true,
    Beam = true,
    Trail = true,
    Sound = true,
    ScreenGui = true,
    BillboardGui = true,
    SurfaceGui = true,
    Frame = true,
    TextLabel = true,
    ImageLabel = true,
    ScrollingFrame = true,
    TextBox = true,
    TextButton = true,
}

function Replicator.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Replicator)
    self.transport = opts.transport
    self.players = game:GetService("Players")
    self.lp = self.players.LocalPlayer
    self.throttleMs = opts.throttleMs or 1500
    self.maxDeltaBytes = opts.maxDeltaBytes or 2048
    self.lastDeltaSend = os.clock()
    self.stats = { snapshotsSent = 0, deltasSent = 0, playersJoined = 0, playersLeft = 0 }
    self.changed = {}
    self.outdated = false
    self.running = false
    self.cbOnJoin = nil
    self.cbOnLeave = nil
    self.cbOnSnapshot = nil
    self.cbOnDelta = nil
    self.connections = {}
    if Wire == nil then
        return nil, "wire_missing"
    end
    return self
end

function Replicator:isReplicable(obj)
    return obj ~= nil and REPLICABLE[obj.ClassName] == true
end

function Replicator:sendSnapshot()
    if not self.transport then
        return nil, "no_transport"
    end
    if Snapshots == nil then
        return nil, "snapshots_missing"
    end
    local ok, data = pcall(function()
        return Snapshots.serialize(workspace)
    end)
    if not ok or not data then
        return nil, "pack_failed"
    end
    local sent = self.transport:send("P", "S\0" .. data, true)
    if sent then
        self.stats.snapshotsSent = self.stats.snapshotsSent + 1
    end
    return sent
end

function Replicator:queueDelta(obj)
    if not obj or not self:isReplicable(obj) then
        return
    end
    self.changed[obj] = true
    self.outdated = true
end

function Replicator:flushDelta()
    if not self.transport then
        return nil, "no_transport"
    end
    local parts = {}
    local size = 0
    local wire = Wire.new()
    for obj in pairs(self.changed) do
        if obj and obj.Parent then
            local ok, data = pcall(function()
                return wire:packInstance(obj)
            end)
            if ok and data and size + #data <= self.maxDeltaBytes then
                parts[#parts + 1] = data
                size = size + #data
            end
        end
    end
    self.changed = {}
    self.outdated = false
    if #parts == 0 then
        return
    end
    local sent = self.transport:send("P", "D\0" .. table.concat(parts, "\0"), true)
    if sent then
        self.stats.deltasSent = self.stats.deltasSent + 1
    end
    return sent
end

function Replicator:onFrame(uid, data)
    if type(data) ~= "string" then
        return
    end
    local kind = string.sub(data, 1, 1)
    if kind == "S" then
        local ok, inst = pcall(function()
            return Snapshots.deserialize(string.sub(data, 3), workspace)
        end)
        if ok and inst and self.cbOnSnapshot then
            self.cbOnSnapshot(uid, inst)
        end
    elseif kind == "D" then
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
            if ok and inst and self.cbOnDelta then
                self.cbOnDelta(uid, inst)
            end
            pos = np
        end
    end
end

function Replicator:start()
    if self.running then
        return self
    end
    self.running = true
    self.connections[#self.connections + 1] = self.players.PlayerAdded:Connect(function(player)
        self.stats.playersJoined = self.stats.playersJoined + 1
        if self.cbOnJoin then
            self.cbOnJoin(player)
        end
    end)
    self.connections[#self.connections + 1] = self.players.PlayerRemoving:Connect(function(player)
        self.stats.playersLeft = self.stats.playersLeft + 1
        if self.cbOnLeave then
            self.cbOnLeave(player)
        end
    end)
    task.spawn(function()
        while self.running do
            task.wait(0.1)
            if self.outdated and os.clock() - self.lastDeltaSend >= self.throttleMs / 1000 then
                self:flushDelta()
                self.lastDeltaSend = os.clock()
            end
        end
    end)
    return self
end

function Replicator:stop()
    self.running = false
    for _, c in ipairs(self.connections) do
        c:Disconnect()
    end
    self.connections = {}
end

return Replicator
