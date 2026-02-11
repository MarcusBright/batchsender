# Disperse 合约安全审计报告

## 基本信息

| 项目 | 详情 |
|------|------|
| **合约名称** | Disperse |
| **文件路径** | `src/Disperse.sol` |
| **Solidity 版本** | `^0.8.20` |
| **编译器设置** | optimizer = true, runs = 200 |
| **许可证** | MIT |
| **审计日期** | 2026-02-11 |
| **代码行数** | 181 行（含注释） |
| **测试用例** | 27 个（全部通过） |

---

## 审计范围

| 文件 | 描述 |
|------|------|
| `src/Disperse.sol` | 核心业务合约 |
| `src/mocks/MockERC20.sol` | 测试用 ERC20 代币 |
| `test/Disperse.t.sol` | 测试套件（27 个测试） |
| `script/Deploy.s.sol` | 部署脚本 |

---

## 审计结果汇总

| 严重程度 | 数量 | 状态 |
|---------|------|------|
| 🔴 严重 (Critical) | 0 | — |
| 🟠 高危 (High) | 0 | — |
| 🟡 中危 (Medium) | 0 | — |
| 🔵 低危 (Low) | 2 | 已知限制（文档说明） |
| ℹ️ 信息 (Informational) | 2 | 设计选择 |

---

## 合约概述

Disperse 是一个无状态的批量转账工具合约，支持：

1. **disperseNative**: 批量发送原生代币（ETH/BNB 等）
2. **disperseToken**: 批量发送 ERC20 代币（先汇聚后分发）
3. **disperseTokenSimple**: 批量发送 ERC20 代币（直接分发，适用于 fee-on-transfer 代币）

---

## 安全分析

### 1. 重入攻击防护 ✅

**分析位置**: `disperseNative` 函数 L67-L101

合约在退款阶段使用 `msg.value - total` 计算退款金额，而非 `address(this).balance`：

```solidity
// Refund excess native tokens
// Use msg.value - total instead of address(this).balance to prevent
// reentrancy attack where inner calls drain funds via inflated refund
uint256 refund = msg.value - total;
if (refund > 0) {
    (bool success, ) = msg.sender.call{value: refund}("");
    if (!success) revert RefundFailed();
}
```

**结论**: 即使恶意接收者在 `receive()` 回调中重入，也无法通过膨胀余额来盗取资金。测试用例 `testDisperseNativeReentrantRecipient` 验证了此防护有效。

---

### 2. 输入验证 ✅

所有函数均实现了完整的输入验证：

| 检查项 | 错误类型 | 覆盖函数 |
|-------|---------|---------|
| 数组长度不匹配 | `LengthMismatch()` | 全部 |
| 空数组 | `EmptyRecipients()` | 全部 |
| 零地址接收者 | `ZeroAddress()` | 全部 |
| 发送金额不足 | `InsufficientValue()` | `disperseNative` |

---

### 3. 外部调用安全 ✅

| 函数 | 调用方式 | 返回值检查 |
|-----|---------|-----------|
| `disperseNative` | `call{value:}("")` | ✅ 检查 `success` |
| `disperseToken` | `transferFrom` / `transfer` | ✅ 检查 `bool` 返回值 |
| `disperseTokenSimple` | `transferFrom` | ✅ 检查 `bool` 返回值 |

---

### 4. 整数溢出保护 ✅

Solidity 0.8.x 默认启用溢出检查。循环计数器使用 `unchecked { ++i; }` 是安全的，因为：
- 数组长度受 EVM 限制
- 不可能循环超过 `type(uint256).max` 次

---

## 已知限制

### 🔵 L-1: 非标准 ERC20 代币不兼容

**描述**: 合约使用标准 `IERC20` 接口，部分代币（如 USDT）的 `transfer`/`transferFrom` 不返回 `bool`，调用时会 revert。

**影响**: 无法直接用于 USDT 等非标准代币。

**缓解**: NatSpec 已明确标注限制，建议用户使用 SafeERC20 包装器。

---

