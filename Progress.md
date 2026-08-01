# Tổng quan tiến độ

> Cập nhật lần cuối: **2026-08-01**
> Phạm vi: toàn bộ LingoRoad gồm backend .NET, ML service, Flutter mobile,
> PostgreSQL, dữ liệu nội dung, Admin Web, kiểm thử và phát hành.

## Kết luận hiện tại

- Mốc **16/16 task hoàn thành** trong ledger backend là kết quả của kế hoạch
  nghiên cứu backend/AI, không phải trạng thái hoàn thành của toàn bộ MVP.
- Luồng sản phẩm thật hiện chạy được:
  `Register/Login → Placement → MainShell → Logout/Login`; trong `MainShell`,
  Learning Path đã gọi `GET /path` và Profile đã đọc `GET /auth/me`.
- Home, Review và Progress vẫn dùng dữ liệu mock/tĩnh. Review đã có bốn nút
  Forgot/Hard/Good/Easy nhưng chưa gọi `/reviews/*`; Profile đã hiện dữ liệu đọc
  thật nhưng các thay đổi mục tiêu, preferences/toggles và mật khẩu chưa có API.
  Các màn hình đã bổ sung trên Figma mới là design coverage, chưa được tính là
  Flutter implementation.
- Các lỗ hổng `CorrectAnswer`, placement session binding/idempotency và chuẩn
  hóa/validation email đã được xử lý; các kiểm soát speaking, rate limit, token
  lifecycle và secrets/config validation vẫn còn thiếu.
- Admin Web chưa tồn tại. Lesson, onboarding, gamification và dashboard aggregate
  chưa có domain/API đầy đủ.
- Vì vậy, dự án hiện là **backend/AI foundation + auth/placement E2E + các lát
  cắt API thật cho Learning Path/Profile read**, chưa phải MVP sản phẩm có vòng
  lặp học khép kín.

## Snapshot bằng chứng ngày 2026-08-01

- Trước khi cập nhật tài liệu, checkout ở `main@f6da732` và đã đồng bộ với
  `origin/main`. Working tree có thay đổi ngoài phạm vi tài liệu này và được giữ
  nguyên.
- .NET hiện có **23 route/10 feature group**: 22 lệnh `Map*` trong `Endpoints`
  cộng `GET /health` trong `Program.cs`; profile read dùng `GET /auth/me`.
- Flutter: `flutter analyze` sạch; `flutter test` đạt **62/62 test**.
- .NET test chưa được chạy lại trong lượt đồng bộ tài liệu này; mốc **42/42**
  bên dưới phụ lục chỉ là bằng chứng lịch sử của lần xác minh trước.
- ML chưa tái kiểm chứng được trong lần rà soát này: `.venv` có FastAPI nhưng
  thiếu `pytest`; Python hệ thống có pytest nhưng thiếu `fastapi` và `nltk`.
  Con số 47 test đạt trong tài liệu cũ chỉ được coi là bằng chứng lịch sử.
- Snapshot PostgreSQL local gần nhất (chưa tái kiểm tra ngày 2026-08-01) có:
  `Users=2`, `Skills=174`, `Items=12`, `TestSessions=2`, `Masteries=7`,
  `ReviewCards=0`, `Exercises=0`, `SpeakingAttempts=0`.
- `docker` chưa có trong `PATH`. Compose hiện chỉ khai báo PostgreSQL, chưa đóng
  gói API, ML, model/RAG artifacts hoặc reverse proxy.
- Hai dependency transitive .NET đang có advisory mức **High**:
  `Microsoft.OpenApi 2.0.0` và `SQLitePCLRaw.lib.e_sqlite3 2.1.11`.

## Ma trận trạng thái sản phẩm

