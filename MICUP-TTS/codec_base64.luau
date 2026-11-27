--!nocheck
local Base64 = {}

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LOOKUP = {}
for i = 1, #CHARS do
    LOOKUP[string.sub(CHARS, i, i)] = i - 1
end

function Base64.encode(str)
    if type(str) ~= "string" then
        return nil
    end
    local out = {}
    local len = #str
    local i = 1
    while i <= len do
        local b1 = string.byte(str, i)
        local b2 = i + 1 <= len and string.byte(str, i + 1) or nil
        local b3 = i + 2 <= len and string.byte(str, i + 2) or nil
        local c1 = math.floor(b1 / 4)
        local c2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
        out[#out + 1] = string.sub(CHARS, c1 + 1, c1 + 1)
        out[#out + 1] = string.sub(CHARS, c2 + 1, c2 + 1)
        if b2 ~= nil then
            local c3 = (b2 % 16) * 4 + math.floor((b3 or 0) / 64)
            out[#out + 1] = string.sub(CHARS, c3 + 1, c3 + 1)
            if b3 ~= nil then
                out[#out + 1] = string.sub(CHARS, (b3 % 64) + 1, (b3 % 64) + 1)
            end
        end
        i = i + 3
    end
    return table.concat(out)
end

function Base64.decode(str)
    if type(str) ~= "string" then
        return nil
    end
    local out = {}
    local acc = 0
    local nbits = 0
    for i = 1, #str do
        local v = LOOKUP[string.sub(str, i, i)]
        if v == nil then
            return nil
        end
        acc = acc * 64 + v
        nbits = nbits + 6
        if nbits >= 8 then
            nbits = nbits - 8
            out[#out + 1] = math.floor(acc / 2 ^ nbits) % 256
            acc = acc % 2 ^ nbits
        end
    end
    return string.char(table.unpack(out))
end

function Base64.encodedLen(strLen)
    return math.ceil(strLen * 4 / 3)
end

return Base64
