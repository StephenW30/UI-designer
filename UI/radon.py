# radon_from_scratch_s_theta.py
# Author: GPT-5 Thinking
# -----------------------------------------------------------
# Radon transform implemented from scratch using only NumPy.
# 纯 NumPy "从零实现" Radon 变换（无现成库）
# -----------------------------------------------------------
# ✅ 输出正弦图的形状为 (num_s, num_angles)：
#    - 行（纵轴 y）：探测器坐标 s
#    - 列（横轴 x）：角度 θ（度）
# ✅ 可选可视化仅用 matplotlib（不是必须），便于快速验证
# ✅ 主要思路：Rotate-and-Sum（旋转 + 列求和）近似线积分
# -----------------------------------------------------------
# 术语说明 / Terms:
# - s (detector position): 探测器坐标（以像素为单位，中心对齐）
# - θ (angle): 角度（度），逆时针为正方向（数学正向）
# - Sinogram: 正弦图，记录不同角度 θ 下关于 s 的投影值
# -----------------------------------------------------------

import math
import numpy as np


# ===========================================================
# 1) Padding 到对角线尺寸，避免旋转裁切
#    Pad the image to its diagonal size to avoid rotation cropping
# ===========================================================
def pad_to_diagonal(img: np.ndarray, fill: float = 0.0) -> np.ndarray:
    """
    将输入图像在四周填充到"对角线长度 × 对角线长度"的正方形，
    这样旋转任意角度都不会因为边界而丢失信息。

    Pad the input image to a square whose side equals the diagonal length
    so that no content is lost after rotation.

    Parameters
    ----------
    img : np.ndarray (H, W)
        输入图像 / input image.
    fill : float
        填充值 / padding fill value.

    Returns
    -------
    out : np.ndarray (S, S)
        填充后的图像 / padded image (square).
    """
    h, w = img.shape
    # 对角线长度（向上取整） / ceil of diagonal length
    side = int(math.ceil(math.sqrt(h * h + w * w)))
    pad_h = (side - h) // 2
    pad_w = (side - w) // 2

    out = np.full((side, side), fill, dtype=img.dtype)
    out[pad_h:pad_h + h, pad_w:pad_w + w] = img
    return out


# ===========================================================
# 2) 仅保留内切圆视野（经典 Radon 定义）
#    Keep only the inscribed circular field-of-view (classical Radon)
# ===========================================================
def apply_circular_fov(img: np.ndarray) -> np.ndarray:
    """
    将内切圆之外的区域置零，使视野符合经典 Radon 变换的定义。
    Zero out pixels outside the inscribed circle.

    Notes:
    - 这有助于减少边缘伪影；对于非圆形 FOV 可按需关闭。
      Helpful to reduce edge artifacts; disable if undesired.
    """
    h, w = img.shape
    cy, cx = (h - 1) / 2.0, (w - 1) / 2.0
    yy, xx = np.meshgrid(np.arange(h), np.arange(w), indexing="ij")
    r = min(cx, cy)
    mask = (xx - cx) ** 2 + (yy - cy) ** 2 <= r ** 2

    out = np.zeros_like(img)
    out[mask] = img[mask]
    return out


