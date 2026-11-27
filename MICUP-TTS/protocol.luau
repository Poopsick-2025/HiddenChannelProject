--!nocheck
local Protocol = {}

Protocol.MAGIC = "HTS1"
Protocol.MAX_FRAME = 300
Protocol.HEADER_LEN = 14
Protocol.MAX_SEQ = 46655

Protocol.TYPES = {
    Movement = "M",
    File = "F",
    Text = "T",
    Command = "C",
    Ping = "P",
}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, #B64 do
    B64_LOOKUP[string.sub(B64, i, i)] = i - 1
end

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local B36_LOOKUP = {}
for i = 1, #B36 do
    B36_LOOKUP[string.sub(B36, i, i)] = i - 1
end

local CRC_TABLE = {}
for i = 0, 255 do
    local crc = bit32.lshift(i, 8)
    for _ = 1, 8 do
        if bit32.btest(crc, 0x8000) then
            crc = bit32.band(bit32.bxor(bit32.lshift(crc, 1), 0x1021), 0xFFFF)
        else
            crc = bit32.band(bit32.lshift(crc, 1), 0xFFFF)
        end
    end
    CRC_TABLE[i] = crc
end

local function crc16(data)
    local crc = 0xFFFF
    for i = 1, #data do
        local b = string.byte(data, i)
        local idx = bit32.bxor(bit32.rshift(crc, 8), b)
        crc = bit32.bxor(bit32.band(bit32.lshift(crc, 8), 0xFFFF), CRC_TABLE[idx])
    end
    return crc
end

local function toBase36(value, width)
    local out = table.create(width)
    for i = width, 1, -1 do
        local rem = value % 36
        out[i] = string.sub(B36, rem + 1, rem + 1)
        value = math.floor(value / 36)
    end
    return table.concat(out)
end

local function fromBase36(str)
    local v = 0
    for i = 1, #str do
        local d = B36_LOOKUP[string.sub(str, i, i)]
        if d == nil then
            return nil
        end
        v = v * 36 + d
    end
    return v
end

local function crcToChars(crc)
    local c1 = math.floor(crc / 4096)
    local c2 = math.floor(crc / 64) % 64
    local c3 = crc % 64
    return string.sub(B64, c1 + 1, c1 + 1)
        .. string.sub(B64, c2 + 1, c2 + 1)
        .. string.sub(B64, c3 + 1, c3 + 1)
end

local function crcFromChars(str)
    local c1 = B64_LOOKUP[string.sub(str, 1, 1)]
    local c2 = B64_LOOKUP[string.sub(str, 2, 2)]
    local c3 = B64_LOOKUP[string.sub(str, 3, 3)]
    if c1 == nil or c2 == nil or c3 == nil then
        return nil
    end
    return c1 * 4096 + c2 * 64 + c3
end

function Protocol.build(frameType, seq, total, payload)
    if type(frameType) ~= "string" or #frameType ~= 1 then
        return nil, "bad_type"
    end
    if type(payload) ~= "string" then
        return nil, "bad_payload"
    end
    seq = math.floor(tonumber(seq) or -1)
    total = math.floor(tonumber(total) or -1)
    if seq < 0 or seq > Protocol.MAX_SEQ then
        return nil, "bad_seq"
    end
    if total < 1 or total > Protocol.MAX_SEQ then
        return nil, "bad_total"
    end
    if seq >= total then
        return nil, "bad_order"
    end
    local body = Protocol.MAGIC .. frameType .. toBase36(seq, 3) .. toBase36(total, 3) .. payload
    local frame = body .. crcToChars(crc16(body))
    if #frame > Protocol.MAX_FRAME then
        return nil, "too_long"
    end
    return frame
end

function Protocol.parse(str)
    if type(str) ~= "string" then
        return nil, "bad_input"
    end
    if #str < Protocol.HEADER_LEN then
        return nil, "too_short"
    end
    if string.sub(str, 1, 4) ~= Protocol.MAGIC then
        return nil, "bad_magic"
    end
    local frameType = string.sub(str, 5, 5)
    local seq = fromBase36(string.sub(str, 6, 8))
    local total = fromBase36(string.sub(str, 9, 11))
    if seq == nil or total == nil then
        return nil, "bad_header"
    end
    if total < 1 or seq >= total then
        return nil, "bad_order"
    end
    local body = string.sub(str, 1, #str - 3)
    local expected = crc16(body)
    local got = crcFromChars(string.sub(str, #str - 2, #str))
    if got == nil then
        return nil, "bad_crc_chars"
    end
    if got ~= expected then
        return nil, "crc_mismatch"
    end
    return {
        type = frameType,
        seq = seq,
        total = total,
        payload = string.sub(str, 12, #str - 3),
    }
end

function Protocol.newReassembler()
    return { pending = {} }
end

function Protocol.push(r, frame)
    if type(r) ~= "table" or type(frame) ~= "table" then
        return nil, nil, false, "bad_input"
    end
    local key = frame.type
    local buf = r.pending[key]
    if frame.seq == 0 then
        buf = { total = frame.total, frames = {}, count = 0 }
        r.pending[key] = buf
    elseif buf == nil or buf.total ~= frame.total or frame.seq ~= buf.count then
        return nil, key, false, "out_of_order"
    end
    if buf.frames[frame.seq + 1] == nil then
        buf.frames[frame.seq + 1] = frame.payload
        buf.count = buf.count + 1
    end
    if buf.count >= buf.total then
        r.pending[key] = nil
        return table.concat(buf.frames), key, true
    end
    return nil, key, false
end

return Protocol
