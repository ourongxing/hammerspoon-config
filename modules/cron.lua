--- 看上去这个 timer 不给赋予一个全局变量，就始终不会执行，好像是被垃圾回收了, Hammerspoon 真的 bug 太多了。
--- https://github.com/Hammerspoon/hammerspoon/issues/2416
-- A = hs.timer.doAt("23:24", "7d", function()
--   hs.alert("执行了")
-- end)

T = {
  hs.timer.doAt("14:00", "12h", function()
    hs.execute("bash ~/dotfiles/update.sh")
  end),

  hs.timer.doAt("13:00", "2d", function()
    hs.reload()
  end),

  -- 一般两个月没有更新就会自动停用 Github Action
  -- 顺便双向同步一下 github 和 notion
  hs.timer.doAt("22:00", "7d", function()
    hs.execute("bash /Users/ourongxing/Development/github-notion-star/bi-sync.sh")
  end),
}
