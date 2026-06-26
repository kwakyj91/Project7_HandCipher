# HandCipher — FPGA Handwritten Letter Recognition & Caesar Cipher System (v6)

## Context

**HandCipher** is a standalone FPGA system on Basys3 (Artix-7 35T) that lets a user draw English letters (A–Z) on an ILI9341 touchscreen, recognizes them with a custom EMNIST NPU, applies Caesar cipher encryption or decryption, and displays the results on a VGA monitor — all controlled by on-board buttons and switches.

EMNIST NPU, VGA, TFT-LCD를 각각 AXI Custom IP로 패키징해 Vivado Block Design에 연결하고, MicroBlaze에서 Vitis C 코드로 암호화 로직과 UI를 제어하는 시스템.

**역할 분리:**

- **RTL (Custom IP)**: NPU 추론, VGA 신호 생성, ILI9341/XPT2046 SPI 제어
- **C 소프트웨어 (Vitis)**: 카이사르 암호화/복호화, 화면 구성, 버튼/스위치 처리, 모드 제어

**시스템 흐름:**

```
[암호화] 글자 그리기(TFT IP) → btnC → NPU IP 추론 → C코드 Caesar 암호화 → VGA IP 출력
[복호화] SW[14]=1 → 버퍼 내 암호문 C코드 역변환 → VGA IP 출력
```

---

## 하드웨어 구성

| 하드웨어                 | 역할                               |
| ------------------------ | ---------------------------------- |
| ILI9341 (240×320, PMOD) | 글자 그리기 캔버스                 |
| XPT2046 (PMOD 공유)      | 터치 좌표 입력                     |
| VGA 모니터 (640×480)    | 텍스트/결과 출력                   |
| btnC/U/D/L/R             | OK / 모드전환 / CLEAR / 버퍼초기화 |
| SW[4:0]                  | 카이사르 시프트 값 (0~25)          |
| SW[14]                   | 0=암호화, 1=복호화                 |
| SW[15]                   | 전체 리셋                          |

---

## Block Design 구성 (Vivado)

```
┌─────────────────────────────────────────────────────┐
│                  AXI Interconnect                    │
│                                                     │
│  MicroBlaze ──┬──► NPU IP      (0x43C0_0000)       │
│  (32KB BRAM)  ├──► VGA IP      (0x43C1_0000)       │
│               ├──► TFT-LCD IP  (0x43C2_0000)       │
│               └──► AXI GPIO    (0x40000000)         │
│                    (buttons + switches)              │
└─────────────────────────────────────────────────────┘

캔버스 BRAM: TFT-LCD IP(Port A 쓰기) ↔ NPU IP(Port B 읽기) 공유
→ CPU가 784바이트 전송 불필요, "추론 시작" 명령만 전송
```

---

## BRAM 리소스 (Artix-7 35T: BRAM18 100개)

| 내용                          | BRAM18             |
| ----------------------------- | ------------------ |
| MicroBlaze 로컬 메모리 (32KB) | 16                 |
| NPU L1 weight ROM (784×64)   | 25                 |
| NPU L2 weight ROM (64×26)    | 1                  |
| 캔버스 BRAM (28×28, 공유)    | 1                  |
| VGA 문자 버퍼 (80×60)        | 3                  |
| VGA 폰트 ROM (8×8 × 128)    | 1                  |
| **합계**                | **47 / 100** |

---

## 전체 파일 구조

```
Project_7_NPU/
├── Vivado_NPU/
│   ├── NPU.xpr
│   ├── mem/
│   │   ├── weights_l1.mem
│   │   ├── weights_l2.mem
│   │   ├── biases_l1.mem
│   │   └── biases_l2.mem
│   ├── NPU.srcs/sources_1/
│   │   ├── imports/
│   │   │   └── tft_lcd_sv.sv          (spi, xpt2046 모듈 재사용)
│   │   └── new/
│   │       ├── npu_params.vh
│   │       ├── npu_ip/                (Custom IP #1)
│   │       │   ├── npu_axi.v          (AXI4-Lite 래퍼)
│   │       │   ├── npu_ctrl.v         (EMNIST FSM)
│   │       │   ├── image_buffer.v     (캔버스 BRAM Port B)
│   │       │   ├── weight_rom_l1.v
│   │       │   ├── weight_rom_l2.v
│   │       │   └── bias_rom.v
│   │       ├── vga_ip/                (Custom IP #2)
│   │       │   ├── vga_axi.v          (AXI4-Lite 래퍼)
│   │       │   ├── vga_ctrl.v         (VGA 타이밍 + 문자 렌더러)
│   │       │   └── font_rom.v
│   │       └── tft_ip/                (Custom IP #3)
│   │           ├── tft_axi.v          (AXI4-Lite 래퍼)
│   │           ├── canvas_display.v   (ILI9341 캔버스 스트리밍)
│   │           └── draw_canvas.v      (터치 → 캔버스 BRAM Port A)
│   ├── NPU.srcs/constrs_1/new/
│   │   └── basys3.xdc
│   ├── NPU.srcs/sim_1/new/
│   │   ├── tb_npu_ip.v
│   │   ├── tb_vga_ip.v
│   │   └── tb_tft_ip.v
│   └── setup_project.tcl
├── Vitis_NPU/
│   └── src/
│       ├── main.c
│       ├── caesar.c
│       ├── caesar.h
│       ├── display.c
│       └── display.h
└── training/
    ├── requirements.txt
    ├── train_emnist.py
    ├── quantize_export.py
    └── test_inference.py
```

