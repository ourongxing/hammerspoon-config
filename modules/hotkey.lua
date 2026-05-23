-- autolayout window，焦点 app 始终在左边和上边，占据优势地位。
V.LeftTopFirst = true
V.Gap = 0
-- true: 强制统一显示模式；false: 当前显示器模式；"auto": 跟随「显示器具有单独空间」
V.UnifiedDisplayMaximize = "auto"
-- 这些屏幕不参与 Unified Display；可填屏幕名或 screen id
V.UnifiedDisplayIsolatedScreens = {
  "Sidecar Display (AirPlay)",
}
V.MaxUndoHistory = 20
local W = require("modules.window")

-- 一些基本的窗口管理，比如全屏，左右分屏，上下分屏，居中，然后四分之一屏，循环
local h = {
  -- window
  { { "alt" },          "f",      function() W.screenFull() end },
  { { "alt" },          "l",      function() W.baseTransform("right") end },
  { { "alt" },          "h",      function() W.baseTransform("left") end },
  { { "alt" },          "j",      function() W.baseTransform("bottom") end },
  { { "alt" },          "k",      function() W.baseTransform("top") end },
  { { "alt", "shift" }, "k",      function() W.baseTransform("vertical-above") end },
  { { "alt", "shift" }, "j",      function() W.baseTransform("vertical-below") end },
  { { "alt" },          "c",      function() W.baseTransform("center") end },
  { { "alt", "shift" }, "c",      function() W.baseTransform("reasonable") end },
  { { "alt" },          "m",      function() W.autoLayout() end },
  { { "alt", "shift" }, "m",      function() W.autoLayout(true) end },
  { { "alt", "shift" }, "right",  function() W.switchSpace() end },
  { { "alt", "shift" }, "left",   function() W.switchSpace(true) end },
  { { 'alt' },          '`',      function() W.focusToNextScreen() end },
  { { 'alt', "shift" }, '`',      function() W.moveToNextScreen() end },
  { { 'cmd' },          '`',      function() W.focusToNextWindow() end },
  { { 'alt', },         'b',      function() W.focusToPrimaryScreen() end },
  { { 'alt', "shift" }, 'b',      function() W.moveToPrimaryScreen() end },
  { { "alt", "shift" }, "q",      function() W.quitAppSafely() end },
  { { "alt", "shift" }, "w",      function() W.closeWindownSafely() end },
  { { "alt", "shift" }, "f",      function() W.baseTransform("full") end },
  { { "alt" },          "z",      function() W.undo() end },
  { { "alt", "shift" }, "z",      function() W.redo() end },
  { { "alt", "shift" }, "r",      function() W.restartApp() end },

  --
  { { "alt" },          "return", function() require("modules.search").searchCopiedText() end },
}

for _, v in ipairs(h) do
  hs.hotkey.bind(v[1], v[2], v[3])
end
