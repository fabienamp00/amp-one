# AMP One — Windows Starter

## 1) Lancer
1. Ouvre PowerShell:
   cd C:\amp-one
   Copy-Item .env.example .env
   cd .\infra
   docker compose up -d --build

2. Ouvre:
- Console: http://localhost:5173
- API: http://localhost:8080/health
- Keycloak: http://localhost:8081 (admin/admin)
- MinIO: http://localhost:9001 (amp/ampampamp)