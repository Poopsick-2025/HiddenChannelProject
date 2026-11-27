--!nocheck
local ImageStream = {}
ImageStream.__index = ImageStream

ImageStream.MAX_WIDTH = 256
ImageStream.MAX_HEIGHT = 256
ImageStream.MAX_PALETTE = 256
ImageStream.MAX_STRIP = 64
ImageStream.MAX_STRIPS = 256

local function loadModule(envKey, path)
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

local Hex = loadModule("HEX_SRC", "HiddenChannelProject/hex.luau")
local Base64 = loadModule("B64_SRC", "HiddenChannelProject/codec_base64.luau")

function ImageStream.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ImageStream)
    self.transport = opts.transport
    if self.transport == nil then
        return nil, "missing_transport"
    end
    self.onImage = opts.onImage
    self.onStrip = opts.onStrip
    self.onHeader = opts.onHeader
    self.allowedUsers = opts.allowedUsers
    self.incoming = {}
    self.stats = { sent = 0, received = 0, strips = 0, ignored = 0, rejected = 0 }
    return self
end

function ImageStream:headerPayload(spec)
    local colors = {}
    for i, c in ipairs(spec.palette) do
        colors[i] = string.gsub(tostring(c), "#", "")
    end
    return string.format("%d;%d;%d;%d;%s", spec.width, spec.height, spec.strip, #colors, table.concat(colors, ","))
end

function ImageStream:send(spec, frameType)
    if type(spec) ~= "table" or type(spec.strips) ~= "table" then
        return nil, "bad_spec"
    end
    local header = self:headerPayload(spec)
    local ok = self.transport:send("I", header, true)
    if ok == nil then
        return nil, "header_send_failed"
    end
    local sent = 0
    for i, strip in ipairs(spec.strips) do
        local payload = tostring(i - 1) .. ";" .. tostring(strip)
        local res = self.transport:send(frameType or "F", payload, true)
        if res == nil then
            return nil, "strip_send_failed:" .. tostring(i - 1)
        end
        sent = sent + 1
    end
    self.stats.sent = self.stats.sent + 1
    return sent
end

function ImageStream:parseHeader(payload)
    local w, h, s, count, rest = string.match(tostring(payload), "^(%d+);(%d+);(%d+);(%d+);(.*)$")
    if w == nil then
        return nil, "bad_header"
    end
    w = tonumber(w)
    h = tonumber(h)
    s = tonumber(s)
    count = tonumber(count)
    if w < 1 or w > ImageStream.MAX_WIDTH then
        return nil, "bad_width"
    end
    if h < 1 or h > ImageStream.MAX_HEIGHT then
        return nil, "bad_height"
    end
    if s < 1 or s > ImageStream.MAX_STRIP then
        return nil, "bad_strip"
    end
    if count < 1 or count > ImageStream.MAX_PALETTE then
        return nil, "bad_palette"
    end
    local colors = {}
    for hex in string.gmatch(rest, "[^,]+") do
        if #hex ~= 6 then
            return nil, "bad_color"
        end
        colors[#colors + 1] = "#" .. hex
    end
    if #colors ~= count then
        return nil, "palette_mismatch"
    end
    local total = math.ceil(h / s)
    if total > ImageStream.MAX_STRIPS then
        return nil, "too_many_strips"
    end
    return {
        width = w,
        height = h,
        strip = s,
        palette = colors,
        total = total,
    }
end

function ImageStream:ingest(userId, kind, payload)
    if self.allowedUsers ~= nil and not self.allowedUsers[userId] then
        self.stats.ignored = (self.stats.ignored or 0) + 1
        return nil, "unauthorized"
    end
    if kind == "I" then
        local spec, err = self:parseHeader(payload)
        if spec == nil then
            self.stats.rejected = self.stats.rejected + 1
            return nil, err
        end
        self.incoming[userId] = {
            spec = spec,
            strips = {},
            count = 0,
            total = spec.total,
        }
        self.stats.received = self.stats.received + 1
        if self.onHeader then
            self.onHeader(userId, spec)
        end
        return spec
    end
    if kind ~= "F" then
        return nil
    end
    local buf = self.incoming[userId]
    if buf == nil then
        self.stats.rejected = self.stats.rejected + 1
        return nil, "no_header"
    end
    local index, data = string.match(tostring(payload), "^(%d+);(.*)$")
    if index == nil then
        self.stats.rejected = self.stats.rejected + 1
        return nil, "bad_strip"
    end
    index = tonumber(index)
    if index < 0 or index >= buf.total then
        self.stats.rejected = self.stats.rejected + 1
        return nil, "strip_out_of_range"
    end
    local expected = buf.spec.width * buf.spec.strip * 4 / 3 + 4
    if #data > expected then
        self.stats.rejected = self.stats.rejected + 1
        return nil, "strip_too_long"
    end
    if buf.strips[index + 1] == nil then
        buf.strips[index + 1] = data
        buf.count = buf.count + 1
        self.stats.strips = self.stats.strips + 1
        if self.onStrip then
            self.onStrip(userId, index, buf.total, buf.spec, data)
        end
    end
    if buf.count >= buf.total then
        local flat = {}
        for i = 1, buf.total do
            flat[i] = buf.strips[i]
        end
        local image = {
            spec = buf.spec,
            strips = flat,
        }
        self.incoming[userId] = nil
        if self.onImage then
            self.onImage(userId, image)
        end
        return image
    end
    return nil
end

function ImageStream:decodeStrip(hexStr)
    if Hex ~= nil then
        return Hex.decode(hexStr)
    end
    if Base64 ~= nil then
        return Base64.decode(hexStr)
    end
    return nil, "no_decoder"
end

function ImageStream:pixels(image)
    local spec = image.spec
    local bytes = {}
    for _, s in ipairs(image.strips) do
        local b = self:decodeStrip(s)
        if b == nil then
            return nil, "bad_strip_data"
        end
        for i = 1, #b do
            bytes[#bytes + 1] = string.byte(b, i)
        end
    end
    local pixels = {}
    for i = 1, #bytes do
        local idx = bytes[i]
        if idx >= #spec.palette then
            return nil, "palette_index_out_of_range"
        end
        pixels[i] = spec.palette[idx + 1]
    end
    local expected = spec.width * spec.height
    if #pixels ~= expected then
        return nil, "pixel_count_mismatch"
    end
    return pixels
end

return ImageStream
