-- Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Local Player & Camera
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Detect Game Defaults for Universal Settings
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local defaultWS = humanoid.WalkSpeed
local defaultJP = humanoid.JumpPower

-- Settings & State
local SETTINGS = {
	Smoothing = 0.15,
	Prediction = 0.135,
	FOV_Radius = 150,
	LockKey = Enum.KeyCode.E,
	UIToggleKey = Enum.KeyCode.B,
	TriggerKey = Enum.KeyCode.T,
	ESPKey = Enum.KeyCode.H,
	FOVKey = Enum.KeyCode.V,
	FOV_Color = Color3.fromRGB(255, 0, 0),
	WalkSpeed = defaultWS,
	JumpPower = defaultJP 
}

local lockOn = false
local triggerActive = false
local fireDelay = 0.2
local lastShot = 0
local espEnabled = false
local showFOV = false

-- UI Theme
local THEME = {
	BG = Color3.fromRGB(11, 13, 18),
	PANEL = Color3.fromRGB(14, 17, 24),
	PANEL_2 = Color3.fromRGB(18, 22, 31),
	STROKE = Color3.fromRGB(70, 86, 115),
	TEXT = Color3.fromRGB(245, 248, 255),
	MUTED = Color3.fromRGB(165, 175, 195),
	MUTED_2 = Color3.fromRGB(195, 205, 225),
	ACCENT = Color3.fromRGB(60, 160, 255),
	ACCENT_2 = Color3.fromRGB(110, 200, 255),
	ACCENT_DARK = Color3.fromRGB(10, 16, 24),
}

-- FOV Drawing
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Radius = SETTINGS.FOV_Radius
FOVCircle.Filled = false
FOVCircle.Visible = showFOV
FOVCircle.Color = SETTINGS.FOV_Color
FOVCircle.Transparency = 0.7

-- UI Utils
local function tween(inst: Instance, ti: TweenInfo, props: {[string]: any})
	TweenService:Create(inst, ti, props):Play()
end

local function mk(className: string, props: {[string]: any}, parent: Instance?): Instance
	local inst = Instance.new(className)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(parent: Instance, r: number)
	mk("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
end

-- Logic Functions
local function getPrediction(part)
	if part.Parent:FindFirstChild("HumanoidRootPart") then
		return part.Position + (part.Parent.HumanoidRootPart.Velocity * SETTINGS.Prediction)
	end
	return part.Position
end

local function isVisible(part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character, Camera}
	local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
	return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function getBestTarget()
	local bestTarget, shortestDist = nil, math.huge
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("Head") then
			local head = p.Character.Head
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and isVisible(head) then
				local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
				local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
				if onScreen and distFromCenter <= SETTINGS.FOV_Radius then
					if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						local worldDist = (player.Character.HumanoidRootPart.Position - head.Position).Magnitude
						if worldDist < shortestDist then
							shortestDist = worldDist; bestTarget = head
						end
					end
				end
			end
		end
	end
	return bestTarget
end

-- UI Main
local gui = mk("ScreenGui", {Name = "NexoHubUI", ResetOnSpawn = false, IgnoreGuiInset = true}, PlayerGui) :: ScreenGui
local blur = Lighting:FindFirstChild("NexoHubBlur") :: BlurEffect?
	or mk("BlurEffect", {Name="NexoHubBlur", Size=0}, Lighting)

local toggle = mk("TextButton", {
	Name = "FloatingToggle", 
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = THEME.ACCENT, Text = "N", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = THEME.ACCENT_DARK, AutoButtonColor = false
}, gui) :: TextButton
corner(toggle, 999)
mk("UIStroke", {Color = THEME.ACCENT_2, Thickness = 2, Transparency = 0.30}, toggle)

-- Draggable Logic
do
	local dragging, dragStart, startPos, lastInput = false, Vector2.zero, UDim2.new(), nil
	toggle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastInput, dragStart, startPos = true, input, input.Position, toggle.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			toggle.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input) if input == lastInput then dragging = false end end)
end

local root = mk("Frame", {
	Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(860, 500), BackgroundColor3 = THEME.BG, Visible = true
}, gui) :: Frame
corner(root, 18);
mk("UIStroke", {Color = THEME.ACCENT, Thickness = 1, Transparency = 0.62}, root)

