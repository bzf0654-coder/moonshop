# moonshop

> MoonBit 极简电商演示系统 —— 一个纯 MoonBit 实现的电商领域引擎：商品目录、库存、购物车、定价、下单、订单全链路，加 JSON 持久化与 Markdown 小票输出，零第三方依赖。

## 解决什么问题

用一门新语言"从零造一遍电商核心"是最好的领域建模练习：钱怎么表示（分为单位的整数，拒绝浮点误差）、库存怎么扣（先校验后变更）、价格怎么快照（下单时刻留档，目录改价不改历史）……moonshop 把这些经典问题做成一个**可运行、全测试覆盖的参考实现**，也是 MoonBit 生态里第一个电商领域模型。

## 项目方向与通用性

本项目属于**领域建模 / 后端基础设施**方向。核心是"目录 + 购物车 + 结算"这一类系统的原型骨架：定价规则（批发折扣、满额券、免邮门槛）全部以常量参数化，换一行配置就是另一套玩法；`Store` 聚合与 HTTP 无关，可直接套在任何 Web 框架（mocket / crescent）后面变成真 API，也可移植到订阅制、积分兑换、食堂点餐等任何"可下单"场景。

## 预期使用场景

1. **电商领域建模教学/原型**：用 `moon run cmd/main` 看一次完整购物（导入目录 → 加购物车 → 用券结算 → 出小票 → 超库存被拒 → 订单导出），每一环节都有对应测试；
2. **定价规则实验场**：修改 `pricing.mbt` 顶部的四个常量（免邮门槛/运费/批发起量/折扣比例），重跑测试与演示即可对比规则变化对客单价结构的影响；
3. **MoonBit Web 生态的后端示例骨架**：`Store` + `store_checkout` 是现成的领域层，社区 HTTP 框架接入后即可演示"商品列表 / 下单 / 查单"三个 API。

## 当前功能

- **商品与库存**：JSON 目录导入（脏数据跳过）、按 id 入库合并库存、大小写不敏感的名称/类目搜索、类目清单
- **购物车**：同品合并、改量、删行、非法数量拒绝
- **定价引擎**：分阶段流水线——行小计 → 单品 3 件起 95 折（向下取整）→ 满额优惠券（封顶不透支）→ 满 ¥99 免邮否则 ¥8
- **下单结账**：先校验后变更（库存不足全单拒绝、库存分文不动）、订单号 MO-000001 递增、**下单时刻价格快照**
- **订单**：按单号查询、订单导出为 JSON（可被同一 JsonValue 模型解析回去）
- **小票**：`¥` 两位小数格式化 + GitHub 风格 Markdown 明细（含每个定价阶段）
- **零第三方依赖**：仅 `moonbitlang/core`；JSON 解析/序列化复用自作者本人的 [benchlens](https://github.com/bzf0654-coder/benchlens) 项目（Apache-2.0，文件头已注明）

## 快速开始

```bash
moon run cmd/main   # 完整购物演示：目录导入 → 用券结算 → 小票 → 超库存拒绝 → JSON 导出
moon test           # 24 个行为测试
```

小票输出示例：

```
## Receipt MO-000001

| item | qty | unit | line total |
|---|---:|---:|---:|
| Mech Keyboard 87 | 2 | ¥499.00 | ¥998.00 |
| SSD 1TB NVMe | 3 | ¥459.00 | ¥1377.00 |

- subtotal: ¥2574.00
- bulk discount (qty ≥ 3): -¥68.85
- coupon SAVE5000: -¥50.00
- shipping: free
- **total: ¥2455.15**
```

## API 一览

```moonbit
// 目录与库存
@moonshop.store_new / store_add_product / store_find / store_stock
@moonshop.store_in_stock / store_decrement / store_search / store_categories
// 购物车
@moonshop.cart_new / cart_add / cart_set_qty / cart_remove / cart_total_qty
// 定价与优惠券
@moonshop.price_cart(store, cart, coupon?) -> PriceBreakdown?
@moonshop.coupon_new("SAVE5000", 5000, 100000)
// 结账与订单
@moonshop.store_checkout(store, cart, coupon?) -> Order?
@moonshop.store_find_order / store_orders
// 持久化与输出
@moonshop.store_import_json(store, catalog_json) -> Int
@moonshop.orders_export_json(store) -> String
@moonshop.order_receipt(order) -> String   // Markdown 小票
@moonshop.format_cents(49900)              // "¥499.00"
```

## 路线图

- [x] HTTP API 层：`cmd/server`（js 后端跑在 Node 上，宿主仅 ~20 行 socket 胶水）：商品列表 / 下单 / 订单列表 / 按单号查询 / 健康检查
- [x] 会话持久化：目录/库存/订单经 localStorage 落盘，刷新不丢（wasm-gc 与 js 后端同套宿主桥），带一键重置
- [x] 库存预占：store_reserve / store_available / store_sweep（逻辑时钟），普通结账按可用库存校验，预占结账原子提交
- [x] 更多定价规则：会员折扣（第五阶段）+ 阶梯运费 + 满减 + 批发折扣
- [x] 网页版演示：wasm-gc 优先 + js 自动回退（cmd/web，DOM 桥接仅三函数）
- [x] 管理台：`cmd/admin`（与商店共享引擎和 localStorage 数据）：库存表格补货、订单流水、一键重置
- [ ] HashMap 索引：按 id 点查 O(1)（当前 O(n) 扫描，演示数据量下够用）

## 参赛声明

- 本项目为 **MoonBit 月度黑客松**参赛作品，原创开发
- JSON 解析/序列化模块复用自作者本人的 benchlens 项目（同一作者、同为 Apache-2.0，`json.mbt` 文件头已注明出处），此外未参考或复用任何已有开源项目实现
- 开发过程在本仓库公开进行，每个 commit 对应一个完整功能（含测试）

## License

Apache-2.0

## 网页版演示（wasm-gc 优先，js 自动回退）

```bash
moon build --target wasm-gc
moon build --target js
cp _build/wasm-gc/debug/build/cmd/web/web.wasm web/web.wasm
cp _build/js/debug/build/cmd/web/web.js web/web.js
python -m http.server 8181   # 仓库根目录执行
# 浏览器打开 http://127.0.0.1:8181/web/
```

页面优先加载 **wasm-gc** 后端（约 110KB，比 js 产物小 40%），浏览器不支持时自动回退 js 后端，页首徽标实时显示当前驱动。界面**中英文一键切换**（含商品名、类目、定价明细与历史小票的整体重渲染），**刷新不丢数据**（localStorage 持久化 + 一键重置），全部由 MoonBit 侧管理。商品目录、加购/减购、优惠券开关、结账、小票渲染、库存打减全部是 `cmd/web` 包里的 **MoonBit 代码**在跑——DOM 桥接（`extern "js"` / wasm 宿主导入）只有三个函数，页面零业务 JS。

## HTTP API（Node 运行 MoonBit）

```bash
moon build --target js
node _build/js/debug/build/cmd/server/server.js   # 监听 8080
curl http://127.0.0.1:8080/api/products
curl -X POST http://127.0.0.1:8080/api/checkout   -d '{"lines":[{"id":"sd-01","qty":3}],"coupon":"SAVE5000","rebate":true}'
curl http://127.0.0.1:8080/api/orders/MO-000001
```

## 管理台

`moon build` 后打开 `http://127.0.0.1:8181/web/admin.html`：库存表格逐品补货（数量来自共享输入框）、订单流水表、一键重置——与商店页共享同一份引擎实例数据，补货后商店刷新即见。
