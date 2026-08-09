# LingoRoad Admin

React CMS dành cho developer/operator chạy local với tài khoản có role `Admin`.
Ứng dụng gọi API LingoRoad thật tại `http://localhost:5000`; backend vẫn là lớp
bắt buộc thực thi authentication và authorization, còn route guard phía client
chỉ hỗ trợ trải nghiệm người dùng.

## Giao diện và chức năng hiện có

Admin dùng design system Stitch với font Hanken Grotesk và màu thương hiệu chính
`#B22300`. Màn đăng nhập dùng `src/admin/src/assets/logo.png`; sidebar sáng dùng
`src/admin/src/assets/logo_black.png` không nền. Hai file là bản sao nguyên gốc
từ `src/mobile/assets/images/` để Docker build Admin độc lập.

Các route hiện có:

- `/overview`: tổng quan người học, nội dung, mastery, item usage và audit gần đây.
- `/users` và `/users/:id`: tra cứu, lọc, phân trang và xem hồ sơ người dùng ở
  chế độ read-only.
- `/skills`, `/items`, `/lessons`: quản lý taxonomy và học liệu qua API thật.
- `/analytics`: analytics tổng quan và learning-quality.
- `/imports`: nhập bundle JSON hoặc CSV, validate, preview, xác nhận rồi mới
  apply.
- `/audit`: tra cứu audit log.

Route `/` và route không hợp lệ chuyển về `/overview`. Item editor hỗ trợ tạo
item bằng AI với loại `mcq` hoặc `cloze`, CEFR và số lượng từ 1 đến 20. Trạng
thái `insufficient_sample` trong learning-quality là dữ liệu hợp lệ, không phải
lỗi.

Các bảng Users, Skills, Items, Lessons và Audit mặc định hiển thị 10 dòng. Bộ
phân trang cho phép chọn 10/20/50 dòng, chuyển tới trang đầu/trước/số
trang/sau/cuối và tự đặt lại trang khi tìm kiếm, lọc hoặc đổi số dòng. Users gửi
`limit`/`offset` tương ứng tới server; các bảng nội dung còn lại phân trang trên
dữ liệu API hiện có.

## Import CSV

CSV được chuyển thành cùng JSON contract với `/admin/imports/validate` và
`/admin/imports`; backend, checksum và cơ chế idempotency không thay đổi. File
phải có đủ header theo đúng tên sau (thứ tự có thể khác):

```text
kind,version,source,license,reviewer,code,name,nameVi,category,parentCode,cefrLevel,stableId,skillCode,type,stem,options,correctAnswer,explanationVi,slug,title,titleVi,descriptionVi,order,isPublished,itemStableIds
```

- `kind`: `skill`, `item` hoặc `lesson`.
- Dòng dữ liệu đầu tiên phải có `version`, `source`, `license`, `reviewer`; các
  dòng sau có thể để trống metadata hoặc lặp lại đúng cùng giá trị.
- Dòng `skill` dùng `code,name,nameVi,category,parentCode,cefrLevel`.
- Dòng `item` dùng `stableId,skillCode,cefrLevel,type,stem,options,correctAnswer,explanationVi`.
- Dòng `lesson` dùng `stableId,slug,title,titleVi,descriptionVi,skillCode,cefrLevel,order,isPublished,itemStableIds`.
- `options` và `itemStableIds` là mảng chuỗi JSON; trong CSV, dấu nháy kép JSON
  phải được escape thành hai dấu nháy kép.

Ví dụ rút gọn:

```csv
kind,version,source,license,reviewer,code,name,nameVi,category,parentCode,cefrLevel,stableId,skillCode,type,stem,options,correctAnswer,explanationVi,slug,title,titleVi,descriptionVi,order,isPublished,itemStableIds
skill,2026.08.09-csv-v1,LingoRoad Admin CSV,Proprietary,Content reviewer,grammar.example,Example skill,Kỹ năng mẫu,grammar,,A1,,,,,,,,,,,,,,
item,,,,,,,,,,A1,item-example-01,grammar.example,mcq,"Choose the correct answer, please.","[""Answer A"",""Answer B""]",Answer A,Giải thích mẫu,,,,,,,
lesson,,,,,,,,,,A1,lesson-example-01,grammar.example,,,,,,example-lesson,Example lesson,Bài học mẫu,Mô tả mẫu,1,true,"[""item-example-01""]"
```