local topbar = mk("Frame", {Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58)}, root)
mk("TextLabel", {
    BackgroundTransparency = 1, 
    Position = UDim2.fromOffset(20, 16), 
    Size = UDim2.new(1, -40, 0, 24), 
    Font = Enum.Font.GothamBold, 
    Text = "NEXO HUB | FLICK", -- Updated Title
    TextColor3 = THEME.TEXT, 
    TextSize = 22, 
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)

local sidebar = mk("Frame", {Name = "Sidebar", Position = UDim2.fromOffset(14, 66), Size = UDim2.fromOffset(230, 420), BackgroundColor3 = THEME.PANEL}, root)
corner(sidebar, 16);
mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
mk("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, sidebar)

local content = mk("Frame", {Name = "Content", Position = UDim2.fromOffset(254, 66), Size = UDim2.fromOffset(592, 420), BackgroundColor3 = THEME.PANEL}, root)
corner(content, 16)
local pages = mk("Folder", {Name = "Pages"}, content)

local function makeNavButton(text: string, order: number)
	local btn = mk("TextButton", {LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.PANEL_2, Text = text, Font = Enum.Font.GothamSemibold, TextSize = 15, TextColor3 = THEME.MUTED_2, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, sidebar)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 12)}, btn);
	corner(btn, 14)
	local st = mk("UIStroke", {Color = THEME.ACCENT, Thickness = 2, Transparency = 1}, btn)
	return btn, st
end

local function makePage(name: string)
	local page = mk("ScrollingFrame", {Name = name, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 5, ScrollBarImageColor3 = THEME.ACCENT, BackgroundTransparency = 1, Visible = false}, pages)
	mk("UIPadding", {PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14)}, page)
	local layout = mk("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18) end)
	return page
end

local function makeCard(parent: Instance, header: string, sub: string)
	local card = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = THEME.PANEL_2}, parent)
	corner(card, 16); mk("UIStroke", {Color = THEME.STROKE, Thickness = 1, Transparency = 0.70}, card)
	mk("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, card)
	mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, card)
	mk("TextLabel", {LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, Text = header, TextSize = 17, TextColor3 = THEME.TEXT, TextXAlignment = Enum.TextXAlignment.Left}, card)
	mk("TextLabel", {LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Gotham, Text = sub, TextSize = 13, TextColor3 = THEME.MUTED, TextXAlignment = Enum.TextXAlignment.Left}, card)
	local inner = mk("Frame", {LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, card)
	mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, inner)
	return inner
end

-- UI Controls
local function addToggle(parent: Instance, label: string, default: boolean, onChanged: ((boolean) -> ())?)
	local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1}, parent)
	mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -64, 1, 0), Font = Enum.Font.GothamSemibold, Text = label, TextSize = 14, TextColor3 = THEME.TEXT, TextXAlignment = Enum.TextXAlignment.Left}, row)
	local btn = mk("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(54, 26), BackgroundColor3 = Color3.fromRGB(26, 31, 44), Text = "", AutoButtonColor = false}, row)
	corner(btn, 999); local knob = mk("Frame", {Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(170, 185, 210), BorderSizePixel = 0}, btn);
	corner(knob, 999)
	
	local state = default
	local function render()
		tween(btn, TweenInfo.new(0.12), {BackgroundColor3 = state and THEME.ACCENT or Color3.fromRGB(26, 31, 44)})
		tween(knob, TweenInfo.new(0.12), {Position = state and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3)})
	end
	
	btn.MouseButton1Click:Connect(function() state = not state; render(); if onChanged then onChanged(state) end end)
	render();
	return {
		Set = function(v: boolean) state = v; render() end,
		Get = function() return state end
	}
end

local function addSlider(parent: Instance, label: string, min: number, max: number, default: number, precision: number, onChanged: ((number) -> ())?)
	local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1}, parent)
	local top = mk("Frame", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1}, holder)
	mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0), Font = Enum.Font.GothamSemibold, Text = label, TextSize = 13, TextColor3 = THEME.MUTED_2, TextXAlignment = Enum.TextXAlignment.Left}, top)
	local v = mk("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(80, 18), Font = Enum.Font.GothamBold, Text = tostring(default), TextSize = 13, TextColor3 = THEME.TEXT, TextXAlignment = Enum.TextXAlignment.Right}, top)
	local bar = mk("Frame", {Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(16, 20, 30)}, holder);
	corner(bar, 999)
	local fill = mk("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.ACCENT}, bar);
	corner(fill, 999)
	local knob = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = THEME.TEXT}, bar);
	corner(knob, 999)
	local dragging = false
	local function update(input)
		local pc = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local val = min + (max - min) * pc
		val = math.floor(val / precision + 0.5) * precision
		v.Text = string.format("%." .. (tostring(precision):find("%.") and #tostring(precision) - tostring(precision):find("%.") or 0) .. "f", val)
		fill.Size = UDim2.fromScale(pc, 1);
		knob.Position = UDim2.fromScale(pc, 0.5)
		if onChanged then onChanged(val) end
	end
	bar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(input) end end)
	UIS.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end end)
	UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	local initialPc = (default - min) / (max - min);
	fill.Size = UDim2.fromScale(initialPc, 1); knob.Position = UDim2.fromScale(initialPc, 0.5)
