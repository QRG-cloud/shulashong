# 鼠拉松

<p align="center">
  <img src="Assets/ShuLaSong-AppIcon-1024.png" width="180" alt="鼠拉松应用图标">
</p>

鼠拉松是一个隐私优先的 macOS 菜单栏小工具：记录光标一天在屏幕上走了多少米，以及你最终写入文本框多少字，再把数字换算成一次散步或一部小说。

## 功能

- 记录光标在屏幕上的物理等效距离；
- 统计最终写入文本框的 Unicode 字符，支持中文输入法和粘贴；
- 将里程换算成“工位到茶水间”“操场一圈”等路线；
- 将字数换算成长消息、邮件、小说章节和十万字长篇进度；
- 展示最近 7 天数据，支持暂停、清空当天和导出 CSV；
- 原生 macOS 菜单栏运行，不联网、没有第三方依赖。

## 安装与使用

1. 运行构建脚本，或从 Release 下载应用包。
2. 将 `鼠拉松.app` 拖入 `/Applications` 后启动。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许鼠拉松。
4. 回到任意受支持的文本框输入；菜单栏会在输入稳定后更新准确字数。

不需要开启“输入监控”。如果菜单显示“打字待辅助功能授权”，请确认授权列表里的开关已开启，然后重启鼠拉松。

## 统计口径

### 字数

鼠拉松比较当前文本框输入稳定前后的内容，只累计最终新增的 Unicode 字符簇：

- `你好` 计为 2 字，而不是拼音按键数；
- 删除不会倒扣当天累计字数；
- 粘贴的内容按实际字符数计入；
- 家庭 emoji 等组合字符计为 1；
- 切换应用或文本框时只建立新基线，不把已有内容算进去。

部分不向 macOS 辅助功能公开文本内容的应用或自绘编辑器可能无法统计。

### 光标距离

光标里程依据每块屏幕的逻辑坐标和系统报告的物理尺寸换算。它表示光标在屏幕上的等效路程，不是鼠标硬件在桌面上滑过的精确距离。

## 隐私

鼠拉松只把每天的累计数字写入硬盘，不保存输入原文、按键、应用名、窗口名或鼠标轨迹。文本只会短暂存在内存中用于计算差值，密码框会跳过。

本地数据路径：

```text
~/Library/Application Support/DayTrace/daily-stats.json
```

为了兼容旧版本，数据目录仍使用内部名称 `DayTrace`。

## 本地构建

要求：macOS 13 或更高版本、Apple Command Line Tools。当前产物面向 Apple Silicon。

```bash
cd daytrace-macos
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

构建结果位于 `dist/鼠拉松.app`。脚本会生成多尺寸 `.icns`、编译 Objective-C 源码并运行自测。

如果钥匙串中存在 `ShuLaSong Local Code Signing`，脚本会用它稳定签名；其他电脑会自动使用 ad-hoc 签名。ad-hoc 构建每次重签名后可能需要重新授权辅助功能。

## 项目结构

```text
Assets/                         图标源文件
Sources/DayTrace/DayTrace.m     应用源码与自测
scripts/build-app.sh            构建、图标打包和签名
scripts/IconPack.m              ICNS 打包工具
Info.plist                      macOS 应用配置
```

## License

暂未指定开源许可证。代码版权归项目作者所有。