Trang Import có nút tải CSV mẫu. Chỉnh sửa nội dung hoặc đổi định dạng sau khi
preview sẽ vô hiệu hóa Apply cho tới khi validate lại.

Layout dùng sidebar 256px trên desktop và drawer có scrim trên mobile. Drawer
đóng sau khi điều hướng, hỗ trợ phím `Escape`, trả focus về nút mở và khóa focus
trong drawer khi đang mở. Các control chính có label/accessible name, trạng thái
loading/error/empty và dialog xác nhận cho mutation nhạy cảm.

## Điều kiện chạy local

- Node.js/npm phù hợp với lockfile trong `src/admin`.
- PostgreSQL đang chạy và truy cập được bằng connection string Development.
- Backend LingoRoad đang chạy tại `http://localhost:5000`.

Từ repo root, khởi động backend bằng một terminal:

```powershell
dotnet run --project src/backend/LingoRoad --launch-profile http
```

Trong terminal khác, cài dependency và chạy Admin:

```powershell
npm --prefix src/admin ci
npm --prefix src/admin exec -- playwright install chromium
$env:VITE_API_BASE_URL = "http://localhost:5000"
npm --prefix src/admin run dev
```

Hoặc chạy từ thư mục `src/admin`:

```powershell
cd src/admin
npm ci
npx playwright install chromium
$env:VITE_API_BASE_URL = "http://localhost:5000"
npm run dev
```

Mở Admin tại `http://localhost:5173`. Nếu không đặt `VITE_API_BASE_URL`, client
mặc định gọi `http://localhost:5000`. Cấu hình Development hiện cho phép origin
`http://localhost:5173`; khi triển khai môi trường khác phải cấu hình lại CORS.

## Tài khoản Development

`src/backend/LingoRoad/appsettings.Development.json` bootstrap tài khoản local:

- Email: `admin@lingoroad.dev`
- Password: `LingoRoadAdmin123!`

Đây chỉ là credential Development để chạy local. Không dùng lại trong
production, không đưa vào secret/config production và phải cấp credential thật
qua secret hoặc environment store.

## Quality gate

Trạng thái quality gate hiện tại:

- `npm run lint`: đạt.
- `npm test -- --run`: 33/33 unit tests đạt.
- `npm run build`: đạt.
- `npm run test:e2e`: 10/10 Playwright E2E đạt.

Chạy từ `src/admin`:

```powershell
npm run lint
npm test -- --run
npm run build
npm run test:e2e
```

Playwright E2E bao phủ route guard, đăng nhập và các luồng API/mutation chính,
Users, mobile drawer và AI item generation. Bộ test cũng có visual regression
cho Overview, Users, Lessons, Analytics ở desktop và navigation drawer ở mobile;
baseline nằm trong `e2e/admin.spec.ts-snapshots`.

## Session và bảo mật

Session chỉ lưu trong `sessionStorage`. Client hợp nhất các request refresh đang
diễn ra thành một request; nếu refresh thất bại, session được xóa, React quay về
màn hình đăng nhập và hiển thị thông báo hết hạn. Client cũng chặn session không
có role `Admin` trước khi tải dữ liệu, nhưng backend vẫn phải kiểm tra role trên
mọi Admin API.

Không commit production secret, bootstrap credential hoặc API URL nhạy cảm.
Origin của Admin phải nằm trong CORS allowlist của backend.

## Trạng thái dependency audit

Tại lần kiểm tra ngày 2026-08-09, `npm audit` báo `0 vulnerabilities`. Chạy lại
trước khi release vì kết quả có thể thay đổi theo lockfile và advisory upstream.