end

local function addTextbox(parent: Instance, label: string, placeholder: string, onSubmit: ((string) -> ())?)
	local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1}, parent)
	mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamSemibold, Text = label, TextSize = 13, TextColor3 = THEME.MUTED_2, TextXAlignment = Enum.TextXAlignment.Left}, holder)
	local box = mk("TextBox", {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(16, 20, 30), Text = "", PlaceholderText = placeholder, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = THEME.TEXT, ClearTextOnFocus = false}, holder)
	corner(box, 14);
	mk("UIStroke", {Color = THEME.STROKE, Thickness = 1, Transparency = 0.72}, box)
	box.FocusLost:Connect(function(ep) if ep and onSubmit then onSubmit(box.Text) end end)
end

local function addKeybind(parent: Instance, label: string, defaultKey: Enum.KeyCode, onChanged: ((Enum.KeyCode) -> ())?)
	local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1}, parent)
	mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -110, 1, 0), Font = Enum.Font.GothamSemibold, Text = label, TextSize = 14, TextColor3 = THEME.TEXT, TextXAlignment = Enum.TextXAlignment.Left}, holder)
	local btn = mk("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(102, 30), BackgroundColor3 = Color3.fromRGB(16, 20, 30), Text = defaultKey.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.TEXT, AutoButtonColor = false}, holder)
	corner(btn, 14); local waiting = false
	btn.MouseButton1Click:Connect(function() waiting = true; btn.Text = "..." end)
	UIS.InputBegan:Connect(function(input, gpe) if not gpe and waiting and input.KeyCode ~= Enum.KeyCode.Unknown then waiting = false; btn.Text = input.KeyCode.Name; if onChanged then onChanged(input.KeyCode) end end end)
end

-- Pages Initialization
local pageCombat = makePage("Combat")
local pageAim = makePage("Aim")
local pageVisuals = makePage("Visuals")
local pageUniversal = makePage("Universal")

local nav = {
	Combat = {page = pageCombat, btn = nil, stroke = nil},
	Aim = {page = pageAim, btn = nil, stroke = nil},
	Visuals = {page = pageVisuals, btn = nil, stroke = nil},
	Universal = {page = pageUniversal, btn = nil, stroke = nil},
}

local function setTab(name: string)
	for k, t in pairs(nav) do
		t.page.Visible = (k == name)
		if t.stroke then t.stroke.Transparency = (k == name) and 0.15 or 1 end
		if t.btn then t.btn.BackgroundColor3 = (k == name) and Color3.fromRGB(18, 26, 40) or THEME.PANEL_2 end
	end
end

do
	local b1, s1 = makeNavButton("Combat", 1);
	nav.Combat.btn, nav.Combat.stroke = b1, s1
	local b2, s2 = makeNavButton("Aim", 2); nav.Aim.btn, nav.Aim.stroke = b2, s2
	local b3, s3 = makeNavButton("Visuals", 3);
	nav.Visuals.btn, nav.Visuals.stroke = b3, s3
	local b4, s4 = makeNavButton("Universal", 4);
	nav.Universal.btn, nav.Universal.stroke = b4, s4
end

for name, t in pairs(nav) do t.btn.MouseButton1Click:Connect(function() setTab(name) end) end

-- Content
local combatCard = makeCard(pageCombat, "Combat Assist", "Primary tools")
local aimlockToggle = addToggle(combatCard, "Aimlock", false, function(v) lockOn = v end)
addKeybind(combatCard, "Aimlock Keybind", Enum.KeyCode.E, function(k) SETTINGS.LockKey = k end)

local aimCard = makeCard(pageAim, "Aim Configuration", "Technical logic")
addSlider(aimCard, "Smoothing", 0.01, 1.0, 0.15, 0.01, function(v) SETTINGS.Smoothing = v end)
addSlider(aimCard, "Prediction", 0.001, 0.5, 0.135, 0.001, function(v) SETTINGS.Prediction = v end)
addSlider(aimCard, "FOV Radius", 50, 800, 150, 1, function(v) SETTINGS.FOV_Radius = v; FOVCircle.Radius = v end)

local triggerCard = makeCard(pageAim, "TriggerBot", "Auto engagement")
local triggerToggle = addToggle(triggerCard, "Enable TriggerBot", false, function(v) triggerActive = v end)
addTextbox(triggerCard, "Fire Delay", "0.2", function(t) fireDelay = tonumber(t) or 0.2 end)
addKeybind(triggerCard, "TriggerBot Keybind", SETTINGS.TriggerKey, function(k) SETTINGS.TriggerKey = k end)

local visualCard = makeCard(pageVisuals, "Player Visuals", "Tracking systems")
local espToggle = addToggle(visualCard, "Player ESP Highlights", false, function(v) espEnabled = v end)
local fovToggle = addToggle(visualCard, "Show FOV Circle", false, function(v) showFOV = v; FOVCircle.Visible = v end)
addKeybind(visualCard, "ESP Keybind", SETTINGS.ESPKey, function(k) SETTINGS.ESPKey = k end)
addKeybind(visualCard, "FOV Keybind", SETTINGS.FOVKey, function(k) SETTINGS.FOVKey = k end)

local universalCard = makeCard(pageUniversal, "Universal Character", "Character modifications")
addSlider(universalCard, "WalkSpeed Boost", defaultWS, 150, defaultWS, 1, function(v) SETTINGS.WalkSpeed = v end)
addSlider(universalCard, "JumpPower Boost", defaultJP, 300, defaultJP, 1, function(v) SETTINGS.JumpPower = v end)
addKeybind(universalCard, "UI Toggle Keybind", SETTINGS.UIToggleKey, function(k) SETTINGS.UIToggleKey = k end)

-- Core Engine
RunService.RenderStepped:Connect(function()
	FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	
	if lockOn then
		local target = getBestTarget()
		if target then
			local lookAt = CFrame.new(Camera.CFrame.Position, getPrediction(target))
			Camera.CFrame = Camera.CFrame:Lerp(lookAt, SETTINGS.Smoothing)
			
			if triggerActive and (tick() - lastShot) >= fireDelay then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = {player.Character, Camera}
				local res = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, params)
				if res and res.Instance:IsDescendantOf(target.Parent) then
					lastShot = tick();
					if mouse1click then mouse1click() end
				end
			end
		end
	end

	-- Character Logic
	local char = player.Character
	if char and char:FindFirstChildOfClass("Humanoid") then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if SETTINGS.WalkSpeed ~= defaultWS then hum.WalkSpeed = SETTINGS.WalkSpeed end
		if SETTINGS.JumpPower ~= defaultJP then hum.JumpPower = SETTINGS.JumpPower end
		hum.UseJumpPower = true
	end
end)

