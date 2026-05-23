local M = require("modules.window.undoManager")
local SingleTransform = require("modules.window.transform.single")
local UnifiedTransform = require("modules.window.transform.unified")
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
	local screens = hs.screen.allScreens() or {}
	if mode == "auto" then
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
	if #screens < 2 then
		return false
	end
	return true
end

local function screenMatchesListItem(screen, item)
	if not (screen and item) then
		return false
	end
	if type(item) == "number" then
		return screen:id() == item
	end
	if type(item) == "string" then
		return screen:name() == item or tostring(screen:id()) == item
	end
	return false
end

local function isUnifiedIsolatedScreen(screen)
	local isolated = V.UnifiedDisplayIsolatedScreens
	if type(isolated) ~= "table" then
		return false
	end
	for _, item in ipairs(isolated) do
		if screenMatchesListItem(screen, item) then
			return true
		end
	end
	return false
end

local function unifiedScreens()
	local result = {}
	for _, screen in ipairs(hs.screen.allScreens() or {}) do
		if not isUnifiedIsolatedScreen(screen) then
			result[#result + 1] = screen
		end
	end
	return result
end

local function screensAreOneHorizontalOneVertical(screens)
	if not screens or #screens ~= 2 then
		return false
	end
	local horizontal = 0
	local vertical = 0
	for _, screen in ipairs(screens) do
		local frame = screen:frame()
		if frame.w > frame.h then
			horizontal = horizontal + 1
		elseif frame.h > frame.w then
			vertical = vertical + 1
		end
	end
	return horizontal == 1 and vertical == 1
end

local function shouldUseUnifiedDisplayForScreen(screen)
	if not shouldUseUnifiedDisplay() or isUnifiedIsolatedScreen(screen) then
		return false
	end
	return screensAreOneHorizontalOneVertical(unifiedScreens())
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

function W.transfrom(win, type, superposition)
	if shouldUseUnifiedDisplayForScreen(win:screen()) then
		UnifiedTransform.transform(win, type, superposition, unifiedScreens())
	else
		SingleTransform.transform(win, type, superposition)
	end
end

function W.baseTransform(type)
	local win = U.currentWindow()
	nextLayout = nil
	W.transfrom(win, type, true)
end

function W.screenFull()
	local win = U.currentWindow()
	if not win then
		return
	end
	nextLayout = nil
	local app = win:application()
	local axApp = app and hs.axuielement.applicationElement(app)
	if axApp and axApp.AXEnhancedUserInterface then
		axApp.AXEnhancedUserInterface = false
	end

	local origin = win:frame()
	local preset = win:screen():frame()
	M.undoManager(function()
		win:setFrame(preset, U.allowAnimation(preset, origin) and 0.2 or 0)
	end, { win = win })
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
	local leftTopFirst = V.LeftTopFirst
	if leftTopFirst == nil then
		leftTopFirst = true
	end
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

	local current = U.currentWindow()
	if not current then
		return
	end
	local useUnified = shouldUseUnifiedDisplayForScreen(current:screen())
	local screens = useUnified and unifiedScreens() or nil
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
	local windows = shouldUseUnifiedDisplayForScreen(current:screen())
			and U.currentSpaceWindows(unifiedScreens(), hs.window.filter.sortByCreated)
		or U.currentSpaceWindows(current:screen(), hs.window.filter.sortByCreated)
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
