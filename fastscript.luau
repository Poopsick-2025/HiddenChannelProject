--!nocheck
getgenv()["HiddenChannel_WS"] = getgenv()["HiddenChannel_WS"] or "ws://127.0.0.1:8767"

local function load(path)
    local source = game:HttpGet("http://127.0.0.1:8767/" .. path, false)
    if type(source) ~= "string" or #source == 0 then
        error("Failed to load: " .. path)
    end
    local loader = loadstring(source)
    if not loader then
        error("Compile failed: " .. path)
    end
    return loader()
end

local ENV = load("HiddenChannelProject/CORE/ENV.luau")
local WS = load("HiddenChannelProject/CORE/ws_channel.luau")
local H = load("HiddenChannelProject/HIDDEN-CHAT/hidden_chat.lua")
local A = load("HiddenChannelProject/AnimDATA/anim_channel.luau")

local ws = WS.new({ url = getgenv()["HiddenChannel_WS"] })
local chat = H.new({
    ws = ws,
    anim = A.new({ delay = 0.1 }),
})

ws:start()
getgenv().HiddenChatInstance = chat
getgenv().HiddenChannelWS = ws
return chat