-- Global Keybinds
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == SETTINGS.LockKey then
		lockOn = not lockOn
		aimlockToggle.Set(lockOn)
	end
	if input.KeyCode == SETTINGS.TriggerKey then
		triggerActive = not triggerActive
		triggerToggle.Set(triggerActive)
	end
	if input.KeyCode == SETTINGS.ESPKey then
		espEnabled = not espEnabled
		espToggle.Set(espEnabled)
	end
	if input.KeyCode == SETTINGS.FOVKey then
		showFOV = not showFOV
		FOVCircle.Visible = showFOV
		fovToggle.Set(showFOV)
	end
	if input.KeyCode == SETTINGS.UIToggleKey then
		root.Visible = not root.Visible
		tween(blur, TweenInfo.new(0.2), {Size = root.Visible and 14 or 0})
	end
end)

-- ESP System
local function applyESP(p)
	if p == player then return end
	RunService.Heartbeat:Connect(function()
		local char = p.Character
		if char and char:FindFirstChild("Humanoid") then
			local h = char:FindFirstChild("FlickESP")
			if not h then
				h = Instance.new("Highlight", char);
				h.Name = "FlickESP"
				h.FillColor = THEME.ACCENT; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			end
			h.Enabled = espEnabled
		end
	end)
end

Players.PlayerAdded:Connect(applyESP);
for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end

toggle.MouseButton1Click:Connect(function()
	root.Visible = not root.Visible
	tween(blur, TweenInfo.new(0.2), {Size = root.Visible and 14 or 0})
end)

setTab("Combat")
