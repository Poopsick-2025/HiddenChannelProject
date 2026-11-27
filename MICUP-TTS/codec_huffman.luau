--!nocheck
local Huffman = {}

Huffman.NAME = "huffman"

local function findSource(envKey, paths)
    local ok, src = pcall(function()
        return getgenv()[envKey]
    end)
    if ok and type(src) == "string" and #src > 0 then
        return src
    end
    if type(httpget) == "function" then
        for _, path in ipairs(paths) do
            local okGet, res = pcall(httpget, "http://127.0.0.1:8766/" .. path)
            if okGet and type(res) == "string" and #res > 0 then
                return res
            end
        end
    end
    return nil
end

function Huffman.load(opts)
    opts = opts or {}
    local src = opts.source
    if src == nil then
        src = findSource(opts.envKey or "CODEC_SRC", opts.paths or {
            "roblox_huffman_luau/src/codec.luau",
        })
    end
    if src == nil then
        return nil, "source_not_found"
    end
    local loader = loadstring(src)
    if loader == nil then
        return nil, "compile_failed"
    end
    local ok, Codec = pcall(loader)
    if not ok or type(Codec) ~= "table" then
        return nil, "load_failed"
    end
    return Codec
end

function Huffman.new(opts)
    local Codec, err = Huffman.load(opts)
    if Codec == nil then
        return nil, err
    end
    local instance = Codec.new(opts and opts.codecOpts or nil)
    return {
        codec = Codec,
        instance = instance,
        compress = function(self, data)
            return self.instance:compress(data)
        end,
        decompress = function(self, blob)
            return self.instance:decompress(blob)
        end,
    }
end

function Huffman.fit(samples, opts)
    local Codec, err = Huffman.load(opts)
    if Codec == nil then
        return nil, err
    end
    local weights = Codec.fit(samples)
    local instance = Codec.new({ weights = weights })
    return {
        codec = Codec,
        instance = instance,
        weights = weights,
        compress = function(self, data)
            return self.instance:compress(data)
        end,
        decompress = function(self, blob)
            return self.instance:decompress(blob)
        end,
    }
end

return Huffman
