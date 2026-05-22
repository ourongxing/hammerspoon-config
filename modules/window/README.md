# 窗口管理逻辑梳理

## 一、整体架构

```
hotkey.lua (快捷键绑定)
    ↓
modules/window/init.lua (核心逻辑)
    ├── transfrom()      - 窗口尺寸/位置变换
    ├── baseTransform() - 带叠加的变换入口
    ├── autoLayout()    - 双窗口自动排列
    └── 其他功能 (screen/space/undo 等)
    ↓
utils/window.lua (工具函数)
modules/window/undoManager.lua (撤销/重做)
```

---

## 二、屏幕模式

### 2.1 当前显示器模式

- 条件：`V.UnifiedDisplayMaximize = false`、**只有 1 块显示器**，或 `V.UnifiedDisplayMaximize = "auto"` 且 macOS 开启了 **Displays have separate Spaces**
- 使用：当前窗口所在的 `win:screen():frame()` 作为当前屏幕
- 所有 preset 基于当前窗口所在屏幕的 50-50 / 1/3-2/3 划分

### 2.2 统一显示模式 (Unified Display)

- 条件：`V.UnifiedDisplayMaximize = true` 且 **≥ 2 块显示器**，或 `V.UnifiedDisplayMaximize = "auto"`、**≥ 2 块显示器** 且 macOS 关闭了 **Displays have separate Spaces**
- 使用：`getUnifiedFrame()` 计算统一区域

#### getUnifiedFrame() 返回

| 字段 | 含义 |
|------|------|
| **screen** | 统一 frame：x=最左, y=横屏 y, w=总跨度, h=横屏 h |
| **split.leftScreen** | 左侧块完整 frame |
| **split.rightScreen** | 右侧块完整 frame |
| **split.splitX** | 左右分界线 x 坐标 |
| **split.leftW / rightW** | 左右块宽度 |

**主屏始终是横屏**（w > h）。y、h 取横屏作为参考。竖屏（h > w）可充分利用上下高度。

两块 16:9 屏（一竖一横）并排时，最大可用区域宽高比 = **25:9**（竖 9 + 横 16 = 宽 25，高取 min = 9）。

#### 布局示意（竖屏 1080×1920 左，横屏 1920×1050 右）

```
        竖屏                    横屏 (主屏)
    ┌─────────────┐        ┌─────────────────────┐
    │  y=-425     │        │  y=30               │
    │  1080×1920  │        │  1920×1050          │
    │             │   x=0  │                     │
    │             │        │                     │
    │             │        │                     │
    └─────────────┘        └─────────────────────┘
    x=-1080
```

---

## 三、Preset 预设

### 3.1 基准变量

| 变量 | 单屏 | 统一模式 |
|------|------|----------|
| 左半宽 | `halfWLeft` | 左屏宽 - gap/2 |
| 右半宽 | `halfWRight` | 右屏宽 - gap/2 |
| 分界线 | `halfX` | splitX + gap/2 |
| 上半高 | `halfH` | 统一高度的一半 |
| 竖屏上半 | `leftVerticalHalfH` | 左侧为竖屏时，其 h 的一半 |
| 竖屏下半 | `leftVerticalBottomH` | 剩余高度（右侧同理） |

### 3.2 Preset 列表

| 类型 | 区域 | 行为 |
|------|------|------|
| **full** | 全屏 | 统一区域：宽=总跨度，高=横屏高 |
| **left** | 左半 | 左侧块：竖屏时高=**1920**，横屏时用统一高 |
| **right** | 右半 | 右侧块：竖屏时用其完整高，横屏时用统一高 |
| **top** | 上半 | 横跨两屏，高=统一区域高的一半 |
| **bottom** | 下半 | 同上 |
| **vertical-above** | 竖屏上 | 竖屏超出横屏上方的区域（Alt+Shift+K） |
| **vertical-below** | 竖屏下 | 竖屏超出横屏下方的区域（Alt+Shift+J） |
| **left-top** | 左上 1/4 | 左侧为竖屏时用其上半，否则用统一区域上半 |
| **left-bottom** | 左下 1/4 | 左侧为竖屏时用其下半 |
| **right-top** | 右上 1/4 | 右侧为竖屏时用其上半，否则用统一区域上半 |
| **right-bottom** | 右下 1/4 | 右侧为竖屏时用其下半 |
| **reasonable** | 居中 | 80% 宽、60% 高，居中 |
| **center** | 居中 | 保持原尺寸，居中 |

### 3.3 叠加规则 (superposition)

当 `baseTransform(type, true)` 时，会根据当前窗口状态切换到下一个 preset：

- **左/右**：top → left-top，bottom → left-bottom，right-top → left-top，right-bottom → left-bottom，left ↔ right
- **上/下**：left → left-top，right → right-top，left-bottom → left-top，right-bottom → right-top，top ↔ bottom

---

## 四、Gap 规则

- `V.Gap = 6`（默认）
- 两个窗口之间留 gap：`leftW - gap/2` 与 `rightW - gap/2` 之间留 6px
- 窗口与屏幕边缘不留 gap

---

## 五、快捷键

| 快捷键 | 功能 |
|--------|------|
| Alt+F | 全屏 |
| Alt+H | 左半 | Alt+L | 右半 |
| Alt+K | 上半 | Alt+J | 下半 |
| Alt+Shift+K | 竖屏上 | Alt+Shift+J | 竖屏下 |
| Alt+C | 居中 | Alt+Shift+C | reasonable |
| Alt+M | 自动布局 | Alt+Shift+M | 自动布局（反向） |
| Alt+Shift+←/→ | 切换 Space |
| Alt+` | 焦点切到下一屏 | Alt+Shift+` | 移动窗口到下一屏 |
| Cmd+` | 同屏切换窗口 |
| Alt+B | 焦点到主屏（横屏） | Alt+Shift+B | 移动窗口到主屏（横屏） |
| Alt+Shift+Q | 安全关闭应用 | Alt+Shift+W | 安全关闭窗口 |
| Alt+Shift+F | 切换全屏 |
| Alt+Z | 撤销 | Alt+Shift+Z | 重做 |

---

## 六、跨屏鼠标位置

- 切换显示器焦点时，会按显示器 ID 记录每块屏幕上一次的鼠标位置
- 再次切回该显示器时，优先恢复上次位置；没有记录时回退到目标窗口中心或屏幕中心
- 记录保存在 `hs.settings` 中，Hammerspoon reload 后仍可恢复

---

## 七、自动布局 (autoLayout)

- 目标：当前 Space 的前两个窗口
- 布局循环（`V.LeftTopFirst = true`）：`left + right` → `top + bottom`
- 焦点窗口始终在左/上位置

---

## 八、撤销系统 (undoManager)

- 记录：frame、screen、space、全屏状态、鼠标位置、focusWin
- 上限：`V.MaxUndoHistory = 20`
- 每次变换后自动入栈，支持 undo/redo

---

## 九、特殊处理

1. **Raycast 空标题窗口**：用方向键而非 setFrame 控制
2. **AXEnhancedUserInterface**：变换前关闭，避免动画异常
3. **动画**：仅位置或仅尺寸变化时使用 0.2s 动画
