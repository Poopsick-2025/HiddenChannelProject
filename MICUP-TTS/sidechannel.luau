--!nocheck
local SideChannel = {}

SideChannel.BITS_PER_VALUE = 48
SideChannel.BYTES_PER_MESSAGE = 12
SideChannel.SPEED_MIN = 0.5
SideChannel.SPEED_MAX = 2.0
SideChannel.PITCH_MIN = -12.0
SideChannel.PITCH_MAX = 12.0

local DIV = 2 ^ 48

local function readU48(str, offset)
    local u = 0
    for i = 0, 5 do
        u = u * 256 + (string.byte(str, offset + i) or 0)
    end
    return u
end

local function writeU48(u)
    local out = table.create(6)
    for i = 6, 1, -1 do
        out[i] = u % 256
        u = math.floor(u / 256)
    end
    return string.char(table.unpack(out))
end

function SideChannel.encodeSpeed(u)
    return 1.0 + u / DIV
end

function SideChannel.decodeSpeed(v)
    return math.floor((v - 1.0) * DIV + 0.5)
end

function SideChannel.encodePitch(u)
    return 4.0 + u / DIV * 4.0
end

function SideChannel.decodePitch(v)
    return math.floor((v - 4.0) / 4.0 * DIV + 0.5)
end

function SideChannel.encode(data)
    if type(data) ~= "string" or #data ~= SideChannel.BYTES_PER_MESSAGE then
        return nil, "bad_input"
    end
    local uSpeed = readU48(data, 1)
    local uPitch = readU48(data, 7)
    return SideChannel.encodeSpeed(uSpeed), SideChannel.encodePitch(uPitch)
end

function SideChannel.decode(speed, pitch)
    local uSpeed = SideChannel.decodeSpeed(speed)
    local uPitch = SideChannel.decodePitch(pitch)
    return writeU48(uSpeed) .. writeU48(uPitch)
end

function SideChannel.inRange(speed, pitch)
    return speed >= SideChannel.SPEED_MIN and speed <= SideChannel.SPEED_MAX
        and pitch >= SideChannel.PITCH_MIN and pitch <= SideChannel.PITCH_MAX
end

return SideChannel
