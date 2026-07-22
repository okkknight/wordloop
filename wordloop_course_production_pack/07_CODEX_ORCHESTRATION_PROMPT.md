# 交给 Codex 的总执行指令

下面内容可以直接作为 Codex 的项目任务说明。

---

请为 WordLoop 搭建一套可重复执行的 AI 英语课程内容生产流水线。

## 一、先阅读

按顺序阅读本目录：

1. `00_README.md`
2. `01_GLOBAL_CONTENT_STANDARD.md`
3. `02_PROMPT_0_CURRICULUM_PLANNER.md`
4. `03_PROMPT_1_COURSE_BLUEPRINT.md`
5. `04_PROMPT_2_CANDIDATE_GENERATOR.md`
6. `05_PROMPT_3_REVIEWER_EDITOR.md`
7. `06_CHECKER_SPEC.md`
8. `schemas/`
9. `examples/production_config.example.json`

不要修改课程原则，除非发现明确矛盾；如发现矛盾，先记录在 README 的实现说明中。

## 二、要实现的流程

```text
生产配置 + 已有课程目录
        ↓
Prompt 0：批量生成课程规划
        ↓
保存 curriculum-plan.json
        ↓
等待人工批准或读取 approved 标记
        ↓
逐门调用 Prompt 1 生成 course-blueprint.json
        ↓
等待人工批准或读取 approved 标记
        ↓
调用 Prompt 2 生成 candidate-sentences.json
        ↓
运行确定性检查程序
        ↓
保存 checker-report.json
        ↓
存在可自动重试的 error 时，针对失败槽位重新调用 Prompt 2
        ↓
调用 Prompt 3 生成 final-course.json
        ↓
若存在 regenerateSlots，针对指定槽位重生候选并重新检查、重新编辑
        ↓
输出等待人工终审的最终课程
```

## 三、工程要求

请优先构建简单、透明、可调试的流水线，不要过度设计多智能体框架。

建议模块：

- `planner`：Prompt 0；
- `blueprint`：Prompt 1；
- `candidate-generator`：Prompt 2；
- `checker`：确定性检查；
- `reviewer-editor`：Prompt 3；
- `orchestrator`：串联流程；
- `storage`：保存每一步输入输出；
- `cli`：人工触发、批准、重试和批量执行。

## 四、模型调用要求

- Prompt 文件作为版本化模板读取，不要硬编码在业务逻辑中；
- 每次调用保存 prompt 版本、模型名、输入、原始输出和解析后 JSON；
- 使用结构化输出或 JSON Schema；
- JSON 解析失败时允许有限次数重试；
- 不允许后续步骤静默修复上一步的结构错误；
- 对单个失败槽位进行局部重试，不要默认重生整门课程；
- Prompt 2 不得改变蓝图；
- Prompt 3 不得推翻课程学习成果。

## 五、人工检查点

第一版保留两个明确人工批准点：

1. 课程池批准；
2. 单课蓝图批准。

最终课程输出后标记为 `needs_human_review`，不自动发布。

人工批准的实现可以先采用：

- 修改 JSON 中的 `approved` 字段；
- CLI 命令；
- 简单本地页面；

任选最简单可靠的方式。

## 六、检查程序

严格按照 `06_CHECKER_SPEC.md` 实现。

检查程序只检查确定性内容，不判断自然度和 CEFR 精确等级。

必须提供：

- 单元测试；
- 示例输入输出；
- JSON 报告；
- 终端摘要；
- 可配置阈值；
- 非零错误退出码。

## 七、目录建议

```text
wordloop-course-pipeline/
  prompts/
  schemas/
  src/
    planner/
    blueprint/
    candidates/
    checker/
    reviewer/
    orchestrator/
  data/
    inputs/
    outputs/
    catalog/
  tests/
  README.md
```

可以根据现有 WordLoop 项目结构调整，但职责边界要保留。

## 八、推荐的 CLI

至少支持：

```bash
# 规划一批课程
course-pipeline plan --config production-config.json

# 批准课程池
course-pipeline approve-plan --file curriculum-plan.json

# 生成单课蓝图
course-pipeline blueprint --course C001

# 批准蓝图
course-pipeline approve-blueprint --course C001

# 生成候选、检查并组课
course-pipeline build --course C001

# 对失败槽位重试
course-pipeline retry --course C001 --slots 7,14

# 批量执行全部已批准蓝图
course-pipeline build-approved
```

## 九、完成标准

完成后必须能够：

1. 从一份生产配置自动生成课程池；
2. 人工批准课程池后生成单课蓝图；
3. 人工批准蓝图后生成 40 个候选句；
4. 运行检查程序并输出结构化报告；
5. 将候选句、蓝图和报告交给 Prompt 3；
6. 得到最终 20 句或明确的待重生槽位；
7. 保存完整过程文件，支持局部重试；
8. 使用示例配置完整跑通至少一门课程；
9. 在 README 中写明安装、配置、运行和人工审核方式。

## 十、实现原则

> Prompt 负责语言判断，程序负责确定性检查，人负责最终教学价值。
