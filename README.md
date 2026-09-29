# WordLoop

WordLoop 是一款把英语“听出来、说出来”的练习器。它不让你一次吞下一大段课，而是把注意力放到一句一句的日常表达上：先听清标准发音，再打开麦克风跟读，把那句话真正说出口。

LISTEN 负责听辨和自动连播；REPEAT 负责实时跟读练习。两条进度分开保存，所以你可以清楚地知道一门课是已经听熟，还是还需要再开口练几次。无需注册，换课、重练和恢复进度都尽量不打断节奏。

**[打开 WordLoop →](https://boringmax.com/wordloop/)**

## 里面有什么

- 36 门原创日常英语会话课是当前 iOS 正式发布内容；
- Web 仓库还保留 IELTS 高频词、《Modern Family》精选对白与 VOA Learning English 等练习资料。

选一门课，先按 **LISTEN** 听，再打开 **REPEAT** 跟读。每个单元都可以回头重来，也可以直接跳到真正需要练的内容。

## 本地运行 Web 版

需要 Node.js `>=22.13.0` 和 npm：

```bash
npm install
npm run dev
```

开发命令会启动前端和本地 Node API。学习进度默认保存在 `data/wordloop.local.sqlite`，可用 `WORDLOOP_DB_PATH` 指定其他路径。要使用 REPEAT 跟读，在本地 `.dev.vars` 中配置 `OPENAI_API_KEY`；不要把密钥提交到仓库。

生产构建使用 `npm run build`。部署说明在 [VPS 文档](docs/WORDLOOP_VPS_RUNBOOK.md)。

## iOS 客户端与课程制作

仓库也有原生 SwiftUI 客户端，代码在 [`ios/`](ios/)。Web 和 iOS 的发布课程并不完全一样：iOS 首发包是 36 门原创日常英语会话课，Web 则保留了更多课程资料。

想做自己的课程，从[通用课程指南](docs/COURSE_PRODUCTION_GUIDE.md)开始。课程文字、逐句音频和时间轴要一起对齐；更完整的制作边界见 [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md)。

## 许可

应用代码采用 [MIT 许可证](LICENSE)。`modernfamily/season-01-subtitles/` 的字幕、`app/data/` 的课程文本，以及 `public/audio/` 和 `public/courses/` 的课程音频与配套内容，按 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) 公开。仓库自带字体仍遵循 [SIL Open Font License 1.1](ios/Packages/WordLoopDesignSystem/Sources/WordLoopDesignSystem/Resources/Fonts/LICENSE.txt)，其他第三方依赖遵循各自许可证。用户进度与本地环境变量不属于公开课程素材。
