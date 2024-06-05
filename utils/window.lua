-- 当前屏幕可见的 Space 的所有窗口
function U.currentSpaceWindows(screen, sortOrder)
  if not sortOrder then sortOrder = hs.window.filter.sortByFocusedLast end
  if not screen then screen = hs.screen.mainScreen() end
  -- 默认 currentSpace 包括了当前所有显示器可见的窗口，指的是整个 mission control 的 space。
  -- 可以通过设置 allowScreens 来筛选
  -- 我发现一旦全屏之后，就算不再全屏，也会被筛选出去
  -- 这些属性，比如  currentSpace，如果为 nil，那就是所有 space 的窗口，但如果是 false，就只有非当前 space 的窗口。
  ---@return hs.window[]
  local windows = hs.window.filter.new(true):setOverrideFilter({
    visible = true,
    allowRoles = { "AXStandardWindow" },
    allowScreens = screen:id(),
    currentSpace = true
  }):getWindows(sortOrder)
  return windows
end

---@return hs.window
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
  repeat
    target = target:next()
  until target:name() and not string.find(target:name(), "Sidecar")
  return target
end

---@return hs.screen
function U.previousScreen(current)
  local target = current
  repeat
    target = target:previous()
  until target:name() and not string.find(target:name(), "Sidecar")
  return target
end

function U.screens()
  -- filter Sidecat
  local screens = hs.screen.allScreens()
  local result = {}
  if not screens then return result end
  for _, screen in ipairs(screens) do
    if not string.find(screen:name(), "Sidecar") then
      table.insert(result, screen)
    end
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
