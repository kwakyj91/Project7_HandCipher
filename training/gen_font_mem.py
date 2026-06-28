"""
8x8 ASCII 폰트 비트맵을 font.mem으로 생성한다.

출력: training/exported/font_rom.mem

형식: 1024줄, 각 줄은 2자리 hex
  - ASCII 0~31  : 제어문자 → 8바이트 전부 00 (빈 칸)
  - ASCII 32~127: 렌더링된 비트맵
  - addr 계산식 : addr = char_code * 8 + row_in_char  (offset 없음)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/usr/share/fonts/truetype/ubuntu/UbuntuMono-R.ttf"
FONT_SIZE = 8
OUT_PATH  = Path(__file__).parent / "exported/font_rom.mem"


def render_char(font, code: int) -> list[int]:
    """ASCII code 한 문자를 8x8 비트맵으로 렌더링해 8바이트 리스트로 반환한다."""
    img  = Image.new("L", (8, 8), 0)
    draw = ImageDraw.Draw(img)
    draw.text((0, 0), chr(code), fill=255, font=font)
    rows = []
    for row in range(8):
        bits = 0
        for col in range(8):
            if img.getpixel((col, row)) > 127:
                bits |= (1 << (7 - col))
        rows.append(bits)
    return rows


def main():
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)

    lines = []
    for code in range(0, 128):
        if code < 32:
            rows = [0] * 8      # 제어문자는 빈 칸
        else:
            rows = render_char(font, code)
        for byte in rows:
            lines.append(f"{byte:02x}")

    assert len(lines) == 1024, f"expected 1024 lines, got {len(lines)}"

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text("\n".join(lines) + "\n")
    print(f"generated: {OUT_PATH}  ({len(lines)} lines)")


if __name__ == "__main__":
    main()
