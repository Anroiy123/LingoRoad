# LingoRoad Mobile

Ứng dụng Flutter dành cho người học của LingoRoad. Các lệnh dưới đây được chạy
từ thư mục gốc của repository bằng PowerShell.

## Yêu cầu

- Flutter SDK `>=3.44` (Dart `>=3.12.0 <4.0.0`); kiểm tra bằng `flutter doctor`.
- Android SDK và Android SDK Platform-Tools (`adb`) nếu chạy trên Android.
- .NET SDK, PostgreSQL và môi trường Python của dịch vụ ML nếu chạy toàn bộ
  stack trên máy local.

## Cài dependency và kiểm tra

```powershell
Set-Location src/mobile
flutter pub get
flutter analyze
flutter test
Set-Location ../..
```

## Khởi động stack local

Ứng dụng cần PostgreSQL và backend .NET. Dịch vụ ML cũng phải chạy khi bắt đầu
hoặc tiếp tục bài placement. Chạy mỗi tiến trình foreground trong một terminal
riêng:

```powershell
docker compose -f src/backend/docker-compose.yml up -d db
dotnet run --project src/backend/LingoRoad --launch-profile http -- --urls "http://0.0.0.0:5000"

Set-Location src/backend/ml
.\.venv\Scripts\uvicorn.exe lingoroad_ml.serving.app:app --host 127.0.0.1 --port 8001
```

Nếu dùng PostgreSQL local, chưa có môi trường ML hoặc cần kiểm tra health, xem
[Hướng dẫn phát triển mobile trên máy local](../../docs/mobile-local-development.md).

## Chạy ứng dụng

`API_BASE_URL` được truyền bằng `--dart-define`. Thay placeholder bằng URL mà
thiết bị đang chạy ứng dụng có thể truy cập:

```powershell
Set-Location src/mobile

# Web
flutter run -d chrome --dart-define="API_BASE_URL=http://<BACKEND_HOST>:5000"

# Android
flutter devices
$deviceId = "<DEVICE_ID>"
flutter run -d $deviceId --dart-define="API_BASE_URL=http://<BACKEND_HOST>:5000"
```

Mỗi loại thiết bị hoặc emulator có cách truy cập máy host khác nhau; không mặc
định `localhost` sẽ hoạt động trên Android. Xem bảng URL và hướng dẫn kết nối
thiết bị trong [guide local](../../docs/mobile-local-development.md).

## Build APK

```powershell
Set-Location src/mobile
flutter build apk --debug --dart-define="API_BASE_URL=http://<BACKEND_HOST>:5000"
```

APK debug được tạo tại `build\app\outputs\flutter-apk\app-debug.apk`.
