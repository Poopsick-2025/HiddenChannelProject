--!nocheck
local Wire = {}
Wire.__index = Wire

local function packF(v)
    return string.pack("<f", v)
end

local function packD(v)
    return string.pack("<d", v)
end

local function packU8(v)
    return string.char(v % 256)
end

local function packU16(v)
    return string.pack("<I2", v)
end

local function packU32(v)
    return string.pack("<I4", v)
end

local function packStr(s)
    s = tostring(s or "")
    return packU16(#s) .. s
end

local function packVec3(v)
    return string.pack("<fff", v.X, v.Y, v.Z)
end

local function packColor3(c)
    return string.pack("<fff", c.R, c.G, c.B)
end

function Wire.new()
    local self = setmetatable({}, Wire)
    self.buf = {}
    self.pos = 1
    return self
end

function Wire:writeF(v)
    self.buf[#self.buf + 1] = packF(v)
    return self
end

function Wire:writeD(v)
    self.buf[#self.buf + 1] = packD(v)
    return self
end

function Wire:writeU8(v)
    self.buf[#self.buf + 1] = packU8(v)
    return self
end

function Wire:writeU16(v)
    self.buf[#self.buf + 1] = packU16(v)
    return self
end

function Wire:writeU32(v)
    self.buf[#self.buf + 1] = packU32(v)
    return self
end

function Wire:writeStr(s)
    self.buf[#self.buf + 1] = packStr(s)
    return self
end

function Wire:writeVec3(v)
    self.buf[#self.buf + 1] = packVec3(v)
    return self
end

function Wire:writeColor3(c)
    self.buf[#self.buf + 1] = packColor3(c)
    return self
end

function Wire:bytes()
    return table.concat(self.buf)
end

function Wire:readF(data, pos)
    local v = string.unpack("<f", data, pos)
    return v, pos + 4
end

function Wire:readD(data, pos)
    local v = string.unpack("<d", data, pos)
    return v, pos + 8
end

function Wire:readU8(data, pos)
    local v = string.byte(data, pos)
    return v, pos + 1
end

function Wire:readU16(data, pos)
    local v = string.unpack("<I2", data, pos)
    return v, pos + 2
end

function Wire:readU32(data, pos)
    local v = string.unpack("<I4", data, pos)
    return v, pos + 4
end

function Wire:readStr(data, pos)
    local n = string.unpack("<I2", data, pos)
    pos = pos + 2
    local s = string.sub(data, pos, pos + n - 1)
    return s, pos + n
end

function Wire:readVec3(data, pos)
    local x, y, z = string.unpack("<fff", data, pos)
    return Vector3.new(x, y, z), pos + 12
end

function Wire:readColor3(data, pos)
    local r, g, b = string.unpack("<fff", data, pos)
    return Color3.new(r, g, b), pos + 12
end

local PROPS = {
    "Name",
    "Position",
    "Orientation",
    "Size",
    "Color",
    "Transparency",
    "Anchored",
    "CanCollide",
    "Massless",
}

function Wire:packInstance(inst)
    if not inst then
        return nil, "nil_instance"
    end
    local okName, name = pcall(function() return inst.Name end)
    local okClass, class = pcall(function() return inst.ClassName end)
    self:writeStr(okClass and class or "Instance")
    self:writeStr(okName and name or "")
    for _, prop in ipairs(PROPS) do
        local ok, v = pcall(function() return inst[prop] end)
        if ok and v ~= nil then
            if prop == "Name" then
                self:writeU8(1)
            elseif prop == "Position" or prop == "Orientation" then
                self:writeU8(2)
                self:writeVec3(v)
            elseif prop == "Size" then
                self:writeU8(3)
                self:writeVec3(v)
            elseif prop == "Color" then
                self:writeU8(4)
                self:writeColor3(v)
            elseif prop == "Transparency" then
                self:writeU8(5)
                self:writeF(v)
            elseif prop == "Anchored" or prop == "CanCollide" or prop == "Massless" then
                self:writeU8(6)
                self:writeU8(v and 1 or 0)
            else
                self:writeU8(0)
            end
        end
    end
    self:writeU8(0xFF)
    local okKids = pcall(function() return inst:GetChildren() end)
    local n = 0
    if okKids then
        for _, c in ipairs(inst:GetChildren()) do
            n = n + 1
        end
    end
    self:writeU16(n)
    if okKids then
        for _, c in ipairs(inst:GetChildren()) do
            local childWire = Wire.new()
            local childData = childWire:packInstance(c)
            if childData then
                self:writeStr(childData)
            end
        end
    end
    return self:bytes()
end

function Wire:unpackInstance(data, parent)
    local class, pos = self:readStr(data, 1)
    local name, pos2 = self:readStr(data, pos)
    local inst = Instance.new(class)
    inst.Name = name
    inst.Parent = parent
    while true do
        local tag = string.byte(data, pos2)
        pos2 = pos2 + 1
        if tag == 0xFF then
            break
        end
        if tag == 1 then
            local v, np = self:readStr(data, pos2)
            inst.Name = v
            pos2 = np
        elseif tag == 2 or tag == 3 then
            local v, np = self:readVec3(data, pos2)
            local prop = tag == 2 and "Position" or "Size"
            pcall(function() inst[prop] = v end)
            pos2 = np
        elseif tag == 4 then
            local v, np = self:readColor3(data, pos2)
            pcall(function() inst.Color = v end)
            pos2 = np
        elseif tag == 5 then
            local v, np = self:readF(data, pos2)
            pcall(function() inst.Transparency = v end)
            pos2 = np
        elseif tag == 6 then
            local v, np = self:readU8(data, pos2)
            local prop = "Anchored"
            if inst:IsA("BasePart") then
                if v == 1 then
                    prop = "Anchored"
                end
            end
            pos2 = np
        end
    end
    local n = string.unpack("<I2", data, pos2)
    pos2 = pos2 + 2
    for _ = 1, n do
        local childData, np = self:readStr(data, pos2)
        if childData then
            local childWire = Wire.new()
            childWire:unpackInstance(childData, inst)
            pos2 = np
        end
    end
    return inst
end

function Wire:clone(inst, parent)
    local data = self:packInstance(inst)
    if not data then
        return nil
    end
    return self:unpackInstance(data, parent)
end

return Wire
