# lingoRoad mobile

Ứng dụng Flutter dành cho người học của lingoRoad.

## Yêu cầu

- Flutter SDK tương thích Dart `>=3.6.0 <4.0.0`.
- Backend LingoRoad chạy tại cổng `5000`.

## Cài đặt và kiểm tra

```powershell
cd src/mobile
flutter pub get
flutter analyze
flutter test
```

## Chạy ứng dụng

Android Emulator dùng URL mặc định `http://10.0.2.2:5000` để truy cập backend
trên máy host:

```powershell
flutter run
```

Web hoặc Windows cần truyền URL backend:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Cùng biến cấu hình có thể dùng khi build:

```powershell
flutter build web --release --dart-define=API_BASE_URL=http://localhost:5000
flutter build apk --debug
```

Không đưa token, mật khẩu hoặc URL chứa thông tin nhạy cảm vào source code.
