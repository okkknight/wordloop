# Geist 字体资产审计

## 固定来源

- 上游仓库：[vercel/geist-font](https://github.com/vercel/geist-font)
- 固定 tag：[`1.8.0`](https://github.com/vercel/geist-font/releases/tag/1.8.0)
- 固定 commit：[`91158e012bdc4abd59fa066d0eae9fc11c2c9f24`](https://github.com/vercel/geist-font/tree/91158e012bdc4abd59fa066d0eae9fc11c2c9f24)
- 核验方式：`git ls-remote https://github.com/vercel/geist-font.git refs/tags/1.8.0` 返回上述 commit；随后以该 tag 的 detached HEAD 读取资产。

App 只需要直立体的 Sans 与 Mono 可变字重，因此保留上游 `fonts/*/variable/` 下两份 `[wght]` TTF。没有纳入 italic variable、静态 OTF/TTF、Web WOFF2 或 Geist Pixel；这些文件不会被当前 iPhone 产品使用。

## 提交资产

仓库路径均相对于 `ios/Packages/WordLoopDesignSystem/Sources/WordLoopDesignSystem/Resources/Fonts/`。

| 仓库文件 | 上游原始文件 | SHA-256 | 字节数 |
| --- | --- | --- | ---: |
| `Geist[wght].ttf` | [`fonts/Geist/variable/Geist[wght].ttf`](https://github.com/vercel/geist-font/blob/91158e012bdc4abd59fa066d0eae9fc11c2c9f24/fonts/Geist/variable/Geist%5Bwght%5D.ttf) | `8f700c5c9f8e5af507132f1b50baf02fc12ca4c04a1100473bf44babbe8528fe` | 168,828 |
| `GeistMono[wght].ttf` | [`fonts/GeistMono/variable/GeistMono[wght].ttf`](https://github.com/vercel/geist-font/blob/91158e012bdc4abd59fa066d0eae9fc11c2c9f24/fonts/GeistMono/variable/GeistMono%5Bwght%5D.ttf) | `506fbaf05ffde249c7c400b5591d1999577ebe82372b0e35266dd5d9ee385771` | 171,072 |
| `LICENSE.txt` | [`LICENSE.txt`](https://github.com/vercel/geist-font/blob/91158e012bdc4abd59fa066d0eae9fc11c2c9f24/LICENSE.txt) | `930853ee1daa68554d9e35c8a9175affb74f699fad9a5da6ee5ebe76379d9137` | 4,368 |

- 字体文件合计：339,900 bytes（约 331.93 KiB）。
- 连同必须分发的许可文本，总增量：344,268 bytes（约 336.20 KiB）。
- 上述数字是未压缩的仓库资源字节数，不等同于 App Store 下载包压缩后的增量。

## 许可与分发要求

上游字体使用 SIL Open Font License 1.1。随 App 嵌入和分发原始字体是允许的，但发布产物必须遵守以下边界：

1. 每一份随软件分发的字体副本必须同时包含上游 copyright notice 与完整 OFL 1.1 文本；本目录的原始 `LICENSE.txt` 必须作为 Swift Package resource 进入 App 分发物。
2. 字体或其中的独立组件不能单独售卖。
3. 如果未来修改字体文件，修改版字体仍须按 OFL 1.1 分发，且未经版权方明确许可不得使用 Reserved Font Name。
4. Vercel、basement.studio 或贡献者名称不得被用来宣传或背书修改版字体，除非取得明确许可。
5. OFL 约束字体软件本身，不扩展到使用字体渲染出的普通 App 内容。

当前提交的是上游未修改的字体字节与原始许可文本；后续若替换版本或做字体子集化，必须重新记录来源、许可影响、逐文件 SHA-256 和包体增量。
