--!nocheck
local function loadM(path)
    local ok, src = pcall(httpget, "http://127.0.0.1:8766/" .. path)
    if not ok or type(src) ~= "string" or #src == 0 then
        return nil, "load_fail:" .. tostring(src)
    end
    local l = loadstring(src)
    if not l then
        return nil, "compile_fail"
    end
    local ok2, m = pcall(l)
    return ok2 and m or nil, tostring(m)
end

function loadR(path)
    local ok, src = pcall(readfile, path)
    if not ok or type(src) ~= "string" or #src == 0 then
        return nil, "readfile_fail:" .. tostring(src)
    end
    local l = loadstring(src)
    if not l then
        return nil, "compile_fail"
    end
    local ok2, m = pcall(l)
    return ok2 and m or nil, ok2 and "ok" or tostring(m)
end

local function muteGameAudio()
    local broadcast = game:GetService("ReplicatedStorage"):WaitForChild("event_text_to_speech_dialog_broadcast")
    local ok, conns = pcall(getconnections, broadcast.OnClientEvent)
    if not ok or type(conns) ~= "table" then
        return 0
    end
    local disabled = 0
    for _, c in ipairs(conns) do
        if typeof(c.Disable) == "function" then
            local ok2, err = pcall(function()
                c:Disable()
            end)
            if ok2 then
                disabled = disabled + 1
            end
        end
    end
    return disabled
end