| Hạng mục | Trạng thái | Phần còn thiếu |
|---|---|---|
| Auth và session | Partial, API thật | Register/login và `GET /auth/me` đã nối mobile; thiếu profile update, refresh/revoke token, forgot-password và role/admin |
| Onboarding và profile | Partial, read API thật | Profile có loading/error/retry; UI render name, level/CEFR hiện tại và badge/profile stats từ response. Email chỉ làm fallback suy ra display name; `targetCefr` đã parse nhưng target tile vẫn hard-code theo localization. Thiếu onboarding, update target/daily goal/purpose/focus/preferences/password; các toggle vẫn là local state |
| Placement | Partial, E2E thật | Answer đã session-bound/idempotent và email đã normalize/validate; vẫn chỉ trả CEFR tổng và mới có 12 smoke items |
| Home/Today Plan | Mobile mock | Quest, lesson hôm nay, due review và recent activity chưa lấy từ backend |
| Learning Path | API thật trên mobile | `ApiLearningPathRepository` đã gọi `GET /path` với loading/empty/error/retry; thiếu path persistence, today plan, lesson mapping, complete/recalculate và smoke test MuMu mới |
| Lesson | Missing | Chưa có entity/table/API, lesson detail, lesson player và completion flow |
| Exercise/AI feedback | Backend primitives | Chưa nối với lesson/path; thiếu mobile exercise/result/explanation và transaction idempotent |
| Mastery/KT | Partial | Read path chưa áp dụng passive decay; SAINT+ `/kt/predict` chưa được .NET production flow sử dụng |
| SRS Review | Backend API + mobile mock-backed UI | Đã có Forgot/Hard/Good/Easy nhưng vẫn tải card từ `MockRepository`; chưa tự tạo card, gọi due/grade, xử lý API state hoặc chặn double-submit; snapshot database có 0 card |
| Dashboard/Progress | Mobile hard-code | Profile read đã thật; Home/Progress vẫn thiếu aggregate API cho CEFR, mastery, weak/strong skill, due count và completed lessons |
| Advisor/Writing/Speaking | Backend/ML-only | Chưa có learner UI; thiếu quota, privacy, fallback và quyết định có thuộc MVP hay không |
| Gamification | Lý thuyết/UI tĩnh | Chưa có XP/streak/badge/quest ledger, rule, API hoặc test idempotency |
| Admin CMS/analytics | Missing | Chưa có Admin Web, role model, admin auth, CRUD nội dung và analytics |
| Dữ liệu nội dung | Partial | Có 174 skills nhưng chỉ 12 items local, chưa có lesson; artifact đang phụ thuộc máy local |
| Deployment/operations | Missing/partial | Thiếu full-stack Docker, CI/CD, secrets, HTTPS, migration job, backup và monitoring |
| Mobile release | Debug-only | Application ID mặc định, release dùng debug signing, thiếu flavor/env production và AAB smoke test |

## Backlog bắt buộc

### P0 — Khép kín MVP và sửa rủi ro dữ liệu/bảo mật

- [ ] **P0-01 — Chốt contract MVP.**
  - Quyết định phạm vi CEFR A1–B2 hay A1–C2.
  - Placement trả overall hay per-skill.
  - Chốt Advisor, Writing và Speaking thuộc MVP hay V2.
  - Đồng bộ `MVP_architecture.md`, API contract, mobile model và kịch bản demo.
- [ ] **P0-02 — Sửa security/integrity.**
  - [x] Không trả `CorrectAnswer` từ public `GET /items`.
  - [x] Placement answer idempotent, chỉ chấp nhận item đã cấp cho session và
    không tăng mastery hai lần khi client retry.
  - [x] Normalize và validate email ở backend.
  - [ ] Bổ sung rate limit, token lifecycle và startup validation cho
    secrets/config nhạy cảm.
  - [ ] Speaking phải từ chối MIME sai, giới hạn dung lượng/thời lượng và có
    chính sách retention/lưu/xóa audio.
- [ ] **P0-03 — User profile và onboarding thật.**
  - [x] `GET /auth/me` và Flutter profile read đã có loading/error/retry; UI
    render name, level/CEFR hiện tại và badge/profile stats từ response. Email
    chỉ dùng làm fallback cho display name.
  - [ ] Render `targetCefr` đã parse thay cho target tile đang hard-code theo
    localization.
  - [ ] Thêm schema/migration/update API/test cho target CEFR, daily minutes,
    purpose, focus skills và preferences.
  - [ ] Tạo Flutter onboarding/update flow, nối toggles/change-password và bỏ
    việc mặc định mục tiêu B2 khi người dùng chưa xác nhận.