# ===========================================================
# 3) 双线性插值采样器（向量化）
#    Vectorized bilinear sampler
# ===========================================================
def sample_bilinear(img: np.ndarray, xs: np.ndarray, ys: np.ndarray, fill: float = 0.0) -> np.ndarray:
    """
    在浮点坐标 (xs, ys) 上对图像进行双线性插值。
    Bilinear sampling at floating-point coordinates.

    Parameters
    ----------
    img : np.ndarray (H, W)
    xs, ys : np.ndarray
        源图像坐标系中的浮点坐标（与输出网格同形状）
        Float coordinates in the source image space.
    fill : float
        越界时的填充值 / fill value for out-of-bound samples.

    Returns
    -------
    out : np.ndarray
        与 xs/ys 同形状的插值结果 / interpolated values.
    """
    h, w = img.shape

    # 邻近四个整数栅格点 / the 4 neighbors
    x0 = np.floor(xs).astype(np.int64)
    y0 = np.floor(ys).astype(np.int64)
    x1 = x0 + 1
    y1 = y0 + 1

    # 小数部分 / fractional parts
    dx = xs - x0
    dy = ys - y0

    # 限制索引到图像范围内 / clip to image bounds
    x0c = np.clip(x0, 0, w - 1)
    x1c = np.clip(x1, 0, w - 1)
    y0c = np.clip(y0, 0, h - 1)
    y1c = np.clip(y1, 0, h - 1)

    # 四个角点像素值 / fetch 4 corners
    Ia = img[y0c, x0c]
    Ib = img[y0c, x1c]
    Ic = img[y1c, x0c]
    Id = img[y1c, x1c]

    # 双线性权重 / bilinear weights
    wa = (1 - dx) * (1 - dy)
    wb = dx * (1 - dy)
    wc = (1 - dx) * dy
    wd = dx * dy

    out = Ia * wa + Ib * wb + Ic * wc + Id * wd

    # 越界处用 fill 覆盖 / overwrite OOB with fill
    outside = (xs < 0) | (xs > (w - 1)) | (ys < 0) | (ys > (h - 1))
    if np.any(outside):
        out = out.astype(np.float64, copy=False)
        out[outside] = fill

    return out


# ===========================================================
# 4) 旋转：逆映射 + 双线性插值（中心旋转）
#    Rotation via inverse mapping + bilinear interpolation (around center)
# ===========================================================
def rotate_image_bilinear(img: np.ndarray, angle_deg: float, fill: float = 0.0) -> np.ndarray:
    """
    将图像围绕几何中心旋转 angle_deg（逆时针），使用逆映射和双线性插值。
    Rotate the image counter-clockwise by angle_deg using inverse mapping.

    Convention:
    - 图像坐标 y 轴向下；这里采用标准逆旋转矩阵 R(-θ) 做反向采样。
      Image coordinates have y downwards; we apply inverse rotation R(-θ).

    Returns
    -------
    rot : np.ndarray (H, W)
        旋转后的图像（与输入同尺寸） / rotated image with same shape.
    """
    h, w = img.shape
    cy, cx = (h - 1) / 2.0, (w - 1) / 2.0

    theta = math.radians(angle_deg)
    cos_t, sin_t = math.cos(theta), math.sin(theta)

    # 构建输出网格（目标像素坐标） / build output grid
    yy, xx = np.meshgrid(np.arange(h), np.arange(w), indexing="ij")

    # 逆映射：输出 -> 输入（先平移到中心，再逆旋转，最后平移回去）
    # Inverse mapping: (x', y') -> (x, y)
    x_rel = xx - cx
    y_rel = yy - cy
    xs =  cos_t * x_rel + sin_t * y_rel + cx
    ys = -sin_t * x_rel + cos_t * y_rel + cy

    rot = sample_bilinear(img, xs, ys, fill=fill)
    return rot.astype(np.float64, copy=False)


