# Docker Compose Safe

Quy tắc viết `docker-compose.yml` cho dev an toàn, tránh mất data, tránh race.

## Cấu trúc tối thiểu

```yaml
services:
  db:
    image: mysql:8.4        # tag cụ thể, KHÔNG :latest
    container_name: myapp-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASS}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASS}
    ports:
      - "3306:3306"          # hoặc "127.0.0.1:3306:3306" giới hạn localhost
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10
    networks:
      - app-net

  api:
    build: ./apps/api
    container_name: myapp-api
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: mysql://${DB_USER}:${DB_PASS}@db:3306/${DB_NAME}
      JWT_SECRET: ${JWT_SECRET}
    ports:
      - "3000:3000"
    networks:
      - app-net

volumes:
  db_data:
    name: myapp-db-data      # named volume, persist qua container recreate

networks:
  app-net:
    name: myapp-net
    driver: bridge
```

## Quy tắc

### Image

- Tag cụ thể (`mysql:8.4`, `postgres:16.3`). KHÔNG `:latest` (rebuild cho kết quả khác).
- Image chính thức: `mysql`, `postgres`, `redis`, `mongo`, `node`, `nginx`.
- Custom image: build từ Dockerfile, multi-stage, distroless / alpine.

### Port

- Format: `"HOST:CONTAINER"` (`"3000:3000"`) hoặc chỉ container port (ẩn khỏi host).
- Giới hạn host: `"127.0.0.1:3000:3000"` (không expose ra network ngoài).
- Conflict port: check `lsof -i :3306` hoặc `ss -tlnp | grep 3306`.
- Production: KHÔNG mở port DB ra host. App connect qua internal network.

### Volume

- **Named volume** cho data (DB, cache, queue): persist qua container recreate.
- **Bind mount** cho code dev: `./apps/api/src:/app/src` (live reload).
- KHÔNG bind mount system path (`/etc`, `/var/run/docker.sock`).
- Backup: snapshot volume định kỳ (`docker run --rm -v vol:/data alpine tar czf backup.tgz /data`).

### Environment

- Dùng `.env` (không commit): `MYSQL_PASSWORD: ${DB_PASS}`.
- KHÔNG inline secret trong docker-compose.
- KHÔNG dùng biến host mà không qua `.env` (lộ trong `docker-compose config`).

### Healthcheck

- DB: `mysqladmin ping` / `pg_isready` / `redis-cli ping`.
- API: `curl -f http://localhost:3000/health`.
- Interval: 5-10s. Timeout: 3-5s. Retries: 3-10.
- KHÔNG healthcheck cho dev container tạm.

### depends_on

- `condition: service_healthy` cho service cần service khác sẵn sàng.
- Mặc định: chỉ chờ container start, không chờ app ready → race.
- Dùng `wait-for-it.sh` hoặc retry trong app code nếu không có healthcheck.

### Network

- Custom network: service gọi nhau qua tên (`db:3306` thay vì `localhost:3306`).
- Driver `bridge` cho single host, `overlay` cho swarm.
- KHÔNG `network_mode: host` (mất isolation).

### Restart policy

- `unless-stopped`: dev, restart khi Docker khởi động lại.
- `always`: production-like.
- `on-failure`: chỉ restart khi crash.

### Resource limit

- `mem_limit: 512m`, `cpus: 1.0` (tránh 1 container nuốt hết RAM).

## Anti-pattern cần tránn

- ❌ `image: mysql:latest` (không ổn định, rebuild khác kết quả).
- ❌ DB không có volume (`db_data:`) → mất data khi recreate.
- ❌ DB không có healthcheck → app start trước khi DB ready.
- ❌ `depends_on` không có `condition: service_healthy` → race.
- ❌ Inline password trong docker-compose (lộ trong git).
- ❌ Port DB expose `0.0.0.0:3306:3306` ở prod.
- ❌ `privileged: true` không cần thiết.
- ❌ `network_mode: host` ở dev (gây conflict port).
- ❌ Build context `.` trong khi project có `node_modules/` (image to).

## Production differences

- KHÔNG bind mount code (image phải self-contained).
- KHÔNG mở port DB ra public.
- Dùng orchestrator (k8s, ECS, Nomad) thay vì `docker-compose`.
- Secret qua orchestrator secret store.
- Log ship sang ELK / Loki.
- Healthcheck + livenessProbe / readinessProbe.

## Reference

- [Compose spec](https://compose-spec.io)
- [MySQL Docker hub](https://hub.docker.com/_/mysql)
- [Postgres Docker hub](https://hub.docker.com/_/postgres)
- [Docker security cheatsheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
