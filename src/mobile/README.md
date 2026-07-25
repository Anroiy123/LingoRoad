# LingoRoad Mobile

Ứng dụng Flutter dành cho người học của LingoRoad. Các lệnh dưới đây được chạy
từ thư mục gốc của repository bằng PowerShell.

## Yêu cầu

- Flutter SDK tương thích Dart `>=3.6.0 <4.0.0`; kiểm tra bằng `flutter doctor`.
- Android SDK và Android SDK Platform-Tools (`adb`) để chạy trên Android.
- .NET SDK phù hợp với backend LingoRoad.
- Docker Desktop để khởi động PostgreSQL bằng Docker Compose.
- Máy host và MuMu Player cùng mạng LAN, nếu chạy ứng dụng trên MuMu.

## Cài dependency và kiểm tra

```powershell
Set-Location src/mobile
flutter pub get
flutter analyze
flutter test
Set-Location ../..
```

## Khởi động PostgreSQL và backend

Khởi động PostgreSQL:

```powershell
docker compose -f src/backend/docker-compose.yml up -d db
```

Khi chạy trên MuMu, backend phải lắng nghe trên mọi card mạng để máy ảo có thể
truy cập qua IP LAN của máy host:

```powershell
dotnet run --project src/backend/LingoRoad --launch-profile http -- --urls "http://0.0.0.0:5000"
```

Không dùng `localhost` hoặc `127.0.0.1` làm `API_BASE_URL` trên MuMu vì các địa
chỉ đó trỏ về chính máy ảo, không phải máy Windows đang chạy backend.

## Chạy trên MuMu Player

### 1. Tìm IP LAN của máy host

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
  Select-Object InterfaceAlias, IPAddress
```

Chọn địa chỉ IPv4 của card mạng đang kết nối với MuMu, ví dụ
`192.168.2.10`. Có thể kiểm tra backend từ máy host tại
`http://localhost:5000/health` trước khi tiếp tục.

### 2. Kết nối và kiểm tra thiết bị

Bật ADB/USB debugging trong phần cài đặt của MuMu nếu cần, sau đó kiểm tra:

```powershell
adb devices
flutter devices
```

Nếu MuMu cung cấp địa chỉ kết nối ADB nhưng thiết bị chưa xuất hiện, kết nối
thủ công rồi kiểm tra lại:

```powershell
$mumuIp = "192.168.2.16"
adb connect "${mumuIp}:5555"
adb devices
```

Ví dụ, thiết bị từng được nhận dưới ID `192.168.2.16:5555`. IP và cổng ADB có
thể thay đổi sau khi khởi động lại MuMu hoặc mạng, vì vậy luôn dùng ID hiện tại
do `adb devices` hiển thị.

### 3. Chạy ứng dụng

Gán ID thiết bị và IP host bằng giá trị thực tế:

```powershell
$deviceId = "192.168.2.16:5555"
$hostIp = "192.168.2.10"
Set-Location src/mobile
flutter run -d $deviceId --dart-define="API_BASE_URL=http://${hostIp}:5000"
```

Các IP trên chỉ là ví dụ; không coi chúng là giá trị cố định.

## Build và cài APK trên MuMu

Phải truyền cùng `API_BASE_URL` khi build vì `--dart-define` được nhúng vào ứng
dụng tại thời điểm biên dịch:

```powershell
$hostIp = "192.168.2.10"
Set-Location src/mobile
flutter build apk --debug --dart-define="API_BASE_URL=http://${hostIp}:5000"
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Nếu có nhiều thiết bị ADB, chỉ định MuMu bằng `-s`:

```powershell
$deviceId = "192.168.2.16:5555"
adb -s $deviceId install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Chạy trên web hoặc Android Studio Emulator

Web truy cập backend trên cùng máy host qua `localhost`:

```powershell
Set-Location src/mobile
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

Android Studio Emulator dùng địa chỉ đặc biệt `10.0.2.2` để truy cập máy host.
Đây cũng là URL mặc định của ứng dụng:

```powershell
Set-Location src/mobile
flutter emulators
$emulatorId = "emulator-id-tu-flutter-emulators"
flutter emulators --launch $emulatorId
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

## Khắc phục sự cố

### Backend bị timeout hoặc không kết nối được

- Xác nhận PostgreSQL đang chạy bằng
  `docker compose -f src/backend/docker-compose.yml ps`.
- Xác nhận backend hiển thị địa chỉ `http://0.0.0.0:5000` và endpoint
  `http://localhost:5000/health` phản hồi trên máy host.
- Kiểm tra lại IP host; IP LAN có thể thay đổi khi chuyển Wi-Fi hoặc nhận
  địa chỉ DHCP mới.
- Cho phép tiến trình .NET hoặc TCP port `5000` qua Windows Defender Firewall
  trên mạng Private. Chỉ mở đúng cổng và profile mạng cần thiết.
- Không truyền `localhost` cho ứng dụng đang chạy trong MuMu.

### `adb devices` không thấy MuMu

- Bật lại ADB/USB debugging trong MuMu và xem địa chỉ ADB hiện tại.
- Chạy `adb kill-server`, `adb start-server`, rồi kết nối lại bằng IP/cổng ADB
  hiện tại do MuMu cung cấp.
- Nếu thiết bị ở trạng thái `offline`, ngắt và kết nối lại bằng
  `adb disconnect $deviceId` rồi `adb connect "${mumuIp}:5555"` sau khi đã gán
  hai biến tương ứng.
- Đảm bảo Flutter và terminal đang dùng cùng bản `adb` trong Android SDK
  Platform-Tools.

### Cảnh báo khi chạy ứng dụng

Các log `Vulkan`, `Gralloc` hoặc cảnh báo secure storage thường đến từ lớp đồ
họa/bộ nhớ bảo mật của emulator và không phải lỗi nghiêm trọng nếu ứng dụng vẫn
mở và hoạt động. Chỉ điều tra thêm khi ứng dụng crash, màn hình không render,
hoặc dữ liệu đăng nhập không thể lưu/đọc.

Không đưa token, mật khẩu hoặc URL chứa thông tin nhạy cảm vào source code.
