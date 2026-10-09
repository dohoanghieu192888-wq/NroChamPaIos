# Build file `.ipa` không cần máy Mac

Project này là bản **Unity export sang Xcode** (`NroChamPa`, scheme `Unity-iPhone`).
Bước cuối để ra `.ipa` là compile + package, việc này **chỉ chạy được trên macOS**
(vì cần iOS SDK + linker của Apple, Xcode không có bản Windows/Linux).

Cách duy nhất không phải mua Mac: để **GitHub Actions** build trên máy macOS miễn phí
của GitHub rồi tải `.ipa` về.

## Đã có sẵn trong project

| File | Việc nó làm |
|---|---|
| [scripts/build-ipa.sh](scripts/build-ipa.sh) | `xcodebuild` tắt code signing → đóng gói `Payload/` → xuất `.ipa`. Có verify Info.plist, binary và `Data/`. |
| [.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml) | Chạy script trên runner `macos-14` (Xcode 15.4), upload `.ipa` thành artifact. |
| [.gitignore](.gitignore) | Bỏ `Xcode.rar` (159 MB — GitHub chặn file >100 MB) và thư mục build. |
| [.gitattributes](.gitattributes) | Chốt LF cho `.sh`/`.yml`. Nếu để CRLF, script sẽ chết trên runner macOS với lỗi `bash\r: command not found`. |

Kết quả: `build/NroChamPa-unsigned.ipa` — **không ký**, cài qua ESign / Sideloadly / AltStore / TrollStore (mấy app này sẽ tự ký lại bằng chứng chỉ của bạn khi cài).

## Các bước chạy

### 1. Đưa project lên GitHub

Máy hiện tại **chưa phải git repo**, nên cần tạo repo trước:

```bash
git init
git add .
git commit -m "Unity iOS export + pipeline build IPA"
```

> `Xcode.rar` đã nằm trong `.gitignore` nên không bị commit. Đừng dùng `git add -f Xcode.rar`.

Tạo repo trên GitHub (có thể để **Public** để dùng runner miễn phí), rồi:

```bash
git remote add origin https://github.com/<user>/<repo>.git
git branch -M main
git push -u origin main
```

### 2. Để GitHub build

- Push lên `main` → workflow tự chạy, **hoặc** vào tab **Actions → Build unsigned IPA → Run workflow**.
- Chờ khoảng 15–40 phút (Unity project khá lớn, lần đầu build il2cpp lâu).
- Vào run đã xong → mục **Artifacts** → tải `NroChamPa-unsigned-ipa`.
- Giải nén ra file `NroChamPa-unsigned.ipa`.

### 3. Cài lên iPhone

Dùng **ESign**, **Sideloadly** hoặc **AltStore** → chọn file `.ipa` → ký bằng Apple ID của bạn.

## Nếu muốn build trên Mac thật / cloud Mac

```bash
bash scripts/build-ipa.sh
# -> build/NroChamPa-unsigned.ipa
```

## Muốn IPA ký sẵn (ad-hoc / App Store)?

Cần Apple Developer account ($99/năm). Khi đó thêm `ExportOptions.plist` và dùng
`xcodebuild -exportArchive` với certificate + provisioning profile nạp qua GitHub Secrets.
