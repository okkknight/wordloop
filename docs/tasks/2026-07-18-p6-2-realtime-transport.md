# P6.2 Realtime Transport

状态：PARTIAL — official WebRTC artifact blocked

## 已完成

- 建立 `PronunciationSessionClient`：仅向配置的 HTTPS API base URL 追加
  `pronunciation-session`，以 `application/sdp` POST offer，并按需传递
  `x-user-id`。它不包含、读取或传递 OpenAI API key。
- 建立独立的 `RealtimeEventDecoder`，只向上层暴露 speech start/stop、commit、
  transcription complete/failed 和 item ID；未知 provider event 不会泄漏到 UI
  状态机。
- 新增 `LiveMicrophoneAuthorizer`。它只能由后续的 REPEAT 用户动作调用；App
  launch、LISTEN 和浏览课程不会触发权限请求。
- 在 `Info.plist` 加入准确的 `NSMicrophoneUsageDescription`。
- 写入 ADR 0001，锁定官方 WebRTC 源码 revision
  `848836f85d4036def631df0ed6eeb001b5c0c174`，禁止未锁定二进制。

## 已验证

- `swift test --package-path ios/Packages/WordLoopRealtime`：4/4 通过。
- `./scripts/verify_ios.sh`：通过（包含全部本地 Swift package 与 Xcode build）。
- SDP client 测试覆盖 VPS `/wordloop/api/pronunciation-session` 路径、请求方法、
  Content-Type、user ID header 和 answer；事件 decoder 测试覆盖 item ID 与未知
  event 隔离。

## 阻塞与下一个安全步骤

首次在本机根据 ADR 构建官方 artifact 时，`depot_tools` 的 CIPD bootstrap 在
`/tmp/wordloop-webrtc-build/depot_tools/.cipd_bin/.cipd/tmp/...` 报
`lstat ... no such file or directory`。已停止所有构建进程；只留下该仓库外的临时
目录和失败缓存，WordLoop 工作树未写入二进制。

在可用的 depot_tools/CIPD 构建机完成官方 `WebRTC.xcframework` 后，记录
revision、SHA-256 和 Xcode 版本，创建不可变 binary artifact，再将其作为
SwiftPM binary target 接入。随后实现 peer connection adapter，并在 P6.3 将
其事件接入 `RepeatSessionController`；在此之前 P6.2 不应标为 PASS，也不能宣称
原生 REPEAT 已可用。
