# Tổng quan tiến độ

> Cập nhật tích hợp 2026-08-01: mobile đã nối `Path → Lesson → Exercise →
> Feedback → Mastery → Review`, Home dùng dashboard aggregate thật và
> gamification có ledger append-only cho XP/coin/streak/quest. Widget/API test
> đã bao phủ retry và double-submit; smoke learner loop trên MuMu đã đạt cả
> grade Review, refresh Progress/Home, mất mạng/retry, app restart và ML tạm
> ngừng. Admin React hiện đã dùng auth/role thật, có CRUD Skills/Items/Lessons,
> import validate/preview/apply, analytics và audit log.
> Lịch sử bên dưới giữ nguyên.

> Cập nhật lần cuối: **2026-08-01**
> Phạm vi: toàn bộ LingoRoad gồm backend .NET, ML service, Flutter mobile,
> PostgreSQL, dữ liệu nội dung, Admin Web, kiểm thử và phát hành.

## Kết luận hiện tại

- Mốc **16/16 task hoàn thành** trong ledger backend là kết quả của kế hoạch
  nghiên cứu backend/AI, không phải trạng thái hoàn thành của toàn bộ MVP.
- Luồng đã được triển khai và kiểm thử ở API/widget:
  `Register/Login → Placement → Profile Setup → Home/Path → Lesson → Exercise →
  Feedback → Mastery → Review → Dashboard`; phần learner loop sau placement đã
  được smoke trên MuMu bằng API/PostgreSQL thật.
- Backend và mobile cùng hỗ trợ start/resume lesson, ba loại exercise, feedback,
  completion, refresh Path/Progress/Review/Home và chống double-submit. Home,
  Profile/onboarding, Review và Progress đều dùng API thật; không còn
  `MockRepository` trong `lib/` production.
  Các màn hình đã bổ sung trên Figma mới là design coverage, chưa được tính là
  Flutter implementation.
- Các lỗ hổng `CorrectAnswer`, placement session binding/idempotency, chuẩn hóa
  email, rate limit, refresh rotation/reuse, role policy và startup config
  validation đã được xử lý; validation/retention Speaking vẫn còn thiếu.
- Admin Web đã có login/route guard theo role, CRUD nội dung, draft/publish,
  soft-delete, import transactional/idempotent, analytics và audit log; learner
  bị từ chối ở toàn bộ `/admin/*`. Gamification đã có XP/coin/streak/quest nhưng
  chưa có badge/reward tuning; mastery passive decay vẫn thiếu.
- Vì vậy, dự án hiện là **learner loop đã nối ở API/mobile và có test tự động**,
  đồng thời đã có device smoke sau placement, nhưng chưa đạt MVP nghiệm thu do
  thiếu full-stack E2E từ account mới, Speaking safety và production
  readiness.

## Snapshot bằng chứng ngày 2026-08-01

- Phase Admin được triển khai trên branch riêng từ `main@2cb2cca`; các file thay
  đổi được review/stage tường minh trước khi đưa lên Git.
- .NET hiện có **50 route/13 feature group**: Health, Auth, Skills, Items,
  Placement, Mastery, Reviews, Path, Lessons, Exercises/Writing,
  Dashboard/Gamification, Speaking và Admin.
- Flutter: `flutter analyze` sạch; `flutter test` đạt **79/79 test**.
- .NET Release test đạt **69/69**; migration identity/profile, Lesson/content,
  gamification và Admin content management đã apply thành công trên PostgreSQL
  local. Concurrent start/answer/completion, reward replay, role enforcement,
  CRUD relation guard và import rollback/idempotency test đều xanh.
- Admin đạt lint, **6/6 Vitest**, **2/2 Playwright E2E** và production build.
  Browser smoke với API/
  PostgreSQL thật đã xác minh login, analytics, tạo skill, import
  validate/apply, refresh danh sách và không có console error.