- [ ] **P0-04 — Data/content có thể tái tạo.**
  - Tối thiểu 100 câu hỏi, 20 lesson, 3 exercise types, 5–10 test learners và
    1 admin theo acceptance criteria hiện tại.
  - Có version, nguồn, validation, deduplication, seed/import và artifact
    distribution; không phụ thuộc file chỉ tồn tại trên một máy.
- [ ] **P0-05 — Learning Path end-to-end.**
  - [x] Mobile dùng repository/API model/ViewModel thật cho `GET /path`, có
    loading, empty, error, retry và Flutter test.
  - [ ] Định nghĩa path item → lesson, today plan, complete và recalculation.
  - [ ] Xác minh lại backend/mobile flow trên MuMu.
- [ ] **P0-06 — Lesson/Exercise/AI feedback end-to-end.**
  - Bổ sung Lesson domain/API và dữ liệu lesson.
  - Tạo lesson detail/player, exercise submit/result/explanation.
  - Cập nhật mastery đúng một lần và quay lại path/progress sau hoàn thành.
- [ ] **P0-07 — SRS Review end-to-end.**
  - [x] Flutter đã có bốn grade control Forgot/Hard/Good/Easy.
  - [ ] Tự tạo `ReviewCard` từ nội dung đã học hoặc trả lời sai.
  - [ ] Thay card mock bằng `/reviews/due` và gửi grade 1–4 qua API.
  - [ ] Có loading/empty/error/complete state, double-submit guard và test lịch
    ôn.
- [ ] **P0-08 — Home/Dashboard/Progress/Profile dùng dữ liệu thật.**
  - [x] Profile read đã dùng `GET /auth/me` cho name, level/CEFR hiện tại và
    badge/profile stats; email chỉ là fallback cho display name.
  - [ ] Hiển thị `targetCefr` đã parse thay cho target tile hard-code.
  - [ ] Tạo aggregate API cho CEFR, mastery, weak/strong skills, due count,
    completed lessons và next lesson.
  - [ ] Áp dụng mastery decay nhất quán khi đọc path/dashboard.
  - [ ] Thay dữ liệu mock/hard-code còn lại ở Home/Progress và các mục profile
    chưa có update API.
- [ ] **P0-09 — Admin tối thiểu.**
  - Thêm role/authorization, Admin Web, CRUD skill/lesson/question, import có
    kiểm soát và analytics cơ bản.
  - Nếu Admin không còn thuộc MVP, phải sửa chính thức scope và acceptance
    criteria thay vì tiếp tục đánh dấu hoàn thành.

### P1 — Production readiness

- [ ] Chuẩn hóa ML environment và biến `LINGOROAD_*`; đóng gói checkpoint, RAG
  index/corpus; thêm readiness, pre-warm, timeout, retry/circuit breaker và bảo vệ
  các route ML chỉ cho API nội bộ.
- [ ] Tích hợp SAINT+ vào learner event pipeline hoặc ghi rõ đây chỉ là model
  serving PoC. DQN/DP hiện vẫn là research evidence, chưa phải production policy.
- [ ] Nếu giữ gamification trong MVP, thiết kế event ledger cho XP/streak/badge/
  quest, timezone, idempotency, API, DB, UI và test.
- [ ] Tạo CI chạy .NET, ML, Flutter analyze/test/build; thêm contract test,
  authorization test, 503/degradation test, main-tab API flow và full-stack E2E.
- [ ] Nâng hai dependency High severity; externalize secrets; thêm startup config
  validation, token refresh/revoke, exception handling, CORS/admin audit log,
  security headers và HTTPS.
- [ ] Tạo Dockerfile .NET/ML và production topology gồm API, ML, PostgreSQL,
  migration/seed, persistent uploads/object storage, backup, logs và metrics.
