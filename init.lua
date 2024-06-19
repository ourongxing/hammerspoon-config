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
-- 生成 hammerspoon lua 定义文件，竟然会影响下面在 canvas 显示，不知道为什么，现在删除这个也会有影响
hs.loadSpoon("Emmylua")
-- 屏幕角落
require("modules.screenCorner")