---

## Part 1: 학습 파이프라인 (변경 없음)

### 데이터셋: EMNIST Letters (A~Z, 26클래스)

```python
from torchvision.datasets import EMNIST
# split='letters', 레이블 1~26 → 0~25 재매핑
# 이미지 전치 처리 필수 (.T)
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Lambda(lambda x: x.squeeze().T.reshape(1, 28, 28))
])
```

### 신경망: MLP 784 → 64 → 26

```python
class MLP(nn.Module):
    def __init__(self):
        self.fc1 = nn.Linear(784, 64)
        self.fc2 = nn.Linear(64, 26)
    def forward(self, x):
        return self.fc2(F.relu(self.fc1(x.view(-1, 784))))
# Adam(lr=1e-3), 20 epochs, 목표 ≥85%
```

### 양자화 계약

```
L1: hidden[n] = clamp(relu(Σ(uint8(px)×int8(w1)) + bias_l1) >> SHIFT_L1, 0, 255)
L2: score[o]  = Σ(uint8(hidden)×int8(w2)) + bias_l2   (o: 0~25)
letter = argmax(score)  → 0=A, 25=Z
```

---

## Part 2: Custom IP 설계

### IP #1: `npu_ip` — NPU 추론 엔진

**AXI 레지스터 맵:**

```
0x00: CTRL    [0]=start (1 쓰면 추론 시작)
0x04: STATUS  [0]=done, [1]=busy
0x08: RESULT  [4:0]=letter (0~25, done=1일 때 유효)
```

**`npu_axi.v` 동작:**

- AXI write CTRL[0]=1 → npu_ctrl에 start 펄스 발생
- npu_ctrl DONE 신호 → STATUS[0]=1, RESULT 레지스터 업데이트
- AXI read → STATUS, RESULT 값 반환

**`npu_ctrl.v` FSM (변경 없음):**

```
IDLE → LOAD_CANVAS → L1×64 → L2×26 → ARGMAX → DONE → IDLE
```

**캔버스 BRAM 공유:**

- `image_buffer.v`: 듀얼포트 BRAM (784-bit, 1-bit wide)
- Port A: `tft_ip`의 `draw_canvas`가 터치 픽셀 1-bit 쓰기
- Port B: `npu_ctrl`이 읽기 (1→0xFF, 0→0x00 변환 후 uint8 사용)

**`npu_axi.v` 추가 포트 (AXI4-Lite 슬레이브 외):**

```verilog
// 캔버스 BRAM Port B 연결
output [9:0]  canvas_rd_addr,
input         canvas_rd_data,    // 1-bit

// NPU 결과
output [4:0]  letter,
output        done
```

---

### IP #2: `vga_ip` — VGA 문자 모드 디스플레이

**AXI 레지스터 맵:**

```
0x00: CTRL      [0]=enable, [1]=clear (전체 스페이스로 채움)
0x04: CHAR_ADDR [12:0] 문자 버퍼 주소 (0~4799, 80×60)
0x08: CHAR_DATA [7:0]  쓸 문자 ASCII
0x0C: WR_STRB   [0]=1 쓰기 실행 (자동 클리어)
0x10: FG_COLOR  [11:0] 전경색 RGB444
0x14: BG_COLOR  [11:0] 배경색 RGB444
```

**`vga_axi.v` 동작:**

- CPU가 CHAR_ADDR, CHAR_DATA 레지스터 설정 후 WR_STRB=1 → 문자 버퍼(BRAM)에 기록
- `vga_ctrl`이 문자 버퍼 + 폰트 ROM 참조해 픽셀 생성 → VGA 출력

**`vga_ctrl.v` (640×480 @ 60Hz, 8×8 폰트, 80×60 문자):**

