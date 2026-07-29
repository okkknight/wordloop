# Course contract fixtures

`valid/` 中每个前缀的 `catalog`、`course` 与 `integrity` 组成一套合同样本：随机顺序的 IELTS 单词、顺序播放的 Modern Family 句子和 VOA 句子。

`invalid/` 中的单文件样本应被对应 JSON Schema 拒绝。`invalid/id-version-mismatch/` 的三个文件单独看都符合 schema，但 course ID/content version 跨文件不一致，必须由课程包验证器拒绝。

fixtures 中的 SHA-256 和字节数只用于合同格式测试，不对应仓库内真实音频；真实文件大小、哈希、未声明文件和软链接由 exporter mutation tests 校验。