### 🔵 L-2: Fee-on-transfer 代币限制

**描述**: `disperseToken` 函数先汇聚代币再分发，对于 fee-on-transfer 代币会因余额不足而失败。

**影响**: 无法用 `disperseToken` 处理 fee-on-transfer 代币。

**缓解**: 
- NatSpec 已标注 `WARNING: Not compatible with fee-on-transfer tokens`
- 提供 `disperseTokenSimple` 作为替代方案

---

## 信息性说明

### ℹ️ I-1: 无状态设计优势

合约不存储任何状态变量：
- ✅ 无资金锁定风险
- ✅ 无权限管理风险
- ✅ 无升级/代理风险
- ✅ 重入攻击影响有限

---

### ℹ️ I-2: Gas 优化措施

| 优化项 | 说明 |
|-------|------|
| `calldata` 参数 | 避免 memory 拷贝 |
| `unchecked { ++i; }` | 节省溢出检查开销 |
| 缓存数组长度 | `uint256 len = recipients.length` |
| Custom Errors | 比 `require` 字符串节省 gas |
| 预计算 total | 提前验证 `msg.value` 避免无效交易 |

---

## 测试覆盖

### 测试结果

```
Ran 27 tests for test/Disperse.t.sol:DisperseTest
Suite result: ok. 27 passed; 0 failed; 0 skipped
```

### 测试用例分类

| 类别 | 数量 | 说明 |
|-----|------|------|
| 正常流程 | 11 | 基础转账、单接收者、重复接收者、大批量 |
| 错误处理 | 14 | 零地址、无授权、余额不足、空数组等 |
| Fuzz 测试 | 2 | 随机金额分发（256 runs） |
| 安全测试 | 2 | 重入攻击、接收者拒绝 ETH |

### 关键安全测试

- `testDisperseNativeReentrantRecipient`: ✅ 重入攻击防护有效
- `testRevertDisperseNativeRecipientRejects`: ✅ 接收者拒绝时正确 revert
- `testDisperseNativeLargeBatch`: ✅ 100 接收者批量转账成功（gas: 3,607,572）

---

## 合约接口

### disperseNative

```solidity
function disperseNative(
    address[] calldata recipients,
    uint256[] calldata values
) external payable
```

批量发送原生代币，多余金额自动退还。

### disperseToken

```solidity
function disperseToken(
    IERC20 token,
    address[] calldata recipients,
    uint256[] calldata values
) external
```

批量发送 ERC20 代币。**不兼容 fee-on-transfer 代币。**

### disperseTokenSimple

```solidity
function disperseTokenSimple(
    IERC20 token,
    address[] calldata recipients,
    uint256[] calldata values
) external
```

批量发送 ERC20 代币（直接分发）。**推荐用于 fee-on-transfer 代币。**

---

## 事件定义

```solidity
event DisperseNative(
    address indexed sender,
    uint256 totalAmount,
    uint256 recipientCount
);

event DisperseToken(
    address indexed token,
    address indexed sender,
    uint256 totalAmount,
    uint256 recipientCount
);
```

---

## 部署建议

1. **网络兼容**: 所有 EVM 兼容链均可部署
2. **代码验证**: 部署后在区块浏览器验证源码
3. **代币兼容性**:
   - 标准 ERC20: ✅ 完全兼容
   - USDT 等非标准: ⚠️ 需 SafeERC20 包装
   - Fee-on-transfer: ⚠️ 使用 `disperseTokenSimple`

---

## 结论

### 审计结果

| 项目 | 结果 |
|-----|------|
| 严重/高危漏洞 | **0** |
| 中危漏洞 | **0** |
| 低危（已知限制） | **2** |
| 测试覆盖 | **27/27 通过** |
| 代码质量 | ✅ 良好 |

### 最终评级

🟢 **审计通过** - 合约可安全部署使用

---

## 审计声明

本审计报告仅针对上述合约代码进行安全评估，不构成投资或使用建议。智能合约存在固有风险，使用前请自行评估。

---

*审计完成日期: 2026-02-11*