- 픽셀 클록: 100MHz ÷ 4 = 25MHz (클록 분주기 내장)
- `H_TOTAL=800, V_TOTAL=525` (표준 640×480 @ 60Hz 타이밍)
- 렌더링: `char_buf[row*80+col]` → `font_rom[(char-32)*8+row_in]` → `pixel_on`

---

### IP #3: `tft_ip` — ILI9341 캔버스 + XPT2046 터치

**AXI 레지스터 맵:**

```
0x00: CTRL      [0]=enable, [1]=clear_canvas
0x04: TOUCH_X   [11:0] raw ADC X (읽기 전용)
0x08: TOUCH_Y   [11:0] raw ADC Y (읽기 전용)
0x0C: STATUS    [0]=touch_valid, [1]=lcd_ready
```

**`tft_axi.v` 동작:**

- `xpt2046`가 터치 감지 → TOUCH_X/Y 레지스터 업데이트, STATUS[0]=1
- `draw_canvas`가 터치 좌표 → 캔버스 BRAM Port A 1-bit 쓰기
- `canvas_display`가 캔버스 BRAM 읽어 ILI9341로 SPI 스트리밍
- CTRL[1]=1 → `draw_canvas`가 캔버스 BRAM 전체 0으로 초기화

**캔버스 BRAM Port A (tft_ip 내부):**

- `draw_canvas` → 캔버스 BRAM Port A (1-bit write, addr = row×28+col)
- `xpt2046` 모듈: `tft_lcd_sv.sv`에서 그대로 재사용, 50MHz 공급 (100MHz ÷ 2)

---

## Part 3: Vitis C 소프트웨어

### `main.c`

```c
#include "xparameters.h"
#include "xgpio.h"
#include "caesar.h"
#include "display.h"

// IP 베이스 주소 (xparameters.h에서 자동 생성)
#define NPU_BASE   XPAR_NPU_IP_0_BASEADDR
#define VGA_BASE   XPAR_VGA_IP_0_BASEADDR
#define TFT_BASE   XPAR_TFT_IP_0_BASEADDR

// 레지스터 오프셋
#define NPU_CTRL   (NPU_BASE + 0x00)
#define NPU_STATUS (NPU_BASE + 0x04)
#define NPU_RESULT (NPU_BASE + 0x08)
#define TFT_STATUS (TFT_BASE + 0x0C)

char plain_buf[64]  = {0};
char cipher_buf[64] = {0};
int  buf_len = 0;

int main() {
    XGpio gpio;
    XGpio_Initialize(&gpio, XPAR_AXI_GPIO_0_DEVICE_ID);

    display_init(VGA_BASE);  // VGA 초기화, 초기 화면 출력

    while (1) {
        u32 sw  = XGpio_DiscreteRead(&gpio, 2);  // 스위치
        u32 btn = XGpio_DiscreteRead(&gpio, 1);  // 버튼 (디바운스)

        int shift = sw & 0x1F;          // SW[4:0]
        int mode  = (sw >> 14) & 0x1;  // SW[14]: 0=암호화, 1=복호화

        // OK 버튼: NPU 추론 → 암호화/복호화
        if (btn & BTN_C) {
            Xil_Out32(NPU_CTRL, 1);          // 추론 시작
            while (!(Xil_In32(NPU_STATUS) & 0x1)); // done 대기
            int letter = Xil_In32(NPU_RESULT) & 0x1F; // 0~25

            char plain_c  = 'A' + letter;
            char cipher_c = mode ? caesar_decode(plain_c, shift)
                                 : caesar_encode(plain_c, shift);

            if (buf_len < 64) {
                plain_buf[buf_len]  = plain_c;
                cipher_buf[buf_len] = cipher_c;
                buf_len++;
            }
            display_update(VGA_BASE, plain_buf, cipher_buf,
                           buf_len, shift, mode, plain_c, cipher_c);
            Xil_Out32(TFT_BASE + 0x00, 0x2); // 캔버스 CLEAR
        }

        // CLEAR 버튼: 캔버스만 초기화
        if (btn & BTN_L)
            Xil_Out32(TFT_BASE + 0x00, 0x2);

        // 버퍼 초기화 버튼
        if (btn & BTN_R) {
            buf_len = 0;
            display_update(VGA_BASE, plain_buf, cipher_buf,
                           0, shift, mode, '-', '-');
        }
    }
}
```

---

### `caesar.c` / `caesar.h`

```c
char caesar_encode(char c, int shift) {
    return 'A' + (c - 'A' + shift) % 26;
}

char caesar_decode(char c, int shift) {
    return 'A' + (c - 'A' + 26 - shift) % 26;
}
```

