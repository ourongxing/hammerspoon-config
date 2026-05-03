-- 当前屏幕可见的 Space 的所有窗口
-- screen: 单个 screen 或 screen 数组（unified 模式下传 allScreens 以包含所有屏）
function U.currentSpaceWindows(screen, sortOrder)
  if not sortOrder then sortOrder = hs.window.filter.sortByFocusedLast end
  if not screen then screen = hs.screen.mainScreen() end
  -- 默认 currentSpace 包括了当前所有显示器可见的窗口，指的是整个 mission control 的 space。
  -- 可以通过设置 allowScreens 来筛选
  -- 我发现一旦全屏之后，就算不再全屏，也会被筛选出去
  -- 这些属性，比如  currentSpace，如果为 nil，那就是所有 space 的窗口，但如果是 false，就只有非当前 space 的窗口。
  ---@return hs.window[]
  local allowScreens = type(screen) == "table" and (function()
    local ids = {}
    for _, s in ipairs(screen) do
      ids[#ids + 1] = s:id()
    end
    return ids
  end)() or screen:id()
  local windows = hs.window.filter.new(true):setOverrideFilter({
    visible = true,
    allowRoles = { "AXStandardWindow" },
    allowScreens = allowScreens,
    currentSpace = true
  }):getWindows(sortOrder)
  return windows
end

function U.currentWindow()
  local win = hs.window.focusedWindow()
  if not win then
    win = hs.window.frontmostWindow()
    win:focus()
  end
  return win
end

-- 下一个屏幕，不包括 Sidecar，顺序大概是显示器连接先后的顺序
---@return hs.screen
function U.nextScreen(current)
  local target = current
  -- repeat
    target = target:next()
  -- until target:name() and not string.find(target:name(), "Sidecar")
  return target
end

---@return hs.screen
function U.previousScreen(current)
  local target = current
  -- repeat
    target = target:previous()
  -- until target:name() and not string.find(target:name(), "Sidecar")
  return target
end

function U.screens()
  -- filter Sidecat
  local screens = hs.screen.allScreens()
  local result = {}
  if not screens then return result end
  for _, screen in ipairs(screens) do
    -- if not string.find(screen:name(), "Sidecar") then
      table.insert(result, screen)
    -- end
  end
end

-- 如果位置和大小只有一个有变化，就加动画，如果两者都有变化，变换会被打断
function U.allowAnimation(f, o)
  return (f.x == o.x and f.y == o.y) or (f.w == o.w and f.h == o.h)
end

-- 修复 animationDuration = 0 不起作用
function U.fixAnimation(win, fn)
  local axApp = hs.axuielement.applicationElement(win:application())
  if not axApp then
    fn()
    return
  end
  local status = axApp.AXEnhancedUserInterface
  if status then
    axApp.AXEnhancedUserInterface = false
    fn()
    axApp.AXEnhancedUserInterface = true
  else
    fn()
  end
end

-- 修复 animationDuration 不起作用，总是有一个默认时常的动画
-- 如果平时不使用旁白，可以直接关闭 AXEnhancedUserInterface 属性，可能效果会好点。否则就需要在 transform 里开关。
-- https://github.com/ourongxing/problems/issues/39
function U.disableAXEnhancedUserInterface(win)
  local axApp = hs.axuielement.applicationElement(win:application())
  if not axApp then return end
  local status = axApp.AXEnhancedUserInterface
  if status then axApp.AXEnhancedUserInterface = false end
end

function U.spaceOf(win)
  return hs.spaces.windowSpaces(win)[1]
end

function U.windowEvent(fn)
  -- 订阅 focus 事件，只有 focus 在 filter 里的窗口，才会触发
  local filter = hs.window.filter.new(true):setOverrideFilter({
    allowRoles = { "AXStandardWindow" },
    visible = true,
    -- currentSpace = true -- 关了才会触发 Created 事件
  })
  if fn.created then filter:subscribe(hs.window.filter.windowCreated, fn.created) end
  if fn.focused then filter:subscribe(hs.window.filter.windowFocused, fn.focused) end
  if fn.unfocused then filter:subscribe(hs.window.filter.windowUnfocused, fn.unfocused) end
end

local displaySleepLayoutSnapshot = nil
local displayWakeRestoreTimer = nil

local function snapshotWindowsForDisplaySleep()
  local filter = hs.window.filter.new(true):setOverrideFilter({
    visible = true,
    allowRoles = { "AXStandardWindow" },
  })
  local wins = filter:getWindows()
  local list = {}
  for _, win in ipairs(wins) do
    local app = win:application()
    local pid = app and app:pid()
    local f = win:frame()
    if pid and f and f.x and f.w then
      list[#list + 1] = {
        id = win:id(),
        pid = pid,
        title = win:title() or "",
        frame = { x = f.x, y = f.y, w = f.w, h = f.h },
      }
    end
  end
  displaySleepLayoutSnapshot = list
end

local function findWindowForLayoutEntry(entry)
  if entry.id then
    local w = hs.window.get(entry.id)
    if w and w:application() and w:application():pid() == entry.pid then
      return w
    end
  end
  local app = hs.application.get(entry.pid)
  if not app then return nil end
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() and (w:title() or "") == entry.title then
      return w
    end
  end
  return nil
end

local function restoreWindowsAfterDisplayWake()
  local snap = displaySleepLayoutSnapshot
  if not snap or #snap == 0 then return end
  for _, entry in ipairs(snap) do
    local win = findWindowForLayoutEntry(entry)
    if win and win:isVisible() and not win:isMinimized() then
      local f = entry.frame
      U.fixAnimation(win, function()
        win:setFrame({ x = f.x, y = f.y, w = f.w, h = f.h }, 0)
      end)
    end
  end
end

local function scheduleRestoreAfterDisplayWake()
  if displayWakeRestoreTimer then
    displayWakeRestoreTimer:stop()
  end
  displayWakeRestoreTimer = hs.timer.doAfter(0.55, function()
    displayWakeRestoreTimer = nil
    restoreWindowsAfterDisplayWake()
  end)
end

function U.startDisplaySleepWindowLayoutWatch()
  if U._displaySleepWindowLayoutWatcher then
    return
  end
  local w = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidSleep
        or event == hs.caffeinate.watcher.systemWillSleep then
      snapshotWindowsForDisplaySleep()
    elseif event == hs.caffeinate.watcher.screensDidWake
        or event == hs.caffeinate.watcher.systemDidWake then
      scheduleRestoreAfterDisplayWake()
    end
  end)
  w:start()
  U._displaySleepWindowLayoutWatcher = w
end

U.startDisplaySleepWindowLayoutWatch()