- [ ] Hoàn thiện mobile release: application ID/name, keystore, dev/staging/prod
  flavors, HTTPS URL, icon/splash, versioning, accessibility và APK/AAB test.
- [ ] Nếu Advisor/Writing/Speaking thuộc MVP, bổ sung màn hình Flutter, audio
  permission/lifecycle, cost/quota UX, privacy/retention và fallback.

### P2 — Học thuật, vận hành và tài liệu

- [ ] Đánh giá/fine-tune Whisper cho giọng Việt và phoneme alignment sau khi core
  MVP ổn định.
- [ ] Bổ sung item/lesson analytics, CAT/KT calibration, fairness và drift
  monitoring.
- [ ] Đồng bộ README, `docs/bao-cao-tien-do.md`, API docs và test counts; phân biệt
  rõ backend-only, PoC, mock, design và product E2E.
- [ ] Chốt consent, retention, export/delete và incident handling cho dữ liệu
  người học và audio.

## Cổng nghiệm thu hoàn thành dự án

1. **Learner gate:** người dùng mới đi trọn onboarding → placement → today plan →
   lesson → exercise → feedback → mastery/path thay đổi → review → dashboard mà
   không qua mock.
2. **Admin gate:** admin đăng nhập, quản lý skill/lesson/question, import nội dung
   và xem analytics; learner không truy cập được admin route.
3. **Data/AI gate:** máy sạch dựng lại được DB, item bank, model checkpoint và RAG
   index; ML degradation không làm mất hoặc nhân đôi dữ liệu.
4. **Quality gate:** .NET, ML, Flutter, contract và full-stack E2E đều xanh trong
   CI; không còn advisory High/Critical chưa xử lý hoặc chưa có chấp nhận rủi ro.
5. **Release gate:** full stack chạy bằng production config, secrets không nằm
   trong repo, có HTTPS/backup/monitoring; APK/AAB được ký đúng và smoke test trên
   thiết bị thật.

## Thứ tự triển khai đề xuất

1. **Flutter quality gate đã đạt:** `main@f6da732` đã đồng bộ `origin/main`,
   Flutter analyze sạch và test đạt 62/62; tiếp tục duy trì gate sau mỗi lát
   cắt. Full project quality gate (.NET/ML/contract/full-stack E2E trong CI)
   chưa đạt và chưa được chạy lại đầy đủ trong lượt này.
2. Đồng bộ tài liệu hiện hành, sau đó xử lý Git bằng commit/PR riêng với danh
   sách file được kiểm tra rõ ràng.
3. Nối Review và Progress với `/reviews/*`, `/mastery`; thêm API states,
   double-submit guard và test.
4. Hoàn thiện Profile/Onboarding update API và Flutter flow; giữ `GET /auth/me`
   làm read path hiện có hoặc chuẩn hóa read/write route cùng lúc.
5. Khép kín learner loop:
   `Path → Lesson → Exercise → Mastery → Review → Dashboard` và xác minh MuMu.
6. Chuẩn hóa data/content có thể tái tạo; hoàn tất speaking validation/retention,
   rate limit, token lifecycle và secrets/config validation.
7. Hoàn thiện Admin, CI/full-stack E2E, deployment và mobile release.

---

# Phụ lục — Snapshot FE-01 đến FE-04 trước ngày 2026-07-31

Phần dưới được giữ lại làm lịch sử triển khai. Các thông tin về tên nhánh, số test,
working tree và “ưu tiên tiếp theo” trong phụ lục không còn là trạng thái hiện hành.

# Những việc đã triển khai (lịch sử)

## FE-01 — Flutter baseline

- Đưa toàn bộ ứng dụng Flutter vào Git.
- Hoàn thiện giao diện 5 tab chính: Trang chủ, Lộ trình, Ôn tập, Tiến độ và Hồ sơ.
- Thiết lập theme, font Hanken Grotesk, widget dùng chung và dữ liệu mock.
- Bổ sung `.gitignore` cho Flutter, cache và công cụ local.
- `.claude/`, `.agents`, `.codex`, `docs/superpowers/` và `context.md` đã được ignore và không còn được Git tracking.
- Commit: `5cdd572 feat(mobile): add Flutter application baseline`.

