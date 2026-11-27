local Snapshots = {}
Snapshots.__index = Snapshots

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

function Snapshots.serialize(inst)
    if Wire == nil then
        return nil, "wire_missing"
    end
    local wire = Wire.new()
    return wire:packInstance(inst)
end

function Snapshots.deserialize(data, parent)
    if Wire == nil then
        return nil, "wire_missing"
    end
    if type(data) ~= "string" then
        return nil, "bad_data"
    end
    local wire = Wire.new()
    local ok, inst = pcall(function()
        return wire:unpackInstance(data, parent)
    end)
    if not ok then
        return nil, inst
    end
    return inst
end

function Snapshots.clone(inst, parent)
    local data = Snapshots.serialize(inst)
    if not data then
        return nil
    end
    return Snapshots.deserialize(data, parent)
end

function Snapshots.apply(inst, data)
    local clone = Snapshots.deserialize(data, inst.Parent)
    if not clone then
        return nil
    end
    inst:Destroy()
    clone.Name = inst.Name
    return clone
end

return Snapshots
