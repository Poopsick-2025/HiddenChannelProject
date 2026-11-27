--!nocheck
local LZ4 = {}

LZ4.NAME = "lz4"
LZ4.HEADER_LEN = 4

local function toLe32(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

local function fromLe32(s)
    local b1, b2, b3, b4 = string.byte(s, 1, 4)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

function LZ4.pack(data)
    if type(data) ~= "string" then
        return nil, "bad_input"
    end
    if type(crypt) ~= "table" or type(crypt.lz4compress) ~= "function" then
        return nil, "no_lz4"
    end
    local ok, compressed = pcall(function()
        return crypt.lz4compress(data)
    end)
    if not ok or type(compressed) ~= "string" then
        return nil, "compress_failed"
    end
    return toLe32(#data) .. compressed
end

function LZ4.unpack(blob)
    if type(blob) ~= "string" or #blob < LZ4.HEADER_LEN then
        return nil, "bad_input"
    end
    if type(crypt) ~= "table" or type(crypt.lz4decompress) ~= "function" then
        return nil, "no_lz4"
    end
    local originalSize = fromLe32(blob)
    local ok, result = pcall(function()
        return crypt.lz4decompress(string.sub(blob, LZ4.HEADER_LEN + 1), originalSize)
    end)
    if not ok or type(result) ~= "string" then
        return nil, "decompress_failed"
    end
    return result
end

function LZ4.sizeOf(blob)
    if type(blob) ~= "string" or #blob < LZ4.HEADER_LEN then
        return nil
    end
    return fromLe32(blob)
end

return LZ4
