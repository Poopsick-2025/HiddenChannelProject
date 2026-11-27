--!nocheck
local Chunker = {}
Chunker.__index = Chunker

local HAVE_CRYPT = typeof(crypt) == "table"
local HAVE_B64 = HAVE_CRYPT and typeof(crypt.base64encode) == "function" and typeof(crypt.base64decode) == "function"

local function toHex(data)
    return (data:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function fromHex(hex)
    return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

function Chunker.encode(data)
    if HAVE_B64 then
        local ok, b = pcall(function() return crypt.base64encode(data) end)
        if ok and type(b) == "string" then
            return "B", b
        end
    end
    return "H", toHex(data)
end

function Chunker.decode(method, data)
    if method == "B" and HAVE_B64 then
        local ok, out = pcall(function() return crypt.base64decode(data) end)
        if ok then
            return out
        end
    end
    if method == "H" then
        return fromHex(data)
    end
    return nil, "decode_failed"
end

function Chunker.split(blob, size)
    size = size or 180
    local chunks = {}
    local total = math.ceil(#blob / size)
    for i = 1, total do
        local part = string.sub(blob, (i - 1) * size + 1, i * size)
        local method, encoded = Chunker.encode(part)
        chunks[i] = {
            idx = i - 1,
            total = total,
            method = method,
            data = encoded,
        }
    end
    return chunks
end

function Chunker.assemble(chunks)
    local maxIdx = -1
    local byIdx = {}
    for _, c in pairs(chunks) do
        if c and c.idx and c.data then
            byIdx[c.idx] = c
            if c.idx > maxIdx then
                maxIdx = c.idx
            end
        end
    end
    for i = 0, maxIdx do
        if not byIdx[i] then
            return nil, "missing_chunk:" .. tostring(i)
        end
    end
    local out = {}
    for i = 0, maxIdx do
        local c = byIdx[i]
        local decoded = Chunker.decode(c.method, c.data)
        if not decoded then
            return nil, "decode_failed:" .. tostring(i)
        end
        out[#out + 1] = decoded
    end
    return table.concat(out)
end

return Chunker
