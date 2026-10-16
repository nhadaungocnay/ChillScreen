# ChillScreen 📸

Ứng dụng chụp ảnh màn hình gọn nhẹ, chạy ẩn trên thanh Menu Bar cho macOS với đầy đủ tính năng tương tự Zalo / Snipaste / CleanShot X.

---

## ✨ Tính năng nổi bật

1. **Chạy ẩn hoàn toàn (Menu Bar & Background):**
   - Ứng dụng chạy ở chế độ `LSUIElement` (Accessory mode), không chiếm chỗ trên thanh Dock.
   - Luôn sẵn sàng trên thanh Menu Bar với biểu tượng máy ảnh hiện đại.

2. **Phím tắt toàn hệ thống (Global Hotkey tùy chỉnh):**
   - Mặc định: **`⌘ + ⇧ + A`** (Cmd + Shift + A, tương tự Zalo / Snipaste).
   - Cho phép người dùng bấm đổi phím tắt bất kỳ trong giao diện Cài đặt (Settings).
   - Sử dụng Carbon Event HotKey tốc độ cao, hoạt động mượt mà khi đang làm việc trong bất kỳ app nào khác.

3. **Kéo & Điều chỉnh khung hình tương tác (Interactive Selection & Resizing):**
   - Click và rê chuột để chọn vùng chụp.
   - 8 điểm mấu (resize handles) ở 4 góc và 4 cạnh để kéo phóng to / thu nhỏ khung hình linh hoạt.
   - Có thể rê chuột vào trong khung để di chuyển toàn bộ vùng chọn.
   - Kính lúp (Magnifier Loupe) phóng đại 4x pixel và tâm chữ thập giúp căn chỉnh chuẩn từng pixel.
   - Hiển thị kích thước vùng chọn theo thời gian thực (vd: `1280 × 720`).

4. **Bộ công cụ chỉnh sửa ảnh phong phú (Annotation Tools):**
   - 🟥 **Hình chữ nhật** (Rectangle)
   - ⭕ **Hình tròn / Elip** (Circle)
   - ➔ **Mũi tên chỉ dẫn** (Arrow)
   - 📏 **Đường thẳng** (Straight Line)
   - ✏️ **Bút vẽ tự do** (Freehand Pen)
   - 🔤 **Chèn văn bản** (Text Box)
   - 🪟 **Làm mờ / Mosaic** (Che mật khẩu, thông tin cá nhân)
   - 🔢 **Đánh số thứ tự các bước** (Step Badges: 1, 2, 3...)
   - Bảng 8 màu sắc hiện đại & 3 mức độ dày nét vẽ.
   - Hỗ trợ **Undo (⌘Z)** và **Redo (⇧⌘Z)** đầy đủ.

5. **Cài đặt đường dẫn lưu ảnh linh hoạt (Storage & Settings):**
   - Tùy chỉnh thư mục lưu ảnh tùy ý thông qua nút "Chọn thư mục...".
   - Mặc định lưu tại `~/Pictures/ChillScreen`.
   - Chọn định dạng xuất file: **PNG** (sắc nét) hoặc **JPG** (tối ưu dung lượng).
   - Bật/tắt tự động lưu ảnh khi bấm Copy (`Enter`).
   - Âm thanh màn trập chân thực (Camera shutter sound).

---

## 🚀 Cách cài đặt & Sử dụng

### 1. Khởi chạy ứng dụng
Chỉ cần chạy lệnh sau trong thư mục dự án:
```bash
make run
```
Hoặc mở trực tiếp file ứng dụng:
```bash
open build/ChillScreen.app
```

### 2. Cài đặt vào thư mục `/Applications` (Nếu muốn dùng lâu dài)
```bash
make install
```
Sau đó bạn có thể mở `ChillScreen` từ Spotlight hoặc Launchpad.

---

## ⌨️ Phím tắt khi chụp

| Phím | Hành động |
| :--- | :--- |
| **`⌘ + ⇧ + A`** | Kích hoạt chụp vùng màn hình từ bất kỳ đâu |
| **`Enter`** hoặc **`⌘ + C`** | Hoàn thành & Sao chép ảnh vào Clipboard |
| **`⌘ + S`** | Lưu trực tiếp vào thư mục ảnh đã cấu hình |
| **`⌘ + Z`** | Hoàn tác (Undo) nét vẽ / chú thích trước |
| **`⇧ + ⌘ + Z`** | Làm lại (Redo) nét vẽ vừa hoàn tác |
| **`Esc`** | Huỷ phiên chụp ảnh |

---

## 🛡️ Cấp quyền Chụp màn hình (Screen Recording)

Khi chạy lần đầu trên macOS (macOS 12/13/14/15+):
1. Hệ thống có thể thông báo yêu cầu cấp quyền **Screen Recording**.
2. Mở **Cài đặt hệ thống (System Settings)** > **Quyền riêng tư & Bảo mật (Privacy & Security)** > **Ghi màn hình & Âm thanh hệ thống (Screen Recording)**.
3. Bật công tắc cho **ChillScreen**.
4. Bạn cũng có thể mở nhanh màn hình cài đặt này bằng cách nhấn vào menu của ChillScreen trên thanh Menu bar > **Cài đặt...** > **Cài đặt hệ thống...**.