## FE-02 — API và session foundation

- Sử dụng `http`, `go_router` và `flutter_secure_storage`.
- Cấu hình `API_BASE_URL` bằng `--dart-define`.
- Android Emulator mặc định truy cập backend qua `10.0.2.2:5000`; MuMu sử dụng IP LAN của máy host.
- Xây dựng `ApiClient` để gắn Bearer token, parse JSON/plain text, xử lý timeout/mất mạng/response không hợp lệ, map lỗi ổn định và xóa session khi nhận `401`.
- Xây dựng `SessionController` và `MemorySessionStore` phục vụ kiểm thử.
- Token được lưu trong secure storage.
- Commit: `85f9bf4 feat(mobile): add API and session foundation`.

## FE-03 — Authentication

- Hoàn thiện Splash, Login và Register.
- Có validation email, mật khẩu tối thiểu 8 ký tự, hiện/ẩn mật khẩu và chống double-submit.
- Email được chuẩn hóa bằng `trim` và lowercase.
- Tích hợp `POST /auth/login` và `POST /auth/register`.
- Có thông báo cho sai mật khẩu, email đã tồn tại, timeout, mất kết nối và lỗi chung.
- Router guard bảo vệ màn hình authenticated.
- Logout trong Profile xóa token thật, chuyển về Login và không cho dùng nút Back để quay lại màn hình authenticated.
- Commit: `bad6e41 feat(mobile): add authentication flow`.

## FE-04 — Placement Flow

- Hoàn thiện Placement Intro, câu hỏi, kết quả và điều hướng vào `MainShell`.
- Tích hợp:
  - `GET /placement/status`
  - `POST /placement/start`
  - `POST /placement/{sessionId}/answer`
  - `GET /placement/{sessionId}/result`
- Backend xác định trạng thái hoàn thành placement từ `TestSessions` của đúng người dùng.
- Flutter quản lý trạng thái onboarding placement:
  - `unknown`
  - `checking`
  - `required`
  - `completed`
  - `error`
- Router quyết định vào Splash, Placement, màn hình lỗi trạng thái hoặc Home dựa trên session và trạng thái placement thật.
- Có retry khi tải trạng thái lỗi và chống kết quả async cũ ghi đè session mới sau restore/login/logout.
- Khi hoàn thành placement, session được đánh dấu `completed` trước khi vào `MainShell`.
- Cold start hoặc đăng nhập lại sẽ đi thẳng vào Home nếu người dùng đã hoàn thành placement.
- Có loading, retry, mapping lỗi placement và router guard cho câu hỏi/kết quả khi chưa có phiên.
- Hỗ trợ câu hỏi listening và phát audio thật.
- Commit nền tảng FE-04: `54e8024 feat(mobile): add placement assessment flow`.
- Endpoint trạng thái, routing onboarding và các test liên quan hiện là thay đổi mới chưa commit.

## Android, MuMu và runtime local

- Android SDK 36 và Build Tools đã được cài đặt; Android licenses đã được chấp nhận.
- Flutter nhận MuMu qua ADB tại `192.168.2.16:5555`, Android 12, API 32.
- Backend đã listen trên `0.0.0.0:5000`, vì vậy MuMu truy cập được backend qua IP LAN của máy host.
- PostgreSQL local và dịch vụ ML đã tham gia đầy đủ trong smoke test.
- Luồng thật đã chạy thành công:

```text
Register → Placement → MainShell → Logout → Login → Home
```

- Placement dùng 12 smoke items local, trong đó có listening audio thật.
- Kết quả đã ghi nhận trong phiên smoke test end-to-end: CEFR `B2`, sai số chuẩn `SE = 0.71`.
- APK debug đã build và cài lên MuMu thành công.
- README đã có hướng dẫn khởi động PostgreSQL/backend, kết nối MuMu, truyền `API_BASE_URL`, build/cài APK và xử lý timeout/ADB.
- Commit tài liệu: `e01b823 docs(mobile): document local and MuMu setup`.

