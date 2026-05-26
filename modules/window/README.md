# Window Manager

这套窗口管理有两套布局规则，并且可以在多屏环境下混合使用：

- `Single Display`：普通显示器内窗口管理。
- `Unified Display`：把一块竖屏和一块横屏看作一个统一桌面。

## 模式判定

### Unified Display

只有下面两种情况会进入 `Unified Display`：

1. `V.UnifiedDisplayMaximize = true`，且显示器数量 `>= 2`
2. `V.UnifiedDisplayMaximize = "auto"`，显示器数量 `>= 2`，且 macOS 关闭了 `Displays have separate Spaces`

并且，当前 unified 规则只适配 **一块竖屏 + 一块横屏** 的排列。

如果参与 unified 的屏幕不是刚好一横一竖，即使满足上面的开关条件，也会回退到 `Single Display` 规则。

### 隔离名单

多于两块屏幕时，可以把额外屏幕放进隔离名单：

```lua
V.UnifiedDisplayIsolatedScreens = {
  "Sidecar Display (AirPlay)",
  -- 也可以填 screen id，比如 25
}
```

名单规则：

- 名单里的屏幕不参与 `Unified Display`，始终使用 `Single Display`。
- 名单外剩下的屏幕如果刚好是一横一竖，就组成 `Unified Display`。
- 当前窗口在名单内屏幕上时，`Alt+H/L/K/J` 都只整理这块屏幕。
- 当前窗口在 unified 参与屏上时，`Alt+H/L/K/J` 在统一桌面内工作。

### Single Display

除了上面的 unified 情况之外，全部使用 `Single Display`：

- `V.UnifiedDisplayMaximize = false`
- 只有一块显示器
- `V.UnifiedDisplayMaximize = "auto"`，但 macOS 开启了 `Displays have separate Spaces`
- 名单外参与 unified 的显示器不是刚好一横一竖
- 当前窗口位于 `V.UnifiedDisplayIsolatedScreens` 名单中的屏幕

## 文件结构

```text
modules/window/init.lua
  -> transform/single.lua   # Single Display
  -> transform/unified.lua  # Unified Display，一横一竖专用
  -> transform/common.lua   # 通用 setFrame / undo / Raycast 特判
  -> undoManager.lua
```

`init.lua` 只负责判断模式并分发：

```lua
if shouldUseUnifiedDisplayForScreen(win:screen()) then
  UnifiedTransform.transform(win, type, superposition, unifiedScreens())
else
  SingleTransform.transform(win, type, superposition)
end
```

`UnifiedTransform` 只接收名单外的 unified 参与屏幕。它内部如果发现当前不是一横一竖，也会回退到 `SingleTransform`。

## Unified Display 布局

Unified Display 假设桌面是一块竖屏加一块横屏。它不是完整矩形，而是下面这种复合区域：

```text
┌────────────┐
│     A      │
├────────────┼────────────┬────────────┐
│     B      │     CL     │     CR     │
├────────────┴────────────┴────────────┘
│     D      │
└────────────┘
```

基础区域：

| 区域 | 含义 |
|------|------|
| `A` | 竖屏高出横屏的上方区域 |
| `B` | 竖屏和横屏共享高度内的竖屏区域 |
| `D` | 竖屏高出横屏的下方区域 |
| `CL` | 横屏左半 |
| `CR` | 横屏右半 |

组合区域：

| 区域 | 含义 |
|------|------|
| `C` | 完整横屏，`CL + CR` |
| `BC` | unified 主区域，`B + CL + CR` |
| `AB` | 竖屏上方 + 中段 |
| `BD` | 竖屏中段 + 下方 |
| `ABD` | 完整竖屏 |
| `VT` | 完整竖屏上半 |
| `VB` | 完整竖屏下半 |

## Unified Display 循环

### 横向循环

`Alt+L` 向右：

```text
B -> CL -> CR -> B
```

`Alt+H` 向左：

```text
B <- CL <- CR <- B
```

其中：

- `C = CL + CR`
- `BC = B + CL + CR`
- `C` 和 `BC` 不参与方向循环，只通过 full 类操作手动进入
- 从 `C` / `BC` 按方向键退出时，会落到对应方向的边缘区域

### 竖向循环

`Alt+J` 向下：

```text
B -> AB -> BD -> VT -> VB -> B
```

`Alt+K` 向上，反向循环。

竖屏同时支持：

- 中段：`B`
- 两段：`VT / VB`
- 组合：`AB / BD`
- `A / D` 不参与方向循环，可通过 `Alt+Shift+K/J` 直达
- `ABD` 不参与方向循环，只通过 full 类操作手动进入
- 从 `ABD` 按 `Alt+K/J` 退出时，会落到 `VT` / `VB`

### 竖屏快捷直达

```text
Alt+Shift+K -> A
Alt+Shift+J -> D
```

## Single Display 布局

Single Display 只看当前窗口所在的物理显示器。

```text
┌────────────┬────────────┐
│ left-top   │ right-top  │
├────────────┼────────────┤
│ left-bottom│ right-bottom
└────────────┴────────────┘
```

规则：

- `Alt+F`：当前物理显示器 full
- `Alt+H/L`：左右半屏；在四角状态下保留上下位置横向切换
- `Alt+K/J`：上下半屏；在四角状态下保留左右位置纵向切换
- `Alt+Shift+K/J`：等同上半屏 / 下半屏

## 快捷键

| 快捷键 | 说明 |
|--------|------|
| `Alt+F` | 当前物理显示器 full |
| `Alt+Shift+F` | unified 下为 `BC`；single 下为当前屏 full |
| `Alt+H` | 向左 |
| `Alt+L` | 向右 |
| `Alt+K` | 向上 |
| `Alt+J` | 向下 |
| `Alt+Shift+K` | unified 下直达 `A` |
| `Alt+Shift+J` | unified 下直达 `D` |
| `Alt+C` | 保持当前尺寸居中 |
| `Alt+Shift+C` | reasonable，当前屏 60% 宽、80% 高 |
| `Alt+M` | 自动排列前两个窗口 |
| `Alt+Shift+M` | 自动排列前两个窗口，反向优先 |
| `Cmd+\`` | 当前屏内切换窗口 |
| `Alt+\`` | 焦点切到下一块有窗口的屏幕 |
| `Alt+Shift+\`` | 移动窗口到下一块屏幕 |
| `Alt+B` | 焦点到主屏，也就是横屏 |
| `Alt+Shift+B` | 移动窗口到主屏，也就是横屏 |
| `Alt+Shift+Left/Right` | 切换 Space |
| `Alt+Z` | undo |
| `Alt+Shift+Z` | redo |

## 其他行为

- `autoLayout()` 只处理当前 Space 的前两个窗口。
- 当前窗口在 unified 参与屏上时，窗口集合来自 unified 参与屏。
- 当前窗口在隔离屏上时，窗口集合只来自当前屏。
- `Cmd+\`` 在 unified 参与屏上跨 unified 参与屏切窗口，在隔离屏上只切当前屏。
- 鼠标跨屏切换时会按显示器 ID 记录上次位置。
- undo 会记录窗口 frame、screen、space、fullscreen、鼠标位置和焦点窗口。
- Raycast 空标题窗口不直接 `setFrame`，而是发送方向键。
- 变换前会关闭 `AXEnhancedUserInterface`，减少窗口动画问题。
