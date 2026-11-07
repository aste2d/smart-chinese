# Smart Chinese · 智能简繁转换

选中文字，按 **Hyper+C**，根据其中简体字和繁体字的数量，转换成另一种。原生 macOS Services 小工具，全部在本机处理。

作者：[aste2d](https://github.com/aste2d/)。MIT 许可。

## 下载与安装

从 [Releases](https://github.com/aste2d/smart-chinese/releases/latest) 下载 `Smart-Chinese-版本号-macOS-universal.zip`，解压到本地文件夹。

1. 双击 `install.command`。也可以在终端执行 `bash /解压目录/install.command`。
2. 安装完成后，在支持 macOS 文本服务的应用里选中文字，按 **Control+Option+Shift+Command+C**。已有 Hyper 键映射时，就是 **Hyper+C**。
3. 也可以从应用菜单的「服务 → 智能简繁转换」调用。若原先已打开的应用暂未更新服务列表，退出并重新打开该应用。

预编译安装包同时包含 Apple Silicon 和 Intel 架构，最低部署版本为 macOS 13。实际验证环境为 Apple Silicon / macOS 27.2；其他版本和 Intel 尚未实机验证。安装包无需 Python、Node.js 或 Xcode，也不要求管理员或辅助功能权限。

应用采用本地临时签名，**未做 Apple Developer ID 签名或公证**。下载后可能触发 macOS 的开发者验证提示；确认来源为本仓库后，可按系统提供的「隐私与安全 → 仍要打开」流程放行。不要关闭系统的安全检查。

## 使用规则

- 可区分的简体字较多：整段转繁体。
- 可区分的繁体字较多：整段转简体。
- 数量相同：转繁体。
- 简繁共用字、英文、数字、标点、Emoji 不投票；没有可区分字时不改变文本。
- 按出现次数统计字符，不是按词义判断。转换使用 macOS 的 `Hans-Hant` / `Hant-Hans` 规则；一简对多繁、地区用词和上下文歧义不保证能准确还原。

例如：

| 所选文字 | 转换结果 |
|---|---|
| 电脑软件設 | 電腦軟件設 |
| 電腦軟件设 | 电脑软件设 |
| hello 123 😀 人民 | 保持原文 |

只处理本次所选文字，不记忆上一次转换方向。系统服务完成后，应用可能取消选区；再次转换前请重新选择文字。结果通过纯文本服务返回，不提供富文本格式转换，也不能直接修改只读网页。并非所有应用都支持 macOS Services。

## 快捷键与启动方式

安装器会：

- 将应用复制到 `~/Applications/Smart Chinese.app`。
- 注册「智能简繁转换」服务，并绑定 Hyper+C。
- 解除系统自带「将文本转换为简体中文」对 Hyper+C 的占用；保留该服务的菜单入口。
- 创建 `~/Library/LaunchAgents/uk.aste.smart-chinese.plist`，在登录后保持服务待命。
- 将安装前相关快捷键记录到 `~/Library/Application Support/Smart Chinese/previous-services.plist`，用于卸载恢复。

工具没有窗口、Dock 图标或菜单栏图标。不会修改 Caps Lock/Hyper 键映射，也不会修改截图快捷键。若 Raycast、Karabiner 或其他软件另外占用了 Hyper+C，需先解除对应冲突。

本工具从慢速 Automator 方案改为常驻原生服务。在开发机器上，10 次完整服务请求平均约 **108 ms**；同机旧 Automator 工作流约 **600–680 ms**。这是特定环境下的测量，实际键盘到画面的延迟还取决于应用和系统负载。

## 更新

下载新安装包并重新运行 `install.command`。安装器使用同一应用目录和启动项，保留首次安装时的快捷键恢复记录。

如果之前手动安装过同名 Automator 工作流，应先停用它，避免出现重名服务。本工具的安装器不会删除用户已有的工作流。

## 卸载

运行下载包里的 `uninstall.command`，或在终端运行：

```sh
"$HOME/Applications/Smart Chinese.app/Contents/MacOS/SmartChinese" --uninstall
```

卸载会停止服务，删除本工具的应用和登录启动项，并恢复安装前记录的快捷键。对于安装后又被手动修改过的相关快捷键，会保留你的后续修改。

## 隐私

不联网，不调用 AI，不上传文本，不做统计分析，不保存所选文本。通过 macOS 提供的服务专用 pasteboard 传递输入和结果，不读取或覆盖系统通用剪贴板。后台缓存仅包含单个字符的简繁分类；进程退出后消失。

## 从源码构建

需要 macOS 和 Xcode Command Line Tools：

```sh
xcode-select --install
./build.sh
```

脚本编译 arm64 与 x86_64 两个架构，合并成通用应用，执行转换测试、签名校验并生成 `dist/` 下的 ZIP 和 SHA-256 校验文件。

## English

Select editable text and press **Control+Option+Shift+Command+C** (Hyper+C). The service counts distinguishable Simplified and Traditional Chinese characters and converts toward the minority form. Ties convert to Traditional; shared characters and non-Chinese text do not vote.

Download the universal macOS ZIP from Releases and run `install.command`. The native background service starts at login. Run `uninstall.command` to remove it and restore shortcut settings where they have not subsequently changed. It works locally, has no network or AI dependency, and does not use the general clipboard. macOS Services support is required in the target app. Reselect text before another conversion if the app clears the selection.

The app is ad-hoc signed, not Developer ID signed or notarized. Deployment target: macOS 13+; tested on Apple Silicon with macOS 27.2. Intel and other macOS versions are not yet tested on hardware.