- ML chưa tái kiểm chứng được trong lần rà soát này: `.venv` có FastAPI nhưng
  thiếu `pytest`; Python hệ thống có pytest nhưng thiếu `fastapi` và `nltk`.
  Con số 47 test đạt trong tài liệu cũ chỉ được coi là bằng chứng lịch sử.
- Từ database test sạch, content bundle `2026.08.01-v1` tái tạo đúng **20
  lesson/100 item/3 exercise type**, seed lại không nhân bản và có checksum,
  nguồn, license, reviewer cùng validation tham chiếu/trùng lặp.
- `docker` chưa có trong `PATH`. Compose hiện chỉ khai báo PostgreSQL, chưa đóng
  gói API, ML, model/RAG artifacts hoặc reverse proxy.
- `dotnet list package --vulnerable --include-transitive` hiện không báo package
  vulnerable cho cả API và test project.
- MuMu Android 12 đã hoàn thành lesson 5 câu (MCQ/cloze/reorder), nhận feedback,
  tạo và grade ReviewCard, cập nhật mastery 77%, streak 1, XP 45, coin 3 và due
  review về 0. Force-stop/relaunch giữ phiên; tháo ADB reverse làm submit lỗi và
  nối lại retry thành công với cùng operation ID. ML không chạy trong lượt này;
  fixture chỉ seed placement-completed cho tài khoản test nên không được tính là
  E2E placement mới.

## Ma trận trạng thái sản phẩm

| Hạng mục | Trạng thái | Phần còn thiếu |
|---|---|---|
| Auth và session | API thật | Access token 15 phút, refresh token hash/rotation/reuse detection, logout/revoke, đổi mật khẩu, role claim/policy và mobile single-flight refresh đã có; forgot-password là phần mở rộng sau MVP |
| Onboarding và profile | API thật | Sau placement có Profile Setup; target chỉ được xác nhận khi user chọn A1–B2. Daily goal, purpose, focus, reminder/timezone, email/app preferences và change-password đều lưu qua API; toggle rollback khi save lỗi |
| Placement | Partial, E2E thật | Answer đã session-bound/idempotent và email đã normalize/validate; vẫn chỉ trả CEFR tổng và mới có 12 smoke items |
| Home/Today Plan | API thật trên mobile | `GET /dashboard` + `/path/today` cấp name, CEFR/target, mastery, goal, next lesson, due review, recent activity và reward stats |
| Learning Path | API thật, MuMu smoke đạt | `/path` mở lesson từ `/path/today`; complete refresh Path/Progress/Review/Home; offline retry và app restart đã được xác minh |
| Lesson | API thật trên mobile | Detail/player start-resume-progress-submit-feedback-complete có loading/error/retry và giữ operation ID khi retry |
| Exercise/AI feedback | API thật trên mobile | Player hỗ trợ MCQ, cloze, reorder; đáp án chỉ xuất hiện sau submit; backend idempotent và cập nhật mastery một lần |
| Mastery/KT | Partial, read API thật | Progress tổng hợp snapshot `/mastery` với catalog `/skills`; chưa áp dụng passive decay và SAINT+ `/kt/predict` chưa được .NET production flow sử dụng |
| SRS Review | API thật, producer backend và MuMu smoke đạt | Dùng `/reviews/due`, grade idempotent, tự tạo card từ câu lesson sai và cập nhật reward/due đúng một lần |
| Dashboard/Progress | API thật, MuMu smoke đạt, còn thiếu decay | Progress dùng `/skills` + `/mastery` và dashboard/gamification aggregate; category chỉ tính skill đã thực hành; Home dùng `/dashboard` |
| Advisor/Writing/Speaking | Backend/ML-only | Chưa có learner UI; thiếu quota, privacy, fallback và quyết định có thuộc MVP hay không |
| Gamification | Partial, API/UI thật | Ledger append-only cho XP/coin/streak/quest, timezone, API, Home/Streak UI và replay test đã có; badge và reward tuning còn thiếu |
| Admin CMS/analytics | API/UI thật, browser smoke đạt | Login/role guard, CRUD Skills/Items/Lessons, draft/publish, soft-delete, import hai bước, analytics và audit đã có; chưa có user-role management, pagination/search và browser E2E tự động trong CI |
| Dữ liệu nội dung | Versioned bundle | Có 174 skills, bundle 20 lesson/100 item/3 type với stable ID/checksum/source/license/reviewer và transactional idempotent seed; còn thiếu 5–10 test learner fixture |
| Deployment/operations | Missing/partial | Thiếu full-stack Docker, CI/CD, secrets, HTTPS, migration job, backup và monitoring |
| Mobile release | Debug-only | Application ID mặc định, release dùng debug signing, thiếu flavor/env production và AAB smoke test |

