local ZipCodec = {}
ZipCodec.__index = ZipCodec

local HAVE_CRYPT = typeof(crypt) == "table"
local HAVE_LZ4 = HAVE_CRYPT and typeof(crypt.lz4compress) == "function"
local HAVE_HASH = HAVE_CRYPT and typeof(crypt.hash) == "function"

local CRC_TABLE = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if c % 2 == 1 then
            c = bit32.bxor(0xEDB88320, math.floor(c / 2))
        else
            c = math.floor(c / 2)
        end
    end
    CRC_TABLE[i] = c
end

function ZipCodec.crc32(data)
    if HAVE_HASH then
        local ok, h = pcall(function() return crypt.hash(data, "crc32") end)
        if ok and type(h) == "string" then
            return h
        end
    end
    local c = 0xFFFFFFFF
    for i = 1, #data do
        local b = string.byte(data, i)
        local idx = bit32.band(bit32.bxor(c, b), 0xFF)
        c = bit32.bxor(CRC_TABLE[idx], bit32.band(bit32.rshift(c, 8), 0xFFFFFF))
    end
    return string.format("%08x", bit32.bxor(c, 0xFFFFFFFF))
end

function ZipCodec.compress(data)
    if HAVE_LZ4 then
        local ok, packed = pcall(function() return crypt.lz4compress(data) end)
        if ok and type(packed) == "string" then
            return "L", packed
        end
    end
    return "R", data
end

function ZipCodec.decompress(method, data, expected)
    if method == "L" then
        if not HAVE_LZ4 then
            return nil, "no_lz4"
        end
        local ok, out
        if expected then
            ok, out = pcall(function() return crypt.lz4decompress(data, expected) end)
        else
            ok, out = pcall(function() return crypt.lz4decompress(data) end)
        end
        if not ok then
            return nil, tostring(out)
        end
        return out
    end
    return data
end

function ZipCodec.pack(data)
    local method, packed = ZipCodec.compress(data)
    local crc = ZipCodec.crc32(data)
    return "ZP" .. method .. string.format("%08s", crc):gsub(" ", "0")
        .. string.format("%08x", #packed) .. string.format("%08x", #data) .. packed
end

function ZipCodec.unpack(blob)
    if type(blob) ~= "string" or #blob < 28 or blob:sub(1, 2) ~= "ZP" then
        return nil, "bad_zip"
    end
    local method = blob:sub(3, 3)
    local crc = blob:sub(4, 11)
    local len = tonumber(blob:sub(12, 19), 16)
    local expected = tonumber(blob:sub(20, 27), 16)
    local packed = blob:sub(28)
    if len == nil or #packed ~= len then
        return nil, "bad_len"
    end
    local out, err = ZipCodec.decompress(method, packed, expected)
    if not out then
        return nil, err
    end
    if ZipCodec.crc32(out) ~= crc then
        return nil, "crc_mismatch"
    end
    return out
end

return ZipCodec