---

### `display.c` / `display.h`

VGA IP에 문자 기록하는 헬퍼 함수

```c
void vga_putchar(u32 base, int row, int col, char c, u32 fg, u32 bg);
void vga_puts(u32 base, int row, int col, const char *str, u32 fg, u32 bg);
void vga_clear(u32 base);

void display_init(u32 vga_base) {
    vga_clear(vga_base);
    vga_puts(vga_base, 0, 20, "=== CAESAR CIPHER SYSTEM ===", WHITE, DARK_BLUE);
    vga_puts(vga_base, 58, 0,
             "btnC=OK  btnL=CLR  btnR=BUF_CLR  SW[4:0]=SHIFT  SW[14]=MODE",
             GRAY, BLACK);
}

void display_update(u32 base, char *plain, char *cipher, int len,
                    int shift, int mode, char last_in, char last_out) {
    char line[82];

    // 모드 + 시프트
    sprintf(line, "MODE: %-9s  SHIFT: +%d  ",
            mode ? "DECRYPT" : "ENCRYPT", shift);
    vga_puts(base, 2, 0, line, CYAN, BLACK);

    // 마지막 입출력
    sprintf(line, "Last Input  : %c", last_in);
    vga_puts(base, 4, 0, line, WHITE, BLACK);
    sprintf(line, mode ? "Decrypted   : %c" : "Encrypted   : %c", last_out);
    vga_puts(base, 5, 0, line, YELLOW, BLACK);

    // 누적 버퍼
    plain[len]  = '\0';
    cipher[len] = '\0';
    sprintf(line, "Plaintext   : %-64s", plain);
    vga_puts(base, 7, 0, line, GREEN, BLACK);
    sprintf(line, "Ciphertext  : %-64s", cipher);
    vga_puts(base, 8, 0, line, CYAN, BLACK);
}
```

---

## Part 4: 테스트벤치

### `tb_npu_ip.v`

- AXI write CTRL=1 → 추론 시작
- STATUS done 확인, RESULT 0~25 범위 검증

### `tb_vga_ip.v`

- AXI로 문자 기록 후 VGA 픽셀 스트림 검증
- hsync/vsync 주기 확인 (640×480 @ 60Hz)

### `tb_tft_ip.v`

- XPT2046 터치 시뮬레이션 → TOUCH_X/Y 레지스터 업데이트 확인
- 캔버스 BRAM Port A 쓰기 확인

---

## 구현 순서

### Phase 1 — 학습 (PC)

1. `training/requirements.txt`
2. `train_emnist.py` → model.pth (≥85%)
3. `quantize_export.py` → .mem 4개 + npu_params.vh
4. `test_inference.py` → ≥80% 정수 시뮬레이션

### Phase 2 — Custom IP RTL

5. `npu_ip/`: npu_ctrl.v, weight_rom*.v, bias_rom.v, image_buffer.v, npu_axi.v
6. `tb_npu_ip.v` → XSim 검증
7. `vga_ip/`: font_rom.v, vga_ctrl.v, vga_axi.v
8. `tb_vga_ip.v` → XSim 검증
9. `tft_ip/`: canvas_display.v, draw_canvas.v, tft_axi.v (spi/xpt2046 재사용)
10. `tb_tft_ip.v` → XSim 검증

### Phase 3 — Vivado Block Design

11. 각 IP를 Vivado IP 카탈로그에 패키징
12. Block Design 생성: MicroBlaze + AXI Interconnect + 3 Custom IP + AXI GPIO
13. 캔버스 BRAM 듀얼포트 연결 (TFT IP ↔ NPU IP)
14. `basys3.xdc` 핀 제약 추가
15. 합성 + 구현 → BRAM18 ≤50, WNS ≥ 0
16. XSA 파일 내보내기 → Vitis로 가져오기

### Phase 4 — Vitis C 코드

17. Vitis에서 Platform + Application 프로젝트 생성
18. `caesar.c` / `caesar.h`
19. `display.c` / `display.h`
20. `main.c`
21. 빌드 + Basys3에 다운로드

### Phase 5 — 하드웨어 검증

22. 글자 그리기 → OK → VGA 암호화 결과 확인
23. SW[14]=1 복호화 모드 전환 확인
24. SW[4:0] 시프트 값 변경 실시간 반영 확인

---

## 검증 기준

