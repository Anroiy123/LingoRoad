# LingoRoad Admin

React CMS dành cho tài khoản có role `Admin`. Ứng dụng dùng API thật để quản lý
Skills, Items và Lessons; import content bundle theo hai bước; xem analytics và
audit log. Backend vẫn là lớp bắt buộc thực thi authorization, route guard phía
client chỉ hỗ trợ UX.

## Chạy local

1. Chạy PostgreSQL và backend tại `http://localhost:5000`.
2. Bootstrap một tài khoản Admin bằng cấu hình backend; không commit mật khẩu.
3. Cài dependency và chạy web:

```powershell
npm ci
npx playwright install chromium
$env:VITE_API_BASE_URL = "http://localhost:5000"
npm run dev
```

Nếu không đặt `VITE_API_BASE_URL`, client dùng `http://localhost:5000`. Origin
của Admin phải nằm trong CORS allowlist khi chạy production.

## Quality gate

```powershell
npm run lint
npm test -- --run
npm run build
npm run test:e2e
```

Session chỉ nằm trong `sessionStorage`; client thực hiện một refresh request tại
một thời điểm và đăng xuất khi token không hợp lệ. Production secrets, bootstrap
credential và API URL phải được cấp qua secret/environment store.
