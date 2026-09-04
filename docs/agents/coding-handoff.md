# Coding Handoff

## Current phase

阶段 0 至阶段 6 已经完成并提交。阶段 6 的真机后台、锁屏和真实长路线验收尚未完成，必须作为验证债务保留，但不阻塞后续模拟器开发。

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

实施阶段 7“回望与单次记录”：

- 提供按跑步开始地当地年月分组的回望列表。
- 展示感受、短记和弱化的客观事实，并区分正常结束与技术中断。
- 提供只读的单次记录详情，正确呈现路线存在与缺失状态。
- 缺失短记、距离或路线不能阻止详情展示，不提供编辑或删除入口。

完成标准以实施计划中的阶段 7 验收条件为准。继续保留阶段 6 的真机验证债务，不实现 HealthKit、作品集、编辑或删除能力。

## Collaboration

遵循 `docs/technical/architecture.md` 的“实施协作约定”。首次落地关键 Swift 或 Apple 框架能力时，先结合当前改动解释产品问题、模块位置、生命周期约束和验证方式；完成后指出最值得阅读的入口文件与状态流。

## Maintain this handoff

每个 Coding 阶段通过验收并完成阶段提交后，更新“Current phase”和“Next task”，使下一次 session 能直接从唯一的下一项工作继续。不要在本文复制产品规格、技术架构或对话历史。
