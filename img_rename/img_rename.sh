#!/bin/bash

# ======================== 配置文件区域 ========================
# 在这里可以统一配置支持的文件格式

# 视频文件格式（不区分大小写）
VIDEO_EXTENSIONS=("mov" "mp4" "m4v" "avi" "mkv" "flv" "wmv" "mpg" "mpeg" "mts" "m2ts")

# 照片文件格式（不区分大小写）
PHOTO_EXTENSIONS=("jpg" "jpeg" "png" "heic" "tiff" "tif" "bmp" "gif" "raw" "arw" "cr2" "nef" "dng")

# 输出文件名前缀（统一使用IMG_）
IMAGE_PREFIX="IMG_"

# ======================== 脚本开始 ========================

# 使用方法提示
show_usage() {
    echo "使用方法: $0 <媒体文件目录路径>"
    echo "示例: $0 /path/to/your/media/files"
    echo ""
    echo "注意：仅使用 'Creation Date' 字段重命名文件"
    echo "所有文件统一使用 '$IMAGE_PREFIX' 前缀"
    echo ""
    echo "支持的视频格式: ${VIDEO_EXTENSIONS[*]}"
    echo "支持的照片格式: ${PHOTO_EXTENSIONS[*]}"
    exit 1
}

# 检查参数
if [[ $# -eq 0 ]]; then
    echo "错误: 需要指定目录路径参数"
    show_usage
fi

TARGET_DIR="$1"

# 检查目录是否存在
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "错误: 目录 '$TARGET_DIR' 不存在"
    exit 1
fi

# 进入目标目录
cd "$TARGET_DIR" || {
    echo "错误: 无法进入目录 '$TARGET_DIR'"
    exit 1
}

echo "处理目录: $(pwd)"
echo "基于Creation Date重命名媒体文件..."
echo "注意：仅使用 'Creation Date' 字段"
echo "所有文件统一使用 '$IMAGE_PREFIX' 前缀"
echo "========================================"
echo "支持的文件格式:"
echo "  - 视频: ${VIDEO_EXTENSIONS[*]}"
echo "  - 照片: ${PHOTO_EXTENSIONS[*]}"
echo "========================================"

# 计数器
renamed_count=0
skipped_count=0
failed_count=0
no_creation_date_count=0
total_files=0
total_videos=0
total_photos=0

# 创建一个临时文件来存储所有匹配的文件
TMP_FILE_LIST=$(mktemp)

# 收集所有支持的文件
for ext in "${VIDEO_EXTENSIONS[@]}" "${PHOTO_EXTENSIONS[@]}"; do
    # 使用find命令收集文件，不区分大小写
    find . -maxdepth 1 -type f -iname "*.${ext}" >> "$TMP_FILE_LIST" 2>/dev/null
done

# 读取文件列表并处理
while IFS= read -r file; do
    # 移除开头的"./"
    file="${file#./}"
    
    ((total_files++))
    echo "处理文件 ($total_files): $file"
    
    # 获取文件扩展名（小写）
    extension="${file##*.}"
    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    # 判断文件类型
    is_video=false
    for video_ext in "${VIDEO_EXTENSIONS[@]}"; do
        if [[ "$extension_lower" == "$video_ext" ]]; then
            is_video=true
            ((total_videos++))
            file_type="视频"
            break
        fi
    done
    
    if [[ "$is_video" == false ]]; then
        for photo_ext in "${PHOTO_EXTENSIONS[@]}"; do
            if [[ "$extension_lower" == "$photo_ext" ]]; then
                ((total_photos++))
                file_type="照片"
                break
            fi
        done
    fi
    
    echo "  文件类型: $file_type"
    
    # 使用exiftool获取Creation Date字段
    # -s3参数：只输出值，不输出标签
    creation_date=$(exiftool -s3 -CreationDate "$file" 2>/dev/null)
    
    # 检查是否获取到Creation Date
    if [[ -z "$creation_date" ]]; then
        echo "  ❌ 错误: 无法获取 'Creation Date' 字段，跳过此文件"
        ((no_creation_date_count++))
        ((failed_count++))
        echo ""
        continue
    fi
    
    echo "  Creation Date: $creation_date"
    
    # 提取时间部分，移除时区信息（+08:00部分）
    # 格式示例: 2022:04:05 14:20:21+08:00
    time_str=$(echo "$creation_date" | sed 's/+.*//')
    
    if [[ -z "$time_str" ]]; then
        echo "  ❌ 错误: 无法解析时间字符串，跳过此文件"
        ((failed_count++))
        echo ""
        continue
    fi
    
    # 验证时间格式是否包含日期和时间
    # 修正正则表达式：确保时间部分包含冒号分隔符
    if [[ ! "$time_str" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "  ❌ 错误: 时间格式不正确: $time_str，跳过此文件"
        ((failed_count++))
        echo ""
        continue
    fi
    
    # 格式化时间为YYYYMMDD_HHMMSS格式
    # 移除冒号，替换空格为下划线
    formatted_time=$(echo "$time_str" | sed 's/://g' | sed 's/ /_/g')
    
    # 验证最终格式 - 应该是8位日期_6位时间
    if [[ ! "$formatted_time" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        echo "  ❌ 错误: 格式化后的时间格式不正确: $formatted_time，跳过此文件"
        ((failed_count++))
        echo ""
        continue
    fi
    
    # 提取日期和时间部分用于调试
    date_part=$(echo "$formatted_time" | cut -d'_' -f1)
    time_part=$(echo "$formatted_time" | cut -d'_' -f2)
    echo "  提取时间: $date_part $time_part"
    
    # 构建新文件名（统一使用IMG_前缀）
    new_name="${IMAGE_PREFIX}${formatted_time}.${extension_lower}"
    echo "  新文件名: $new_name"
    
    # 如果目标文件名已存在，添加序号
    if [[ -f "$new_name" ]]; then
        echo "  ⚠️  注意: 文件 $new_name 已存在，添加序号..."
        counter=2
        original_name="$new_name"
        while [[ -f "$new_name" ]]; do
            # 移除扩展名，添加序号
            base_name="${original_name%.*}"
            # 如果已经有序号，先移除旧的序号
            base_name=$(echo "$base_name" | sed -E 's/_[0-9]+$//')
            new_name="${base_name}_${counter}.${extension_lower}"
            ((counter++))
        done
        echo "  新文件名: $new_name"
    fi
    
    # 重命名文件
    if [[ "$file" != "$new_name" ]]; then
        echo "  ✅ 重命名为: $new_name"
        mv -n "$file" "$new_name"
        if [[ $? -eq 0 ]]; then
            ((renamed_count++))
        else
            echo "  ❌ 错误: 重命名失败"
            ((failed_count++))
        fi
    else
        echo "  ℹ️  文件名已符合格式，跳过"
        ((skipped_count++))
    fi
    
    echo ""
done < "$TMP_FILE_LIST"

# 删除临时文件
rm -f "$TMP_FILE_LIST"

# 总结报告
echo "========================================"
echo "处理完成！"
echo "目录: $(pwd)"
echo "找到文件: $total_files 个"
echo "  - 视频文件: $total_videos 个"
echo "  - 照片文件: $total_photos 个"
echo "成功重命名: $renamed_count 个文件"
echo "跳过（已符合格式）: $skipped_count 个文件"
echo "失败（无Creation Date）: $no_creation_date_count 个文件"
echo "其他失败: $((failed_count - no_creation_date_count)) 个文件"
echo "总计处理: $((renamed_count + skipped_count + failed_count)) 个文件"
