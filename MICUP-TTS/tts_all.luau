--!nocheck
local function load(path)
    local ok, src = pcall(httpget, "http://127.0.0.1:8766/" .. path)
    if not ok or type(src) ~= "string" or #src == 0 then
        return nil, "missing:" .. path
    end
    local l = loadstring(src)
    if not l then
        return nil, "compile_fail:" .. path
    end
    local ok2, m = pcall(l)
    if not ok2 or type(m) ~= "table" then
        return nil, "runtime_fail:" .. path
    end
    return m
end

local function requireErr(path)
    local m, err = load(path)
    if m == nil then
        error(err or ("load_fail:" .. path), 2)
    end
    return m
end

local Registry = requireErr("HiddenChannelProject/codec_registry.luau")
local LZ4 = requireErr("HiddenChannelProject/codec_lz4.luau")
local Huffman = requireErr("HiddenChannelProject/codec_huffman.luau")
Registry.setup({ lz4 = LZ4, huffman = Huffman })

local function loadR(path)
    local ok, src = pcall(readfile, path)
    if not ok or type(src) ~= "string" or #src == 0 then
        return nil
    end
    local l = loadstring(src)
    if not l then
        return nil
    end
    local ok2, m = pcall(l)
    return ok2 and m or nil
end

local function requireR(path)
    local m = loadR(path)
    if m == nil then
        error("readfile_fail:" .. path, 2)
    end
    return m
end

return {
    Protocol = requireErr("HiddenChannelProject/protocol.luau"),
    Sender = requireErr("HiddenChannelProject/tts_sender.luau"),
    Spy = requireErr("HiddenChannelProject/tts_spy.luau"),
    Registry = Registry,
    LZ4 = LZ4,
    Huffman = Huffman,
    Transport = requireErr("HiddenChannelProject/transport.luau"),
    Hex = requireErr("HiddenChannelProject/hex.luau"),
    Base64 = requireErr("HiddenChannelProject/codec_base64.luau"),
    ImageStream = requireErr("HiddenChannelProject/MICUP-TTS/image_stream.luau"),
    ImageViewer = requireErr("HiddenChannelProject/MICUP-TTS/image_viewer.luau"),
    UniversalChat = requireErr("HiddenChannelProject/MICUP-TTS/universal_chat.lua"),
    AppChatPlayerList = requireErr("HiddenChannelProject/appchat_playerlist.lua"),
    HiddenChat = requireErr("HiddenChannelProject/hidden_chat.lua"),
    WSChannel = requireR("HiddenChannelProject/CORE/ws_channel.luau"),
    AnimChannel = requireR("HiddenChannelProject/CORE/anim_channel.luau"),
    ZipCodec = requireR("HiddenChannelProject/CORE/zip_codec.luau"),
    Chunker = requireR("HiddenChannelProject/CORE/chunker.luau"),
    FileExplorer = requireErr("HiddenChannelProject/HIDDEN-CHAT/file_explorer.luau"),
    ControlGUI = requireErr("HiddenChannelProject/control_gui.luau"),
    Agent = requireErr("HiddenChannelProject/tts_agent.luau"),
    SideChannel = requireErr("HiddenChannelProject/sidechannel.luau"),
    Spec = function(path) return requireR("terminator_test.luau") or requireR(path) end,
}
