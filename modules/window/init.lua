local M = require("modules.window.undoManager")
local W = {
	undo = M.undo,
	redo = M.redo,
}

-- autolayout 外置是为了在 base transform 后重现开始
local nextLayout = nil

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

local function overlapsX(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x
end

local function hasStatusBarOnTop(frame)
	local screens = hs.screen.allScreens()
	if not screens then
		return false
	end
	for _, s in ipairs(screens) do
		local usable = s:frame()
		local full = s:fullFrame()
		if overlapsX(frame, usable) and math.abs(frame.y - usable.y) < 1 and usable.y > full.y then
			return true
		end
	end
	return false
end

local function insetFrame(frame, insets)
	local left = insets.left or 0
	local right = insets.right or 0
	local top = insets.top or 0
	local bottom = insets.bottom or 0
	return {
		x = frame.x + left,
		y = frame.y + top,
		w = math.max(1, frame.w - left - right),
		h = math.max(1, frame.h - top - bottom),
	}
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
	for _, f in ipairs({ leftFrame, rightFrame }) do
		if f and f.h > f.w then
			-- 竖屏超出横屏的部分：上、下两块；gap 在 preset 层统一应用
			local hTop = horizontalFrame.y - f.y
			local hBottom = (f.y + f.h) - (horizontalFrame.y + horizontalFrame.h)
			if hTop > 0 then
				verticalAbove = { x = f.x, y = f.y, w = f.w, h = hTop }
			end
			if hBottom > 0 then
				verticalBelow = {
					x = f.x,
					y = horizontalFrame.y + horizontalFrame.h,
					w = f.w,
					h = hBottom,
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
	local useUnified = V.UnifiedDisplayMaximize and #(hs.screen.allScreens() or {}) >= 2
	local screen, split
	if useUnified then
		screen, split = getUnifiedFrame()
	else
		screen = hs.screen.mainScreen():frame()
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
	-- 窗口之间以及屏幕外缘保留 gap；有状态栏的那一侧不额外留外缘 gap

	local fullW = screen.w
	local fullH = screen.h
	local innerGapA = gap // 2
	local innerGapB = gap - innerGapA

	local function gapped(frame, edges)
		local function edgeGap(edge, value)
			if value == true then
				if edge == "top" and hasStatusBarOnTop(frame) then
					return 0
				end
				return gap
			end
			return value or 0
		end
		return insetFrame(frame, {
			left = edgeGap("left", edges.left),
			right = edgeGap("right", edges.right),
			top = edgeGap("top", edges.top),
			bottom = edgeGap("bottom", edges.bottom),
		})
	end

	-- 有 split 时按两块屏幕比例划分，否则 50-50
	local leftRaw, rightRaw
	if split then
		leftRaw = { x = screen.x, y = split.leftScreen.y, w = split.leftW, h = split.leftScreen.h }
		rightRaw = { x = split.splitX, y = split.rightScreen.y, w = split.rightW, h = split.rightScreen.h }
	else
		local leftW = screen.w // 2
		leftRaw = { x = screen.x, y = screen.y, w = leftW, h = fullH }
		rightRaw = { x = screen.x + leftW, y = screen.y, w = screen.w - leftW, h = fullH }
	end

	-- y 是有值的，x 没值（如果多屏幕，x 可能为负数），应该是计算了状态栏，而 screen.h 不包括状态栏，当然也不包括 dock 栏
	local topH = screen.h // 2
	local topRaw = { x = screen.x, y = screen.y, w = fullW, h = topH }
	local bottomRaw = { x = screen.x, y = screen.y + topH, w = fullW, h = screen.h - topH }

	local function verticalPair(frame)
		local h = frame.h // 2
		return { x = frame.x, y = frame.y, w = frame.w, h = h },
			{ x = frame.x, y = frame.y + h, w = frame.w, h = frame.h - h }
	end
	local leftTopRaw, leftBottomRaw = verticalPair(leftRaw)
	local rightTopRaw, rightBottomRaw = verticalPair(rightRaw)

	local presets = {
		full = gapped({ x = screen.x, y = screen.y, w = fullW, h = fullH }, { left = true, right = true, top = true, bottom = true }),
		left = gapped(leftRaw, { left = true, right = innerGapA, top = true, bottom = true }),
		right = gapped(rightRaw, { left = innerGapB, right = true, top = true, bottom = true }),
		top = gapped(topRaw, { left = true, right = true, top = true, bottom = innerGapA }),
		bottom = gapped(bottomRaw, { left = true, right = true, top = innerGapB, bottom = true }),
		["vertical-above"] = split and split.verticalAbove
				and gapped(split.verticalAbove, { left = true, right = true, top = true, bottom = innerGapA })
			or gapped(topRaw, { left = true, right = true, top = true, bottom = innerGapA }),
		["vertical-below"] = split and split.verticalBelow
				and gapped(split.verticalBelow, { left = true, right = true, top = innerGapB, bottom = true })
			or gapped(bottomRaw, { left = true, right = true, top = innerGapB, bottom = true }),
		["left-top"] = gapped(leftTopRaw, { left = true, right = innerGapA, top = true, bottom = innerGapA }),
		["left-bottom"] = gapped(leftBottomRaw, { left = true, right = innerGapA, top = innerGapB, bottom = true }),
		["right-top"] = gapped(rightTopRaw, { left = innerGapB, right = true, top = true, bottom = innerGapA }),
		["right-bottom"] = gapped(rightBottomRaw, { left = innerGapB, right = true, top = innerGapB, bottom = true }),
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
	local windows = (V.UnifiedDisplayMaximize and screens and #screens >= 2)
		and U.currentSpaceWindows(screens)
		or U.currentSpaceWindows()
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

	-- local currentMouse = hs.mouse.absolutePosition()
	M.undoManager(function()
		-- 貌似这个 focus 不同屏幕上相同 app 的窗口，会优先 focus 当前屏幕的
		-- local win = U.currentWindow()
		targetWindows[1]:focus()
		-- if win then
		-- 	hs.mouse.absolutePosition(U.transformPoint(currentMouse, win:frame(), target:frame()))
		-- else
		hs.mouse.absolutePosition(targetWindows[1]:frame().center)
		-- end
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
	M.undoManager(function()
		win:move(currentframe:toUnitRect(current:frame()), target, true, 0)
		hs.mouse.absolutePosition(U.transformPoint(currentMouse, current:frame(), target:frame()))
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
	M.undoManager(function()
		if win then
			win:focus()
			hs.mouse.absolutePosition(win:frame().center)
		else
			hs.mouse.absolutePosition(targetScreen:frame().center)
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
	M.undoManager(function()
		hs.mouse.absolutePosition(U.transformPoint(currentMouse, current:frame(), target:frame()))
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
