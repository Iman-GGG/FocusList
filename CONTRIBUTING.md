# 参与贡献

感谢你愿意改进 FocusList。项目优先保持轻量、纯本地和符合 macOS 使用习惯。

## 开始之前

- 搜索现有 Issue，避免重复提交。
- Bug 请附上 macOS 版本、复现步骤、预期结果和实际结果。
- 较大的功能改动请先创建 Feature Request，确认方向后再实现。
- 不要在 Issue、截图或测试数据中提交真实的个人任务、附件或其他隐私信息。

## 本地开发

要求 macOS 14 或更高版本，并安装支持 Swift 6 的 Xcode Command Line Tools。

```bash
git clone https://github.com/Iman-GGG/FocusList.git
cd FocusList
./build-app.sh
open dist/FocusList.app
```

也可以仅验证 Swift Package：

```bash
swift build
```

## 提交 Pull Request

1. 从 `main` 创建功能分支。
2. 保持改动聚焦，避免混入无关格式化。
3. 确保 `swift build` 通过，并手动验证相关交互。
4. 更新与行为变化相关的 README 或说明。
5. 在 Pull Request 中说明改动目的、验证方式和界面变化；涉及 UI 时请附截图。

提交代码即表示你同意按照项目的 MIT License 授权你的贡献。