# ===========================================================
# 5) Radon 变换（旋转 + 列求和）
#    Radon transform via rotate-and-sum
#    —— 输出即为 (s, θ)：行=s、列=θ
# ===========================================================
def radon_transform_s_theta(img: np.ndarray,
                            angles_deg,
                            use_circular_fov: bool = True,
                            pad: bool = True,
                            fill: float = 0.0):
    """
    通过"旋转 + 按列求和"来近似计算 Radon 投影。
    Approximate the Radon transform via rotation + column-wise sums.

    Parameters
    ----------
    img : np.ndarray (H, W)
        输入图像 / input image.
    angles_deg : iterable of float
        投影角度（度），θ=0° 表示对垂直线积分（对每列按行求和）。
        Projection angles in degrees; θ=0° integrates along vertical lines.
    use_circular_fov : bool
        True 则保留内切圆（经典定义）；False 则使用整个 padded 区域。
        Keep inscribed circle if True (classical).
    pad : bool
        True 则先 pad 到对角线尺寸，避免旋转裁切。
        Pad to diagonal to avoid cropping if True.
    fill : float
        旋转采样越界时的填充值 / fill value for out-of-bound sampling.

    Returns
    -------
    sinogram : np.ndarray (num_s, num_angles)
        正弦图：行=s，列=θ（满足"纵轴是距离 s，横轴是角度 θ"的可视化约定）
        Sinogram with shape (s, θ) as requested.
    s_coords : np.ndarray (num_s,)
        探测器坐标 s（像素，中心对齐，递增）
        Detector coordinate in pixels (centered & increasing).
    angles_rad : np.ndarray (num_angles,)
        角度（弧度） / angles in radians.

    Notes
    -----
    - 数值近似：连续域的线积分被"旋转后按列求和"离散化近似（双线性插值）。
      Numerical approximation via rotate-and-sum with bilinear resampling.
    - 复杂度：O(HW × Nθ)。可通过减少角度数或图像分辨率来平衡速度。
      Complexity O(HW × Nθ).
    """
    assert img.ndim == 2, "img must be 2D"
    work = img.astype(np.float64, copy=False)

    # 可选：先 pad 再裁切内切圆，减少边缘伪影
    if pad:
        work = pad_to_diagonal(work, fill=fill)
    if use_circular_fov:
        work = apply_circular_fov(work)

    h, w = work.shape
    num_s = w  # 对"旋转后按列求和"，探测器数量等于宽度
    angles_deg = np.asarray(list(angles_deg), dtype=np.float64)
    angles_rad = np.deg2rad(angles_deg)

    # 直接按 (s, θ) 排布分配结果矩阵
    sinogram = np.zeros((num_s, len(angles_deg)), dtype=np.float64)

    # 对每个角度：旋转 -> 按列求和（即对 y 求和）
    for j, ang in enumerate(angles_deg):
        rot = rotate_image_bilinear(work, ang, fill=fill)  # (H, W)
        proj = rot.sum(axis=0)                             # (W,) = (num_s,)
        sinogram[:, j] = proj

    # 探测器坐标 s：以中心 0 对齐，从负到正均匀采样
    s_coords = np.linspace(-(num_s - 1) / 2.0,
                            (num_s - 1) / 2.0,
                            num_s, dtype=np.float64)
    return sinogram, s_coords, angles_rad


# ===========================================================
# 6) 生成一个简易 "PL-star" 测试图（含弱噪声线）
#    Build a toy PL-star image with optional faint noise rays
# ===========================================================
def make_pl_star(shape=(1000, 1000),
                 center=None,
                 main_angles_deg=(0, 60, 120, 180, 240, 300),
                 length=380,
                 thickness=1,
                 noise_angles_deg=(30, 90, 150, 210, 270, 330)) -> np.ndarray:
    """
    生成从中心点向若干角度发射的射线图案，可用于测试正弦图。
    Generate a simple star-shaped pattern for testing the sinogram.

    Parameters
    ----------
    shape : tuple
        图像尺寸 / image shape (H, W).
    center : (cy, cx) or None
        射线中心；None 则取图像中心。
        Ray origin; defaults to image center if None.
    main_angles_deg : iterable
        主要射线角度（值较强） / main ray angles (strong).
    length : int
        射线长度（像素） / ray length in pixels.
    thickness : int
        线条"刷子"的半径（越大线越粗）。brush radius for thickness.
    noise_angles_deg : iterable
        噪声射线角度（值较弱） / faint noise ray angles.
    """
    h, w = shape
    img = np.zeros(shape, dtype=np.float64)

    if center is None:
        cy, cx = h // 2, w // 2
    else:
        cy, cx = center

    def draw_ray(angle_deg, val=1.0):
        """在给定角度上画一条长度为 length 的射线（小方块刷实现厚度）。
        Draw a ray using a small square brush to control thickness."""
        theta = math.radians(angle_deg)
        dx, dy = math.cos(theta), math.sin(theta)
        for r in range(length):
            x = int(round(cx + r * dx))
            y = int(round(cy + r * dy))
            if 0 <= x < w and 0 <= y < h:
                # 用 (2*thickness+1)×(2*thickness+1) 的小方块加粗
                img[max(0, y - thickness):min(h, y + thickness + 1),
                    max(0, x - thickness):min(w, x + thickness + 1)] = val

    # 画主射线（强信号）
    for a in main_angles_deg:
        draw_ray(a, val=1.0)

    # 画弱噪声射线（弱信号）
    for a in noise_angles_deg:
        draw_ray(a, val=0.25)

    return img


