local FileExplorer = {}
FileExplorer.__index = FileExplorer
FileExplorer.active = nil

local function getParent()
    local ok, h = pcall(gethui)
    if ok and h then
        return h
    end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then
        return cg
    end
    return game:GetService("Players").LocalPlayer.PlayerGui
end

local function norm(path)
    return tostring(path or ""):gsub("\\", "/")
end

local function relativePath(full, root)
    full = norm(full)
    root = norm(root)
    if full:sub(1, #root) == root then
        local rest = full:sub(#root + 1)
        return rest:gsub("^/+", "")
    end
    return full
end

local function listFolder(path)
    local ok, entries = pcall(listfiles, path)
    if not ok or type(entries) ~= "table" then
        return {}
    end
    local folders, files = {}, {}
    for _, full in ipairs(entries) do
        local okDir, isDir = pcall(isfolder, full)
        local rel = relativePath(full, path)
        if isDir then
            folders[#folders + 1] = { name = rel, path = full, kind = "folder" }
        else
            files[#files + 1] = { name = rel, path = full, kind = "file" }
        end
    end
    table.sort(folders, function(a, b) return a.name < b.name end)
    table.sort(files, function(a, b) return a.name < b.name end)
    local out = {}
    for _, f in ipairs(folders) do out[#out + 1] = f end
    for _, f in ipairs(files) do out[#out + 1] = f end
    return out
end

local function new(t, parent, props)
    local i = Instance.new(t)
    if props then
        for k, v in pairs(props) do
            pcall(function() i[k] = v end)
        end
    end
    if parent then
        i.Parent = parent
    end
    return i
end

function FileExplorer.OpenFileDialog(filterExtensions, onFileSelected)
    if FileExplorer.active then
        pcall(function() FileExplorer.active:close() end)
        FileExplorer.active = nil
    end
    local parent = getParent()
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("ScreenGui") and c.Name == "FileExplorer" then
            c:Destroy()
        end
    end
    filterExtensions = filterExtensions or { "All", ".txt", ".json", ".png" }
    local self = setmetatable({}, FileExplorer)
    FileExplorer.active = self
    self.onSelect = onFileSelected
    self.filters = filterExtensions
    self.filterIndex = 1
    self.current = ""
    self.selected = nil
    self.entries = {}
    self.known = {}
    self.query = ""
    self.checked = 0

    local gui = new("ScreenGui", getParent(), { Name = "FileExplorer", ResetOnSpawn = false })
    local frame = new("Frame", gui, {
        Name = "Window", Size = UDim2.fromOffset(420, 320),
        Position = UDim2.new(0.5, -210, 0.5, -160),
        BackgroundColor3 = Color3.fromRGB(24, 24, 24),
        BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(48, 48, 48),
    })
    self.gui = gui
    self.frame = frame

    local header = new("Frame", frame, {
        Name = "Header", Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(33, 33, 33), BorderSizePixel = 0,
    })
    new("TextLabel", header, {
        Name = "Title", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Text = "Select File", TextColor3 = Color3.fromRGB(234, 234, 234),
        Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local close = new("TextButton", header, {
        Name = "Close", Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45), Text = "X",
        TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.GothamBold, TextSize = 13,
    })
    close.Activated:Connect(function() self:close() end)

    local nav = new("Frame", frame, {
        Name = "Nav", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 38),
        BackgroundTransparency = 1,
    })
    local up = new("TextButton", nav, {
        Name = "Up", Size = UDim2.fromOffset(28, 24), BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        Text = "↑", TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.GothamBold, TextSize = 14,
    })
    up.Activated:Connect(function() self:goUp() end)
    local pathBox = new("TextBox", nav, {
        Name = "Path", Size = UDim2.new(1, -96, 0, 24), Position = UDim2.fromOffset(34, 0),
        BackgroundColor3 = Color3.fromRGB(33, 33, 33), Text = "workspace",
        TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.Code, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
    })
    local search = new("TextBox", nav, {
        Name = "Search", Size = UDim2.new(1, -120, 0, 24), Position = UDim2.fromOffset(60, 0),
        BackgroundColor3 = Color3.fromRGB(33, 33, 33), Text = "",
        PlaceholderText = "Search...", TextColor3 = Color3.fromRGB(234, 234, 234),
        Font = Enum.Font.Code, TextSize = 11, ClearTextOnFocus = false,
    })
    search:GetPropertyChangedSignal("Text"):Connect(function()
        self.query = search.Text:lower()
        self:refresh()
    end)
    self.searchBox = search
    local add = new("TextButton", nav, {
        Name = "Add", Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -28, 0, 0),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45), Text = "+",
        TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.GothamBold, TextSize = 14,
    })
    add.Activated:Connect(function()
        local name = pathBox.Text:match("([^/]+)$") or ""
        local newPath = (self.current == "" and "" or (self.current .. "/")) .. name
        pcall(makefolder, newPath)
        self:refresh()
    end)
    self.pathBox = pathBox

    local list = new("ScrollingFrame", frame, {
        Name = "List", Size = UDim2.new(1, -20, 1, -130), Position = UDim2.fromOffset(10, 70),
        BackgroundColor3 = Color3.fromRGB(21, 21, 21), BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(48, 48, 48), ScrollBarThickness = 6,
    })
    local layout = new("UIListLayout", list, { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
    self.list = list
    self.layout = layout

    local bottom = new("Frame", frame, {
        Name = "Bottom", Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 266),
        BackgroundTransparency = 1,
    })
    local fileBox = new("TextBox", bottom, {
        Name = "FileName", Size = UDim2.new(1, -180, 0, 24), BackgroundColor3 = Color3.fromRGB(42, 42, 42),
        Text = "", PlaceholderText = "file name...", TextColor3 = Color3.fromRGB(234, 234, 234),
        Font = Enum.Font.Code, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
    })
    self.fileBox = fileBox
    local filter = new("TextButton", bottom, {
        Name = "Filter", Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -174, 0, 0),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45), Text = tostring(self.filters[1]),
        TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.Gotham, TextSize = 11,
    })
    filter.Activated:Connect(function()
        self.filterIndex = (self.filterIndex % #self.filters) + 1
        filter.Text = tostring(self.filters[self.filterIndex])
        self:refresh()
    end)
    local openBtn = new("TextButton", bottom, {
        Name = "Open", Size = UDim2.fromOffset(50, 24), Position = UDim2.new(1, -98, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 120, 215), Text = "Open",
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 11,
    })
    openBtn.Activated:Connect(function() self:openSelected() end)
    local cancel = new("TextButton", bottom, {
        Name = "Cancel", Size = UDim2.fromOffset(50, 24), Position = UDim2.new(1, -44, 0, 0),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45), Text = "Cancel",
        TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.Gotham, TextSize = 11,
    })
    cancel.Activated:Connect(function() self:close() end)

    local dragging, start, origin = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            start = input.Position
            origin = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - start
            frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)

    self:refresh()
    return self
end

function FileExplorer:isOurFile(path)
    if self.known[path] ~= nil then
        return self.known[path]
    end
    local ext = path:match("(%.[^.]+)$") or ""
    if ext ~= ".luau" and ext ~= ".lua" and ext ~= ".json" and ext ~= ".txt" then
        self.known[path] = false
        return false
    end
    self.checked = self.checked + 1
    if self.checked > 120 then
        return false
    end
    local ok, src = pcall(readfile, path)
    if not ok or type(src) ~= "string" or #src > 65536 then
        self.known[path] = false
        return false
    end
    local head = string.sub(src, 1, 4096)
    local valid = string.find(head, "strips", 1, true) ~= nil
        and (string.find(head, "width", 1, true) ~= nil or string.find(head, "palette", 1, true) ~= nil)
    self.known[path] = valid
    return valid
end

function FileExplorer:refresh()
    for _, c in ipairs(self.list:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    self.checked = 0
    self.entries = listFolder(self.current)
    local f = self.filters[self.filterIndex]
    for i, e in ipairs(self.entries) do
        local show = true
        if e.kind == "file" then
            local ext = e.name:match("(%.[^.]+)$")
            if f ~= "All" then
                show = (ext == f)
            end
            if show and not self:isOurFile(e.path) then
                show = false
            end
        end
        if show and self.query ~= "" and not e.name:lower():find(self.query, 1, true) then
            show = false
        end
        if show then
            local row = new("TextButton", self.list, {
                Name = e.name, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i,
                BackgroundColor3 = Color3.fromRGB(33, 33, 33), Text = (e.kind == "folder" and "📁 " or "📄 ") .. e.name,
                TextColor3 = Color3.fromRGB(234, 234, 234), Font = Enum.Font.Code, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local clickTime = 0
            row.Activated:Connect(function()
                local now = os.clock()
                self.selected = e
                self.fileBox.Text = e.name
                if e.kind == "folder" and now - clickTime < 0.5 then
                    self.current = e.path
                    self.pathBox.Text = relativePath(e.path, "workspace")
                    self:refresh()
                elseif e.kind == "file" and now - clickTime < 0.5 then
                    self:openSelected()
                end
                clickTime = now
            end)
        end
    end
    self.list.CanvasSize = UDim2.new(0, 0, 0, self.layout.AbsoluteContentSize.Y)
end

function FileExplorer:goUp()
    local parent = self.current:match("^(.*)/[^/]+$")
    if parent and parent ~= "" then
        self.current = parent
        self.pathBox.Text = relativePath(parent, "workspace")
        self:refresh()
    end
end

function FileExplorer:openSelected()
    local name = self.fileBox.Text
    if name == "" then return end
    if name:match("^https?://") then
        self:close()
        if self.onSelect then
            self.onSelect("URL:" .. name)
        end
        return
    end
    local full = (self.current == "" and "" or (self.current .. "/")) .. name
    if self.selected and self.selected.name == name then
        full = self.selected.path
    end
    self:close()
    if self.onSelect then
        self.onSelect(full)
    end
end

function FileExplorer:close()
    if self.gui then
        self.gui:Destroy()
        self.gui = nil
    end
    if FileExplorer.active == self then
        FileExplorer.active = nil
    end
end

return FileExplorer
