local M = require("modules.window.undoManager")
local W = {
	undo = M.undo,
	redo = M.redo,
}

-- autolayout 外置是为了在 base transform 后重现开始
local nextLayout = nil
local mousePositionsByScreenKey = "modules.window.mousePositionsByScreen"
local mousePositionsByScreen = hs.settings.get(mousePositionsByScreenKey) or {}
if type(mousePositionsByScreen) ~= "table" then
	mousePositionsByScreen = {}
end

-- 主屏 = 横屏（w > h），用于 unified 区域的 y、h 参考
local function getHorizontalScreenFrame()
	local screens = hs.screen.allScreens()
	if not screens or #screens == 0 then
		return hs.screen.mainScreen():frame()
	end
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.w > f.h then
			return f
		end
	end
	return hs.screen.mainScreen():frame()
end

-- 主屏 = 横屏的 screen 对象
local function getHorizontalScreen()
	local screens = hs.screen.allScreens()
	if not screens or #screens == 0 then
		return hs.screen.mainScreen()
	end
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.w > f.h then
			return s
		end
	end
	return hs.screen.mainScreen()
end

local function shouldUseUnifiedDisplay()
	local mode = V.UnifiedDisplayMaximize
	if mode == "auto" then
		local screens = hs.screen.allScreens() or {}
		if #screens < 2 then
			return false
		end
		if hs.spaces and hs.spaces.screensHaveSeparateSpaces then
			return not hs.spaces.screensHaveSeparateSpaces()
		end
		return true
	end
	if not mode then
		return false
	end
	local screens = hs.screen.allScreens() or {}
	if #screens < 2 then
		return false
	end
	return true
end

local function screenKey(screen)
	if not screen then
		return nil
	end
	return tostring(screen:id())
end

local function pointInFrame(point, frame)
	return point
			and frame
			and point.x >= frame.x
			and point.x <= frame.x + frame.w
			and point.y >= frame.y
			and point.y <= frame.y + frame.h
end

local function saveMousePositionForScreen(screen)
	local key = screenKey(screen)
	if not key then
		return
	end
	local point = hs.mouse.absolutePosition()
	local frame = screen:frame()
	if not pointInFrame(point, frame) then
		return
	end
	mousePositionsByScreen[key] = { x = point.x, y = point.y }
	hs.settings.set(mousePositionsByScreenKey, mousePositionsByScreen)
end

local function mousePositionForScreen(screen, fallback)
	local key = screenKey(screen)
	local point = key and mousePositionsByScreen[key] or nil
	if point and pointInFrame(point, screen:frame()) then
		return point
	end
	return fallback
end

local function moveMouseToScreen(screen, fallback)
	local point = mousePositionForScreen(screen, fallback or screen:frame().center)
	hs.mouse.absolutePosition(point)
	saveMousePositionForScreen(screen)
end

