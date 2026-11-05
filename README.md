# Couple App（情侣向）

移动端情侣 App：账号登录、单人/双人模式、二次元 AI 角色、真心话、日记（图/语音）。

## 仓库结构

```
apps/api       NestJS 后端（账号 / 绑定 / 真心话 / 日记）
apps/mobile    Flutter 客户端
packages/shared  共享类型（可选）
docs           需求与架构说明
```

## 环境

| 工具 | 状态说明 |
|------|----------|
| Node.js 20+ | 已用于 API |
| Flutter 3.x | 需本机安装后才能跑客户端 |
| 数据库 | 本地开发默认 SQLite（Prisma），生产可切 PostgreSQL |

公网 API（SnapDeploy）：见 `apps/mobile/lib/core/config.dart` 默认地址。

## 快速启动 — API

```bash
cd apps/api
cp .env.example .env
npm install
npx prisma db push
npm run start:dev
```

默认：`http://localhost:3000`  
健康检查：`GET /health`

## 快速启动 — Mobile

1. 安装 [Flutter](https://docs.flutter.dev/get-started/install)
2. 执行：

```bash
cd apps/mobile
flutter pub get
flutter run
```

可用 `--dart-define=API_BASE_URL=...` 覆盖 API 地址。

## 当前里程碑

- **M1**：注册登录、邀请码绑定/解绑
- **真心话**：本地题库单人/双人
- **日记**：私密 / 分享 / 共同 + 图片语音
- **AI 角色**：选模板单聊（可选 DeepSeek Key）
- 后续：双人 AI → 亲密度 / 推送 → 外置 Postgres 防丢

详见 `docs/待完成清单.txt`、`docs/架构说明.txt`。
