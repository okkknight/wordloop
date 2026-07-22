# WordLoop App Store 首发准备

## 已确认的首发决策

- App 名称：`WordLoop`
- 发布主体：个人开发者（Lin Peiwen）
- 价格：免费，无内购
- 主分类：教育
- 审核联系人：Lin Peiwen / +86 183 2858 2497 / okkknight@gmail.com
- 支持邮箱：okkknight@gmail.com
- 隐私政策：`https://boringmax.com/wordloop/privacy`
- 支持页：`https://boringmax.com/wordloop/support`
- 首发课程：IELTS 高频词与 AI 原创口语课程
- 首发不包含：Modern Family、VOA 课程、相关文本、音频及封面/元数据
- 首发地区：先不包含中国大陆；待合规手续核验后再决定开放。

## 中国大陆区

中国大陆不是首发阻塞项，因为可以在 App Store Connect 的可用地区中暂不选择。若以后开放，需先核验适用的 ICP 备案及个人开发者的中国大陆合规信息；简体中文商店元数据应与备案信息一致。

## 隐私披露基线

App Privacy 问卷和商店审核说明必须与最终网络行为一致：

1. 随机游客标识、课程偏好和学习进度会同步到 WordLoop 服务。
2. REPEAT 仅在用户主动开始后申请麦克风权限。
3. 跟读语音通过 WordLoop 服务连接 OpenAI Realtime，用于实时转写/发音练习；不将原始录音作为学习进度保存。
4. 不使用广告跟踪，不出售个人信息。
5. 用户可通过支持邮箱请求删除其游客标识关联的服务器进度。

在提交前，需要逐项复核 App Privacy 问卷、OpenAI 的当期数据处理条款和最终服务端日志，不能把以上草稿直接当作法律结论。

## 工程发布闸门

- [ ] 建立仅含 `ielts` 与 `ai-practice` 的 iOS 首发内容包；资源层也不得打入 Modern Family / VOA 音频或课程文件。
- [ ] 首发远程 catalog 与内置 catalog 使用同一课程白名单，默认课程改为 IELTS。
- [ ] 更新课程抽屉/进度页等测试基线，不再引用 Modern Family / VOA。
- [ ] 真实 iPhone 验证 LISTEN、REPEAT、拒绝麦克风、网络失败、游客进度恢复与删除请求路径。
- [ ] 复核 `PrivacyInfo.xcprivacy`、`NSMicrophoneUsageDescription`、第三方 SDK 隐私清单和 App Privacy 问卷。
- [ ] 检查 App Icon、启动体验、版本号/构建号、签名、出口合规问卷。
- [ ] 完成 TestFlight 内测，依据崩溃/反馈修正后再提交审核。

## App Store Connect 待操作项

1. 账户持有人加入 Apple Developer Program，并完成个人身份合规审核。
2. 在 App Store Connect 创建 App：Bundle ID `com.knightspace.wordloop`，SKU 待确定（建议 `wordloop-ios`）。
3. 选择教育分类、免费、首发地区（排除中国大陆），填写年龄分级、隐私信息、版权和审核备注。
4. 上传构建、补齐对应 iPhone 截图和中英文商店文案，然后进入 TestFlight。

## 不要提供

不要发送 Apple ID 密码、双重认证验证码、私钥或证书。账户持有人可在 App Store Connect 完成受控操作；需要协作时使用角色邀请，而不是共享登录凭据。
