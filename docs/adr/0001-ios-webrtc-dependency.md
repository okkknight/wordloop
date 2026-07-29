# ADR 0001: iOS WebRTC 以官方源码固定提交构建

日期：2026-07-18  
状态：Accepted

## 决策

WordLoop iOS 的 Realtime transport 使用 Google WebRTC 的 Objective-C iOS
framework。这个轻量迁移不在本项目自行构建 Chromium/WebRTC 源码，而是引入一个
版本固定、构建过程公开的 binary Swift package。

- 依赖为 `https://github.com/stasel/WebRTC.git`，精确版本 `150.0.0`，tag commit
  为 `6ed87f05368632f71dc95c89c14c051561710925`。
- 该项目公开其 binary 构建流程，声明产物来自未经修改的官方 WebRTC 源码，并提供
  iOS device arm64 与 simulator arm64/x86_64 XCFramework slices。
- SwiftPM 的 exact version 是锁定点；不使用 `latest`、范围版本或手工拖入的
  `.framework`。解析结果由 SwiftPM/Xcode cache 产生，不提交二进制到 WordLoop。

## 可复现流程

为需要更新版本的场景，先审查该 release 的 tag、源码映射与 build workflow，再把
`Package.swift` 的 `exact` 值和本 ADR 一并更新。若产品未来需要独立供应链控制，
再切回官方 `tools_webrtc/ios/build_ios_libs.py` 的源码构建；它不属于本次忠实迁移
的必要工作。

## 后果

`WordLoopRealtime` 把 SDP signaling、事件解析和麦克风授权暴露为纯 Swift 边界；
UI 状态机不接触 WebRTC 回调。P6.2 可以在不泄露 key 的情况下验证 VPS contract。
peer connection adapter 由该固定 package 编译并连接到此边界；没有解析成功的
package 时，App 不得宣称支持原生 Realtime 跟读。

官方依据：WebRTC iOS 文档说明 framework 从源码构建，并提供官方 iOS
XCFramework 构建脚本。
