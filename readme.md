# 铁幕前线 · Iron Meridian

> **安卓安装包：[点击下载 IronMeridian-0.1.0.apk（约 97 MiB）](https://github.com/Clearlove-NaN/codex-play/raw/refs/heads/iron-meridian-v0.1.0-download/downloads/IronMeridian-0.1.0.apk)**
>
> 若手机内置浏览器无法下载，请用系统浏览器打开本仓库页面，在 `downloads` 目录打开 APK 并选择 **Download raw file**（下载原始文件）。
>
> 此分支提供原型源码和测试签名 APK。规则、界面测试和签名检查通过；安卓内运行及真机验证尚未完成。

原创架空背景的六角格回合制战争策略游戏，使用 Godot 4.6.3 / GDScript 开发。参考经典征服类游戏的城市经济、兵种配合和逐回合推进思路；地图、名称、界面与矢量美术均为本项目原创。当前版本为 **0.1.0 可玩原型**。

## 安装与游玩

安装 `IronMeridian-0.1.0.apk`，允许系统提示的“安装未知来源应用”。支持 **Android 7.0 / API 24 及以上**、ARMv7、ARM64 和 x86_64；横屏运行，完全离线，无账号、广告和付费内容。此包为开发测试签名，适合直接安装试玩；未发布至应用商店。

1. 选择“北境破晓”或增援变体“钢铁洪流”，选择三档难度后开始。
2. 点选我方部队，点蓝色可达格移动，点红圈敌军攻击。
3. 步兵可穿山；坦克机动快且克制步兵；火炮射程三格，适合打击装甲。
4. 派部队进入空城即占领。每座城市每回合提供 35 军费和 1 工业，每方另有 30 基础军费。
5. 点我方城市招募部队；新兵下回合行动。点驻城部队可修复，也可花 120 军费任命唯一指挥官。
6. 点“结束回合”让 AI 行动；**35 回合内夺取黑石城获胜，白石城失守或超时失败**。

移动可分多次进行，攻击后该部队的移动结束；相邻敌军在存活时会反击，炮兵不反击。森林减伤 20%，山地及城市减伤 25%。自动存档在玩家操作后保存；AI 回合视为一个事务，中途关闭会恢复到该次敌军行动前。安卓返回键/桌面 Esc 暂停，桌面 Space 结束回合。

## 开发

用 Godot 4.6.3 打开 `project.godot`，按 F6/F5 运行。直接使用当前 checkout；云任务已有隔离环境，无需新建 worktree。没有第三方运行时依赖或外部服务。

```bash
godot --path .
bash scripts/test.sh
bash scripts/build_android.sh
```

规则测试与界面测试使用独立的临时用户目录，不会覆盖正常游戏存档。界面测试确实执行移动、招募、JSON 存档恢复、完整 AI 回合及菜单操作。

Android 导出需要 Godot **同版本导出模板**、JDK 17+、Android SDK platform-tools 与 build-tools 35.0.1+。本云环境的完整工具链位于 `/workspace/toolchains`，脚本会自动使用其路径；在其他机器上先在 Godot 编辑器设置中指定 Java SDK / Android SDK。`export_presets.cfg` 为非 Gradle APK 导出，无需下载 Maven 依赖。Godot 首次导出会生成本地测试密钥；不要将私人发布签名提交到仓库。

## 文件

- `game/battle.gd`：独立战斗规则、寻路、AI、存档序列化。
- `game/main.gd`：原创程序化美术、触控界面、音效与自动存档。
- `tests/test_battle.gd`：实际战斗状态及规则回归测试。
- `assets/licenses/`：Godot、Noto CJK、DejaVu 字体授权说明。

第一版包含一个 200 格北境战场、两个开局变体、三档难度、三种兵种和一位可任命指挥官。尚不包含全球地图、海空军、外交、科技树、多存档槽、联网或长期养成。后续可在独立规则层上扩展。
