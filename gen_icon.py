#!/usr/bin/env python3
"""
生成 ClipboardManager 应用图标 (.icns)
设计：蓝紫渐变圆角底 + 白色剪切板 + 层叠历史效果
"""

import os
import subprocess
from PIL import Image, ImageDraw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ICONSET_DIR = os.path.join(SCRIPT_DIR, "Resources", "AppIcon.iconset")

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def gradient_squircle(draw, size, margin=0):
    """绘制 macOS 风格的蓝紫渐变圆角矩形"""
    radius = int(size * 0.225)  # ~22.5% 模拟 squircle
    r = size - 1 - margin

    # 从上到下渐变：靛蓝 → 紫
    steps = size
    for i in range(steps):
        t = i / (steps - 1)
        r_val = int(70 + t * 20)
        g_val = int(80 + t * 15)
        b_val = int(220 - t * 40)
        color = (r_val, g_val, b_val)

        y0 = i
        y1 = i + 1
        # 计算该行在圆角矩形内的左右边界
        left_cut = 0
        right_cut = 0

        # 上方圆角区域
        if y0 < radius:
            dy = radius - y0
            cut = radius - (radius**2 - dy**2)**0.5 if dy < radius else radius
            left_cut = max(left_cut, cut)
            right_cut = max(right_cut, cut)
        # 下方圆角区域
        if y1 > r - radius:
            dy = y1 - (r - radius)
            cut = radius - (radius**2 - dy**2)**0.5 if dy < radius else radius
            left_cut = max(left_cut, cut)
            right_cut = max(right_cut, cut)

        x0 = int(margin + left_cut)
        x1 = int(size - margin - right_cut)
        if x1 > x0:
            draw.rectangle([x0, y0, x1, y1], fill=color)

    # 顶部高光
    highlight = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle(
        [margin + 4, margin + 2, size - margin - 4, size // 2],
        radius=int(size * 0.2),
        fill=(255, 255, 255, 25)
    )
    return highlight


def draw_icon(size: int) -> Image.Image:
    """绘制指定尺寸的图标，返回 RGBA Image"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = int(size * 0.04)
    s = size - 2 * margin  # 可用区域

    # ── 1. 渐变圆角底 ──
    bg = gradient_squircle(draw, size, margin)
    img = Image.alpha_composite(img, bg)
    draw = ImageDraw.Draw(img)

    # ── 2. 白色剪切板 ──
    cx = size / 2
    cy = size / 2

    board_w = s * 0.56
    board_h = s * 0.72
    board_r = s * 0.07

    bx1 = cx - board_w / 2
    by1 = cy - board_h / 2 + s * 0.02
    bx2 = cx + board_w / 2
    by2 = cy + board_h / 2 + s * 0.02

    # 后面层叠的板子（历史效果）
    offset = s * 0.04
    stack_color = (220, 225, 240, 180)
    draw.rounded_rectangle(
        [bx1 + offset, by1 + offset, bx2 + offset, by2 - board_r],  # bottom offset differently
        radius=board_r,
        fill=stack_color
    )

    # 第二层（更深）
    draw.rounded_rectangle(
        [bx1 + offset * 2, by1 + offset * 2, bx2 + offset * 2, by2 - board_r * 1.5],
        radius=board_r,
        fill=(200, 205, 225, 120)
    )

    # 主体白色板子
    draw.rounded_rectangle(
        [bx1, by1, bx2, by2],
        radius=board_r,
        fill=(255, 255, 255, 255)
    )

    # 板子底部阴影线
    draw.rounded_rectangle(
        [bx1 + 2, by2 - board_r, bx2 - 2, by2],
        radius=board_r // 2,
        fill=(235, 237, 245, 255)
    )

    # ── 3. 文字行 ──
    line_color = (180, 185, 200)
    line_w = board_w * 0.75
    line_h = s * 0.025
    line_x = cx - line_w / 2
    line_y_start = by1 + board_h * 0.2
    line_gap = board_h * 0.17

    # 第 1 行（较短）
    draw.rounded_rectangle(
        [line_x, line_y_start, line_x + line_w * 0.6, line_y_start + line_h],
        radius=line_h // 2,
        fill=line_color
    )
    # 第 2 行（较长，渐变淡）
    draw.rounded_rectangle(
        [line_x, line_y_start + line_gap,
         line_x + line_w, line_y_start + line_gap + line_h],
        radius=line_h // 2,
        fill=(190, 195, 210)
    )
    # 第 3 行（中）
    draw.rounded_rectangle(
        [line_x, line_y_start + line_gap * 2,
         line_x + line_w * 0.8, line_y_start + line_gap * 2 + line_h],
        radius=line_h // 2,
        fill=(195, 200, 215)
    )

    # ── 4. 顶部夹子 ──
    clip_r = s * 0.09
    clip_cx = cx
    clip_cy = by1 + clip_r * 0.3

    # 外圈（深灰）
    draw.ellipse(
        [clip_cx - clip_r, clip_cy - clip_r,
         clip_cx + clip_r, clip_cy + clip_r],
        fill=(80, 85, 95)
    )
    # 内圈（亮色）
    inner_r = clip_r * 0.6
    draw.ellipse(
        [clip_cx - inner_r, clip_cy - inner_r,
         clip_cx + inner_r, clip_cy + inner_r],
        fill=(140, 145, 155)
    )
    # 高光点
    highlight_r = inner_r * 0.35
    draw.ellipse(
        [clip_cx - highlight_r, clip_cy - inner_r * 0.7 - highlight_r,
         clip_cx + highlight_r, clip_cy - inner_r * 0.7 + highlight_r],
        fill=(200, 205, 215)
    )

    # ── 5. 右下角时钟徽章 ──
    badge_r = s * 0.1
    badge_cx = bx2 - badge_r * 0.4
    badge_cy = by2 - badge_r * 0.3

    # 徽章底色（白）
    draw.ellipse(
        [badge_cx - badge_r, badge_cy - badge_r,
         badge_cx + badge_r, badge_cy + badge_r],
        fill=(255, 255, 255, 240)
    )
    # 时钟边框
    draw.ellipse(
        [badge_cx - badge_r, badge_cy - badge_r,
         badge_cx + badge_r, badge_cy + badge_r],
        outline=(100, 110, 170),
        width=max(1, int(size * 0.01))
    )
    # 时针
    import math
    hour_len = badge_r * 0.4
    hour_angle = math.radians(-60)
    hx = badge_cx + hour_len * math.cos(hour_angle)
    hy = badge_cy + hour_len * math.sin(hour_angle)
    draw.line([badge_cx, badge_cy, hx, hy],
              fill=(100, 110, 170),
              width=max(1, int(size * 0.02)))

    # 分针
    min_len = badge_r * 0.55
    min_angle = math.radians(10)
    mx = badge_cx + min_len * math.cos(min_angle)
    my = badge_cy + min_len * math.sin(min_angle)
    draw.line([badge_cx, badge_cy, mx, my],
              fill=(100, 110, 170),
              width=max(1, int(size * 0.015)))

    # 中心点
    dot_r = badge_r * 0.15
    draw.ellipse(
        [badge_cx - dot_r, badge_cy - dot_r,
         badge_cx + dot_r, badge_cy + dot_r],
        fill=(100, 110, 170)
    )

    return img


def main():
    os.makedirs(ICONSET_DIR, exist_ok=True)

    for size in SIZES:
        img = draw_icon(size)

        # 保存 @1x
        path_1x = os.path.join(ICONSET_DIR, f"icon_{size}x{size}.png")
        img.save(path_1x, "PNG")
        print(f"  ✓ {size}x{size}")

        # 保存 @2x (retina)，除了 1024
        if size != 1024:
            path_2x = os.path.join(ICONSET_DIR, f"icon_{size//2}x{size//2}@2x.png")
            img.save(path_2x, "PNG")
            print(f"  ✓ {size//2}x{size//2}@2x")

    # 用 iconutil 打包 .icns
    icns_path = os.path.join(SCRIPT_DIR, "Resources", "AppIcon.icns")
    subprocess.run(
        ["iconutil", "-c", "icns", ICONSET_DIR, "-o", icns_path],
        check=True
    )
    print(f"\n✅ 图标已生成: {icns_path}")


if __name__ == "__main__":
    main()