-- 获取统一显示区域 frame（关闭「显示器具有单独空间」时，两块屏视为一块虚拟桌面）
-- 主屏始终是横屏；x、w：水平总跨度；y、h：取横屏的 y、h
-- 两块 16:9 屏（一竖一横）并排 → 最大可用区域 25:9
-- 返回 frame 以及 split 信息（左块/右块 frame，竖屏可充分利用上下空间）
local function getUnifiedFrame()
	local screens = hs.screen.allScreens()
	if not screens or #screens < 2 then
		return hs.screen.mainScreen():frame(), nil
	end
	local horizontalFrame = getHorizontalScreenFrame()
	local minX, maxRight = math.huge, -math.huge
	local leftFrame, rightFrame
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.x < minX then
			minX = f.x
			leftFrame = f
		end
		maxRight = math.max(maxRight, f.x + f.w)
	end
	local splitX = minX + leftFrame.w
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.x >= splitX then
			rightFrame = f
			break
		end
	end
	rightFrame = rightFrame or horizontalFrame
	local verticalAbove, verticalBelow
	local gap = V.Gap or 6
	for _, f in ipairs({ leftFrame, rightFrame }) do
		if f and f.h > f.w then
			-- 竖屏超出横屏的部分：上、下两块，与横屏之间留 gap
			local hTop = horizontalFrame.y - f.y
			local hBottom = (f.y + f.h) - (horizontalFrame.y + horizontalFrame.h)
			if hTop > gap then
				verticalAbove = { x = f.x, y = f.y, w = f.w, h = hTop - gap // 2 }
			end
			if hBottom > gap then
				verticalBelow = {
					x = f.x,
					y = horizontalFrame.y + horizontalFrame.h + gap // 2,
					w = f.w,
					h = hBottom - (gap - gap // 2),
				}
			end
			break
		end
	end
	return {
		x = minX,
		y = horizontalFrame.y,
		w = maxRight - minX,
		h = horizontalFrame.h,
	}, {
		leftW = leftFrame.w,
		rightW = maxRight - splitX,
		splitX = splitX,
		leftScreen = leftFrame,
		rightScreen = rightFrame,
		verticalAbove = verticalAbove,
		verticalBelow = verticalBelow,
	}
end

-- 一些预设的窗口变化
-- superposition 就是叠加之前的状态，比如之前是上半屏，再按右半屏就是右上四分之一，就是叠加。
function W.transfrom(win, type, superposition)
	local gap = V.Gap or 6
	local useUnified = shouldUseUnifiedDisplay()
	local screen, split
	if useUnified then
		screen, split = getUnifiedFrame()
	else
		screen = win:screen():frame()
		split = nil
	end
	local app = win:application()
	-- 强制每次执行一次，关掉变换动画
	local axApp = hs.axuielement.applicationElement(app)
	if axApp and axApp.AXEnhancedUserInterface then
		axApp.AXEnhancedUserInterface = false
	end

	local origin = win:frame()
	if app:name() == "Raycast" and win:title() == "" then
		if type == "top" then
			hs.eventtap.keyStroke({}, "up", 200000, app)
		elseif type == "bottom" then
			hs.eventtap.keyStroke({}, "down", 200000, app)
		elseif type == "left" then
			hs.eventtap.keyStroke({}, "left", 200000, app)
		elseif type == "right" then
			hs.eventtap.keyStroke({}, "right", 200000, app)
		end
		return
	end

	-- 原点是左上角
	-- 只保留两个窗口之间的 gap，窗口与屏幕边缘不留 gap

	local fullW = screen.w
	local fullH = screen.h

	-- 有 split 时按两块屏幕比例划分，否则 50-50
	local halfWLeft, halfWRight, halfX
	local leftVerticalHalfH, leftVerticalHalfY, leftVerticalBottomH
	local rightVerticalHalfH, rightVerticalHalfY, rightVerticalBottomH
	if split then
		halfWLeft = split.leftW - gap // 2
		halfWRight = split.rightW - (gap - gap // 2)
		halfX = split.splitX + gap // 2
		-- 竖屏（h > w）可上下分半
		if split.leftScreen and split.leftScreen.h > split.leftScreen.w then
			leftVerticalHalfH = (split.leftScreen.h - gap) // 2
			leftVerticalHalfY = split.leftScreen.y + leftVerticalHalfH + gap
			leftVerticalBottomH = split.leftScreen.h - leftVerticalHalfH - gap
		end
		if split.rightScreen and split.rightScreen.h > split.rightScreen.w then
			rightVerticalHalfH = (split.rightScreen.h - gap) // 2
			rightVerticalHalfY = split.rightScreen.y + rightVerticalHalfH + gap
			rightVerticalBottomH = split.rightScreen.h - rightVerticalHalfH - gap
		end
	else
		halfWLeft = (screen.w - gap) // 2
		halfWRight = halfWLeft
		halfX = screen.x + halfWLeft + gap
	end

	-- y 是有值的，x 没值（如果多屏幕，x 可能为负数），应该是计算了状态栏，而 screen.h 不包括状态栏，当然也不包括 dock 栏
	-- halfH + gap + halfH = screen.h
	local halfH = (screen.h - gap) // 2
	local halfY = screen.y + halfH + gap

	-- 竖屏用完整高度，横屏用 unified 区域高度
	local function verticalH(frame) return frame and frame.h > frame.w and frame.h or fullH end
	local function verticalY(frame) return frame and frame.h > frame.w and frame.y or screen.y end
	local leftH = split and verticalH(split.leftScreen) or fullH
	local leftY = split and verticalY(split.leftScreen) or screen.y
	local rightH = split and verticalH(split.rightScreen) or fullH
	local rightY = split and verticalY(split.rightScreen) or screen.y
	local presets = {
		full = { x = screen.x, y = screen.y, w = fullW, h = fullH },
		left = { x = screen.x, y = leftY, w = halfWLeft, h = leftH },
		right = { x = halfX, y = rightY, w = halfWRight, h = rightH },
		top = { x = screen.x, y = screen.y, w = fullW, h = halfH },
		bottom = { x = screen.x, y = halfY, w = fullW, h = halfH },
		["vertical-above"] = split and split.verticalAbove or { x = screen.x, y = screen.y, w = fullW, h = halfH },
		["vertical-below"] = split and split.verticalBelow or { x = screen.x, y = halfY, w = fullW, h = halfH },
		["left-top"] = { x = screen.x, y = leftY, w = halfWLeft, h = leftVerticalHalfH or halfH },
		["left-bottom"] = { x = screen.x, y = leftVerticalHalfY or halfY, w = halfWLeft, h = leftVerticalBottomH or halfH },
		["right-top"] = { x = halfX, y = rightY, w = halfWRight, h = rightVerticalHalfH or halfH },
		["right-bottom"] = { x = halfX, y = rightVerticalHalfY or halfY, w = halfWRight, h = rightVerticalBottomH or halfH },
		reasonable = {
			x = win:screen():frame().x + win:screen():frame().w * 0.2,
			y = win:screen():frame().y + win:screen():frame().h * 0.1,
			w = win:screen():frame().w * 0.6,
			h = win:screen():frame().h * 0.8,
		},
		center = {
			x = screen.x + (screen.w - origin.w) / 2,
			y = screen.y + (screen.h - origin.h) / 2,
			w = origin.w,
			h = origin.h,
		},
	}

	local function withPatterns(patterns, fallback)
		for _, v in ipairs(patterns) do
			if origin == presets[v[1]] then
				return presets[v[2]]
			end
		end
		return presets[fallback]
	end

	local preset = presets[type]
	if superposition then
		if type == "left" or type == "right" then
			local reverse = type == "right" and "left" or "right"
			local patterns = {
				{ "top", type .. "-" .. "top" },
				{ "bottom", type .. "-" .. "bottom" },
				{ reverse .. "-" .. "top", type .. "-" .. "top" },
				{ reverse .. "-" .. "bottom", type .. "-" .. "bottom" },
				{ type, reverse },
			}
			preset = withPatterns(patterns, type)
		elseif type == "top" or type == "bottom" then
			local reverse = type == "bottom" and "top" or "bottom"
			local patterns = {
				{ "left", "left" .. "-" .. type },
				{ "right", "right" .. "-" .. type },
				{ "left" .. "-" .. reverse, "left" .. "-" .. type },
				{ "right" .. "-" .. reverse, "right" .. "-" .. type },
				{ type, reverse },
			}
			preset = withPatterns(patterns, type)
		end
	end

	M.undoManager(function()
		win:setFrame(preset, U.allowAnimation(preset, origin) and 0.2 or 0)
	end, { win = win })
end

function W.baseTransform(type)
	local win = U.currentWindow()
	nextLayout = nil
	W.transfrom(win, type, true)
end

-- 左右循环 space
function W.switchSpace(shift)
	local win = U.currentWindow()
	if not win then
		return
	end
	local screen = hs.screen.mainScreen()
	-- id 并没有按照 123 排序
	local spaces = hs.spaces.spacesForScreen(screen:id())
	if not spaces or #spaces == 0 then
		return
	end
	local prev = U.loopArrayItem(hs.spaces.focusedSpace(), spaces, shift)
	M.undoManager(function()
		hs.spaces.moveWindowToSpace(win, prev)
		win:focus()
	end, {
		-- focus win 不会变化
		fn = function()
			win:focus()
		end,
	})
end

-- 自动排列窗口, 通常是两个窗口的情况，多余窗口不变化。
function W.autoLayout(shift)
	local leftTopFirst = V.LeftTopFirst ~= nil or V.LeftTopFirst or true
	-- 额，shift 为 true，压根不看 leftTopFirst 了，这和三目运算符还有点不同
	-- leftTopFirst = shift and (not leftTopFirst) or leftTopFirst
	if shift then
		leftTopFirst = not leftTopFirst
	end
	local layout = leftTopFirst
			and {
				{ "left", "right" },
				{ "top", "bottom" },
			}
		or {
			{ "right", "left" },
			{ "bottom", "top" },
		}

	local screens = hs.screen.allScreens()
	local useUnified = shouldUseUnifiedDisplay()
	local current = U.currentWindow()
	if not current then
		return
	end
	local windows = useUnified
		and U.currentSpaceWindows(screens)
		or U.currentSpaceWindows(current:screen())
	if #windows ~= 0 then
		-- 如果窗口不一样，就重新开始循环，包括焦点变了
		if not nextLayout or nextLayout[1] ~= windows[1] then
			nextLayout = { windows[1], 1 }
		end
		local pattern = layout[nextLayout[2]]
		if windows[2] then
			W.transfrom(windows[2], pattern[2])
		end
		W.transfrom(windows[1], pattern[1])
		nextLayout[2] = nextLayout[2] % #layout + 1
	end
end

-- 切换显示器焦点以及鼠标，焦点需要有窗口
function W.focusToNextScreen()
	local currentWindow = U.currentWindow()
	if not currentWindow then
		return
	end
	local current = currentWindow:screen()
	local target = U.nextScreen(current)
	local targetWindows = U.currentSpaceWindows(target)

	-- not 0 == false
	while #targetWindows == 0 do
		if target == current then
			return
		end
		target = U.nextScreen(target)
		targetWindows = U.currentSpaceWindows(target)
	end

	saveMousePositionForScreen(hs.mouse.getCurrentScreen())
	M.undoManager(function()
		-- 貌似这个 focus 不同屏幕上相同 app 的窗口，会优先 focus 当前屏幕的
		targetWindows[1]:focus()
		moveMouseToScreen(target, targetWindows[1]:frame().center)
	end)
end

-- 移动到下一块屏幕，顺序未知，可能是按照连接的先后顺序
function W.moveToNextScreen()
	local win = U.currentWindow()
	if not win then
		return
	end
	local current = win:screen()
	local currentframe = win:frame()
	local target = U.nextScreen(current)
	local currentMouse = hs.mouse.absolutePosition()
	saveMousePositionForScreen(hs.mouse.getCurrentScreen())
	M.undoManager(function()
		win:move(currentframe:toUnitRect(current:frame()), target, true, 0)
		hs.mouse.absolutePosition(U.transformPoint(currentMouse, current:frame(), target:frame()))
		saveMousePositionForScreen(target)
	end)
end

-- 焦点切到主屏（横屏），鼠标跟随
function W.focusToPrimaryScreen()
	local targetScreen = getHorizontalScreen()
	local currentScreen = hs.mouse.getCurrentScreen()
	if not (targetScreen and currentScreen) then
		return
	end

	local win = U.currentSpaceWindows(targetScreen)[1]
	saveMousePositionForScreen(currentScreen)
	M.undoManager(function()
		if win then
			win:focus()
			moveMouseToScreen(targetScreen, win:frame().center)
		else
			moveMouseToScreen(targetScreen, targetScreen:frame().center)
		end
	end)
end

-- 将窗口移动到主屏（横屏）
function W.moveToPrimaryScreen()
	local win = U.currentWindow()
	if not win then
		return
	end
	local current = win:screen()
	local currentFrame = win:frame()
	local target = getHorizontalScreen()
	local currentMouse = hs.mouse.absolutePosition()
	saveMousePositionForScreen(hs.mouse.getCurrentScreen())
	M.undoManager(function()
		hs.mouse.absolutePosition(U.transformPoint(currentMouse, current:frame(), target:frame()))
		saveMousePositionForScreen(target)
		win:move(currentFrame:toUnitRect(current:frame()), target, true, 0)
		win:focus()
	end)
end

-- 同一屏幕的焦点切换
function W.focusToNextWindow()
	local current = U.currentWindow()
	-- 保持一个固定的顺序，默认是按照 focus 的顺序，会一直变化
	local windows = U.currentSpaceWindows(current:screen(), hs.window.filter.sortByCreated)
	if #windows > 1 then
		local index = U.indexOf(windows, current)
		if index then
			local next = windows[index % #windows + 1]
			M.undoManager(function()
				next:focus()
			end)
		end
	end
end

-- 关闭应用，先隐藏，然后 10s 后关闭，可以 redo
function W.quitAppSafely()
	local app = U.currentWindow():application()
	if app then
		local id = app:bundleID()
		app:hide()
		-- 10s 后关闭
		local timer = hs.timer.doAfter(10, function()
			app:kill()
		end)
		M.undoManager(nil, {
			fn = function()
				timer:stop()
				if app then
					app:unhide()
				end
				hs.application.launchOrFocusByBundleID(id)
			end,
		})
	end
end

-- 关闭窗口，先移动到最后一个 space，然后 10s 后关闭，可以 redo。最好是创建一个空白的 space 用来放这个 window。
function W.closeWindownSafely()
	-- minimize 不太好用，有动画，还是这个好。
	local win = U.currentWindow()
	-- 都放到主屏（横屏）的最后一个 space
	local screen = getHorizontalScreen()
	-- id 并没有按照 123 排序
	local spaces = hs.spaces.spacesForScreen(screen:id())
	if not spaces or #spaces == 0 then
		return
	end

	-- 10s 后关闭
	local timer = hs.timer.doAfter(10, function()
		win:close()
	end)

	M.undoManager(function()
		hs.spaces.moveWindowToSpace(win, spaces[#spaces])
	end, {
		fn = function()
			timer:stop()
		end,
	})
end

function W.toggleFullScreen()
	M.undoManager(function()
		U.currentWindow():toggleFullScreen()
	end)
end

-- 重启当前 app 或者指定 app
function W.restartApp(appId)
	local app = nil
	if appId then
		-- 只能获取正在运行的
		app = hs.application.get(appId)
	else
		app = U.currentWindow():application()
		appId = app and app:bundleID()
	end
	if app and appId then
		app:kill9()
		local flag = nil
		repeat
			flag = not (app and app:isRunning())
		until flag == true
		hs.application.launchOrFocusByBundleID(appId)
	end
end

-- 切换 app 的状态，比如正在运行就关闭，关闭就运行
function W.switchApp(appId)
	if appId then
		local app = hs.application.get(appId)
		if app and app:isRunning() then
			app:kill()
		else
			hs.application.launchOrFocusByBundleID(appId)
		end
	end
end

return W
