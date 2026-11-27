local P2P = {}
P2P.__index = P2P

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

local Replicator = loadM("REPLICATOR_SRC", "HiddenChannelProject/CORE/p2p_replicator.luau")
local Snapshots = loadM("SNAPSHOTS_SRC", "HiddenChannelProject/CORE/instance_snapshots.luau")

function P2P.new(opts)
    opts = opts or {}
    local self = setmetatable({}, P2P)
    self.transport = opts.transport
    if self.transport == nil then
        return nil, "transport_missing"
    end
    if Replicator == nil then
        return nil, "replicator_missing"
    end
    if Snapshots == nil then
        return nil, "snapshots_missing"
    end
    self.replicator = Replicator.new({
        transport = self.transport,
        throttleMs = opts.throttleMs,
        maxDeltaBytes = opts.maxDeltaBytes,
    })
    if self.replicator == nil then
        return nil, "replicator_init_failed"
    end
    self.prevHandler = self.transport.spy and self.transport.spy.onMessage
    if self.transport.spy then
        self.transport.spy.onMessage = function(uid, kind, data)
            if self.prevHandler then
                local ok, err = pcall(self.prevHandler, uid, kind, data)
                if not ok then
                    warn("P2P: prev handler error: " .. tostring(err))
                end
            end
            if kind == "P" then
                self.replicator:onFrame(uid, data)
            end
        end
    end
    self.onJoin = opts.onJoin
    self.onLeave = opts.onLeave
    self.onSnapshot = opts.onSnapshot
    self.onDelta = opts.onDelta
    self.replicator.cbOnJoin = function(player)
        if self.onJoin then
            self.onJoin(player)
        end
    end
    self.replicator.cbOnLeave = function(player)
        if self.onLeave then
            self.onLeave(player)
        end
    end
    self.replicator.cbOnSnapshot = function(uid, inst)
        if self.onSnapshot then
            self.onSnapshot(uid, inst)
        end
    end
    self.replicator.cbOnDelta = function(uid, inst)
        if self.onDelta then
            self.onDelta(uid, inst)
        end
    end
    return self
end

function P2P:start()
    return self.replicator:start()
end

function P2P:stop()
    return self.replicator:stop()
end

function P2P:snapshot()
    if Snapshots == nil then
        return nil, "snapshots_missing"
    end
    return Snapshots.serialize(workspace)
end

function P2P:sendSnapshot()
    return self.replicator:sendSnapshot()
end

function P2P:sendDelta(obj)
    self.replicator:queueDelta(obj)
end

function P2P:flushDelta()
    return self.replicator:flushDelta()
end

function P2P:stats()
    return self.replicator.stats
end

return P2P
