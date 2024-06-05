hs.timer.doAt("14:00", "1d", function()
  hs.execute("bash ~/dotfiles/update.sh")
end)


-- 一般两个月没有更新就会自动停用 Github Action
hs.timer.doAt("14:00", "30d", function()
  hs.execute("bash /Users/ourongxing/Development/github-notion-star/update.sh")
end)