## Backlog bắt buộc

### P0 — Khép kín MVP và sửa rủi ro dữ liệu/bảo mật

- [ ] **P0-01 — Chốt contract MVP.**
  - [x] Phạm vi CEFR A1–B2.
  - [x] Placement trả overall level.
  - [x] Advisor, Writing và Speaking thuộc phạm vi roadmap P0–P2.
  - [ ] Đồng bộ `MVP_architecture.md`, API contract, mobile model và kịch bản demo.
- [ ] **P0-02 — Sửa security/integrity.**
  - [x] Không trả `CorrectAnswer` từ public `GET /items`.
  - [x] Placement answer idempotent, chỉ chấp nhận item đã cấp cho session và
    không tăng mastery hai lần khi client retry.
  - [x] Normalize và validate email ở backend.
  - [x] Bổ sung rate limit, token lifecycle và startup validation cho
    secrets/config nhạy cảm.
  - [ ] Speaking phải từ chối MIME sai, giới hạn dung lượng/thời lượng và có
    chính sách retention/lưu/xóa audio.
- [x] **P0-03 — User profile và onboarding thật.**
  - [x] `GET /auth/me` và Flutter profile read đã có loading/error/retry; UI
    render name, level/CEFR hiện tại và badge/profile stats từ response. Email
    chỉ dùng làm fallback cho display name.
  - [x] Render `targetCefr` đã parse thay cho target tile đang hard-code theo
    localization.
  - [x] Thêm schema/migration/update API/test cho target CEFR, daily minutes,
    purpose, focus skills và preferences.
  - [x] Tạo Flutter onboarding/update flow, nối toggles/change-password và bỏ
    việc mặc định mục tiêu B2 khi người dùng chưa xác nhận.
- [ ] **P0-04 — Data/content có thể tái tạo.**
  - [x] Có 100 câu hỏi, 20 lesson và 3 exercise types trong bundle được test.
  - [ ] Bổ sung 5–10 test learners; admin production dùng bootstrap secret đã có.
  - [x] Có version, nguồn, validation, deduplication, seed/import và artifact
    distribution; không phụ thuộc file chỉ tồn tại trên một máy.
- [x] **P0-05 — Learning Path end-to-end.**
  - [x] Mobile dùng repository/API model/ViewModel thật cho `GET /path`, có
    loading, empty, error, retry và Flutter test.
  - [x] Backend định nghĩa path item → lesson, today plan, complete và recalculation.
  - [x] Nối các API learner path mới vào mobile.
  - [x] Xác minh lại backend/mobile flow trên MuMu, gồm offline retry, app
    restart và ML tạm ngừng.
- [x] **P0-06 — Lesson/Exercise/AI feedback end-to-end.**
  - [x] Bổ sung Lesson domain/API và dữ liệu lesson.
  - [x] Tạo mobile lesson detail/player; backend submit/result/explanation đã có.
  - [x] Backend cập nhật mastery đúng một lần và recalculation sau hoàn thành.
  - [x] Mobile refresh path/progress/review/dashboard sau hoàn thành.
- [x] **P0-07 — SRS Review end-to-end ở API/mobile screen hiện có.**
  - [x] Flutter dùng `/reviews/due`, gửi grade 1–4 idempotent và có
    loading/empty/error/complete state cùng double-submit guard/test lịch ôn.
  - [x] Tự tạo `ReviewCard` từ câu trả lời sai khi complete lesson.
