hs.timer.doAt("14:00", "1d", function()
  hs.execute("bash ~/dotfiles/update.sh")
end)

hs.timer.doAt("13:00", "2d", function()
  hs.reload()
end)

-- 一般两个月没有更新就会自动停用 Github Action
hs.timer.doAt("14:10", "30d", function()
  hs.execute("bash /Users/ourongxing/Development/github-notion-star/update.sh")
end)