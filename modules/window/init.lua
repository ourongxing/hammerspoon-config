local M = require("modules.window.undoManager")
local W = {
  undo = M.undo,
  redo = M.redo
}

-- autolayout 外置是为了在 base transform 后重现开始
local nextLayout = nil

-- 一些预设的窗口变化
-- superposition 就是叠加之前的状态，比如之前是上半屏，再按右半屏就是右上四分之一，就是叠加。
function W.transfrom(win, type, superposition)
  local gap = V.Gap or 6
  local screen = hs.screen.mainScreen():frame()
  local app = win:application()
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
  -- 顶上不要 gap

  local fullW = screen.w - gap * 2
  local fullH = screen.h - gap

  -- gap + halfW + gap + halfW + gap = screen.w
  -- // 表示向下取整，避免后续判断相同 frame 不准确
  local halfW = (screen.w - gap) // 2 - gap
  local halfX = screen.x + gap + halfW + gap

  -- y 是有值的，x 没值（如果多屏幕，x 可能为负数），应该是计算了状态栏，而 screen.h 不包括状态栏，当然也不包括 dock 栏
  -- halfH + gap + halfH + gap = screen.h
  local halfH = screen.h // 2 - gap
  local halfY = screen.y + halfH + gap

  -- gap + oneThirdW  + gap + twoThirdW + gap = screen.w
  local oneThirdW = screen.w // 3 - gap
  local oneThirdX = screen.x + gap + oneThirdW + gap

  local twoThirdW = screen.w - 3 * gap - oneThirdW
  local twoThirdX = screen.x + gap + twoThirdW + gap

  -- oneThirdH + gap + twoThirdH + gap = screen.h
  local oneThirdH = (screen.h - 2 * gap) // 3
  local oneThirdY = screen.y + oneThirdH + gap

  local twoThirdH = screen.h - 2 * gap - oneThirdH
  local twoThirdY = screen.y + twoThirdH + gap

  local presets = {
    full = { x = screen.x + gap, y = screen.y, w = fullW, h = fullH },
    left = { x = screen.x + gap, y = screen.y, w = halfW, h = fullH },
    ["left-1/3"] = { x = screen.x + gap, y = screen.y, w = oneThirdW, h = fullH },
    ["left-2/3"] = { x = screen.x + gap, y = screen.y, w = twoThirdW, h = fullH },
    right = { x = halfX, y = screen.y, w = halfW, h = fullH },
    ["right-1/3"] = { x = twoThirdX, y = screen.y, w = oneThirdW, h = fullH },
    ["right-2/3"] = { x = oneThirdX, y = screen.y, w = twoThirdW, h = fullH },
    top = { x = screen.x + gap, y = screen.y, w = fullW, h = halfH },
    ["top-1/3"] = { x = screen.x + gap, y = screen.y, w = fullW, h = oneThirdH },
    ["top-2/3"] = { x = screen.x + gap, y = screen.y, w = fullW, h = twoThirdH },
    bottom = { x = screen.x + gap, y = halfY, w = fullW, h = halfH },
    ["bottom-1/3"] = { x = screen.x + gap, y = twoThirdY, w = fullW, h = oneThirdH },
    ["bottom-2/3"] = { x = screen.x + gap, y = oneThirdY, w = fullW, h = twoThirdH },
    ["left-top"] = { x = screen.x + gap, y = screen.y, w = halfW, h = halfH },
    ["left-bottom"] = { x = screen.x + gap, y = halfY, w = halfW, h = halfH },
    ["right-top"] = { x = halfX, y = screen.y, w = halfW, h = halfH },
    ["right-bottom"] = { x = halfX, y = halfY, w = halfW, h = halfH },
    reasonable = {
      x = screen.x + screen.w * 0.2,
      y = screen.y + screen.h * 0.1,
      w = screen.w * 0.6,
      h = screen.h * 0.8,
    },
    center = {
      x = screen.x + (screen.w - origin.w) / 2,
      y = screen.y + (screen.h - origin.h) / 2 - gap,
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
        { "top",                      type .. "-" .. "top" },
        { "bottom",                   type .. "-" .. "bottom" },
        { reverse .. "-" .. "top",    type .. "-" .. "top" },
        { reverse .. "-" .. "bottom", type .. "-" .. "bottom" },
        { type,                       reverse },
      }
      preset = withPatterns(patterns, type)
    elseif type == "top" or type == "bottom" then
      local reverse = type == "bottom" and "top" or "bottom"
      local patterns = {
        { "left",                    "left" .. "-" .. type },
        { "right",                   "right" .. "-" .. type },
        { "left" .. "-" .. reverse,  "left" .. "-" .. type },
        { "right" .. "-" .. reverse, "right" .. "-" .. type },
        { type,                      reverse },
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
  if not win then return end
  local screen = hs.screen.mainScreen()
  -- id 并没有按照 123 排序
  local spaces = hs.spaces.spacesForScreen(screen:id())
  if not spaces or #spaces == 0 then return end
  local prev = U.loopArrayItem(hs.spaces.focusedSpace(), spaces, shift)
  M.undoManager(function()
    hs.spaces.moveWindowToSpace(win, prev)
    win:focus()
  end, {
    -- focus win 不会变化
    fn = function()
      win:focus()
    end
  })
end

-- 自动排列窗口, 通常是两个窗口的情况，多余窗口不变化。
function W.autoLayout(shift)
  local leftTopFirst = V.LeftTopFirst ~= nil or V.LeftTopFirst or true
  -- 额，shift 为 true，压根不看 leftTopFirst 了，这和三目运算符还有点不同
  -- leftTopFirst = shift and (not leftTopFirst) or leftTopFirst
  if shift then leftTopFirst = not leftTopFirst end
  local layout =
      leftTopFirst and {
        { "left-2/3", "right-1/3" },
        { "left",     "right" },
        { "top-2/3",  "bottom-1/3" },
        { "top",      "bottom" },
      } or {
        { "right-2/3",  "left-1/3" },
        { "right",      "left" },
        { "bottom-2/3", "top-1/3" },
        { "bottom",     "top" },
      }

  local windows = U.currentSpaceWindows()
  if #windows ~= 0 then
    -- 如果窗口不一样，就重新开始循环，包括焦点变了
    if not nextLayout or nextLayout[1] ~= windows[1] then
      nextLayout = { windows[1], 1 }
    end
    local pattern = layout[nextLayout[2]]
    if windows[2] then W.transfrom(windows[2], pattern[2]) end
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
    if target == current then return end
    target = U.nextScreen(target)
    targetWindows = U.currentSpaceWindows(target)
  end

  M.undoManager(function()
    -- 貌似这个 focus 不同屏幕上相同 app 的窗口，会优先 focus 当前屏幕的
    targetWindows[1]:focus()
    hs.mouse.absolutePosition(targetWindows[1]:frame().center)
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

-- 将任意屏幕的鼠标移动到主屏幕，同时切换焦点
function W.focusToPrimaryScreen()
  local targetScreen = hs.screen.primaryScreen()
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

-- 将任意屏幕的窗口移动到主屏幕
function W.moveToPrimaryScreen()
  local win = U.currentWindow()
  if not win then return end
  local current = win:screen()
  local currentFrame = win:frame()
  local target = hs.screen.primaryScreen()
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
      M.undoManager(function() next:focus() end)
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
      end
    })
  end
end

-- 关闭窗口，先移动到最后一个 space，然后 10s 后关闭，可以 redo。最好是创建一个空白的 space 用来放这个 window。
function W.closeWindownSafely()
  -- minimize 不太好用，有动画，还是这个好。
  local win = U.currentWindow()
  -- 都放到主显示器最后一个 space
  local screen = hs.screen.primaryScreen()
  -- id 并没有按照 123 排序
  local spaces = hs.spaces.spacesForScreen(screen:id())
  if not spaces or #spaces == 0 then return end

  -- 10s 后关闭
  local timer = hs.timer.doAfter(10, function()
    win:close()
  end)

  M.undoManager(function()
    hs.spaces.moveWindowToSpace(win, spaces[#spaces])
  end, { fn = function() timer:stop() end
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
