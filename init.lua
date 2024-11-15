-- global variables
V = {}
-- global util functions
U = {}
-- hs commandline
require("hs.ipc")
require("utils")

-- 效果不好，有时会会失效
-- U.windowEvent({
-- 	created = function(win)
-- 		-- hs.alert("window created")
-- 		U.disableAXEnhancedUserInterface(win)
-- 	end,
-- })

-- hs.timer.doAfter(1, function()
-- 	for _, win in ipairs(windows) do
-- 		U.disableAXEnhancedUserInterface(win)
-- 	end
-- end)

-- 定时执行
require("modules.cron")
-- URL Scheme
require("modules.urlEvent")
-- 快捷键
require("modules.hotkey")

-- hs.loadSpoon("SpoonInstall")
hs.loadSpoon("Corners")
spoon.Corners:start()
