# P6.2 Realtime Transport

状态：PASS

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
- `LiveRealtimePeerConnection` 使用固定的 WebRTC `150.0.0` XCFramework 创建
  audio track、`oai-events` data channel、SDP offer/answer 和 provider event bridge。
- ADR 0001 固定可审计的 WebRTC `150.0.0` release；不使用 `latest` 或手工二进制。

## 已验证

- `swift test --package-path ios/Packages/WordLoopRealtime`：4/4 通过。
- `WordLoopFeatures` package：104/104 通过，确认该 XCFramework 可由完整 Feature
  依赖图解析、链接和运行测试。
- SDP client 测试覆盖 VPS `/wordloop/api/pronunciation-session` 路径、请求方法、
  Content-Type、user ID header 和 answer；事件 decoder 测试覆盖 item ID 与未知
  event 隔离。

## 阻塞与下一个安全步骤

P6.2 到此完成；P6.3 负责将该 transport 接入 Web 已验证的 turn/state machine，
触发真实麦克风授权、控制音轨开关、评分和 UI。P6.2 本身不提前重写这些业务逻辑。