| 단계         | 기준                                     |
| ------------ | ---------------------------------------- |
| 학습         | float ≥85%, 정수 시뮬레이션 ≥80%       |
| NPU IP       | AXI start → done, RESULT 0~25           |
| VGA IP       | 640×480 @ 60Hz, 문자 정상 출력          |
| TFT IP       | 터치 → 캔버스 BRAM 정상 기록            |
| Block Design | 합성 BRAM18 ≤50, WNS ≥ 0               |
| C 코드       | H→K(shift=3), K→H(decrypt) 정상        |
| 하드웨어     | 글자 그리기 → OK → VGA 결과 (3초 이내) |

---

## 버전별 변경 요약

| 항목        | v5 (순수 RTL)    | v6 (Custom IP + Vitis)  |
| ----------- | ---------------- | ----------------------- |
| 제어 로직   | Verilog FSM      | MicroBlaze C 코드       |
| 암호화 로직 | cipher_encoder.v | caesar.c (수정 용이)    |
| 화면 구성   | text_buffer.v    | display.c (printf 수준) |
| 디버깅      | XSim 시뮬레이션  | UART printf 가능        |
| IP 구조     | 단일 top.v       | 3× Custom IP + BD      |
| BRAM        | 31 / 100         | 47 / 100                |
| Vivado 작업 | RTL only         | RTL + Block Design      |
| Vitis 작업  | 없음             | C 코드 작성             |

---

## basys3.xdc (주요 핀)

```tcl
# Clock
set_property PACKAGE_PIN W5   [get_ports clk]
create_clock -period 10.000   [get_ports clk]

# Buttons
set_property PACKAGE_PIN U18  [get_ports btnC]
set_property PACKAGE_PIN T18  [get_ports btnU]
set_property PACKAGE_PIN U17  [get_ports btnD]
set_property PACKAGE_PIN W19  [get_ports btnL]
set_property PACKAGE_PIN T17  [get_ports btnR]

# Switches SW[0..4] = shift, SW[14]=mode, SW[15]=reset
set_property PACKAGE_PIN V17  [get_ports {sw[0]}]
set_property PACKAGE_PIN V16  [get_ports {sw[1]}]
set_property PACKAGE_PIN W16  [get_ports {sw[2]}]
set_property PACKAGE_PIN W17  [get_ports {sw[3]}]
set_property PACKAGE_PIN W15  [get_ports {sw[4]}]
set_property PACKAGE_PIN V15  [get_ports {sw[14]}]
set_property PACKAGE_PIN R2   [get_ports {sw[15]}]

# VGA
set_property PACKAGE_PIN G19  [get_ports {vga_r[0]}]
set_property PACKAGE_PIN H19  [get_ports {vga_r[1]}]
set_property PACKAGE_PIN J19  [get_ports {vga_r[2]}]
set_property PACKAGE_PIN N19  [get_ports {vga_r[3]}]
set_property PACKAGE_PIN J17  [get_ports {vga_g[0]}]
set_property PACKAGE_PIN H17  [get_ports {vga_g[1]}]
set_property PACKAGE_PIN G17  [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D17  [get_ports {vga_g[3]}]
set_property PACKAGE_PIN N18  [get_ports {vga_b[0]}]
set_property PACKAGE_PIN L18  [get_ports {vga_b[1]}]
set_property PACKAGE_PIN K18  [get_ports {vga_b[2]}]
set_property PACKAGE_PIN J18  [get_ports {vga_b[3]}]
set_property PACKAGE_PIN P19  [get_ports vga_hs]
set_property PACKAGE_PIN R19  [get_ports vga_vs]

# SPI LCD/Touch (PMOD JA)
set_property PACKAGE_PIN J1   [get_ports tft_sdi]
set_property PACKAGE_PIN L2   [get_ports tft_sdo]
set_property PACKAGE_PIN J2   [get_ports tft_sck]
set_property PACKAGE_PIN G2   [get_ports tft_cs]
set_property PACKAGE_PIN H1   [get_ports touch_cs_n]
set_property PACKAGE_PIN K2   [get_ports tft_dc]
set_property PACKAGE_PIN H2   [get_ports tft_reset]
set_property PACKAGE_PIN G3   [get_ports touch_pen_irq_n]

set_property IOSTANDARD LVCMOS33 [get_ports {clk sw[*] btn* vga_* tft_* touch_*}]
```

---

## tft_lcd_sv.sv 재사용 범위

| 모듈         | 사용 여부                          |
| ------------ | ---------------------------------- |
| `spi`      | ✅ canvas_display.v에서 재사용     |
| `tft_sv`   | ❌ (캔버스 전용 스트리밍으로 대체) |
| `lcd_bram` | ❌ (듀얼포트 image_buffer로 대체)  |
| `xpt2046`  | ✅ 그대로 재사용 (50MHz 분주 공급) |
