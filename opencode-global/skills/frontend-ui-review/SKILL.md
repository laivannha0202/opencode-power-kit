# Frontend UI Review

Skill review UI/UX cho frontend change, focus accessibility + consistency.

## A11y (a11y — accessibility)

- Keyboard: tab order hợp lý, focus ring visible, Esc/Enter hoạt động.
- Screen reader: aria-label, aria-describedby, role đúng.
- Color contrast: WCAG AA — 4.5:1 cho text, 3:1 cho UI component.
- Alt text cho img, label cho input, không dùng placeholder thay label.
- Không rely on color alone (icon + text cho status).

## Layout & Spacing

- Mobile-first: test 320px, 375px, 768px, 1280px.
- Touch target ≥ 44x44px (mobile).
- Spacing nhất quán: 4/8/12/16/24/32 scale.
- Container max-width hợp lý (chunks > 1200px khó đọc).

## Typography

- Font size scale: 12/14/16/18/24/32/48.
- Line-height 1.5 cho body, 1.2 cho heading.
- Font weight: 400/500/600/700, không 300 cho UI text.
- Không dùng > 2 font family.

## Color

- Palette 5-7 màu: primary, secondary, success, warning, danger, neutral.
- Dark mode support nếu có brand guideline.
- Token system (CSS variable / Tailwind config), không hardcode hex.

## State

- Loading state: skeleton hoặc spinner, không để trống.
- Empty state: icon + message + CTA.
- Error state: message rõ, retry button nếu được.
- Success state: confirmation tạm thời (toast) hoặc redirect.

## Performance

- LCP < 2.5s, FID < 100ms, CLS < 0.1 (Core Web Vitals).
- Image: lazy load, webp/avif, srcset cho responsive.
- JS bundle: code split theo route, lazy import component nặng.
- Không re-render toàn list khi 1 item đổi (virtualization nếu > 100 items).

## Consistency

- Cùng component dùng cùng style (Button, Input, Card).
- Icon cùng bộ (lucide, heroicons, …), không trộn nhiều bộ.
- Spacing/typography theo design system, không mỗi trang 1 kiểu.
- Form: cùng validation pattern, cùng error message style.

## Output

Bảng:
| Issue | Severity | Location | Fix | Effort |

Severity: BLOCKING (a11y/visual bug) | HIGH | MEDIUM | LOW.

Không tự sửa — chỉ report. Đợi user chốt.
