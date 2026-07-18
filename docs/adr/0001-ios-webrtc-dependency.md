# ADR 0001: iOS WebRTC 以官方源码固定提交构建

日期：2026-07-18  
状态：Accepted

## 决策

WordLoop iOS 的 Realtime transport 使用 Google WebRTC 的 Objective-C iOS
framework，但不直接引入社区维护的、版本漂移的预编译 SPM binary package。

- 唯一允许的源码上游为 `https://webrtc.googlesource.com/src`。
- 本次锁定 revision 为 `848836f85d4036def631df0ed6eeb001b5c0c174`。
- 产物必须由该 revision 用官方 `tools_webrtc/ios/build_ios_libs.py` 生成
  `WebRTC.xcframework`，包含 iPhone arm64 和 Simulator arm64/x86_64 slices。
- 交付的 XCFramework 必须放到有版本号的不可变 release artifact；登记其
  SHA-256、源码 revision、构建命令和 Xcode 版本后，才能作为 SwiftPM binary
  target 引入 `WordLoopRealtime`。
- 不提交未锁定的框架、手工拖入的 `.framework` 或 `latest` URL。源码 checkout
  也不进入 WordLoop 仓库。

## 可复现流程

构建机准备 Google `depot_tools` 后，在仓库外执行：

```bash
fetch --nohooks webrtc_ios
cd src
gclient sync --nohooks --revision src@848836f85d4036def631df0ed6eeb001b5c0c174
python3 tools_webrtc/ios/build_ios_libs.py --output-dir /tmp/wordloop-webrtc
shasum -a 256 /tmp/wordloop-webrtc/WebRTC.xcframework.zip
```

发布记录必须同时保存 `gclient sync` 实际解析的 revision、上述 SHA-256 和 Xcode
版本。接入项目时在 `Package.swift` 使用该不可变 artifact 的 HTTPS URL 与 checksum；
`Package.resolved`/Xcode package resolution 也必须随提交纳入审查。

## 后果

`WordLoopRealtime` 把 SDP signaling、事件解析和麦克风授权暴露为纯 Swift 边界；
UI 状态机不接触 WebRTC 回调。P6.2 可以在不泄露 key 的情况下验证 VPS contract。
真正的 peer connection adapter 只在已校验的 `WebRTC.xcframework` 接入后编译并
连接到该边界；未具备 artifact 时，App 不得宣称支持原生 Realtime 跟读。

官方依据：WebRTC iOS 文档说明 framework 从源码构建，并提供官方 iOS
XCFramework 构建脚本。
