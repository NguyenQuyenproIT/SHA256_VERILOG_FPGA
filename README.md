# SHA256 FPGA Implementation - Tài liệu Dự án

## 📋 Mục Lục
1. [Tổng Quan Dự Án](#tổng-quan-dự-án)
2. [Giới Thiệu SHA256](#giới-thiệu-sha256)
3. [Cấu Trúc Dự Án](#cấu-trúc-dự-án)
4. [Kiến Trúc Phần Cứng](#kiến-trúc-phần-cứng)
5. [Các Thành Phần Chính](#các-thành-phần-chính)
6. [Quy Trình Hoạt Động](#quy-trình-hoạt-động)
7. [Chi Tiết Triển Khai](#chi-tiết-triển-khai)
8. [Hướng Dẫn Sử Dụng](#hướng-dẫn-sử-dụng)
9. [Tham số Kỹ Thuật](#tham-số-kỹ-thuật)

---

## 🎯 Tổng Quan Dự Án

### Mô Tả
**FPGA_VERILOG_PROJECT** là một triển khai phần cứng (Hardware Implementation) của thuật toán **SHA-256** sử dụng ngôn ngữ **Verilog HDL**. Dự án này tối ưu hóa tốc độ xử lý bằng cách sử dụng các phần cứng chuyên biệt (dedicated hardware) thay vì phần mềm truyền thống.

### Mục Đích
- Tính toán giá trị hash SHA-256 nhanh chóng trên FPGA
- Xử lý khối dữ liệu 512-bit trong mỗi chu kỳ
- Cung cấp giá trị hash 256-bit đầu ra

### Ứng Dụng
- Kiến trúc bảo mật (Security Architecture)
- Xác thực dữ liệu (Data Authentication)
- Ứng dụng blockchain/cryptocurrency
- Hệ thống mã hóa (Cryptographic Systems)

---

## 🔐 Giới Thiệu SHA256

### SHA-256 Là Gì?

**SHA-256 (Secure Hash Algorithm - 256-bit)** là một hàm hash mã hóa được xuất bản bởi NIST (National Institute of Standards and Technology) như một phần của gia đình SHA-2.

#### Đặc Điểm Chính
| Thuộc Tính | Giá Trị |
|-----------|--------|
| **Tên Đầy Đủ** | SHA-256 (Secure Hash Algorithm - 256 bit) |
| **Kích Thước Hash** | 256 bit (32 byte) |
| **Kích Thước Input** | Tùy ý (không giới hạn) |
| **Kích Thước Block** | 512 bit (64 byte) |
| **Số Vòng** | 64 vòng xử lý (rounds) |
| **Tính Chất** | Một chiều (one-way), kháng va chạm (collision-resistant) |

### Nguyên Lý Hoạt Động

SHA-256 hoạt động dựa trên các nguyên lý:

#### 1. **Giá Trị Khởi Tạo (Initial Hash Values)**
Thuật toán bắt đầu với 8 giá trị hằng số 32-bit được khởi tạo:
```
H₀ = 6a09e667
H₁ = bb67ae85
H₂ = 3c6ef372
H₃ = a54ff53a
H₄ = 510e527f
H₅ = 9b05688c
H₆ = 1f83d9ab
H₇ = 5be0cd19
```

Những giá trị này là 8 số nguyên tố 32-bit đầu tiên của các căn bậc hai của 8 số nguyên tố đầu tiên.

#### 2. **Hằng Số Vòng (Round Constants - K)**
64 hằng số K[0] đến K[63], mỗi hằng số 32-bit. Chúng được tính toán từ 64 số nguyên tố đầu tiên:
```
K[0] = 428a2f98, K[1] = 71374491, K[2] = b5c0fbcf, ...
```

#### 3. **Quy Trình Xử Lý (Processing Steps)**

**Bước 1: Khai Triển Dữ Liệu (Message Expansion)**
```
Cho w[0..63]:
  - w[0..15]:  16 từ 32-bit từ khối input (message block)
  - w[16..63]: Được tính toán từ công thức:
    w[t] = σ1(w[t-2]) + w[t-7] + σ0(w[t-15]) + w[t-16]
```

**Bước 2: Nén Dữ Liệu (Compression - Main Loop)**
Thực hiện 64 vòng lặp. Trong mỗi vòng t (t = 0 đến 63):

```
T1 = h + Σ1(e) + Ch(e,f,g) + K[t] + w[t]
T2 = Σ0(a) + Maj(a,b,c)

h = g
g = f
f = e
e = d + T1
d = c
c = b
b = a
a = T1 + T2
```

Trong đó:
- **Σ0(a)**: `ROTR(a,2) ⊕ ROTR(a,13) ⊕ ROTR(a,22)`
- **Σ1(e)**: `ROTR(e,6) ⊕ ROTR(e,11) ⊕ ROTR(e,25)`
- **σ0(x)**: `ROTR(x,7) ⊕ ROTR(x,18) ⊕ SHR(x,3)`
- **σ1(x)**: `ROTR(x,17) ⊕ ROTR(x,19) ⊕ SHR(x,10)`
- **Ch(x,y,z)**: `(x ∧ y) ⊕ (¬x ∧ z)`  (Chọn lựa)
- **Maj(x,y,z)**: `(x ∧ y) ⊕ (x ∧ z) ⊕ (y ∧ z)`  (Đa số)
- **ROTR(x,n)**: Xoay phải x đi n bit
- **SHR(x,n)**: Dịch phải x đi n bit

**Bước 3: Cập Nhật Hash (Hash Value Update)**
Sau 64 vòng, cập nhật các giá trị hash ban đầu:
```
H₀ = H₀ + a
H₁ = H₁ + b
H₂ = H₂ + c
H₃ = H₃ + d
H₄ = H₄ + e
H₅ = H₅ + f
H₆ = H₆ + g
H₇ = H₇ + h
```

### Quy Trình SHA-256 Tổng Thể (Flow Diagram)

```
┌─────────────────────────────────────┐
│  Dữ Liệu Input (Message)            │
│  Độ dài: Tùy ý                      │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Padding & Khởi Tạo (Pre-processing)│
│  - Thêm bit 1 vào sau message       │
│  - Thêm bit 0 để padding            │
│  - Thêm độ dài message (64-bit)     │
│  - Chia thành các block 512-bit     │
└────────────┬────────────────────────┘
             │
             ▼
    ┌────────────────────────┐
    │  Với mỗi block 512-bit │
    └────────────┬───────────┘
                 │
                 ▼
    ┌─────────────────────────────────┐
    │  Load H values (H₀..H₇)         │
    │  Từ ROM K và ROM H              │
    └────────────┬────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────┐
    │  Message Expansion              │
    │  - Load W[0..15] từ block       │
    │  - Tính W[16..63] dùng σ0, σ1   │
    └────────────┬────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────┐
    │  Compression (64 vòng lặp)      │
    │  - t = 0 đến 63                 │
    │  - Tính T1, T2                  │
    │  - Cập nhật a,b,c,d,e,f,g,h     │
    │  - Sử dụng K[t] từ ROM K        │
    └────────────┬────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────┐
    │  Finalization                   │
    │  - H₀ = H₀ + a                  │
    │  - H₁ = H₁ + b                  │
    │  - ... (Cập nhật cả 8 giá trị)  │
    └────────────┬────────────────────┘
                 │
                 ▼
         ┌───────────────┐
         │  Hash Output  │
         │  256-bit      │
         └───────────────┘
```

---

## 📁 Cấu Trúc Dự Án

```
FPGA_VERILOG_PROJECT/
│
├── SHA256_basic/                    # Thư mục chính chứa toàn bộ dự án
│   │
│   ├── src/                         # Thư mục source code Verilog
│   │   ├── sha256_basic.v          # Module chính: sha256_core
│   │   ├── read_hash.v             # ROM modules: rom_K và rom_H
│   │   ├── hang_so_tron_K.mem      # Memory file: 64 hằng số K
│   │   └── hash_value_eight.mem    # Memory file: 8 giá trị H khởi tạo
│   │
│   └── tb/                          # Thư mục Testbench (kiểm thử)
│       ├── tb_sha256.v             # Testbench chính
│       └── test_read_ROM.v         # Testbench kiểm thử ROM
│
└── README.md                        # Tài liệu này
```

---

## 🏗️ Kiến Trúc Phần Cứng

### Sơ Đồ Kiến Trúc Tổng Quát

```
                    ┌──────────────────────────────────┐
                    │    sha256_core (Main Module)     │
                    ├──────────────────────────────────┤
                    │  Inputs:                         │
                    │  - clk: Clock signal             │
                    │  - rst: Reset signal             │
                    │  - start: Start signal           │
                    │  - block_in[511:0]: Data input   │
                    │                                  │
                    │  Outputs:                        │
                    │  - done: Hoàn thành flag         │
                    │  - hash_out[255:0]: Kết quả      │
                    └──────────────────────────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
        ┌────────────────┐ ┌───────────────┐ ┌─────────────────┐
        │  32-bit Array  │ │  State Machine│ │  ROM Instances  │
        │   W[0:63]      │ │  (FSM)        │ └─────────────────┘
        │                │ │               │        │
        │  Registers:    │ │  States:      │        ├── rom_K
        │  a,b,c,d,e,f,g │ │  IDLE         │        │   (64 từ K)
        │  h             │ │  LOAD_H_*     │        │
        │                │ │  LOAD_W0      │        └── rom_H
        │  H_reg[0:7]    │ │  EXPAND_*     │            (8 từ H)
        │                │ │  COMPRESS_*   │
        │  Temp: t_S0,   │ │  FINISH       │
        │  t_S1, t_ch,   │ └───────────────┘
        │  t_temp1,      │
        │  t_temp2,      │
        │  t_maj         │
        └────────────────┘
```

### Các Thành Phần Chính

#### 1. **sha256_core** (Module Chính)
**Chức năng**: Xử lý thuật toán SHA-256 trên dữ liệu input 512-bit

**Inputs**:
| Tín Hiệu | Chiều Rộng | Mô Tả |
|---------|-----------|------|
| `clk` | 1-bit | Xung nhịp FPGA |
| `rst` | 1-bit | Reset tích cực cao (Active High) |
| `start` | 1-bit | Tín hiệu bắt đầu xử lý |
| `block_in` | 512-bit | Khối dữ liệu input (16 từ 32-bit) |

**Outputs**:
| Tín Hiệu | Chiều Rộng | Mô Tả |
|---------|-----------|------|
| `done` | 1-bit | Flag xử lý hoàn thành |
| `hash_out` | 256-bit | Giá trị hash SHA-256 (8 từ 32-bit) |

**Các Register Nội Bộ**:
```verilog
W[0:63]              // 64 từ 32-bit - Message schedule array
a, b, c, d, e, f, g, h  // 8 register làm việc cho compression
H_reg[0:7]           // 8 register lưu giá trị hash
round                // Bộ đếm vòng (0-63)
status               // State machine (14 states)
```

#### 2. **rom_K Module**
**Chức Năng**: Lưu trữ 64 hằng số SHA-256 trong ROM

**Thông Số**:
- Data Width: 32-bit
- Memory Size: 64 từ (0-63)
- Type: Read-Only Memory (ROM)
- Format File: `hang_so_tron_K.mem`

**Giao Tiếp**:
```verilog
Input:  clk, addr[5:0]
Output: dout[31:0]
```

**Nội Dung**: 64 giá trị K từ K[0] đến K[63]
```
K[0]  = 0x428a2f98    (căn bậc ba của số nguyên tố thứ 1)
K[1]  = 0x71374491    (căn bậc ba của số nguyên tố thứ 2)
...
K[63] = 0x1f83d9ab    (căn bậc ba của số nguyên tố thứ 64)
```

#### 3. **rom_H Module**
**Chức Năng**: Lưu trữ 8 giá trị hash khởi tạo trong ROM

**Thông Số**:
- Data Width: 32-bit
- Memory Size: 8 từ (0-7)
- Type: Read-Only Memory (ROM)
- Format File: `hash_value_eight.mem`

**Giao Tiếp**:
```verilog
Input:  clk, addr[2:0]
Output: dout[31:0]
```

**Nội Dung**: 8 giá trị khởi tạo ban đầu
```
H[0] = 0x6a09e667
H[1] = 0xbb67ae85
H[2] = 0x3c6ef372
H[3] = 0xa54ff53a
H[4] = 0x510e527f
H[5] = 0x9b05688c
H[6] = 0x1f83d9ab
H[7] = 0x5be0cd19
```

#### 4. **Memory Files**

##### a) `hang_so_tron_K.mem`
- **Định Nghĩa**: Round constant K values cho SHA-256
- **Ý Nghĩa**: Được tính từ phần thập phân sau khi căn bậc 3 của 64 số nguyên tố đầu tiên
- **Giá Trị**: 64 word hex 32-bit
- **Phạm Vi**: K[0] = 428a2f98 đến K[63] = 1f83d9ab
- **Mục Đích**: Tăng tính không tuyến tính của thuật toán

##### b) `initial_hash_values.mem`
- **Định Nghĩa**: Initial hash values (H₀ đến H₇)
- **Ý Nghĩa**: Giá trị khởi tạo ban đầu cho mỗi lần xử lý
- **Giá Trị**: 8 word hex 32-bit
- **Phạm Vi**: H[0] = 6a09e667 đến H[7] = 5be0cd19
- **Mục Đích**: Điểm bắt đầu chuẩn cho tất cả SHA-256 computations

---

## ⚙️ Các Thành Phần Chính

### State Machine - Máy Trạng Thái

Module `sha256_core` sử dụng FSM (Finite State Machine) gồm 14 trạng thái:

```
        ┌─────────────────────────────────┐
        │         IDLE (0x0)              │
        │  Chờ tín hiệu start             │
        └────────────┬────────────────────┘
                     │ start=1
                     ▼
        ┌─────────────────────────────────┐
        │     LOAD_H_SET (0x1)            │
        │  Thiết lập địa chỉ ROM H[0]     │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │   LOAD_H_CAPTURE (0x2)          │
        │  Nhận giá trị H từ ROM          │
        │  (Lặp lại 8 lần)                │
        └────────────┬────────────────────┘
                     │ h_idx=7
                     ▼
        ┌─────────────────────────────────┐
        │     LOAD_H_DONE (0x3)           │
        │  Tất cả H[0..7] sẵn sàng        │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │      LOAD_W0 (0x4)              │
        │  Trích xuất W[0..15] từ block   │
        │  block_in[511..0]               │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │    EXPAND_CALC (0x5)            │
        │  Tính σ0(W[t-15]) và σ1(W[t-2]) │
        │  W[t] = W[t-16] + σ0 + ...      │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │     EXPAND_W (0x6)              │
        │  Lưu W[t] vào mảng W            │
        │  (Lặp lại từ t=16 đến t=63)     │
        └────────────┬────────────────────┘
                     │ w_idx=63
                     ▼
        ┌─────────────────────────────────┐
        │  COMPRESS_CALC_1 (0x7)          │
        │  Tính Σ0, Σ1, Ch, Maj           │
        │  Bắt đầu vòng lặp compression   │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │  COMPRESS_CALC_2_WAIT (0x8)     │
        │  Chờ K[t] từ ROM sẵn sàng       │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │  COMPRESS_CALC_2 (0x9)          │
        │  Tính T1, T2                    │
        │  T1 = h + Σ1 + Ch + K[t] + W[t] │
        │  T2 = Σ0 + Maj                  │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │   COMPRESS_UPDATE (0xA)         │
        │  Cập nhật a,b,c,d,e,f,g,h       │
        │  h=g, g=f, f=e, e=d+T1, ...     │
        │  (Lặp lại 64 vòng)              │
        └────────────┬────────────────────┘
                     │ round=63
                     ▼
        ┌─────────────────────────────────┐
        │      FINISH (0xB)               │
        │  Finalization:                  │
        │  H₀=H₀+a, H₁=H₁+b, ...          │
        │  Xuất hash_out                  │
        │  done=1                         │
        └────────────┬────────────────────┘
                     │
                     ▼ (Trở về IDLE)
```

### Chi Tiết Từng Trạng Thái

| Trạng Thái | Giá Trị | Mô Tả | Thời Gian |
|-----------|--------|-------|----------|
| **IDLE** | 0x0 | Trạng thái khởi tạo, chờ start | ∞ |
| **LOAD_H_SET** | 0x1 | Thiết lập addr ROM, chờ dữ liệu | 1 CLK |
| **LOAD_H_CAPTURE** | 0x2 | Capture H_value, lặp 8 lần | 8 CLK |
| **LOAD_H_DONE** | 0x3 | Xác nhận tất cả H sẵn sàng | 1 CLK |
| **LOAD_W0** | 0x4 | Tách W[0..15] từ input 512-bit | 1 CLK |
| **EXPAND_CALC** | 0x5 | Tính σ0, σ1 cho mở rộng | 1 CLK |
| **EXPAND_W** | 0x6 | Lưu W[16..63], lặp 48 lần | 48 CLK |
| **COMPRESS_CALC_1** | 0x7 | Tính Σ0, Σ1, Ch, Maj | 1 CLK |
| **COMPRESS_CALC_2_WAIT** | 0x8 | Chờ K[t] sẵn sàng | 1 CLK |
| **COMPRESS_CALC_2** | 0x9 | Tính T1, T2 | 1 CLK |
| **COMPRESS_UPDATE** | 0xA | Cập nhật a-h, lặp 64 lần | 64 CLK |
| **FINISH** | 0xB | Cập nhật H_reg + output | 1 CLK |

**Tổng thời gian xử lý**: ~131 chu kỳ xung nhịp (clock cycles)

---

## 🔄 Quy Trình Hoạt Động

### Luồng Dữ Liệu Chi Tiết

```
┌───────────────────────────────────────────────────────────────┐
│  BƯỚC 1: KHỞI TẠO & TẢI GIÁ TRỊ H                             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Khi start=1:                                                 │
│  1. FSM: IDLE → LOAD_H_SET                                    │
│  2. Thiết lập H_addr = 0 (yêu cầu H[0] từ ROM)                │
│  3. Chờ 1 CLK để dữ liệu sẵn sàng                             │
│  4. FSM: LOAD_H_SET → LOAD_H_CAPTURE                          │
│  5. Capture H_value vào H_reg[0]                              │
│  6. Nếu h_idx < 7:                                            │
│     - H_addr = h_idx + 1 (yêu cầu H tiếp theo)                │
│     - FSM → LOAD_H_SET (quay lại bước 2)                      │
│  7. Khi h_idx = 7: FSM → LOAD_H_DONE                          │
│                                                               │
│  Kết quả: H_reg[0..7] = [0x6a09e667, 0xbb67ae85, ...]         │
│  Thời gian: 8 × 2 CLK = 16 CLK                                │
│                                                               │
└───────────────────────────────────────────────────────────────┘
            ▼
┌───────────────────────────────────────────────────────────────┐
│  BƯỚC 2: TẢI KHỐI DỮ LIỆU INPUT                               │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  1. FSM: LOAD_H_DONE → LOAD_W0                                │
│  2. Trích xuất W[0..15] từ block_in[511:0]:                   │
│     for i=0 to 15:                                            │
│       W[i] <= block_in[511 - i*32 : (511-i*32)-31]            │
│                                                               │
│  Ví dụ: block_in = 512'b...                                   │
│     W[0] = block_in[511:480]   (bits cao nhất)                │
│     W[1] = block_in[479:448]                                  │
│     ...                                                       │
│     W[15] = block_in[31:0]     (bits thấp nhất)               │
│                                                               │
│  3. Đặt w_idx = 16 (chuẩn bị mở rộng)                         │
│  4. FSM → EXPAND_CALC                                         │
│                                                               │
│  Thời gian: 1 CLK                                             │
│                                                               │
└───────────────────────────────────────────────────────────────┘
            ▼
┌───────────────────────────────────────────────────────────────┐
│  BƯỚC 3: MỞ RỘNG MESSAGE (MESSAGE EXPANSION)                  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Tính W[16..63] dùng công thức:                               │
│  W[t] = σ1(W[t-2]) + W[t-7] + σ0(W[t-15]) + W[t-16]           │
│                                                               │
│  Trong đó:                                                    │
│  σ0(x) = ROTR(x,7) ⊕ ROTR(x,18) ⊕ SHR(x,3)                  │
│  σ1(x) = ROTR(x,17) ⊕ ROTR(x,19) ⊕ SHR(x,10)                │
│                                                               │
│  Quy trình (Lặp từ w_idx=16 đến 63):                          │
│  1. FSM: EXPAND_CALC                                          │
│     - Tính t_S0 = σ0(W[w_idx-15])                             │
│     - Tính t_S1 = σ1(W[w_idx-2])                              │
│  2. FSM: EXPAND_W                                             │
│     - W[w_idx] = W[w_idx-16] + t_S0 + W[w_idx-7] + t_S1       │
│     - w_idx += 1                                              │
│  3. Nếu w_idx < 64: Quay lại EXPAND_CALC                      │
│  4. Nếu w_idx = 64: FSM → COMPRESS_CALC_1                     │
│                                                               │
│  Thời gian: 48 × 2 CLK = 96 CLK                               │
│                                                               │
│  Kết quả: W[0..63] được tính toàn bộ                          │
│                                                               │
└───────────────────────────────────────────────────────────────┘
            ▼
┌───────────────────────────────────────────────────────────────┐
│  BƯỚC 4: NÉN DỮ LIỆU (COMPRESSION - 64 VÒNG)                  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Khởi tạo a-h từ H_reg:                                       │
│  a = H_reg[0], b = H_reg[1], ..., h = H_reg[7]                │
│  round = 0, K_addr = 0                                        │
│                                                               │
│  Lặp từ round=0 đến 63 (64 vòng):                             │
│                                                               │
│  ┌─ COMPRESS_CALC_1                                           │
│  │  Tính các hàm trung gian:                                  │
│  │  Σ1(e) = ROTR(e,6) ⊕ ROTR(e,11) ⊕ ROTR(e,25)             │
│  │  Ch(e,f,g) = (e ∧ f) ⊕ (¬e ∧ g)                           │
│  │  Σ0(a) = ROTR(a,2) ⊕ ROTR(a,13) ⊕ ROTR(a,22)             │
│  │  Maj(a,b,c) = (a ∧ b) ⊕ (a ∧ c) ⊕ (b ∧ c)                │
│  │                                                            │
│  ├─ COMPRESS_CALC_2_WAIT                                      │
│  │  Chờ K[round] sẵn sàng từ ROM                              │
│  │                                                            │
│  ├─ COMPRESS_CALC_2                                           │
│  │  Tính T1 và T2:                                            │
│  │  T1 = h + Σ1(e) + Ch(e,f,g) + K[round] + W[round]          │
│  │  T2 = Σ0(a) + Maj(a,b,c)                                   │
│  │                                                            │
│  └─ COMPRESS_UPDATE                                           │
│     Cập nhật a-h (chuyển dịch vòng):                          │
│     h ← g                                                     │
│     g ← f                                                     │
│     f ← e                                                     │
│     e ← d + T1                                                │
│     d ← c                                                     │
│     c ← b                                                     │
│     b ← a                                                     │
│     a ← T1 + T2                                               │
│                                                               │
│     Nếu round < 63:                                           │
│       K_addr = round + 1                                      │
│       round += 1                                              │
│       → COMPRESS_CALC_1                                       │
│                                                               │
│  Thời gian: 64 × 4 CLK = 256 CLK                              │
│  (Tính từ COMPRESS_CALC_1 đến kết thúc COMPRESS_UPDATE)       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
            ▼
┌───────────────────────────────────────────────────────────────┐
│  BƯỚC 5: HOÀN THIỆN (FINALIZATION)                            │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  1. FSM: COMPRESS_UPDATE → FINISH                             │
│  2. Cập nhật H_reg (add-and-compress):                        │
│     H_reg[0] ← H_reg[0] + a                                   │
│     H_reg[1] ← H_reg[1] + b                                   │
│     H_reg[2] ← H_reg[2] + c                                   │
│     H_reg[3] ← H_reg[3] + d                                   │
│     H_reg[4] ← H_reg[4] + e                                   │
│     H_reg[5] ← H_reg[5] + f                                   │
│     H_reg[6] ← H_reg[6] + g                                   │
│     H_reg[7] ← H_reg[7] + h                                   │
│                                                               │
│  3. Ghép H_reg[0..7] thành hash_out[255:0]:                   │
│     hash_out = {H_reg[0], H_reg[1], ..., H_reg[7]}            │
│                                                               │
│  4. Đặt done = 1 (tín hiệu hoàn thành)                        │
│  5. FSM → IDLE (sẵn sàng cho lần xử lý tiếp theo)             │
│                                                               │
│  Thời gian: 1 CLK                                             │
│                                                               │
└───────────────────────────────────────────────────────────────┘

TỔNG THỜI GIAN: ~130 chu kỳ xung nhịp (clock cycles)
```

---

## 💻 Chi Tiết Triển Khai

### Phép Toán Bit (Bitwise Operations)

#### 1. **Xoay Phải (ROTR - Right Rotate)**
```verilog
// ROTR(x, n) = xoay phải x đi n bit vòng tròn
ROTR(x, 2) = {x[1:0], x[31:2]}
ROTR(x, 7) = {x[6:0], x[31:7]}
ROTR(x, 11) = {x[10:0], x[31:11]}
...

// Ví dụ:
x = 32'b10110101_11001011_10101010_01010101
ROTR(x, 7) = 32'b10101010_10110101_11001011_10101
```

#### 2. **Dịch Phải (SHR - Logical Right Shift)**
```verilog
// SHR(x, n) = dịch phải x đi n bit, lấp đầu 0
SHR(x, 3) = {3'b0, x[31:3]}
SHR(x, 10) = {10'b0, x[31:10]}

// Ví dụ:
x = 32'b10110101_11001011_10101010_01010101
SHR(x, 3) = 32'b00010110_10111001_01110101_01010
```

#### 3. **Hàm Ch (Choose)**
```verilog
// Ch(x, y, z) = (x AND y) OR (NOT x AND z)
// Nếu x[i]=1, chọn y[i]; nếu x[i]=0, chọn z[i]
t_ch <= (e & f) ^ ((~e) & g)

// Ví dụ:
e = 32'b1010...
f = 32'b1111...
g = 32'b0000...
Ch(e,f,g) = 32'b1010... (bit từ f nơi e=1, từ g nơi e=0)
```

#### 4. **Hàm Maj (Majority)**
```verilog
// Maj(x, y, z) = (x AND y) OR (x AND z) OR (y AND z)
// Bit kết quả là giá trị xuất hiện nhiều nhất trong 3 bit đầu vào
t_maj <= (a & b) ^ (a & c) ^ (b & c)

// Ví dụ:
a = 32'b1_0_1_...
b = 32'b1_0_0_...
c = 32'b1_0_0_...
Maj(a,b,c) = 32'b1_0_0_... (majority vote)
```

### Cấu Trúc Dữ Liệu

#### 1. **Array W[0:63]**
```verilog
reg [31:0] W [0:63];

// W[0..15]:   Từ khối input (16 từ 32-bit)
// W[16..63]:  Được tính toán bằng σ0 và σ1
```

#### 2. **Working Registers (a,b,c,d,e,f,g,h)**
```verilog
reg [31:0] a, b, c, d, e, f, g, h;

// Mỗi register chứa 1 từ 32-bit làm việc
// Được cập nhật mỗi vòng lặp compression
```

#### 3. **H_reg[0:7]**
```verilog
reg [31:0] H_reg [0:7];

// Lưu 8 giá trị hash
// H_reg[0] ← H₀, H_reg[1] ← H₁, ..., H_reg[7] ← H₇
// Được cập nhật sau mỗi khối input
```

### Tối Ưu Hóa Phần Cứng

#### 1. **Pipeline không đầy**
```
FSM sử dụng kiến trúc một pha đơn giản để:
- Tính σ0, σ1 (EXPAND_CALC) → 1 CLK
- Tính T1, T2 (COMPRESS_CALC_1, _CALC_2) → 3 CLK
- Cập nhật a-h (COMPRESS_UPDATE) → 1 CLK
```

#### 2. **ROM Distributed**
- rom_K (64 từ) và rom_H (8 từ) được triển khai trong LUT FPGA
- Độ trễ: 1 CLK (registered output)

#### 3. **Tổng Khóa (Registered Logic)**
- Tất cả công thức được ghi vào register
- Giảm timing critical path
- Tăng Maximum Frequency

---

## 📖 Hướng Dẫn Sử Dụng

### 1. Cấu Trúc Thư Mục

```
FPGA_VERILOG_PROJECT/
├── SHA256_basic/src/
│   ├── sha256_basic.v          ← Module chính + ROM instances
│   ├── read_hash.v             ← Định nghĩa ROM modules
│   ├── hang_so_tron_K.mem      ← K constants
│   └── hash_value_eight.mem    ← H initial values
└── SHA256_basic/tb/
    ├── tb_sha256.v             ← Testbench chính
    └── test_read_ROM.v         ← ROM testbench
```

### 2. Cách Sử Dụng Testbench

#### **tb_sha256.v** - Testbench Chính

**Input dữ liệu**: 
```verilog
block_in = 512'b01110001_01110101_01111001_01100101_...
// "quyen" trong ASCII + padding

// "quyen" = 0x71 0x75 0x79 0x65 0x6E
// q = 0x71, u = 0x75, y = 0x79, e = 0x65, n = 0x6E
```

**Kích hoạt**:
```verilog
initial begin
    clk = 0; 
    rst = 1;      // Reset hệ thống
    start = 0;
    #20 
    rst = 0;      // Kết thúc reset
    #20 
    start = 1;    // Kích hoạt SHA256
    #10 
    start = 0;    // Kết thúc tín hiệu start
    #50;          // Chờ kết quả
end
```

**Quan sát kết quả**:
- Chờ tín hiệu `done = 1`
- Đọc `hash_out[255:0]` = Giá trị hash SHA-256

#### **test_read_ROM.v** - Testbench ROM

**Mục đích**: Kiểm tra dữ liệu trong ROM K và ROM H

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        addr_K <= 0;
        addr_H <= 0;
    end
    else begin
        addr_K <= addr_K + 1'b1;        // Đọc tuần tự K[0..63]
        if(addr_H < MEM_SIZE_H - 1) 
            addr_H <= addr_H + 1'b1;    // Đọc tuần tự H[0..7]
        else
            addr_H <= 0;                // Wrap around
    end
end
```

### 3. Cách Chạy Simulation

#### Với Vivado/ISE:
1. Tạo project mới
2. Thêm files: `sha256_basic.v`, `read_hash.v`
3. Thêm testbench: `tb_sha256.v`
4. Đặt behavioral simulation
5. Chạy simulation: **Run → Run Behavioral Simulation**

#### Với ModelSim:
```bash
# Compile
vlog src/read_hash.v src/sha256_basic.v tb/tb_sha256.v

# Simulate
vsim work.tb_sha256

# Run
run 500ns
```

#### Với Icarus Verilog (Open Source):
```bash
# Compile
iverilog -o sha256_sim tb/tb_sha256.v src/sha256_basic.v src/read_hash.v

# Simulate
vvp sha256_sim

# Dump VCD
./sha256_sim dump.vcd
gtkwave dump.vcd
```

### 4. Kết Quả Mong Đợi

**Input**: 
```
"quyen" = 01110001 01110101 01111001 01100101 01101110
(5 byte, dùng SHA-256 1-block message với padding)
```

**Output hash (256-bit)**:
```
Dạng hex: [H0][H1][H2][H3][H4][H5][H6][H7]
Mỗi H = 8 chữ số hex (32-bit)
```

---

## 📊 Tham Số Kỹ Thuật

### Thông Số Thuật Toán

| Tham Số | Giá Trị | Ghi Chú |
|---------|--------|--------|
| **Input Data Width** | 512 bit | 16 từ 32-bit |
| **Output Hash Width** | 256 bit | 8 từ 32-bit |
| **Number of Rounds** | 64 | Compression rounds |
| **Round Constants** | 64 × 32-bit | ROM K |
| **Initial Values** | 8 × 32-bit | ROM H |
| **Word Length** | 32-bit | Chuẩn SHA-256 |

### Thông Số Phần Cứng

| Tham Số | Giá Trị | Ghi Chú |
|---------|--------|--------|
| **Clock Frequency** | Configurable | Phụ thuộc FPGA |
| **Latency** | ~130 CLK | Từ start đến done |
| **Throughput** | 512 bit/130 CLK | ~3.9 Gbit/s @ 100MHz |
| **LUT Usage** | ~500 LUT | Ước tính |
| **Registers** | ~800 FF | Ước tính |
| **ROM Size** | 72 × 32-bit | K(64) + H(8) |
| **Power** | Low | Tùy FPGA |

### Độ Trễ Chi Tiết

| Phần | Thời Gian (CLK) |
|-----|-----------------|
| Load H (Initial) | 16 CLK |
| Load W[0..15] | 1 CLK |
| Expand W[16..63] | 96 CLK |
| Compression (64 rounds) | 256 CLK |
| Finalization | 1 CLK |
| **TỔNG** | **~370 CLK** |

*Lưu ý: Thời gian thực tế có thể khác tùy triển khai*

### ROM Content Summary

**ROM K** (64 hằng số):
```
K[0] = 0x428a2f98, K[1] = 0x71374491, ..., K[63] = 0x1f83d9ab
```

**ROM H** (8 giá trị khởi tạo):
```
H[0] = 0x6a09e667, H[1] = 0xbb67ae85, H[2] = 0x3c6ef372, H[3] = 0xa54ff53a
H[4] = 0x510e527f, H[5] = 0x9b05688c, H[6] = 0x1f83d9ab, H[7] = 0x5be0cd19
```

---

## 🔗 Tham Chiếu & Tài Liệu

### Chuẩn SHA-256
- **FIPS 180-4**: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf
- **RFC 3174**: SHA-1, SHA-2, and SHA-3

### Tài Liệu FPGA
- Vivado Design Suite User Guide
- ModelSim Reference Manual
- Verilog HDL Language Reference

### Ký Ức Tính Toán
- Bit rotation operations
- Logical functions (AND, OR, XOR)
- Modular addition (32-bit)

---

## 📝 Ghi Chú Quan Trọng

1. **Memory File Path**: Đảm bảo `hang_so_tron_K.mem` và `hash_value_eight.mem` ở đúng thư mục khi simulate
2. **Timing**: Total latency khoảng 130-370 CLK tùy triển khai
3. **Input Format**: block_in[511:0] được sắp xếp theo big-endian
4. **Output Format**: hash_out[255:0] = [H_reg[0]][H_reg[1]]...[H_reg[7]]
5. **Reset**: Active High (rst = 1 để reset)

