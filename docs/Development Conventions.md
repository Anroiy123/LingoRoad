# Development Conventions

This document outlines the coding standards, guidelines, and conventions for development in the LingoRoad project. All developers (and AI assistants) must adhere to these rules when generating or modifying code.

---

## 1. Flutter/Dart Code Generation Guidelines

### Responsive UI Design (BẮT BUỘC)
Tuyệt đối không sử dụng các con số fixed (cố định) cho kích thước giao diện. Phải luôn sử dụng `flutter_screenutil` để UI tự động co giãn theo tỷ lệ màn hình (Design Size mặc định: `390x844`). Cụ thể:
* **Font chữ**: Dùng `.sp` (ví dụ: `fontSize: 14.sp`).
* **Chiều rộng, lề ngang** (width, horizontal padding/margin): Dùng `.w` (ví dụ: `width: 50.w`, `horizontal: 16.w`).
* **Chiều cao, lề dọc** (height, vertical padding/margin): Dùng `.h` (ví dụ: `height: 50.h`, `vertical: 16.h`). 
  > [!WARNING]
  > Không lạm dụng `.h` cho các chiều cao quá nhỏ (< 3) vì có thể làm vỡ line-height của text.
* **Bo góc** (Border Radius): Dùng `.r` (ví dụ: `Radius.circular(8.r)`).

## 2. Flutter/Dart Localization Guidelines

### JSON-Based Translations
Do NOT hardcode user-facing strings or use custom in-file translation classes (e.g. `Chào mừng trở lại`, `welcome back`). All translations must reside in the standard assets translation JSON files:
* **Vietnamese**: `assets/translations/vi.json`
* **English**: `assets/translations/en.json`

### Strict Enforcement During Code Generation
Whenever you create or modify a widget, you **MUST** proactively extract any new user-facing text into the JSON files and replace them with `l10n.translate(...)`. **NEVER** output hardcoded UI text in the Dart file, even as placeholders.

### Mandatory JSON Verification Step
It is **NOT** enough to just use `l10n.translate()` in the Dart code. Every time you introduce a new translation key, you **MUST** immediately edit both `vi.json` and `en.json` to insert the new key-value pair. Make this a verified checklist item before concluding any localization task.

### Using Translations in Code
* Watch the localization helper using:
  ```dart
  final l10n = ref.watch(localizationsProvider);
  ```
* Translate keys using dot notation:
  ```dart
  l10n.translate('namespace.key')
  ```
* Use placeholders for dynamic values (which replaces `{}` placeholders in the JSON value):
  ```dart
  l10n.translate('namespace.key', [arg1, arg2])
  ```

---

## 3. Backend Execution Guidelines

* **EF Core (Entity Framework Core) Commands**: All commands related to EF Core (e.g., `dotnet ef migrations add <MigrationName>`, `dotnet ef database update`) or backend running commands (e.g., `dotnet run`) MUST be executed within the `src/backend/LingoRoad` directory.
  - Alternatively, if run from the root workspace, you MUST explicitly specify the target project and startup project paths:
    ```powershell
    dotnet ef database update --project src/backend/LingoRoad --startup-project src/backend/LingoRoad
    ```

---

## 4. File Length Limitation

* **Soft Limit (Warning)**: Code files should not exceed **800 lines**. When a file reaches this length, it is highly recommended to plan a refactoring.
* **Hard Limit (Block/Error)**: Code files must not exceed **1000 lines** under any circumstances (except for pure static config files, mock data, or auto-generated files like migrations which are allowed up to **1500 lines**).
* **Component-specific Thresholds**:
  - **C# / .NET Endpoints/Controllers**: Max **300 lines** (all business logic must be delegated to Services).
  - **C# / .NET Services**: Max **600 - 800 lines** (split logic into sub-services or helper classes if exceeded).
  - **Flutter Screen/Widget Files (Dart)**: Max **500 - 800 lines** (extract sub-widgets, separate UI from business logic using state management providers if exceeded).
  - **React Admin Page/Component Files (TSX)**: Max **500 - 800 lines** (extract sub-components, table columns, modals, and logic to custom hooks or helper files if exceeded).
  - **Python / FastAPI Endpoint & Utility Files (ML)**: Max **500 - 800 lines** (extract helper functions or model integration logic to separate modules if exceeded).
* **Action**: If a file exceeds or is approaching these limits, refactor it by splitting smaller sections/parts into separate components, custom hooks, helper classes/services, or extension methods to ensure readability and long-term maintainability.
