--!nocheck
local Hex = {}

local CHARS = "0123456789ABCDEF"
local LOOKUP = {}
for i = 1, 16 do
    LOOKUP[string.sub(CHARS, i, i)] = i - 1
end

function Hex.encode(bytes)
    if type(bytes) ~= "string" then
        return nil
    end
    local out = {}
    for i = 1, #bytes do
        local b = string.byte(bytes, i)
        out[#out + 1] = string.sub(CHARS, math.floor(b / 16) + 1, math.floor(b / 16) + 1)
        out[#out + 1] = string.sub(CHARS, b % 16 + 1, b % 16 + 1)
    end
    return table.concat(out)
end

function Hex.decode(str)
    if type(str) ~= "string" or #str % 2 ~= 0 then
        return nil
    end
    local out = {}
    for i = 1, #str, 2 do
        local hi = LOOKUP[string.sub(str, i, i)]
        local lo = LOOKUP[string.sub(str, i + 1, i + 1)]
        if hi == nil or lo == nil then
            return nil
        end
        out[#out + 1] = string.char(hi * 16 + lo)
    end
    return table.concat(out)
end

return Hex
