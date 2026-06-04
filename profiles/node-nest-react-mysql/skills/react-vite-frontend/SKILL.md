# React + Vite Frontend

Quy tắc và pattern khi sửa code React + Vite (TypeScript).

## Cấu trúc thư mục

```
web/  (hoặc frontend/, apps/web/)
├── src/
│   ├── main.tsx                  # entry, mount App
│   ├── App.tsx                   # router + provider
│   ├── routes/                   # route definitions
│   │   ├── index.tsx
│   │   └── ProtectedRoute.tsx
│   ├── pages/                    # page-level component
│   │   ├── HomePage.tsx
│   │   ├── LoginPage.tsx
│   │   └── users/
│   │       ├── ListUsersPage.tsx
│   │       └── UserDetailPage.tsx
│   ├── components/               # reusable component
│   │   ├── ui/                   # primitive (Button, Input, Modal)
│   │   └── feature/              # feature-specific
│   ├── hooks/                    # custom hook
│   │   ├── useAuth.ts
│   │   └── useDebounce.ts
│   ├── api/                      # API client (axios/fetch wrapper)
│   │   ├── client.ts
│   │   ├── users.ts
│   │   └── auth.ts
│   ├── stores/                   # zustand / context
│   ├── schemas/                  # zod schema
│   ├── lib/                      # util
│   ├── types/                    # type chung
│   └── styles/                   # css / tailwind
├── public/
├── index.html
├── vite.config.ts
└── package.json
```

## Component

- Functional + hooks. Không class component (trừ error boundary).
- Mỗi file ≤ 300 dòng. Quá dài → tách.
- Props: khai báo `type Props = { ... }` riêng, không inline.
- Default export: chỉ cho page. Component khác dùng named export.
- Tên file = tên component: `UserCard.tsx` → `export function UserCard`.
- `displayName` chỉ cần khi debug.

## Hook

- Bắt đầu bằng `use`: `useAuth`, `useFetchUser`.
- Mỗi hook 1 trách nhiệm. Không gộp 5 thứ vào 1 hook.
- Trả object `{ data, isLoading, error }` hoặc tuple `[state, setter]`.
- Cleanup: `useEffect` phải return cleanup function khi subscribe / interval.
- Custom hook dùng lại logic từ React Query / SWR / form lib, không tự viết lại fetch.

## API client

- Centralize trong `src/api/`. KHÔNG gọi `fetch` / `axios` rải rác trong component.
- Axios instance:
  ```ts
  export const api = axios.create({
    baseURL: import.meta.env.VITE_API_URL,
    timeout: 10000,
  });
  api.interceptors.request.use((cfg) => {
    const token = getAccessToken();
    if (token) cfg.headers.Authorization = `Bearer ${token}`;
    return cfg;
  });
  api.interceptors.response.use(
    (r) => r,
    async (err) => {
      if (err.response?.status === 401) {
        await tryRefreshToken();
        return api(err.config);
      }
      return Promise.reject(err);
    },
  );
  ```
- Mỗi resource 1 file: `api/users.ts` export `listUsers`, `getUser`, `createUser`, ...
- Type-safe: function trả `Promise<User>` (không `any`). Lỗi throw `AxiosError`.
- Timeout mặc định 10s. Endpoint nặng → tăng riêng.

## State

- **Server state** (data từ API) → React Query (`@tanstack/react-query`) hoặc SWR.
  - Key: `['users', userId]`.
  - `staleTime` / `cacheTime` theo use case.
  - Mutation: `useMutation` + `onSuccess` invalidate query.
- **Client state** (UI local) → Zustand hoặc Context.
- **Form state** → React Hook Form + Zod schema.
- **URL state** → React Router `useSearchParams`.
- KHÔNG dùng Redux trừ khi team đã quen hoặc app rất lớn.
- KHÔNG dùng `useState` cho data fetch — dùng React Query.

## Form

- React Hook Form + Zod.
- Schema trong `schemas/`, share với backend nếu có thể (DTO ↔ Zod).
- Validate onSubmit + onBlur. Không validate tay trong onChange trừ khi cần.
- Error message hiển thị ngay dưới field.
- Submit button disable khi `isSubmitting`.
- Reset form sau submit thành công (nếu cần).

## Routing

- React Router v6+.
- `createBrowserRouter` + `RouterProvider` (data API) ưu tiên hơn `<BrowserRouter>`.
- Nested route: `path="users"` → `<UsersLayout>` → `<Outlet />`.
- Private route: wrap trong `<ProtectedRoute>`:
  ```tsx
  export function ProtectedRoute({ children }: { children: ReactNode }) {
    const { user, isLoading } = useAuth();
    if (isLoading) return <Spinner />;
    if (!user) return <Navigate to="/login" replace />;
    return <>{children}</>;
  }
  ```
- Lazy load: `const UsersPage = lazy(() => import('./pages/users/ListUsersPage'));`.
- Suspense boundary quanh lazy component.

## TypeScript

- `strict: true` trong `tsconfig.json`. Bắt buộc.
- `noUncheckedIndexedAccess: true` nếu có thể.
- Không `any`. Dùng `unknown` rồi narrow bằng type guard / Zod parse.
- Enum: dùng `const enum` hoặc `as const` object (TypeScript enum có issue).
- Import type: `import type { User } from './types'` khi chỉ dùng type.
- `verbatimModuleSyntax: true` nếu build bằng Vite + SWC.

## Env

- Chỉ `VITE_*` được expose ra client. Tên khác → undefined trong browser.
- `.env.local` cho dev, `.env.production` cho prod. KHÔNG commit secret.
- Type env trong `vite-env.d.ts`:
  ```ts
  /// <reference types="vite/client" />
  interface ImportMetaEnv {
    readonly VITE_API_URL: string;
    readonly VITE_APP_NAME: string;
  }
  interface ImportMeta { readonly env: ImportMetaEnv; }
  ```
- KHÔNG đặt secret backend trong `.env` frontend. Nếu backend cần secret → để trên server.

## Build & dev

- `npm run dev` → Vite dev server (HMR).
- `npm run build` → production build ra `dist/`.
- `npm run preview` → serve `dist/` để test.
- `tsc --noEmit` trong CI để check type.
- Bundle size: kiểm tra với `rollup-plugin-visualizer` hoặc `vite-bundle-visualizer`.

## Testing

- Unit: Vitest + React Testing Library.
- Component test: render + screen query. Không test implementation detail.
- Hook test: `renderHook` từ RTL.
- E2E: Playwright. Tách khỏi unit test.
- MSW (Mock Service Worker) cho API mock trong unit test.

## Anti-pattern cần tránh

- ❌ Gọi `fetch` / `axios` trực tiếp trong component.
- ❌ `useEffect` fetch data (dùng React Query).
- ❌ `any` trong props / state.
- ❌ Inline function lớn trong JSX (tách ra).
- ❌ Inline style lặp lại nhiều chỗ (đưa vào class / theme).
- ❌ Quên cleanup interval / subscription trong useEffect.
- ❌ Lưu token vào `localStorage` khi có thể dùng httpOnly cookie.
- ❌ Đặt secret backend trong `.env` frontend.

## Reference

- [Vite docs](https://vitejs.dev)
- [React Router v6](https://reactrouter.com)
- [React Query](https://tanstack.com/query)
- [React Hook Form](https://react-hook-form.com)
- [Zod](https://zod.dev)
