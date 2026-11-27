--!nocheck
local Registry = {}

Registry.DEFAULT = "lz4"

local loaded = { lz4 = nil, huffman = nil }

local function loadModule(key, envKey, path)
    if loaded[key] ~= nil then
        return loaded[key]
    end
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
    if loader == nil then
        return nil
    end
    local okRun, mod = pcall(loader)
    if not okRun or type(mod) ~= "table" then
        return nil
    end
    loaded[key] = mod
    return mod
end

function Registry.setup(modules)
    if type(modules) ~= "table" then
        return
    end
    if type(modules.lz4) == "table" then
        loaded.lz4 = modules.lz4
    end
    if type(modules.huffman) == "table" then
        loaded.huffman = modules.huffman
    end
end

function Registry.lz4()
    return loadModule("lz4", "LZ4_SRC", "HiddenChannelProject/codec_lz4.luau")
end

function Registry.huffman()
    return loadModule("huffman", "HUFFMAN_SRC", "HiddenChannelProject/codec_huffman.luau")
end

function Registry.resolve(name)
    if name == nil or name == "lz4" or name == "L" then
        return Registry.lz4(), "lz4"
    end
    if name == "huffman" or name == "H" then
        return Registry.huffman(), "huffman"
    end
    return nil, "unknown_method"
end

function Registry.tag(method)
    if method == Registry.lz4() then
        return "CL"
    end
    if method == Registry.huffman() then
        return "CH"
    end
    return nil
end

function Registry.untag(prefix)
    if type(prefix) ~= "string" or string.sub(prefix, 1, 1) ~= "C" then
        return nil
    end
    local id = string.sub(prefix, 2, 2)
    if id == "L" then
        return Registry.lz4()
    end
    if id == "H" then
        return Registry.huffman()
    end
    return nil
end

function Registry.compress(method, data, opts)
    if method == Registry.lz4() then
        local m = Registry.lz4()
        return m.pack(data)
    end
    if method == Registry.huffman() then
        local m = Registry.huffman()
        if m == nil then
            return nil, "huffman_unavailable"
        end
        local h = m.new(opts)
        if h == nil then
            return nil, "huffman_init_failed"
        end
        return h:compress(data)
    end
    return nil, "unknown_method"
end

function Registry.decompress(method, blob, opts)
    if method == Registry.lz4() then
        return method.unpack(blob)
    end
    if method == Registry.huffman() then
        local h = method.new(opts)
        if h == nil then
            return nil, "huffman_init_failed"
        end
        return h:decompress(blob)
    end
    return nil, "unknown_method"
end

function Registry.auto(data, opts)
    local lz = Registry.lz4()
    local lzBlob, lerr = nil, "lz4_unavailable"
    if lz ~= nil then
        lzBlob, lerr = lz.pack(data)
    end
    local lzLen = type(lzBlob) == "string" and #lzBlob or math.huge

    local hm = Registry.huffman()
    local huffBlob, herr = nil, "huffman_unavailable"
    if hm ~= nil then
        local h = hm.new(opts)
        if h ~= nil then
            huffBlob, herr = h:compress(data)
        end
    end
    local huffLen = type(huffBlob) == "string" and #huffBlob or math.huge

    if lzLen <= huffLen and lzBlob ~= nil then
        return lz, lzBlob, "lz4"
    end
    if huffBlob ~= nil then
        return hm, huffBlob, "huffman"
    end
    if lzBlob ~= nil then
        return lz, lzBlob, "lz4"
    end
    return nil, nil, lerr or herr
end

return Registry
