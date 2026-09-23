# FocusList

纯本地 macOS 任务管理应用，采用 SwiftUI / AppKit 构建，无账号、无网络请求、无第三方依赖。

## 构建与运行

```bash
cd FocusList
chmod +x build-app.sh
./build-app.sh
open dist/FocusList.app
```

要求 macOS 14 或更高版本。首次使用提醒功能时，系统会询问通知权限。

## 已实现

- 我的⼀天、智能建议、重要 / 已完成 / 已过期智能列表
- 自定义列表与分组、列表颜色、置顶 / 隐藏 / 删除 / 清理完成项
- 任务增删改查、截止日期、系统本地提醒、星标、备注、子步骤
- 25MB 本地附件、重复任务（日 / 周 / 月）
- JSON 导入与导出、本机 Application Support 持久化
- 深色三栏原生 macOS 界面

桌面小组件需要完整 Xcode 的 Widget Extension 与签名配置，当前命令行构建版本未包含。
