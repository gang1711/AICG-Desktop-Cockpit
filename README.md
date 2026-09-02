<div align="center">

# 🎬 AICG Desktop Cockpit · 漫剧创作桌面驾驶舱

**一键把 Windows 桌面变成漫剧生产驾驶舱：管线在左、素材在中、应用在右，任务栏隐形，壁纸即氛围。**

![平台](https://img.shields.io/badge/平台-Windows_10_\/_11-0078D4) ![安装](https://img.shields.io/badge/部署-一键-3DDC84) ![许可](https://img.shields.io/badge/脚本-MIT-blue) ![账号](https://img.shields.io/badge/注册-不需要-orange)

**13 个桌面格子 · 7 个开源组件 · 0 个账号 · 全部数据本地**

</div>

---

## 这是什么

给 **AI 漫剧创作者** 定制的桌面工作流套件。一条命令，把散乱的 Windows 桌面改造成：

- **左边看管线** —— 漫剧生产管线（策划→创作→生产→后期→运营）、剧组项目、时光氛围板
- **中间收发素材** —— 待处理收纳箱（微信/网盘文件拖进来）、素材中心（音乐库/视频素材/壁纸库）、知识收件箱、工作台归档
- **右边开应用** —— AI 创作应用（剪映/漫创AI/灰豆/造梦工坊…）、常用工具
- **底部胶囊** —— 音乐遥控胶囊（Listen1 播什么它显示什么）、天气胶囊
- **沉浸视觉** —— 任务栏全透明、漫剧生成图每小时自动轮换上墙、听歌时全屏音频可视化

> 一个文件 `deploy-cockpit.ps1`，从零到满配大约 10 分钟（视网速）。

## 一键安装

### 方式 A · 克隆运行（推荐）

```powershell
git clone https://github.com/<你的用户名>/AICG-Desktop-Cockpit.git
cd AICG-Desktop-Cockpit
powershell -ExecutionPolicy Bypass -File .\deploy-cockpit.ps1
```

### 方式 B · 单文件直跑

```powershell
irm https://raw.githubusercontent.com/<你的用户名>/AICG-Desktop-Cockpit/main/deploy-cockpit.ps1 -OutFile deploy-cockpit.ps1
powershell -ExecutionPolicy Bypass -File .\deploy-cockpit.ps1
```

### 可选参数

| 参数 | 默认 | 说明 |
|:---|:---|:---|
| `-WorkRoot` | 自动：`D:\漫剧工作台` 或 `%USERPROFILE%\漫剧工作台` | 工作台根目录 |
| `-AppRoot` | 自动选 `F:\软件 → D:\软件 → %LOCALAPPDATA%\Programs` | 软件安装根 |
| `-AicgRoot` | 自动探测磁盘上的 `*AICG*` 目录 | 有 AICG 系统则自动映射管线/剧组/知识库格子 |
| `-NoDownload` | — | 已装好组件，只重建目录/配置/自启 |

> 脚本会**自动关闭相关进程**再修改配置，不怕文件占用。Listen1 安装可能弹一次 UAC，点允许即可。

## 部署的 7 个模块

| 模块 | 开源仓库 | 驾驶舱里的角色 |
|:---|:---|:---|
| **DeskBox** 1.4.8 | [Tianyu199509/DeskBox](https://github.com/Tianyu199509/DeskBox) | 13 个桌面格子：收纳格子+映射格子+功能格子，WinUI 3 原生质感 |
| **Listen1** 2.33 | [listen1/listen1_desktop](https://github.com/listen1/listen1_desktop) | 网易云/QQ/酷狗/酷我/B站/咪咕 聚合搜索播放 |
| **Lively Wallpaper** 2.2.1 | [rocksdanister/lively](https://github.com/rocksdanister/lively) | 视频/网页/图片壁纸 + 内置音频可视化（Fluids/Music TV/Music Tunnel） |
| **TagStudio** 9.6.3 | [TagStudioDev/TagStudio](https://github.com/TagStudioDev/TagStudio) | 图片/视频/音频原地索引打标签（已切简体中文） |
| **QuickLook** 4.5.0 | [QL-Win/QuickLook](https://github.com/QL-Win/QuickLook) | 空格键即时预览任何文件 |
| **Everything** 1.4.1 | [voidtools/Everything](https://www.voidtools.com/) | 全盘文件秒搜（并入 DeskBox 搜索） |
| **TranslucentTB** 2026.1 | [TranslucentTB/TranslucentTB](https://github.com/TranslucentTB/TranslucentTB) | 任务栏全透明沉浸 |

另外自带：**壁纸轮换循环**（每小时从壁纸库随机上墙）、**素材中心目录结构**、**DeskBox 13 格配置注入**（含待办五色、桌面自动整理、收纳根迁移、Ctrl+Alt+D 显隐热键）。

## 专为漫剧创作者设计

### 五个高频场景

| 场景 | 这套桌面的解法 |
|:---|:---|
| **早晨开工** | 「待办·今天」看今天卡在哪一环（🔵剧本 🟣分镜 🟠生成 🟢审核 🔴发布，颜色即阶段）→ 双击「剧组项目」直接进集数目录 |
| **素材轰炸** | 微信/网盘/浏览器的文件直接拖进「待处理」，每天固定 5 分钟分类：工程素材→剧组项目、参考图→归档库、方法论→知识收件箱 |
| **找素材** | 记得标签用 TagStudio（"捞所有雨夜场景图"），记得文件名用 Everything 秒搜，只想看一眼按空格 QuickLook |
| **听歌定节奏** | Listen1 一框搜全网 → DeskBox 音乐胶囊直接遥控；满屏可视化找画面节奏（Lively 选 Fluids） |
| **成片交付** | 导出视频进「归档库\项目压缩包」，满意剧照扔进「壁纸库\静态」——下一秒它就是你的桌面壁纸 |

### 效率技巧 10 条

1. **Ctrl+Alt+D** 一键显隐全部格子——录屏/演示/专注三态切换
2. 待办**颜色=制作阶段**，一屏看清整集瓶颈在哪个环节
3. 格子内**空格预览**分镜图/参考视频，不用开资源管理器
4. 「待处理」拖入即移动（默认），桌面自动整理还会把新出现的桌面文件自动收进去
5. 映射格子**不挪文件**：删格子不删数据，放心折腾
6. 生成的新壁纸/锚点图直接扔 `素材中心\壁纸库\静态`，每小时自动上墙
7. `暂停轮换.flag` 文件 = 壁纸轮换的暂停开关（删掉即恢复）
8. 双击格子标题重命名；Ctrl+滚轮缩放格子图标
9. 胶囊悬停自动展开——音乐/天气不占地方但随手可及
10. 发布检查：发布前用 TagStudio 按项目标签过滤，确认资产一致性

## 目录结构（部署后）

```
<WorkRoot>\漫剧工作台\
├── AI创作应用\        剪映/漫创AI/灰豆/造梦工坊…（拖快捷方式进来）
├── 常用工具\          浏览器/微信/网盘/ZCode…
├── 归档库\            项目压缩包 / 照片素材 / 文档便签 / 网络与下载
├── 收纳箱\待处理\     桌面收纳格子的真实目录
├── 氛围板\            时光格背景锚点图
└── 素材中心\
    ├── 音乐库\ 视频素材\
    └── 壁纸库\{静态,动态,可视化} + 壁纸轮换脚本
```

## 首次使用手动清单（各 10 秒）

1. **时光格氛围板**：右键时光格 → 背景设置 → 本地文件夹 → 选 `素材中心\壁纸库\静态`
2. **TagStudio 建库**：`TagStudio.exe` → 打开/创建库 → 选 `素材中心`（界面已是简体中文）
3. **格子组**（可选）：按住一个格子标题拖到另一个格子标题上，"松开后组成格子组"
4. **Lively 性能**：设置 → 勾选「全屏时暂停」（剪辑/生图时省 GPU）

## FAQ

<details>
<summary>Listen1 搜到的歌能直接剪进漫剧吗？</summary>

**不能。** Listen1 聚合的是各平台版权曲库，仅限个人试听找感觉。发布作品必须用可商用音乐（爱给网商用授权/Artlist/自作曲/CC0 音效库），否则会被平台下架甚至索赔。
</details>

<details>
<summary>格子组重启后掉到左下角？</summary>

DeskBox 1.4.8 组表面的启动锚点小毛病。重跑本脚本可恢复独立三格布局；想要组轮切建议用真鼠标「标题拖标题」成组。
</details>

<details>
<summary>壁纸轮换怎么暂停/关闭？</summary>

暂停：在 `壁纸库` 文件夹里新建文件 `暂停轮换.flag`；彻底关闭：删除启动文件夹里的 `壁纸轮换启动.vbs`。
</details>

<details>
<summary>TranslucentTB 任务栏没变透明？</summary>

Win10 用户需用本仓库的 msixbundle 安装（便携 zip 仅 Win11）。安装后任务栏桌面模式默认 Clear；若被安全软件拦截自启，在其托盘菜单勾选 Open at boot。
</details>

<details>
<summary>我不想装某个模块怎么办？</summary>

脚本各步骤独立：下载失败只跳过该模块不影响其余；`-NoDownload` 可只做目录/配置/自启部分。
</details>

## 版权与致谢

| 组件 | 许可 | 版权 |
|:---|:---|:---|
| DeskBox | GPL-3.0 | 朱天雨 [Tianyu199509](https://github.com/Tianyu199509) |
| Lively Wallpaper | GPL-3.0 | [rocksdanister](https://github.com/rocksdanister) |
| QuickLook | GPL-3.0 | [QL-Win](https://github.com/QL-Win) |
| TagStudio | GPL-3.0 | [TagStudioDev](https://github.com/TagStudioDev) |
| Listen1 | Apache-2.0 | [listen1](https://github.com/listen1) |
| Everything | 免费软件 | [voidtools](https://www.voidtools.com/) |
| TranslucentTB | GPL-3.0 | [Charles Milette](https://github.com/TranslucentTB) |
| 本仓库脚本与文档 | MIT | 叶浩 |

感谢以上开源作者——这套驾驶舱建立在他们的肩膀上。

## ⭐ 反馈与交流

如果这套驾驶舱提升了你的漫剧生产效率，**点个 Star ⭐ 就是对独立开发最大的鼓励**，也会让更多漫剧创作者看到它。

有建议、Bug、想要新模块？欢迎加我一起迭代：

<div align="center">

**微信：`g1711356511`　·　QQ：`1711356511`　·　叶浩**

*加好友备注「驾驶舱」，聊聊你的漫剧工作流*

</div>
