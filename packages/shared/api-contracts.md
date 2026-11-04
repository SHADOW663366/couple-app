# API 约定（M1）

Base URL: `http://localhost:3000`

## Auth

### POST /auth/register
```json
{ "email": "a@example.com", "password": "secret1", "nickname": "阿狸" }
```
响应：`{ accessToken, user: { id, email, nickname, pairId, bound } }`

### POST /auth/login
```json
{ "email": "a@example.com", "password": "secret1" }
```

## Users

### GET /users/me
Header: `Authorization: Bearer <token>`  
响应含 `bound`、`partner`（若已绑定）

## Pair

### POST /pair/invite → `{ code, expiresAt, qrPayload }`
### POST /pair/accept `{ "code": "ABC123" }`
### GET /pair/status
### POST /pair/unbind

## Health

### GET /health → `{ ok, service, milestone }`
