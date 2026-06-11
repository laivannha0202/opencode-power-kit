---
description: Research-first — hiểu codebase/domain/dependency trước khi code
subtask: true
agent: ecc-lite-strong
---

# /research-first

Research-first approach: understand before implementing.

## Cách dùng

```
/research-first <task description>
/research-first "add JWT auth middleware"
```

## ⚠️ Scope Guard — Research only

Research-first **CHỈ** đọc và phân tích. **KHÔNG** sửa code trừ khi user yêu cầu rõ ràng.

## Workflow

### Phase 1: Understand
1. **Dependencies**: `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`
2. **File structure**: `ls` project root, `fd --type f | head -30`
3. **Key files**: tìm controller/service/entity liên quan
4. **Data flow**: input → xử lý → output

### Phase 2: Research questions
- "File nào cần sửa?"
- "Dependency nào cần thêm?"
- "API contract thay đổi thế nào?"
- "Có breaking change không?"
- "Cần migration không?"

### Phase 3: Output

```
## Research Results
- **Task:** {task description}
- **Files affected:** {list}
- **Dependencies:** {list}
- **Assumptions:** {bullet list}
- **Risk:** low/medium/high
- **Recommendation:** {proceed / need more info / blocked}
```

## When to use

- Feature implementation phức tạp
- Bugfix mà root cause chưa rõ
- Refactor codebase
- Khi task description mơ hồ
