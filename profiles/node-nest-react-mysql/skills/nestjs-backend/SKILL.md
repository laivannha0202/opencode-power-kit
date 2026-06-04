# NestJS Backend

Quy tắc và pattern khi sửa code NestJS (TypeScript).

## Cấu trúc module

```
src/
├── modules/
│   ├── users/
│   │   ├── users.module.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.repository.ts        # hoặc dùng TypeORM repo trực tiếp
│   │   ├── dto/
│   │   │   ├── create-user.dto.ts
│   │   │   └── update-user.dto.ts
│   │   ├── entities/
│   │   │   └── user.entity.ts
│   │   ├── guards/
│   │   │   └── user-role.guard.ts
│   │   └── tests/
│   │       └── users.service.spec.ts
├── common/                            # guard/pipe/filter/decorator dùng chung
│   ├── guards/auth.guard.ts
│   ├── interceptors/transform.interceptor.ts
│   ├── filters/all-exceptions.filter.ts
│   └── pipes/zod-validation.pipe.ts
├── config/
│   └── configuration.ts               # ConfigService schema
├── app.module.ts
└── main.ts
```

## Controller

- Decorator: `@Controller('users')`, `@Get`, `@Post`, `@Put`, `@Delete`, `@Patch`.
- Validate: `@Body() dto: CreateUserDto` (DTO có class-validator).
- Param: `@Param('id', ParseUUIDPipe) id: string`.
- Query: `@Query() filter: ListUserDto`.
- Guard: `@UseGuards(JwtAuthGuard, RolesGuard)`.
- Response: trả object thuần, không trả entity trực tiếp (dùng mapper hoặc class-transformer `@Expose`).
- Status: 200 (GET/PUT/PATCH), 201 (POST), 204 (DELETE).
- KHÔNG: try/catch trong controller (để global filter lo), không business logic, không truy cập DB.

## Service

- Inject repo qua constructor (token-based nếu dùng custom repository).
- Method trả về Promise / Observable.
- Throw exception chuẩn: `NotFoundException`, `ConflictException`, `BadRequestException`, `UnauthorizedException`, `ForbiddenException`.
- Business logic thuần: validate cross-field, transform, gọi repo.
- Logging: dùng `Logger` từ `@nestjs/common`. Không log PII.
- Transaction: nếu ghi nhiều bảng, dùng `DataSource.transaction()` hoặc `@Transactional()` (nestjs-cls).

## Module

- `@Module({ imports, controllers, providers, exports })`.
- Import module khác qua `imports: [TypeOrmModule.forFeature([UserEntity])]`.
- Export service nếu module khác cần dùng.
- KHÔNG: global provider không cần thiết (tránh leak).

## DTO

- Class + class-validator decorators:
  - `@IsString()`, `@IsNotEmpty()`, `@IsEmail()`, `@IsOptional()`, `@IsEnum(Role)`, `@Min(0)`, `@Max(100)`, `@IsUUID()`.
- `class-transformer` cho response: `@Exclude()`, `@Expose()`.
- File riêng cho create / update / query / response. Không reuse 1 DTO cho nhiều route.
- Validation pipe global: `app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }))`.

## Entity (TypeORM)

- Decorator: `@Entity()`, `@PrimaryGeneratedColumn('uuid')`, `@Column({ type: 'varchar', length: 255, nullable: false })`.
- Index: `@Index(['email'], { unique: true })` cho cột tìm kiếm thường xuyên.
- Relation: `@ManyToOne(() => Role, role => role.users)`, `@OneToMany`, `@JoinColumn`.
- Soft delete: `@DeleteDateColumn()` (typeorm) hoặc cột `deleted_at` + query filter.
- Timestamp: `@CreateDateColumn()`, `@UpdateDateColumn()`.
- Eager loading: tắt mặc định. Chỉ load quan hệ khi cần (tránh N+1).

## Guard

- Implement `CanActivate`:
  ```ts
  @Injectable()
  export class RolesGuard implements CanActivate {
    constructor(private reflector: Reflector) {}
    canActivate(ctx: ExecutionContext): boolean {
      const required = this.reflector.getAllAndOverride<Role[]>('roles', [
        ctx.getHandler(),
        ctx.getClass(),
      ]);
      if (!required) return true;
      const req = ctx.switchToHttp().getRequest();
      return required.includes(req.user.role);
    }
  }
  ```
- Set metadata qua custom decorator: `@Roles(Role.Admin)`.
- Áp dụng: `@UseGuards(JwtAuthGuard, RolesGuard)`.
- Thứ tự guard quan trọng: Auth trước, Role sau.

## Pipe

- Built-in: `ValidationPipe`, `ParseUUIDPipe`, `ParseIntPipe`, `ParseEnumPipe`.
- Custom: implement `PipeTransform.transform(value, metadata)`.
- Use case: chuẩn hóa string (trim, lowercase), parse JSON an toàn.

## Interceptor

- Logging: log request/response, duration, status.
- Transform: bọc response `{ data, meta }` để chuẩn hóa.
- Cache: trả cache nếu có, gọi handler nếu không.
- Timeout: `timeout(5000)` để tránh treo.

## Middleware

- Dùng cho tác vụ trước guard: request ID, CORS, body parser.
- Sau guard mới biết user → nếu cần user thì dùng guard / interceptor.

## Exception filter

- Global: `@Catch()` không tham số → bắt mọi exception.
- Trả format nhất quán: `{ statusCode, error, message, path, timestamp }`.
- Log server-side: stack trace, userId, requestId.
- Trả client-side: chỉ message an toàn, không stack.

## Config

- `@nestjs/config` với schema validation (Joi hoặc class-validator).
- Đọc: `constructor(private config: ConfigService) {}` → `this.config.get<string>('DB.host')`.
- File `.env` cho dev. Production: env inject qua Docker / k8s.
- Tách schema: `configuration.ts` export factory.

## Logging

- `Logger` từ `@nestjs/common`. Context = tên class.
- Level: `log`, `error`, `warn`, `debug`, `verbose`.
- Production: ship sang ELK / Loki / Datadog. Local: pretty.

## Testing

- Unit: `Test.createTestingModule({ providers: [UsersService] })`. Mock repo.
- Integration: dùng `Test.createTestingModule` thật, DB sandbox (Docker testcontainer).
- E2E: `Test.createTestingModule` + `app.init()` + supertest `request(app.getHttpServer())`.
- Reset DB giữa test: transaction rollback hoặc truncate.

## Anti-pattern cần tránh

- ❌ Business logic trong controller.
- ❌ Dùng `any` ở boundary.
- ❌ Trả entity trực tiếp ra response (lộ field nhạy cảm).
- ❌ Sync schema tự động ở production.
- ❌ Try/catch nuốt lỗi trong service.
- ❌ Global guard cản public route (route health check phải bypass).
- ❌ Log token / password / PII.

## Reference

- [NestJS docs](https://docs.nestjs.com)
- [TypeORM](https://typeorm.io) hoặc [Prisma](https://www.prisma.io)
- Pattern trong repo cũ nếu có: `rg "Controller|Service|Module" src/`.
