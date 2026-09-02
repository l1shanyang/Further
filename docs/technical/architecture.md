# Further 技术架构

> 状态：已确认

## 目标与边界

Further 首版采用 Apple 原生技术栈，在保持工程简单的同时，优先保证长跑追踪可靠、记录不可丢失、领域语义清晰，并为未来备份、Apple Watch 和产品矩阵扩展保留可演进空间。

本文确定模块、interface、seam、adapter、并发模型、持久化、系统集成和测试策略。具体页面布局、作品美术规则以及逐文件实施顺序由后续阶段决定。

## 工程基础

- 最低系统版本保持 iOS 18。
- 使用 Swift 6、SwiftUI，并保持完整严格并发检查。
- 使用 SwiftData、Core Location、HealthKit、MapKit 和 OSLog。
- 首版不引入第三方依赖。
- App 保持单一 target，不拆成本地 Swift Package 或多个 framework。
- 保留单元测试 target，并在实施阶段增加 UI 测试 target。
- 不建立 CloudKit、App Group 或共享数据库。

SwiftData 提供持久化容器、内存配置和显式迁移能力；Core Location 的持续后台定位需要工程声明 Location Background Mode，并只在真实跑步期间启用；iPhone 端使用 `HKWorkoutBuilder` 和 `HKWorkoutRouteBuilder` 写入完成后的 workout 与路线。

相关官方资料：

