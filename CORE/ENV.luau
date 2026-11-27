local ENV = {}

local function missing(kind, value, fallback)
    if type(value) == kind then
        return value
    end
    return fallback
end

ENV.cloneref = missing("function", cloneref, function(...) return ... end)
ENV.gethui = missing("function", gethui or get_hidden_gui)
ENV.sethiddenproperty = missing("function", sethiddenproperty or set_hidden_property or set_hidden_prop)
ENV.gethiddenproperty = missing("function", gethiddenproperty or get_hidden_property or get_hidden_prop)
ENV.httprequest = missing("function", request or http_request or (syn and syn.request) or (http and http.request))
ENV.isfile = missing("function", isfile)
ENV.readfile = missing("function", readfile)
ENV.writefile = missing("function", writefile)
ENV.makefolder = missing("function", makefolder)
ENV.isfolder = missing("function", isfolder)
ENV.getcustomasset = missing("function", getcustomasset or getsynasset)
ENV.getconnections = missing("function", getconnections or get_signal_cons)
ENV.firetouchinterest = missing("function", firetouchinterest)

if not ENV.isfile and ENV.readfile then
    ENV.isfile = function(file)
        local ok, data = pcall(ENV.readfile, file)
        return ok and data ~= nil and data ~= ""
    end
end

if ENV.writefile then
    ENV.writefileSafe = function(file, data)
        return pcall(ENV.writefile, file, data)
    end
end
if ENV.readfile then
    ENV.readfileSafe = function(file)
        return pcall(ENV.readfile, file)
    end
end

ENV.httpget = function(url)
    if type(game.HttpGet) == "function" then
        local ok, body = pcall(function() return game:HttpGet(url, false) end)
        if ok and type(body) == "string" then
            return body
        end
    end
    if ENV.httprequest then
        local ok, res = pcall(ENV.httprequest, { Url = url, Method = "GET" })
        if ok and res then
            return res.Body
        end
    end
    return nil
end

ENV.Services = setmetatable({}, {
    __index = function(self, name)
        local ok, service = pcall(function()
            return ENV.cloneref(game:GetService(name))
        end)
        if ok then
            rawset(self, name, service)
            return service
        end
        error("Invalid Service: " .. tostring(name))
    end,
})

ENV.Players = ENV.Services.Players
ENV.UserInputService = ENV.Services.UserInputService
ENV.TweenService = ENV.Services.TweenService
ENV.HttpService = ENV.Services.HttpService
ENV.RunService = ENV.Services.RunService
ENV.StarterGui = ENV.Services.StarterGui
ENV.GuiService = ENV.Services.GuiService
ENV.ReplicatedStorage = ENV.Services.ReplicatedStorage
ENV.SoundService = ENV.Services.SoundService
ENV.Teams = ENV.Services.Teams
ENV.TextChatService = ENV.Services.TextChatService
ENV.CoreGui = ENV.Services.CoreGui
ENV.LocalPlayer = ENV.Players.LocalPlayer
ENV.PlaceId = game.PlaceId
ENV.JobId = game.JobId

ENV.WebSocket = typeof(WebSocket) == "table" and WebSocket or nil
ENV.crypt = typeof(crypt) == "table" and crypt or nil

return ENV
