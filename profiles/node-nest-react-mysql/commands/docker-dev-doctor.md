---
description: Kiểm tra docker-compose dev: ports, volumes, env, healthcheck, data persistence
---

Kiểm tra `docker-compose.yml` / `docker-compose.dev.yml` cho môi trường dev:

- **Services:** đếm và liệt kê service nào (db, cache, api, web, ...).
- **Ports:** port host nào map vào port container. Có conflict cổng phổ biến không.
- **Volumes:** bind mount hay named volume. Có persist data không (db, redis).
- **Env:** biến nào hardcode trong compose. Cảnh báo nếu có secret thật (password, key).
- **Healthcheck:** mỗi service có healthcheck không. DB thường cần `mysqladmin ping` hoặc `pg_isready`.
- **Depends on:** dependency giữa service. Có `condition: service_healthy` không.
- **Network:** service cùng network. Có expose port thừa ra host không.
- **Data:** volume cho mysql/postgres/redis có path rõ ràng không (tránh mất data khi down).
- **Resource limit:** có giới hạn CPU/RAM không (cảnh báo nếu không, không block).

Output: bảng Service | Port | Volume | Healthcheck | Env | Issue.
Đề xuất fix cho mỗi issue. Không tự sửa.