- [SwiftData ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [SwiftData Schema](https://developer.apple.com/documentation/swiftdata/schema)
- [Core Location 后台更新](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)
- [HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder)
- [创建 workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)

## 组织方式

工程采用单体但模块化的结构，按业务能力组织，不按 `Views`、`Models`、`Managers` 横向堆放所有代码。

建议目录职责如下：

- `App`：组合入口、启动协调与根级路由。
- `Domain`：领域值类型、状态、规则和版本化数据契约。
- `Persistence`：SwiftData 模型、容器、迁移与映射。
- `Features/Artwork`：当前作品、周期选择和已完成作品。
- `Features/Run`：环境选择、倒数和跑步追踪。
- `Features/Reflection`：感受收束、室内距离和记录进入作品。
- `Features/Lookback`：回望与单次记录。
- `Features/Collection`：作品集与已完成作品浏览。
- `Features/Settings`：单位与权限状态。
- `Integrations/Location`：Core Location adapter。
- `Integrations/Health`：HealthKit adapter 与写入协调。
- `Artwork`：作品生成和可渲染描述。
- `Support`：少量跨领域基础设施，例如日志和本地化。

目录用于维持代码局部性，不表示每个目录都需要独立 target、protocol 或公开 interface。只有确实隐藏复杂行为、被调用方共同使用的能力才形成模块。

## 依赖方向

SwiftUI 页面只负责呈现状态和发送用户意图。页面不能直接操作 SwiftData、Core Location 或 HealthKit，也不能自行拼接跨实体状态变化。

依赖方向固定为：

1. 页面依赖对应流程的状态模型。
2. 状态模型依赖业务模块提供的 interface。
3. 业务模块依赖持久化能力或系统 seam。
4. 生产 adapter 在 App 组合入口中注入。

领域值类型不依赖 SwiftUI、SwiftData、Core Location 或 HealthKit。系统框架对象在 adapter 内转化为领域类型，不能穿透到页面或版本化数据契约。

`FurtherApp` 是唯一组合入口，负责创建持久化容器、生产 adapter、业务模块和根状态模型。业务模块接受依赖，不在内部自行构造全局单例。

## 核心模块

### FurtherStore

`FurtherStore` 是持久化领域状态的深模块，负责：

- 当前作品唯一性
- 跑步开始时的活动身份与作品归属
- 检查点保存
- 正常结束与技术中断
- 收束草稿和最终表达锁定
- 作品完成与归集
- 回望和作品集读取快照
- 外部写入状态

它的 interface 使用领域操作，例如开始跑步、保存检查点、结束跑步、锁定表达和开始下一幅作品。它不向调用方暴露通用 CRUD、`ModelContext` 或 SwiftData `@Model` 对象。

跨活动、表达和作品的变化由 `FurtherStore` 原子保存。调用方不需要理解多个持久化对象的写入顺序。

### RunRecorder

`RunRecorder` 是实时跑步追踪的深模块，负责：

- 明确的跑步状态机
- 基于时间点计算计时
- 暂停和继续
- 消费位置流
- 位置质量判断与距离累计
- 检查点触发
- 正常结束

它向页面提供只读运行快照，以及开始、暂停、继续和结束等少量命令。页面不协调计时器、定位 delegate、距离算法或数据库写入。

跑步状态使用明确枚举表示准备、倒数、运动中、暂停和结束，不由多个可能矛盾的布尔值组合。

### ArtworkEngine

`ArtworkEngine` 是纯计算模块。它根据作品快照、视觉生成版本、稳定种子和版本化参数产生可渲染描述。

该模块不读取数据库、不修改作品，也不持有 SwiftUI View。相同输入必须得到相同结果，使作品可重建、可测试，并避免 App 更新无意改写历史作品。

### HealthExporter

`HealthExporter` 负责：

- HealthKit 授权结果解释
- 接收已经结束的活动快照
- 创建 workout、事件、距离样本和路线
- 保存 HealthKit UUID
- 使用产品全局活动 ID 保证幂等
- 处理部分失败和静默重试

它不接触进行中的跑步会话，不拥有本地活动、表达或作品状态。感受色、短记和作品信息不写入 HealthKit。

### AppBootstrap

`AppBootstrap` 负责启动时的协调：

- 打开并验证持久化数据
- 将遗留进行中会话形成技术中断记录
- 将遗留收束草稿锁定为最终表达
- 检查时间作品边界
- 返回根级初始路由与必要的一次性说明

页面不自行判断数据库中残留状态，也不承担恢复顺序。

## Seam 与 adapter

只有行为确实需要在生产和测试间变化时才建立 seam：

- `LocationSource`：生产 adapter 使用 Core Location，测试 adapter 输出固定位置序列。
- `HealthWriter`：生产 adapter 使用 HealthKit，测试 adapter 模拟成功、拒绝和部分失败。
- `TimeSource`：生产 adapter 使用系统时间，测试 adapter 可精确推进时间。

SwiftData 不额外套一层逐实体 Repository protocol。生产测试使用磁盘配置，集成测试使用内存 `ModelContainer`；`FurtherStore` 本身已经隔离了调用方与 SwiftData 实现。

不为只有一个实现且没有测试替代需求的对象提前创建 protocol。内部实现可以继续拆分，但不会仅为了测试而扩大外部 interface。

## 持久化策略

SwiftData 是首版本地持久化实现。从第一版开始定义 `VersionedSchema` 和 `SchemaMigrationPlan`，使未来字段和关系变化具有明确迁移路径。

SwiftData `@Model` 类型只存在于 Persistence 内部。业务模块和页面使用不可变、`Sendable` 的领域快照；SwiftData 模型对象不跨 actor 或进入 SwiftUI 页面。

持久化由独立 actor 串行管理其 `ModelContext`。页面不使用 `@Query` 后直接修改对象，业务规则也不依赖隐式自动保存完成原子操作。

### 路线

路线点首版使用独立子记录，包含测量事实、质量判断和算法版本。`RunRecorder` 缓冲位置后批量交给持久化实现，避免每次 UI 刷新都写数据库。

如果真机性能测试证明逐点记录不能满足长跑需要，可以替换 Persistence 内部的路线实现，例如改为分块存储；业务模块 interface 和共享活动数据契约保持不变。

### 检查点

计时画面的每秒刷新只更新内存状态，不写数据库。检查点至少由以下事件触发：

- 正式开始
- 可靠位置更新后的受控批次
- 暂停
- 继续
- 进入后台
- 正常结束

实现可以增加有上限的周期检查点，但不能依赖每秒持久化保证可靠性。

### 数据契约与缓存

可移植数据契约使用独立 `Codable` 值类型，不直接编码 SwiftData 模型。契约从首版建立编码、解码和语义往返测试。

作品渲染图片、派生配速和查询摘要属于可重建缓存。缓存损坏或丢失不能影响原始活动、表达、作品关系和路线事实。

## 并发模型

- 页面状态模型运行在 `@MainActor`。
- `RunRecorder`、持久化与 `HealthExporter` 分别拥有 actor 隔离。
- Core Location delegate 封装在生产 adapter 内，并向 `RunRecorder` 输出规范化位置流。
- 页面消费状态模型整理后的 Observation 状态，不直接处理 delegate 回调。
- 领域快照和值类型满足 `Sendable`，跨 actor 只传递值，不传递可变框架对象。

计时以开始、暂停、继续和当前时间点计算，不以每秒累加整数作为权威事实。位置过滤与距离累计是带版本的纯计算模块，可使用固定位置样本重复验证。

普通后台运行或系统挂起不结束跑步。后台位置更新只在正在进行的室外跑步中启用，并在结束后立即关闭。下一次启动发现无法继续的遗留进行中会话时，才形成技术中断记录。

## 界面状态与导航

根级导航使用单一、类型安全的路由状态，避免各页面用多个展示布尔值共同决定当前空间。

- 当前作品是根空间。
- 回望、作品集、单次详情和设置使用 `NavigationStack`。
- 跑步、收束和记录进入作品组成连续的全屏流程。
- 一个状态模型可以覆盖一个完整流程，不为每个简单页面机械创建对象。
- 持久化事实只来自 `FurtherStore`；输入焦点、临时动画等纯界面状态保留在页面本地。

SwiftUI Preview 使用内存数据和显式样例。样例构造不能写入真实 App 数据库，也不能在真实空白作品中出现。

## HealthKit 与系统能力

工程实施时启用 HealthKit capability 和 Location Background Mode。定位权限、后台定位和 HealthKit 写入彼此独立降级。

HealthKit 授权流程在本地记录完成收束、进入作品之后触发。实际导出由 `HealthExporter` 接管，页面不等待外部写入才能确认作品更新。

正常结束和技术中断都可以导出其中可靠的客观事实。权限拒绝停止自动写入尝试；临时失败保留静默重试状态。任何 HealthKit 结果都不能回滚本地记录。

## 错误、隐私与恢复

- 不使用 `try?` 静默吞掉关键持久化、追踪或导出错误。
- 权限拒绝、距离缺失和 HealthKit 不可用是正常降级，不是致命错误。
- SwiftData 容器无法打开时显示非破坏性的阻断状态，不创建新数据库覆盖旧数据。
- 使用 OSLog 记录必要诊断，但不记录短记全文、完整路线、精确坐标或可识别个人内容。
- 技术中断原因只保存结构化类别和最后检查点，不把日志文件混入活动记录。
- 数据库、路线和缓存使用系统应用容器与数据保护，不自行引入未经验证的加密方案。

## 本地化

所有用户可见文案从首版进入 String Catalog，不在 SwiftUI 页面散落硬编码字符串。

首版只维护英文界面，与 `Further` 和 `still going.` 的现有语气保持一致。工程结构允许未来增加简体中文，但当前不同时维护两套产品文案。

## 测试策略

测试通过模块的 interface 验证可观察行为，不越过 interface 绑定内部实现。

### 领域测试

覆盖作品周期、跨边界跑步、里程碑、技术中断、暂停时长、距离缺失、表达锁定和作品唯一性。

### 持久化集成测试

使用内存 SwiftData 容器验证原子状态变化、模型映射、唯一当前作品、迁移和数据契约往返。

### 跑步追踪测试

使用测试时间源和位置 adapter 验证倒数、计时、暂停、距离、位置缺口和检查点。

### HealthKit 协调测试

使用测试 adapter 验证授权拒绝、临时失败、部分失败、重试和幂等。

### UI 与真机验收

UI 测试只覆盖首次建立作品、完整跑步收束、技术中断后的启动，以及开启下一幅作品等关键路径。美术语言确定前不加入脆弱的全屏截图测试。

后台定位、锁屏持续追踪、长时间路线写入和 HealthKit 导出必须通过真机验收，不能只依赖模拟器。

## 实施协作约定

项目所有者目前没有 Swift 原生开发经验。实施过程除了交付代码，还应逐步建立对 Swift、SwiftUI 和 Apple 系统框架的理解。

每项关键能力第一次实施前，需要结合当前任务说明：

1. 它解决的产品问题。
2. 它所在模块及依赖方向。
3. 相关 Swift 或 Apple 框架的关键生命周期约束。
4. 将使用什么测试或真机场景验证。

实施完成后，指出最值得阅读的入口文件和关键类型，解释状态如何流动以及错误如何降级。解释应紧贴 Further 的真实代码，不额外扩展成脱离项目的通用课程。

对难以逆转的技术决策，先说明替代方案和取舍，再实施并在满足条件时记录 ADR。普通、可逆的实现细节由架构原则约束，不为每项选择增加文档和抽象。

## 暂不实施

- Apple Watch target 与多设备 workout
- Widget 和 Live Activity
- CloudKit 与跨设备同步
- App Group 与产品矩阵实时共享
- 完整备份和恢复界面
- AI 艺术生成与多套艺术风格
- 第三方分析、崩溃上报或行为统计 SDK