## Branding

- Logo chính đã được dùng làm launcher icon Android.
- `logo_black.png` được dùng trên giao diện nền trắng.
- Đã bỏ khung nền đen không cần thiết trên Login/Register/Splash.
- Commit:
  - `69dce59 feat(mobile): apply provided brand logo`
  - `e69a142 fix(mobile): use light-background brand logo`

# Kết quả kiểm thử tại thời điểm snapshot (lịch sử)

- `flutter analyze`: sạch, không có lỗi.
- `flutter test`: 47/47 test đạt.
- Backend `PlacementTests`: 4/4 test đạt.
- Verifier chạy toàn bộ backend test: 42/42 test đạt.
- APK debug: build và cài đặt thành công trên MuMu.
- Smoke test end-to-end trên MuMu với backend/PostgreSQL/ML: đạt.
- `git diff --check`: sạch, không phát hiện lỗi whitespace.

Phạm vi test hiện bao phủ:

- Base URL, Bearer token và xử lý lỗi API.
- Session restore/authenticate/logout/invalidate.
- Trạng thái placement, retry khi lỗi và chống stale async.
- Auth repository, AuthViewModel, validation và điều hướng Login/Register.
- Router guard cho người dùng mới và người dùng đã hoàn thành placement.
- Placement repository, ViewModel, luồng widget, listening và kết quả.
- Logout và năm tab chính.

# Những việc chưa hoàn tất tại thời điểm snapshot (lịch sử)

## Dữ liệu placement hiện chỉ là smoke data local

- 12 items đang dùng để smoke test, chưa phải item bank mục tiêu 617 câu.
- Chưa tích hợp quy trình tạo/nạp item bank bằng Gemini hoặc OpenAI vì môi trường hiện chưa có API key tương ứng.
- Kết quả B2 và `SE = 0.71` của phiên smoke test end-to-end đã ghi nhận chỉ là bằng chứng vận hành trên bộ smoke data local, không phải kết quả hiệu chuẩn học thuật hay production.

## Các tab chính vẫn dùng dữ liệu mock

- Home, Learning Path, Review và Progress vẫn sử dụng `MockRepository`.
- Profile vẫn còn dữ liệu hard-code.
- API thật cho các tab chính chưa được nối.

## Hạ tầng và nền tảng chưa hoàn tất

- Docker chưa được cài hoặc chưa có trong `PATH`; runtime hiện dùng PostgreSQL local.
- Windows desktop chưa được xác minh vì thiếu Visual Studio workload “Desktop development with C++”.
- Cảnh báo dependency `NU1903` vẫn còn tồn tại và cần được xử lý riêng.

## Git và phát hành

- Các thay đổi endpoint placement status, routing/session Flutter và test hiện chưa commit.
- `placement_status_error_screen.dart` đang untracked, cần add khi commit.
- `Progress.md` đang untracked.
- `logo.png` là thay đổi chưa commit của người dùng; cần quyết định giữ và commit riêng hoặc hoàn tác trước khi gom commit tính năng.
- Chưa tạo PR và chưa merge nhánh `feat/mobile-foundation-auth` vào `main`.

# Ưu tiên đề xuất tại thời điểm snapshot (lịch sử)

1. Rà soát thay đổi đang chờ, add `placement_status_error_screen.dart`, tách `logo.png` theo quyết định của người dùng và tạo commit cho placement completion routing.
2. Xử lý cảnh báo dependency `NU1903`, sau đó chạy lại toàn bộ Flutter/backend test.
3. Tạo PR từ `feat/mobile-foundation-auth` sang `main` và review FE-01 đến FE-04.
4. Chuẩn bị item bank 617 câu hoặc quy trình sinh/nạp dữ liệu khi có Gemini/OpenAI key; bổ sung đánh giá chất lượng dữ liệu trước khi coi placement là production-ready.
5. Tích hợp API thật cho Home, Learning Path, Review, Progress và Profile.
6. Bổ sung Docker khi môi trường hỗ trợ và xác minh Windows desktop nếu đây vẫn là nền tảng mục tiêu.
