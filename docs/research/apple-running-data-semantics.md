# Apple 平台跑步数据语义研究

> 研究日期：2026-09-01
> 范围：iPhone 首版跑步追踪、HealthKit/Core Location、产品矩阵数据契约
> 来源：仅采用 Apple 官方文档

## 结论摘要

1. `HKWorkout` 适合作为系统级跑步事实的摘要与容器；它保存活动类型、起止时间、持续时间、总距离等摘要，并可关联更细粒度的样本。[HKWorkout](https://developer.apple.com/documentation/healthkit/hkworkout)
2. iPhone 上可以使用 `HKWorkoutBuilder` 增量构建并保存 workout；Apple 明确区分 iPhone 的 `HKWorkoutBuilder` 与 watchOS 常用的 `HKWorkoutSession` + `HKLiveWorkoutBuilder`。[HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder)
3. 室外路线应由 Core Location 的 `CLLocation` 序列形成，并通过 `HKWorkoutRouteBuilder` 与 workout 关联。路线包含经纬度、海拔和时间；Apple 要求过滤低精度位置，并建议位置间隔不超过约 3 秒。[Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)
4. iPhone 本身没有心率传感器。iPhone 跑步只有在连接外部心率设备时才可能采集心率；Apple Watch 自动产生的一些跑姿数据不能假定在 iPhone 首版可用。[HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
5. HealthKit 样本具有 UUID、时间范围、来源版本、设备和 metadata；这些信息是去重、追踪来源和未来互操作的重要基础。[HKObject sourceRevision](https://developer.apple.com/documentation/healthkit/hkobject/sourcerevision)、[HKDevice](https://developer.apple.com/documentation/healthkit/hkdevice)、[HKSample](https://developer.apple.com/documentation/healthkit/hksample)
6. HealthKit workout 的摘要值与关联样本是两个层次。Apple 建议在相关数据可用时同时提供 workout 摘要，以及能够汇总到摘要的细粒度样本。[Adding samples to a workout](https://developer.apple.com/documentation/healthkit/adding-samples-to-a-workout)

## Apple 的数据对象关系

```text
HKWorkout
  ├── 跑步活动类型
  ├── 起止时间、持续时间
  ├── 总距离、总能量等摘要
  ├── HKWorkoutEvent（暂停等事件）
  ├── HKQuantitySample（距离、能量、心率等时段样本）
  └── HKWorkoutRoute
        └── 分批读取的 CLLocation 序列
```

`HKWorkoutBuilder` 可以开始和结束采集、添加样本与事件、添加 metadata、生成统计，并在完成后保存 `HKWorkout`。[HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder)

`HKWorkoutRoute` 是 `HKSeriesSample`，路线可能包含大量位置点，因此 Apple 提供异步、分批读取的 route query，而不是把路线视为一个普通数组字段。[HKWorkoutRoute](https://developer.apple.com/documentation/healthkit/hkworkoutroute)

## iPhone 首版能够可靠承担的内容

### 所有跑步场景

- 跑步会话的开始时间、结束时间和持续时间。
- 用户主动暂停、继续与结束产生的会话事件。
- App 自己的稳定活动标识与 schema 版本。
- 感受色、短记或沉默表达。

### 室外路跑、操场与越野

- Core Location 位置序列：时间、经纬度、海拔，以及水平/垂直精度。
- 基于经过质量过滤的位置序列形成的累计距离。
- 路线可以写入 `HKWorkoutRoute` 并关联到对应的 `HKWorkout`。[Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)
- 长跑期间 App 进入后台后仍需持续接收位置，因此必须声明 Location background mode 并在运动期间开启后台位置更新。[Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)、[allowsBackgroundLocationUpdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)

### 室内跑步机

- `HKWorkoutConfiguration.locationType` 可以区分 indoor 与 outdoor。[HKWorkoutConfiguration](https://developer.apple.com/documentation/healthkit/hkworkoutconfiguration)
- 室内没有可用于真实跑步距离的 GPS 路线，不能把缺失路线解释为采集失败。
- 仅凭 iPhone 无法保证获得可靠的跑步机距离。距离来源必须允许缺失，或明确来自跑步机、外部传感器、HealthKit 中其他设备，不能伪造为 GPS 距离。

最后两点是基于 Apple 的 indoor/outdoor 配置与 Core Location 路线语义作出的产品推论，Apple 没有承诺 iPhone 能自动获得跑步机距离。

## 可用数据与可选数据

### 规范基础

- `distanceWalkingRunning`：步行或跑步距离。[HKQuantityTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)
- workout 摘要：持续时间、总距离、总能量等。[HKWorkout](https://developer.apple.com/documentation/healthkit/hkworkout)
- 细粒度样本：距离、能量、步数、心率等可以按时间片关联到 workout。[Adding samples to a workout](https://developer.apple.com/documentation/healthkit/adding-samples-to-a-workout)
- 路线：`CLLocation` 序列，可用于路线呈现或派生分段速度。[Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)

### 不能在 iPhone 首版假定存在

- 心率：iPhone/iPad 需要外部心率传感器。[HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- running speed、stride length、running power、ground contact time、vertical oscillation：HealthKit 定义了这些类型，但 Apple 文档明确提到其中的 running speed 会在 Apple Watch 室外跑步时由系统自动记录；iPhone 首版应把整组跑姿指标视为可选来源数据，而不是必填字段。[HKQuantityTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)、[Running Speed](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/runningspeed)
- 室内路线与 GPS 距离。

## 数据来源和身份

每条共享活动记录至少需要保留以下身份语义：

- 产品矩阵自己的全局活动 ID，用作跨产品稳定身份。
- HealthKit 保存后的 UUID，用作与系统对象关联的身份。Apple 说明 HealthKit 自己分配 UUID；若 App 需要自己的 ID，应使用 `HKMetadataKeyExternalUUID` 写入 metadata。[HKObject UUID](https://developer.apple.com/documentation/healthkit/hkobject/uuid)
- schema 版本。
- 创建记录的产品与版本。
- 生成样本的设备信息。
- 原始数据来源、来源版本与系统版本。HealthKit 在读取对象时提供 `sourceRevision`，其中包含来源、版本、产品类型和系统版本。[sourceRevision](https://developer.apple.com/documentation/healthkit/hkobject/sourcerevision)、[HKSourceRevision version](https://developer.apple.com/documentation/healthkit/hksourcerevision/version)

不要把 `HKDevice.localIdentifier` 当作跨设备全局 ID。Apple 明确说明同一外设连接不同 Apple 设备时会产生不同 local identifier，设备更新也可能改变它。[localIdentifier](https://developer.apple.com/documentation/healthkit/hkdevice/localidentifier)

## 时间、单位和缺失值建议

以下是基于 Apple 数据语义形成的数据契约建议：

- 保存绝对起止时间，同时保存跑步开始地的时区标识，便于未来按当地日期回顾。
- 统一使用规范基础单位持久化，例如持续时间用秒、距离用米；展示时再按用户偏好转换。
- 原始值和派生值分开，并记录派生算法版本。
- 每个可选指标需要同时记录值、来源和覆盖范围；不能用 `0` 代替未知。
- 路线点保留时间、经纬度、海拔和精度，先通过质量规则过滤，再参与距离计算。
- 摘要值与细粒度样本可以同时存在，但需要定义一致性校验规则。Apple 明确指出后添加的样本不会自动改写 workout 的摘要属性。[Adding samples to a workout](https://developer.apple.com/documentation/healthkit/adding-samples-to-a-workout)

## HealthKit 与 App 数据库的职责建议

### HealthKit

- Apple 生态中的系统级 workout 与健康数据交换层。
- 保存 `HKWorkout`、关联的 quantity samples 和 `HKWorkoutRoute`。
- 允许系统“健身”与其他授权 App 识别 Further 记录的跑步。

### Further 自有数据

- 保存产品矩阵全局活动 ID、数据契约版本和同步状态。
- 保存感受色、短记、沉默及其锁定状态。
- 保存用于中断恢复的进行中会话状态。
- 保存 HealthKit UUID 与产品矩阵活动 ID 的映射。
- 必要时保存规范化事实的本地投影，但不能让该投影与 HealthKit 对同一事实形成两个无规则的权威来源。

这是架构建议而非 Apple 强制要求。最终需要明确每类字段的唯一权威来源，以及 HealthKit 写入失败、延迟或用户撤销权限时的处理方式。

## 对 Further 的直接约束

1. “界面只显示时间与距离”可以成立，但底层必须区分摘要、样本、路线、来源和表达数据。
2. 数据契约必须允许合法缺失，尤其是室内距离、路线、心率和 Apple Watch 专属跑姿数据。
3. 路跑、操场和越野可以共享 outdoor running 基础结构，但原始位置质量和海拔质量必须保留，不能只保存最终距离。
4. 运动期间需要后台位置能力，否则 iPhone 锁屏后无法可靠完成长跑路线追踪。
5. 感受色、短记和沉默不属于 HealthKit 标准健康指标，应该由产品矩阵自己的版本化表达结构承载；可以通过外部 UUID 与对应的 HealthKit workout 对齐。
