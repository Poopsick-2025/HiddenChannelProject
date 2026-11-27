--!nocheck
local Pipeline = {}

local function load(envKey, path)
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
    return mod
end

local MODULES = {
    { key = "PROTOCOL_SRC", path = "HiddenChannelProject/protocol.luau", name = "protocol" },
    { key = "SENDER_SRC", path = "HiddenChannelProject/tts_sender.luau", name = "sender" },
    { key = "SPY_SRC", path = "HiddenChannelProject/tts_spy.luau", name = "spy" },
    { key = "LZ4_SRC", path = "HiddenChannelProject/codec_lz4.luau", name = "lz4" },
    { key = "HUFFMAN_SRC", path = "HiddenChannelProject/codec_huffman.luau", name = "huffman" },
    { key = "REGISTRY_SRC", path = "HiddenChannelProject/codec_registry.luau", name = "registry" },
    { key = "B64_SRC", path = "HiddenChannelProject/codec_base64.luau", name = "base64" },
    { key = "HEX_SRC", path = "HiddenChannelProject/hex.luau", name = "hex" },
    { key = "TRANSPORT_SRC", path = "HiddenChannelProject/transport.luau", name = "transport" },
    { key = "FILE_SRC", path = "HiddenChannelProject/file_transfer.luau", name = "file" },
    { key = "SIDE_SRC", path = "HiddenChannelProject/sidechannel.luau", name = "side" },
}

function Pipeline.loadAll()
    local out = {}
    for _, def in ipairs(MODULES) do
        out[def.name] = load(def.key, def.path)
    end
    return out
end

function Pipeline.start(opts)
    opts = opts or {}
    local mods = Pipeline.loadAll()
    if mods.protocol == nil or mods.sender == nil or mods.spy == nil or mods.transport == nil then
        return nil, "core_modules_missing"
    end
    if mods.registry ~= nil then
        mods.registry.setup({ lz4 = mods.lz4, huffman = mods.huffman })
    end
    local transport = mods.transport.new({
        protocol = mods.protocol,
        senderClass = mods.sender,
        spyClass = mods.spy,
        registry = mods.registry,
        method = opts.method,
        auto = opts.auto ~= false,
        interval = opts.interval,
        repeatCount = opts.repeatCount,
        verbose = opts.verbose,
        onMessage = opts.onMessage,
    })
    if transport == nil then
        return nil, "transport_init_failed"
    end
    local started, err = transport:start()
    if not started then
        return nil, err
    end
    local files = nil
    if mods.file ~= nil and mods.base64 ~= nil then
        files = mods.file.new({ base64 = mods.base64, transport = transport })
    end
    return {
        modules = mods,
        transport = transport,
        files = files,
        side = mods.side,
    }
end

return Pipeline
