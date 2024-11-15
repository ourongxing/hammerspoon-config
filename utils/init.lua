require("utils.window")

function U.indexOf(array, object)
  for i, value in ipairs(array) do
    if value == object then
      return i
    end
  end
  return nil
end

function U.toUnitPoint(point, frame)
  local unitPoint = {}
  unitPoint.x = (point.x - frame.x) / frame.w
  unitPoint.y = (point.y - frame.y) / frame.h
  if unitPoint.x < 0 then unitPoint.x = 0 end
  if unitPoint.y < 0 then unitPoint.y = 0 end
  if unitPoint.x > 1 then unitPoint.x = 1 end
  if unitPoint.y > 1 then unitPoint.y = 1 end
  return unitPoint
end

function U.transformPoint(point, origin, target)
  -- 将点的坐标从原始框架转换到单位坐标
  local unitPoint = U.toUnitPoint(point, origin)

  local targetPoint = {}
  targetPoint.x = unitPoint.x * target.w + target.x
  targetPoint.y = unitPoint.y * target.h + target.y

  return targetPoint
end

function U.isNear(a, b)
  return math.abs(a - b) < 2
end

function U.sameSize(a, b)
  return U.isNear(a.w, b.w) and U.isNear(a.h, b.h)
end

function U.samePosition(a, b)
  return U.isNear(a.x, b.x) and U.isNear(a.y, b.y)
end

function U.sameFrame(a, b)
  return U.samePosition(a, b) and U.sameSize(a, b)
end

function U.isArray(t)
  if type(t) ~= "table" then return false end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

function U.isFn(t)
  return type(t) == "function"
end

function U.print(t)
  print(hs.inspect(t))
end

function U.loopArrayItem(value, array, reverse)
  local current = U.indexOf(array, value)
  if reverse then
    return array[(current - 2) % #array + 1]
  else
    return array[current % #array + 1]
  end
end
