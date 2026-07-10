# Eval Harness

Bộ đánh giá (eval) cho OpenCode Power Kit — kiểm tra chất lượng output
của agents, commands, và skills trên các task thực tế.

## Cấu trúc

```
evals/
├── README.md          # File này
├── tasks/             # Task definitions (JSON)
│   ├── code-gen.json  # Code generation eval
│   ├── debug.json     # Debug investigation eval
│   └── fullstack.json # Full-stack feature eval
└── run.sh             # Runner script
```

## Cách dùng

```bash
# Chạy tất cả evals
bash evals/run.sh

# Chạy eval cụ thể
bash evals/run.sh evals/tasks/code-gen.json

# Chạy với model cụ thể
MODEL=anthropic/claude-sonnet-4-20250514 bash evals/run.sh
```

## Task Format

Mỗi task file là một JSON array:

```json
[
  {
    "id": "code-gen-001",
    "name": "Simple function implementation",
    "description": "Write a function that...",
    "input": "The user prompt to send",
    "expected_contains": ["keyword1", "keyword2"],
    "expected_not_contains": ["anti-pattern1"],
    "max_tokens": 2000,
    "timeout_seconds": 60
  }
]
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | ✅ | Unique identifier |
| `name` | ✅ | Human-readable name |
| `description` | ✅ | What this eval tests |
| `input` | ✅ | Prompt to send to the agent |
| `expected_contains` | ❌ | Strings that MUST appear in output |
| `expected_not_contains` | ❌ | Strings that MUST NOT appear |
| `max_tokens` | ❌ | Token limit (default: 4096) |
| `timeout_seconds` | ❌ | Timeout (default: 120) |

## Chạy

```bash
# Yêu cầu: bash, python3, curl (nếu dùng remote API)
bash evals/run.sh
```

Runner sẽ:
1. Load task file
2. Chạy từng task qua agent (hoặc mock)
3. Kiểm tra expected_contains / expected_not_contains
4. In kết quả PASS/FAIL
5. Exit 0 nếu tất cả pass, exit 1 nếu có fail

## Thêm Task

Tạo file JSON mới trong `evals/tasks/`, tuân theo format ở trên.
Runner tự detect tất cả `*.json` trong `evals/tasks/`.

## Note

- Evals hiện tại là **rule-based** (string matching), chưa dùng LLM-as-judge.
- Có thể nâng cấp lên LLM judge trong tương lai.
- Mỗi eval chạy trong isolation — không shared state giữa tasks.
