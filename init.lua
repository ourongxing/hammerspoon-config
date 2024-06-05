-- global variables
V = {}
-- global util functions
U = {}

-- hs 命令行
require("hs.ipc")
require("utils")

U.windowEvent({
	created = function(win)
		U.disableAXEnhancedUserInterface(win)
	end,
})

-- 定时执行
require("modules.cron")
-- URL Scheme
require("modules.urlEvent")
-- 快捷键
require("modules.hotkey")

-- 把鼠标移到右上角可以阻止屏幕熄灭
hs.loadSpoon("SleepCorners")
spoon.SleepCorners:start()
-- 生成 hammerspoon lua 定义文件
hs.loadSpoon("Emmylua")
