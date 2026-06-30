#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"

// =================================================================
// 1. 하드웨어 주소 정의 (xparameters.h에서 정의된 이름으로 자동 매핑)
// =================================================================
// ※ 만약 컴파일 에러가 나면 xparameters.h를 열어 실제 IP 이름을 확인해 보세요.
#define NPU_BASE_ADDR   XPAR_HANDCIPHER_EMNIST_NPU_0_BASEADDR
#define TFT_BASE_ADDR   XPAR_HANDCIPHER_TFT_LCD_0_BASEADDR
#define VGA_BASE_ADDR   XPAR_HANDCIPHER_VGA_0_BASEADDR

// 만약 BRAM이 MicroBlaze의 AXI 주소 버스에도 연결되어 있다면 다이렉트 테스트 가능
#ifdef XPAR_BRAM_0_BASEADDR
#define BRAM_BASE_ADDR  XPAR_BRAM_0_BASEADDR
#endif

int main() {
    int choice;
    u32 read_data;

    // Xil_ICacheEnable();
    // Xil_DCacheEnable();

    print("\r\n==================================================\n\r");
    print("      HandCipher 3총사 IP 하드웨어 연결 검증 통합 툴\n\r");
    print("==================================================\n\r");

    while(1) {
        print("\n\r--- 테스트 메뉴를 선택하세요 ---\n\r");
        print("1. EMNIST NPU IP 통신 상태 확인\n\r");
        print("2. TFT LCD IP 통신 상태 확인\n\r");
        print("3. VGA IP 통신 상태 확인\n\r");
#ifdef BRAM_BASE_ADDR
        print("4. 공유 BRAM 다이렉트 읽기/쓰기 테스트\n\r");
#endif
        print("선택 (1~4): ");

        // 간단한 시리얼 입력 예시 (Vitis Terminal 연동)
        choice = inbyte() - '0';
        xil_printf("%d\n\r", choice);

        switch(choice) {
            case 1:
                print("[NPU 테스트] NPU 제어 레지스터 0번지에 0xAAAA_BBBB 쓰기 시도...\n\r");
                Xil_Out32(NPU_BASE_ADDR + 0, 0xAAAABBBB);
                read_data = Xil_In32(NPU_BASE_ADDR + 0);
                xil_printf("-> 읽어온 값: 0x%08X ", read_data);
                if(read_data == 0xAAAABBBB) print("[성공: NPU 연결 정상]\n\r");
                else print("[실패: 배선이나 레지스터 주소 확인 필요]\n\r");
                break;

            case 2:
                print("[TFT 테스트] TFT 제어 레지스터 0번지에 0x5555_6666 쓰기 시도...\n\r");
                Xil_Out32(TFT_BASE_ADDR + 0, 0x55556666);
                read_data = Xil_In32(TFT_BASE_ADDR + 0);
                xil_printf("-> 읽어온 값: 0x%08X ", read_data);
                if(read_data == 0x55556666) print("[성공: TFT LCD 연결 정상]\n\r");
                else print("[실패: 배선이나 레지스터 주소 확인 필요]\n\r");
                break;

            case 3:
                print("[VGA 테스트] VGA 제어 레지스터 0번지에 0x1234_5678 쓰기 시도...\n\r");
                Xil_Out32(VGA_BASE_ADDR + 0, 0x12345678);
                read_data = Xil_In32(VGA_BASE_ADDR + 0);
                xil_printf("-> 읽어온 값: 0x%08X ", read_data);
                if(read_data == 0x12345678) print("[성공: VGA 연결 정상]\n\r");
                else print("[실패: 배선이나 레지스터 주소 확인 필요]\n\r");
                break;

#ifdef BRAM_BASE_ADDR
            case 4:
                print("[BRAM 테스트] CPU가 버스를 통해 BRAM 0번지에 가상 픽셀 데이터 쓰기...\n\r");
                Xil_Out32(BRAM_BASE_ADDR + 0, 0x1); // 1비트 쓰기
                read_data = Xil_In32(BRAM_BASE_ADDR + 0);
                xil_printf("-> 읽어온 픽셀 데이터: %d ", read_data);
                if((read_data & 0x1) == 0x1) print("[성공: BRAM 읽기/쓰기 완료]\n\r");
                else print("[실패: BRAM 인터커넥트 연결 확인 필요]\n\r");
                break;
#endif

            default:
                print("잘못된 번호입니다. 다시 선택하세요.\n\r");
                break;
        }
    }

    // Xil_DCacheDisable();
    // Xil_ICacheDisable();
    return 0;
}