# 针对PL Star缺陷检测的第一步改进
# 只改进标准化部分，保持其他代码不变

import os
import cv2
import numpy as np
import torch
from torch.utils.data import Dataset
from scipy.io import loadmat

class PLStarSegmentationDataset(Dataset):
    def __init__(self, image_dir, mask_dir, low_prec, high_prec, transform=None,
                 use_global_stats=True,          # 🔥 全局标准化开关
                 preserve_precision=True):       # 🔥 保持数值精度开关
        
        self.image_dir = image_dir
        self.mask_dir = mask_dir
        self.transform = transform
        self.low_prec = low_prec
        self.high_prec = high_prec
        self.use_global_stats = use_global_stats
        self.preserve_precision = preserve_precision  # 🔥 新增
        self.image_files = []
        
        # 原始文件收集逻辑（保持不变）
        all_files = sorted(os.listdir(image_dir))
        for f in all_files:
            if f.endswith(('.png', '.jpg', '.jpeg')):
                self.image_files.append(f)
            if f.endswith('_PLStar.mat'):
                self.image_files.append(f)
        
        print(f"找到 {len(self.image_files)} 个图像文件")
        
        # 🔥 关键改进：预计算全局统计信息
        if self.use_global_stats:
            print("正在计算全局统计信息用于PL Star检测...")
            self.global_stats = self._compute_global_stats()
            print(f"全局统计完成:")
            print(f"  数值范围: {self.global_stats['min']:.4f} ~ {self.global_stats['max']:.4f}")
            print(f"  标准化阈值: {self.global_stats['low_thresh']:.4f} ~ {self.global_stats['high_thresh']:.4f}")
            print(f"  有效像素比例: {self.global_stats['valid_ratio']:.1%}")
    
    def _compute_global_stats(self):
        """
        🔥 针对PL Star的全局统计计算
        重点：保持微弱信号的精度
        """
        all_valid_values = []
        total_pixels = 0
        valid_pixels = 0
        
        # 采样计算（避免内存问题）
        sample_count = min(20, len(self.image_files))
        print(f"从 {sample_count} 个样本计算全局统计...")
        
        for i, img_file in enumerate(self.image_files[:sample_count]):
            try:
                print(f"  处理 {i+1}/{sample_count}: {img_file}")
                
                # 加载图像
                image = self._load_single_image(img_file)
                if image is not None:
                    # 统计有效像素
                    valid_mask = ~np.isnan(image)
                    valid_data = image[valid_mask]
                    
                    total_pixels += image.size
                    valid_pixels += len(valid_data)
                    
                    # 收集有效数值（保持精度）
                    all_valid_values.extend(valid_data.flatten())
                    
                    # 显示这个样本的基本信息
                    if len(valid_data) > 0:
                        print(f"    范围: {valid_data.min():.4f} ~ {valid_data.max():.4f}")
                        print(f"    均值: {valid_data.mean():.4f}")
                        print(f"    有效像素: {len(valid_data)}/{image.size} ({len(valid_data)/image.size:.1%})")
                        
            except Exception as e:
                print(f"    跳过 {img_file}: {e}")
                continue
        
        if not all_valid_values:
            raise RuntimeError("没有找到有效像素进行统计")
        
        # 计算全局统计
        all_valid_values = np.array(all_valid_values, dtype=np.float64)  # 保持精度
        
        stats = {
            'min': np.min(all_valid_values),
            'max': np.max(all_valid_values), 
            'mean': np.mean(all_valid_values),
            'std': np.std(all_valid_values),
            'low_thresh': np.percentile(all_valid_values, self.low_prec),
            'high_thresh': np.percentile(all_valid_values, self.high_prec),
            'valid_ratio': valid_pixels / total_pixels,
            'total_samples': len(all_valid_values)
        }
        
        return stats
    
    def _load_single_image(self, img_file):
        """加载单个图像（复用原有逻辑）"""
        try:
            file_ext = os.path.splitext(img_file)[1].lower()
            image_path = os.path.join(self.image_dir, img_file)
            
            if file_ext == '.mat':
                image_data = loadmat(image_path)
                return image_data['modifiedMap']
            else:
                # 对于图像文件，确保加载为float以保持精度
                img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
                if img is not None and img.dtype == np.uint8:
                    # 如果是8位图像，需要转换回原始范围
                    print(f"    警告: {img_file} 是8位图像，可能丢失精度")
                return img
        except Exception as e:
            print(f"    加载失败: {e}")
            return None
    
    def __len__(self):
        return len(self.image_files)
    
    def __getitem__(self, idx):
        # ============================================
        # 前面的加载逻辑完全保持原样
        # ============================================
        file_name = self.image_files[idx]
        file_ext = os.path.splitext(file_name)[1].lower()
        image_path = os.path.join(self.image_dir, file_name)
        
        if file_ext == '.mat':
            image_data = loadmat(image_path)
            image = image_data['modifiedMap']
            
            if file_name.endswith('_PLStar.mat'):
                base_name = file_name[:-11]
                mask_file = base_name + "_Mask.mat"
                mask_path = os.path.join(self.mask_dir, mask_file)
            else:
                mask_path = os.path.join(self.mask_dir, file_name)
            
            mask_data = loadmat(mask_path)
            mask = mask_data['maskMap']
        else:
            image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
            base_name = os.path.splitext(file_name)[0]
            mask_candidates = [
                os.path.join(self.mask_dir, base_name + ext)
                for ext in ('.png', '.jpeg', '.jpg')
            ]
            
            mask_path = None
            for candidate in mask_candidates:
                if os.path.exists(candidate):
                    mask_path = candidate
                    break
            
            if mask_path is None:
                base_name = file_name[:-11]
                mask_file = base_name + "_Mask.mat"
                mask_path = os.path.join(self.mask_dir, mask_file)
            
            mask_ext = os.path.splitext(mask_path)[1].lower()
            if mask_ext == '.mat':
                mask_data = loadmat(mask_path)
                mask = mask_data['maskMap']
            else:
                mask = cv2.imread(mask_path, cv2.IMREAD_GRAYSCALE)
        
        if image is None:
            raise RuntimeError(f"Unable to load image: {image_path}")
        if mask is None:
            raise RuntimeError(f"Unable to load mask: {mask_path}")
        
        if len(mask.shape) == 3:
            mask = mask[:, :, 0]
        
        # ============================================
        # 转换为tensor（保持原样）
        # ============================================
        if len(image.shape) == 2:
            image = torch.from_numpy(image).float().unsqueeze(0)
        else:
            image = torch.from_numpy(image.astype(np.double).transpose(2, 0, 1)).float()
        
        # 🔥 针对二分类的mask处理改进
        mask = torch.from_numpy(mask.astype(np.uint8)).long()  # 改为long类型用于CE loss
        
        # ============================================
        # 🔥🔥 关键改进：PL Star专用标准化 🔥🔥
        # ============================================
        processed_image = image.clone()
        background_mask = torch.isnan(processed_image)
        
        if self.use_global_stats and hasattr(self, 'global_stats'):
            # ✅ 使用全局统计（推荐）
            stats = self.global_stats
            low_thres = stats['low_thresh']
            high_thres = stats['high_thresh']
            
            # 调试信息（可选）
            if idx < 3:  # 只对前3个样本打印
                print(f"样本{idx}: 使用全局阈值 {low_thres:.4f} ~ {high_thres:.4f}")
        else:
            # ❌ 原来的方法（每个样本不同，不推荐）
            valid_values = processed_image[~background_mask]
            if len(valid_values) > 0:
                low_thres = torch.quantile(valid_values, self.low_prec/100.0).item()
                high_thres = torch.quantile(valid_values, self.high_prec/100.0).item()
                if idx < 3:
                    print(f"样本{idx}: 个别阈值 {low_thres:.4f} ~ {high_thres:.4f}")
            else:
                low_thres, high_thres = 0, 0.1
        
        # 🔥 改进的标准化逻辑
        if high_thres > low_thres:
            # 裁剪到分位数范围
            processed_image = torch.clamp(processed_image, min=low_thres, max=high_thres)
            
            if self.preserve_precision:
                # ✅ 直接标准化到[0,1]，保持最大精度
                normalized_image = (processed_image - low_thres) / (high_thres - low_thres)
                # NaN区域设为0
                normalized_image[background_mask] = 0.0
                
                if idx < 3:
                    valid_normalized = normalized_image[~background_mask]
                    if len(valid_normalized) > 0:
                        print(f"    标准化后范围: {valid_normalized.min():.4f} ~ {valid_normalized.max():.4f}")
            else:
                # ❌ 原来的方法（损失精度，不推荐）
                normalized_image = ((processed_image - low_thres)/(high_thres - low_thres)) * (255-20) + 20
                normalized_image[background_mask] = 0
                normalized_image = normalized_image / 255.0
        else:
            # 异常情况处理
            normalized_image = torch.zeros_like(processed_image)
            print(f"警告: 样本{idx}标准化阈值异常")
        
        # ============================================
        # 数据增强（保持原样，但需要注意PL Star的对称性）
        # ============================================
        if self.transform:
            # 注意：对于PL Star，旋转应该是60°的倍数
            transformed = self.transform(image=normalized_image, mask=mask)
            normalized_image = transformed['image']
            mask = transformed['mask']
        
        return normalized_image, mask


# 🔥 使用示例
def create_pl_star_dataset():
    """
    创建PL Star专用数据集
    """
    dataset = PLStarSegmentationDataset(
        image_dir="path/to/your/wafer/images",
        mask_dir="path/to/your/masks", 
        low_prec=10,                    # 您的原始设置
        high_prec=90,                   # 您的原始设置
        use_global_stats=True,          # 🔥 关键：启用全局标准化
        preserve_precision=True,        # 🔥 关键：保持数值精度
        transform=None                  # 先不加数据增强
    )
    
    print(f"\n🎯 PL Star数据集创建完成:")
    print(f"   总样本数: {len(dataset)}")
    print(f"   使用全局标准化: {dataset.use_global_stats}")
    print(f"   保持数值精度: {dataset.preserve_precision}")
    
    return dataset

# 使用方法：
# dataset = create_pl_star_dataset()
