# Coding Handoff

## Current phase

阶段 0 至阶段 10 已经完成并提交，首版实现阶段结束。模拟器构建、单元测试和关键 UI 自动化已经通过；后台、锁屏、长路线和 HealthKit 写入仍待按 `docs/technical/device-acceptance-checklist.md` 完成真机验收。

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

完成首版发布前真机验收，再确定后续产品阶段：

- 在已签名的 iPhone 构建上完成后台、锁屏、长路线、HealthKit 与可访问性验收。
- 将真机发现的问题作为首版发布阻塞项单独修复并回归，不混入新功能。
- 真机验收通过后，根据真实使用反馈另行制定首版后的实施计划。

在新的产品计划确认前，不实现编辑、删除、分享、统计比较或跨产品能力。

## Collaboration

遵循 `docs/technical/architecture.md` 的“实施协作约定”。首次落地关键 Swift 或 Apple 框架能力时，先结合当前改动解释产品问题、模块位置、生命周期约束和验证方式；完成后指出最值得阅读的入口文件与状态流。

## Maintain this handoff

每个 Coding 阶段通过验收并完成阶段提交后，更新“Current phase”和“Next task”，使下一次 session 能直接从唯一的下一项工作继续。不要在本文复制产品规格、技术架构或对话历史。