function startAgent(opts)
    opts = opts or {}
    local failures = {}
    local function check(cond, name, detail)
        if not cond then
            failures[#failures + 1] = name .. (detail and (":" .. tostring(detail)) or "")
        end
    end

    local ControlGUI = loadM("HiddenChannelProject/control_gui.luau")
    local Protocol = loadM("HiddenChannelProject/protocol.luau")
    local Sender = loadM("HiddenChannelProject/tts_sender.luau")
    local Spy = loadM("HiddenChannelProject/tts_spy.luau")
    local Registry = loadM("HiddenChannelProject/codec_registry.luau")
    local Transport = loadM("HiddenChannelProject/transport.luau")
    local ImageStream = loadM("HiddenChannelProject/MICUP-TTS/image_stream.luau")
    local ImageViewer = loadM("HiddenChannelProject/MICUP-TTS/image_viewer.luau")
    local LZ4 = loadM("HiddenChannelProject/codec_lz4.luau")
    local Huffman = loadM("HiddenChannelProject/codec_huffman.luau")
    check(ControlGUI ~= nil, "control_gui")
    check(Protocol ~= nil, "protocol")
    check(Transport ~= nil, "transport")
    check(ImageStream ~= nil, "image_stream")
    if Registry then Registry.setup({ lz4 = LZ4, huffman = Huffman }) end

    local result = { started = false, agent = nil, gui = nil, transport = nil, errors = failures }
    if #failures > 0 then
        return result
    end

    local spec = loadR(opts.specPath or "lua_logo_test.luau")
    check(spec ~= nil, "spec_load")
    if spec == nil then
        return result
    end

    local transport = Transport.new({
        protocol = Protocol,
        senderClass = Sender,
        spyClass = Spy,
        registry = Registry,
        auto = true,
        interval = 1.2,
        repeatCount = 3,
        userId = game:GetService("Players").LocalPlayer.UserId,
        onMessage = nil,
    })
    check(transport ~= nil, "transport_new")
    if transport == nil then
        return result
    end

    local stream
    local sentCount = 0
    local recvCount = 0
    local currentImage = nil

    stream = ImageStream.new({
        transport = transport,
        allowedUsers = { [game:GetService("Players").LocalPlayer.UserId] = true },
        onHeader = function(u, h)
            result.header = h
            if result.gui then
                result.gui:setStatus("header " .. tostring(h.width) .. "x" .. tostring(h.height) .. " strip=" .. tostring(h.strip))
            end
        end,
        onStrip = function(u, i, t, h, p)
            sentCount = sentCount + 1
            if result.gui then
                result.gui:setStatus(string.format("strip %d/%d", i + 1, t))
            end
        end,
        onImage = function(u, img)
            currentImage = img
            if result.gui then
                result.gui:setStatus(string.format("received %d strips", #img.strips))
            end
        end,
    })
    check(stream ~= nil, "stream_new")
    if stream == nil then
        return result
    end
    transport.onMessage = function(uid, kind, data)
        stream:ingest(uid, kind, data)
    end

    local started = transport:start()
    check(started, "transport_start")
    result.muted = muteGameAudio()
    if not started then
        return result
    end

    local function doPreview(fname)
        local curSpec = spec
        local fname = fname or (result.gui and result.gui:filename() or "")
        if fname ~= "" and result.spec == nil then
            local newSpec, newErr = loadR(fname)
            if newSpec ~= nil then
                curSpec = newSpec
                curSpec.Path = fname
            end
        end
        if curSpec == nil then
            if result.gui then
                result.gui:setStatus("no spec loaded yet")
            end
            return
        end
        if result.viewer then
            result.viewer:destroy()
        end
        result.viewer = ImageViewer.new({
            width = curSpec.width,
            height = curSpec.height,
            strip = curSpec.strip,
            palette = curSpec.palette,
            forceWhiteBg = result.gui and result.gui.cbForceWhiteBgChecked == true,
            forceBlackBg = result.gui and result.gui.cbForceBlackBgChecked == true,
        })
        local ok = pcall(function()
            result.lastSpec = curSpec
            result.viewer:update(curSpec)
        end)
        if result.gui then
            result.gui:setStatus("preview ok: " .. curSpec.width .. "x" .. curSpec.height .. (ok and "" or " (render err)"))
        end
    end

    function result.flags()
        local gui = result.gui
        return {
            whiteBg = gui and gui.cbForceWhiteBgChecked == true,
            blackBg = gui and gui.cbForceBlackBgChecked == true,
            muted = result.muted or false,
        }
    end

    local function unmuteGameAudio()
        local broadcast = game:GetService("ReplicatedStorage"):WaitForChild("event_text_to_speech_dialog_broadcast")
        local ok, conns = pcall(getconnections, broadcast.OnClientEvent)
        if not ok or type(conns) ~= "table" then
            return 0
        end
        local enabled = 0
        for _, c in ipairs(conns) do
            if typeof(c.Enable) == "function" then
                pcall(function()
                    c:Enable()
                end)
                enabled = enabled + 1
            end
        end
        return enabled
    end

    result.muteToggle = function(on)
        if on then
            result.muted = muteGameAudio()
        else
            unmuteGameAudio()
            result.muted = false
        end
    end

    local function doSend()
        local ok, err = pcall(function()
            transport.sender.interval = opts.interval or 1.2
            local curSpec = spec
            local fname = result.gui and result.gui:filename() or ""
            if fname ~= "" and fname ~= (result.spec and result.spec.Path or "") then
                local newSpec, newErr = loadR(fname)
                if newSpec == nil then
                    error("load: " .. tostring(newErr))
                end
                curSpec = newSpec
                curSpec.Path = fname
                result.spec = curSpec
                result.gui:setStatus("loaded " .. fname)
            end
            stream:send(curSpec)
            result.sending = true
            if result.gui then
                result.gui:setStatus("sending " .. #curSpec.strips .. " frames")
            end
        end)
        if not ok and result.gui then
            result.gui:setStatus("send error: " .. tostring(err))
        end
    end

    local gui = ControlGUI.new({
        title = "TTS Agent: " .. (opts.specPath or "lua_logo_test.luau"),
        onStart = function(_, interval, repeatN)
            transport.sender.repeatCount = repeatN
            doSend()
        end,
        onPreview = function(fname)
            doPreview(fname)
        end,
        onCheck = function(name, checked)
            if name == "cbForceWhiteBgChecked" and result.viewer then
                result.viewer.forceWhiteBg = checked
                result.viewer:update(result.lastSpec or spec)
            end
            if name == "cbForceBlackBgChecked" and result.viewer then
                result.viewer.forceBlackBg = checked
                result.viewer:update(result.lastSpec or spec)
            end
            if name == "cbMuted" and result.muteToggle then
                result.muteToggle(checked)
            end
            if result.gui then
                result.gui:setStatus("flags: " .. tostring(result.flags and result.flags() or nil))
            end
        end,
        onClose = function(_)
            if result.viewer then
                result.viewer:destroy()
                result.viewer = nil
            end
            transport:stop()
        end,
    })
    result.gui = gui
    result.started = true
    result.transport = transport
    result.agent = { spec = spec, stream = stream, image = function() return currentImage end, send = doSend, preview = doPreview, flags = result.flags }
    return result
end

function main()
    local res = startAgent()
    return { started = res.started, errors = res.errors, sending = res.sending }
end

return { startAgent = startAgent, main = main }
