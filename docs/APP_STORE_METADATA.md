# WordLoop · App Store Connect 商店资料草案

> 适用版本：`1.0`。课程内容完成 36 节白名单包、真实设备验收和截图后再填入并保存。

## 简体中文

- App 名称：`WordLoop`
- 副标题：`把英语说出口`
- 推广文本：`听一句、说一句，把日常英语练成能自然说出口的话。`
- 主分类：教育
- 价格：免费，无内购
- 支持 URL：`https://boringmax.com/wordloop/support`
- 隐私政策 URL：`https://boringmax.com/wordloop/privacy`
- 营销 URL：`https://boringmax.com/wordloop/`
- 版权：`© 2026 Lin Peiwen`
- 关键词：`英语口语,英语听力,英语学习,英语发音,日常英语,跟读,口语练习`

### 描述

WordLoop 是一款轻量的英语听辨与跟读练习应用。

从日常英语会话开始，听一句、说一句、再回到重点表达反复练习。你可以在 LISTEN 中专注听辨，也可以在 REPEAT 中开启麦克风，实时练习自己的发音。

主要功能：

- 日常英语会话：围绕真实生活场景练习常用表达。
- 听辨与跟读：在 LISTEN 和 REPEAT 两种模式之间切换。
- 重点提示：逐步隐藏句子，帮助你把注意力放到正在练习的表达上。
- 自动播放：连续完成一轮听辨练习，不必每句手动点下一条。
- 进度同步：无需注册即可开始；学习进度会随当前设备的游客身份保存。
- 数据掌控：可在“学习进度”侧栏删除当前游客的全部本机和服务器学习数据。

REPEAT 跟读功能需要麦克风权限。拒绝权限不会影响浏览课程、听音或学习单词。

## 审核说明

WordLoop 不要求登录，也没有账号注册页。审核人员打开 App 后即可从内置的日常英语会话课程开始学习。

- `LISTEN`：可直接播放每条英语音频，并可切换自动播放。
- `REPEAT`：首次进入时会请求麦克风权限；该权限仅用于用户主动发起的实时英语跟读和转写，不会保存原始录音作为学习进度。
- 数据删除：打开右上角 `PROGRESS`，在学习进度侧栏底部选择 `DELETE MY LEARNING DATA`，确认后会删除当前游客的本机和服务器进度，并建立新的游客身份。

审核联系人：Lin Peiwen / +86 183 2858 2497 / okkknight@gmail.com

## 在 App Store Connect 填写前复核

- [ ] 关闭“需要登录信息”（游客模式不需账号）。
- [ ] 上传与最终 36 节首发内容一致的 iPhone 截图；不得出现 IELTS、Modern Family 或 VOA。
- [ ] 填写 App Privacy 问卷：选择 `User ID`、`Product Interaction`、`Audio Data`；三项均为 `App Functionality`、`Data Linked to You`、`Not Used for Tracking`。音频仅在用户主动跟读时发送；WordLoop 不保存原始录音，但 OpenAI API 默认滥用监测日志可能保留相关 API 内容最多 30 天。
- [ ] 完成年龄分级与出口合规问卷；如更改加密实现或地区范围，重新核对。
- [ ] 先使用 TestFlight 内测构建；通过真机麦克风、删除数据和离线失败路径后，再选择构建提交审核。
- [ ] 中国大陆暂不勾选为首发地区；EU 仅在完成 DSA 交易者状态处理后开放。