# ===========================================================
# 7) 脚本入口：构造示例、计算 Radon、可视化
#    Script entry: build example, compute Radon, visualize
# ===========================================================
if __name__ == "__main__":
    # (1) 构造一个测试图像（中心偏移以验证非中心情况）
    #     Build a test image; center is slightly off to show generality
    test = make_pl_star(shape=(1000, 1000), center=(800, 470), length=380, thickness=1)

    # (2) 角度范围：0..179 度（常见选择；可按需加密/稀疏）
    #     Angles from 0 to 179 degrees (common choice)
    angles_deg = np.arange(0, 180, 1, dtype=np.float64)

    # (3) 计算 Radon（直接得到 (s, θ) 排布）
    #     Compute Radon; output is already arranged as (s, θ)
    sino, s, ang_rad = radon_transform_s_theta(
        test, angles_deg, use_circular_fov=True, pad=True, fill=0.0
    )

    # (4) 可选可视化（仅演示；无 matplotlib 也能运行）
    #     Optional visualization for quick verification
    try:
        import matplotlib.pyplot as plt

        plt.figure(figsize=(12, 5))

        # 左图：输入图像 / Left: input image
        plt.subplot(1, 2, 1)
        plt.title("Input image", fontsize=14)
        # 使用jet色彩映射，显示坐标轴
        h, w = test.shape
        im1 = plt.imshow(test, cmap="jet", origin="upper", 
                        extent=[0, w, h, 0])  # extent=[left, right, bottom, top]
        plt.xlabel("X (pixels)", fontsize=12)
        plt.ylabel("Y (pixels)", fontsize=12)
        plt.colorbar(im1, label="Intensity")
        
        # 添加网格和刻度
        plt.grid(True, alpha=0.3)
        plt.xticks(np.arange(0, w+1, 100))
        plt.yticks(np.arange(0, h+1, 100))

        # 右图：正弦图（横轴=角度 θ，纵轴=距离 s）
        # Right: sinogram (x = θ, y = s)
        plt.subplot(1, 2, 2)
        plt.title("Sinogram (x = θ, y = s)", fontsize=14)
        im2 = plt.imshow(
            sino,                         # shape: (num_s, num_angles) -> y: s, x: θ
            aspect="auto",
            cmap="jet",                   # 使用jet色彩映射
            origin="lower",               # 让较小的 s 在图下方；如需反转可改 "upper"
            extent=[angles_deg.min(), angles_deg.max(), s.min(), s.max()]
        )
        plt.xlabel("Angle θ (degrees)", fontsize=12)
        plt.ylabel("Detector position s (pixels)", fontsize=12)
        plt.xlim(angles_deg.min(), angles_deg.max())
        plt.ylim(s.min(), s.max())
        plt.xticks(np.arange(0, 180, 20))
        plt.yticks(np.arange(s.min(), s.max()+1, 200))
        plt.grid(True, alpha=0.3)
        plt.colorbar(im2, label="Line integral")
        
        plt.tight_layout()
        plt.show()

    except Exception as e:
        # 没装 matplotlib 时给出文本摘要
        # Fall back to a textual summary if matplotlib is unavailable
        print("Computed sinogram shape (s, θ):", sino.shape)
        print("s range:", (float(s[0]), float(s[-1])))
        print("θ range (deg):", (float(angles_deg[0]), float(angles_deg[-1])))

        # 提示：你可以将 sinogram 保存到磁盘以供其他工具可视化
        # Tip: you may save 'sino' to disk for visualization elsewhere:
        # np.save("sinogram_s_theta.npy", sino)
