-- 包括屏幕，窗口，鼠标位置等
local undoStack = {}
local undoPos = 0
local M = {}
local function undoBase(shift)
  local nextPos = shift and undoPos + 1 or undoPos - 1
  if (nextPos < 1 or nextPos > #undoStack) then return end
  undoPos = nextPos
  local previous = undoStack[undoPos]
  local prevWin = previous.win
  local prevFrame = previous.frame
  if previous.fn and previous.fn.before then previous.fn.before() end
  if previous.screen then prevWin:move(prevFrame, previous.screen, true, 0) end
  if prevFrame then prevWin:setFrame(prevFrame, U.allowAnimation(prevFrame, prevWin:frame()) and 0.2 or 0) end
  if previous.isFullScreen ~= nil then prevWin:setFullScreen(previous.isFullScreen) end
  if previous.mousePos then hs.mouse.absolutePosition(previous.mousePos) end
  if previous.space then hs.spaces.moveWindowToSpace(previous.win, previous.space) end
  if previous.focusWin then previous.focusWin:focus() end
  if previous.fn and previous.fn.after then previous.fn.after() end
end

function M.undo()
  -- 经过 transfrom 后会重置 pos = #stack + 1，在这之后的第一次 undo，同样经过 manger，保存状态。
  if undoPos == #undoStack + 1 then
    M.undoManager(function() undoBase() end)
    -- pos 假设是 20, #stack = 19，undo 之后 pos 该变成 19，但是这里通过 undoManager，#stack + 1，pos 相当于 + 2。
    -- 本质的目的就是为了保存状态，但是 pos 不应该受到 manager 影响。
    undoPos = undoPos - 2
  else
    undoBase()
  end
end

function M.redo()
  undoBase(true)
end

-- 可以直接传入 undo 的信息，也可以自动获取，可能效率上好点
function M.undoManager(fn, opt)
  opt = opt or {}
  -- win 不一定是当前焦点窗口，是指对其变换的窗口，大多数情况下 win 和 focusWin 是一样的
  opt.win = opt.win or U.currentWindow()
  -- focusWin 一般只用来 focus
  opt.focusWin = opt.focusWin or U.currentWindow()
  opt.frame = opt.frame or opt.win:frame()
  opt.space = opt.space or U.spaceOf(opt.win)
  opt.mousePos = opt.mousePos or hs.mouse.absolutePosition()
  opt.screen = opt.screen or opt.win:screen()
  opt.isFullScreen = opt.isFullScreen or opt.win:isFullScreen()
  if fn then fn() end
  -- 判断变化了的信息
  if opt.focusWin == U.currentWindow() then opt.focusWin = nil end
  if opt.frame == opt.win:frame() then opt.frame = nil end
  if opt.screen == opt.win:screen() then opt.screen = nil end
  if opt.space == U.spaceOf(opt.win) then opt.space = nil end
  if opt.isFullScreen == opt.win:isFullScreen() then opt.isFullScreen = nil end
  if opt.mousePos == hs.mouse.absolutePosition() then opt.mousePos = nil end
  if opt.fn then
    if U.isFn(opt.fn) then
      -- 默认 fn 是变换完执行
      opt.fn = {
        after = opt.fn
      }
    end
    opt.fn = {
      before = opt.fn.before,
      after = opt.fn.after
    }
  end

  -- 清理一下
  while #undoStack >= V.MaxUndoHistory do
    table.remove(undoStack, 1)
  end

  undoStack[#undoStack + 1] = opt
  undoPos = #undoStack + 1
end

return M