- [ ] **P0-08 — Home/Dashboard/Progress/Profile dùng dữ liệu thật.**
  - [x] Profile read đã dùng `GET /auth/me` cho name, level/CEFR hiện tại và
    badge/profile stats; email chỉ là fallback cho display name.
  - [x] Hiển thị `targetCefr` đã parse thay cho target tile hard-code.
  - [x] Tạo aggregate API cho CEFR, mastery, weak/strong skills, due count,
    completed lessons và next lesson.
  - [ ] Áp dụng mastery decay nhất quán khi đọc path/dashboard.
  - [x] Progress thay mastery/weak-strong skill mock bằng `/skills` + `/mastery`.
  - [x] Thay dữ liệu mock/hard-code còn lại ở Home/Profile/Streak và dùng API
    update cho profile preferences.
- [x] **P0-09 — Admin tối thiểu.**
  - [x] Role/authorization fail-closed ở backend và route guard phía React.
  - [x] CRUD skill/lesson/question có validation quan hệ, draft/publish,
    soft-delete và audit log.
  - [x] Import hai bước validate/preview → apply, transactional, versioned và
    idempotent.
  - [x] Analytics cơ bản cho learner activity, completion, correctness, due
    review, mastery, item usage và content usage.
  - [x] Unit/component/API test, 2 Playwright E2E và browser smoke trên
    API/PostgreSQL thật.

### P1 — Production readiness

- [ ] Chuẩn hóa ML environment và biến `LINGOROAD_*`; đóng gói checkpoint, RAG
  index/corpus; thêm readiness, pre-warm, timeout, retry/circuit breaker và bảo vệ
  các route ML chỉ cho API nội bộ.
- [ ] Tích hợp SAINT+ vào learner event pipeline hoặc ghi rõ đây chỉ là model
  serving PoC. DQN/DP hiện vẫn là research evidence, chưa phải production policy.
- [ ] Nếu giữ gamification trong MVP:
  - [x] Event ledger XP/coin/streak/quest, timezone, idempotency, API, DB, UI và test.
  - [ ] Badge, reward tuning và acceptance test theo product rule.
- [ ] Tạo CI chạy .NET, ML, Flutter analyze/test/build; thêm contract test,
  authorization test, 503/degradation test, main-tab API flow và full-stack E2E.
- [x] Nâng dependency có advisory; thêm startup config validation, token
  refresh/revoke, exception handling, CORS, role policy và security audit log.
- [ ] Hoàn thiện security headers và HTTPS trong production topology.
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

1. **Flutter quality gate đã đạt:** Flutter analyze sạch và test đạt 79/79;
   tiếp tục duy trì gate sau mỗi lát
   cắt. Full project quality gate (.NET/ML/contract/full-stack E2E trong CI)
   chưa đạt và chưa được chạy lại đầy đủ trong lượt này.
2. Đồng bộ tài liệu hiện hành, sau đó xử lý Git bằng commit/PR riêng với danh
   sách file được kiểm tra rõ ràng.
3. **Learner loop mobile đã nối:** Review/Progress/Home/Lesson đều dùng API,
   có API states, operation ID/retry guard và reward ledger; smoke MuMu đã đạt.
   Phần còn lại là mastery passive decay và full-stack E2E từ account mới.
4. **Profile/Onboarding đã đạt:** `GET/PATCH /auth/me`, refresh/logout,
   change-password và Profile Setup đã nối mobile; PostgreSQL migration đã apply.
5. **Backend learner loop và content seed đã đạt:** 20 lesson/100 item/3 type;
   start/resume/submit/complete/mastery/review/reward idempotent. Mobile đã nối
   toàn vòng và đã xác minh MuMu/offline/restart.
6. Hoàn tất Advisor/Writing/Speaking mobile, speaking validation/retention và
   ML productionization; bổ sung test learner fixtures.
7. Hoàn thiện analytics/privacy lifecycle, CI/full-stack E2E, deployment và
   mobile release.

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
