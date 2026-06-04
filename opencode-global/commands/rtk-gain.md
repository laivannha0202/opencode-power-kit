---
description: Chạy rtk gain hoặc hướng dẫn cài rtk
---

Nếu có rtk (Rust Token Killer) thì chạy:
    rtk gain
Nếu chưa có rtk, in hướng dẫn cài (xem scripts/install-token-tools.sh):
    bash ~/opencode-power-kit/scripts/install-token-tools.sh

rtk gain phân tích shell history + repo state, đề xuất alias tối ưu token
(rtk ls, rtk cat, rtk rg, rtk git, ...). Áp dụng alias thì các lệnh
thường tự động chạy qua rtk, giảm 40-60% output token.

Không tự sửa ~/.bashrc. Chỉ in alias gợi ý, để user tự thêm.
