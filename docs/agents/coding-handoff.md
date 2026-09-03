# Coding Handoff

## Current phase

阶段 0 至阶段 4 已经完成并提交。尚未进入收束表达或系统能力阶段。

## Start here

开始 Coding 或审查实现范围时，按顺序阅读：

1. `CONTEXT.md`：使用 Further 的规范领域语言。
2. `docs/product/first-version-scope.md`：确认首版包含与排除的能力。
3. `docs/product/page-and-state-specification.md`：确认页面状态、流程和验收结果。
4. `docs/product/data-model-and-system-boundaries.md`：确认数据语义与系统权威。
5. `docs/technical/architecture.md`：确认模块、interface、seam、adapter 和测试策略。
6. `docs/technical/implementation-plan.md`：只实施当前阶段，不提前进入后续阶段。

涉及产品动机、信息结构或视觉职责时，再读取对应的 `docs/product/` 文档；涉及难以逆转的决定时，读取相关 `docs/adr/`。

## Next task

实施阶段 5“收束与记录进入作品”：

- 提供默认沉默、感受色、短记和保持沉默的表达路径。
- 在室内流程中允许手动填写或跳过距离，跳过后继续保持未知。
- 最终锁定表达，并让记录原子地进入当前作品。
- 展示记录进入作品的基础反馈，闭合首个完整核心循环。

完成标准以实施计划中的阶段 5 验收条件为准；不要提前进入阶段 6，不实现 Core Location、HealthKit、回望或作品集。

## Collaboration

遵循 `docs/technical/architecture.md` 的“实施协作约定”。首次落地关键 Swift 或 Apple 框架能力时，先结合当前改动解释产品问题、模块位置、生命周期约束和验证方式；完成后指出最值得阅读的入口文件与状态流。

## Maintain this handoff

每个 Coding 阶段通过验收并完成阶段提交后，更新“Current phase”和“Next task”，使下一次 session 能直接从唯一的下一项工作继续。不要在本文复制产品规格、技术架构或对话历史。
