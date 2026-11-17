# 钢琴跟弹 · iOS 源码包（GitHub 云端编译用）

这个包不需要 Mac、不需要 Xcode。用 GitHub 的免费 macOS 服务器编译出 iOS 安装包，再用 Windows 上的 Sideloadly 装进 iPad。

## 包里有什么

- `Sources/` —— 8 个 Swift 源文件（App.swift 是入口，含 @main）
- `project.yml` —— XcodeGen 工程配置（bundle id `com.pianofollow.app`，仅 iPad，横屏）
- `.github/workflows/build-ipa.yml` —— 云端编译脚本，跑完产出一个未签名 ipa

## 三步走

1. 在 GitHub 新建空仓库，把本文件夹里的**全部内容**（含 `.github` 目录）上传上去。
2. 打开仓库的 Actions 页 → 左侧 `Build iOS IPA` → 右侧 `Run workflow`，等 5–10 分钟。
3. 跑完后在本次运行页面底部下载 `PianoFollow-ipa`（里面是 `PianoFollow.ipa`），用 Sideloadly 装到 iPad。

## 注意

- 产物是**未签名** ipa，必须用 Sideloadly / AltStore 这类工具用自己的 Apple ID 签名后才能装。
- 免费 Apple ID 签名的有效期是 7 天，到期重新点一次 Sideloadly 就行，App 里的数据不会丢。
- 编译失败的话，同一次运行里还有个 `build-log`，把它下载下来发给我，我照日志改代码。
