# Coding Handoff

## Current phase

阶段 0 至阶段 10 已经完成并提交，首版 MVP 功能实现阶段结束，当前基线为 `cecf2d3`。模拟器构建、单元测试和关键 UI 自动化已经通过。2026-09-04 已在 iPhone 13 mini（iOS 26.2）完成安装、签名信任与基础真机运行验证，核心流程暂未发现明显问题。

这次结果属于真机冒烟验证，不替代发布前专项验收。后台、锁屏、60 分钟以上长路线、定位拒绝、进程终止、HealthKit 权限组合与写入幂等、无障碍和显示矩阵仍以 `docs/technical/device-acceptance-checklist.md` 为准。

## Start here

开始 Coding 或审查实现范围时，按顺序阅读：

1. `CONTEXT.md`：使用 Further 的规范领域语言。
2. `docs/product/first-version-scope.md`：确认首版包含与排除的能力。
3. `docs/product/page-and-state-specification.md`：确认页面状态、流程和验收结果。
4. `docs/product/data-model-and-system-boundaries.md`：确认数据语义与系统权威。
5. `docs/technical/architecture.md`：确认模块、interface、seam、adapter 和测试策略。
6. `docs/technical/implementation-plan.md`：只实施当前阶段，不提前进入后续阶段。
7. 若任务来自新的 UI/美术设计阶段，先读 `docs/agents/ui-design-handoff.md`，不要直接用当前占位界面反推最终设计。

涉及产品动机、信息结构或视觉职责时，再读取对应的 `docs/product/` 文档；涉及难以逆转的决定时，读取相关 `docs/adr/`。

## Next task

当前没有待立即实施的 Coding 阶段。下一阶段是独立的 UI、交互与美术设计讨论：

- 以 `docs/agents/ui-design-handoff.md` 为入口，在不改变已确认产品范围和领域语义的前提下确定作品、收束、跑步、回望、作品集和设置的视觉与交互语言。
- 先更新产品设计文档并形成可验收的 UI 规格，再另行编写 UI 实施计划；设计讨论期间不直接重写现有 SwiftUI 页面。
- 发布前仍需完成 `docs/technical/device-acceptance-checklist.md` 的专项真机验收；发现的问题作为首版发布阻塞项单独修复，不混入视觉重构或新功能。

在新的产品计划确认前，不实现编辑、删除、分享、统计比较或跨产品能力。

## Collaboration

遵循 `docs/technical/architecture.md` 的“实施协作约定”。首次落地关键 Swift 或 Apple 框架能力时，先结合当前改动解释产品问题、模块位置、生命周期约束和验证方式；完成后指出最值得阅读的入口文件与状态流。

## Maintain this handoff

每个 Coding 阶段通过验收并完成阶段提交后，更新“Current phase”和“Next task”，使下一次 session 能直接从唯一的下一项工作继续。不要在本文复制产品规格、技术架构或对话历史。
