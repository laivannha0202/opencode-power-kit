---
description: Kiểm tra luồng end-to-end UI → API → service → DB → response → UI
---

Kiểm tra 1 luồng end-to-end từ UI tới DB và ngược lại:

- **UI:** form / button / page nào trigger.
- **API:** method, path, headers, body shape. Có auth không.
- **Service:** business logic chính, validate, transform.
- **Repository / DB:** query nào chạy. Có transaction không. Có N+1 không.
- **Response:** status code, body shape, error format.
- **UI render:** state update, loading, error handling.

Output dạng bảng:
| Step | Layer | Endpoint / Action | Validate | Error path | Note |

Đề xuất test cho mỗi step:
- Happy path.
- Validation error (400/422).
- Auth fail (401/403).
- Not found (404).
- Server error (500) — log có stack, response không.

Không tự chạy code. Chỉ đọc và phân tích.
