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
  unitPoint.x = point.x / frame.w
  unitPoint.y = point.y / frame.h
  return unitPoint
end

function U.transformPoint(point, origin, target)
  -- 将点的坐标从原始框架转换到单位坐标
  local unitPoint = {}
  unitPoint.x = (point.x - origin.x) / origin.w
  unitPoint.y = (point.y - origin.y) / origin.h

  local targetPoint = {}
  targetPoint.x = unitPoint.x * target.w + target.x
  targetPoint.y = unitPoint.y * target.h + target.y

  return targetPoint
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
