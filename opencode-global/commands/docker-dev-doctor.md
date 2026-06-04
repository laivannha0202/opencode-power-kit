---
description: Kiểm tra docker-compose dev setup (ports, volumes, healthcheck, env)
---

Kiểm tra docker-compose dev setup của project:

1. Tìm file: `docker-compose.yml`, `docker-compose.yaml`, `docker-compose.override.yml`, `compose.yml`.
2. Với mỗi service check:
   - **Image / build:** có `image` hoặc `build` không? Có tag cụ thể không (tránh `latest`)?
   - **Port mapping:** `ports:` có dùng format `HOST:CONTAINER` không? Có conflict port không?
   - **Volume:** `volumes:` có dùng named volume hay bind mount? Data DB có persistent không?
   - **Env:** `environment:` có dùng `.env` file hay inline? Có secret trong file docker-compose không?
   - **Healthcheck:** service quan trọng (DB, cache) có `healthcheck:` không?
   - **depends_on:** có `condition: service_healthy` không (tránh race)?
   - **Network:** có custom network không, hay dùng default?
3. Cảnh báo:
   - Port 3000/3306/5432/6379/27017 conflict với process khác.
   - `image: mysql:latest` (tag `latest` không ổn định).
   - DB không có volume → mất data khi restart.
   - DB không có healthcheck → app start trước khi DB sẵn sàng.
   - Secret inline trong docker-compose → đẩy ra `.env`.

Output:

| Service | Image | Port | Volume | Healthcheck | Risk |
|---------|-------|------|--------|-------------|------|

KHÔNG tự `docker compose up`. CHỈ detect + in cảnh báo.
