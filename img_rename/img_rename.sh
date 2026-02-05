#!/bin/bash

# ======================== 配置文件区域 ========================
# 在这里可以统一配置支持的文件格式

# 视频文件格式（不区分大小写）
VIDEO_EXTENSIONS=("mov" "mp4" "m4v" "avi" "mkv" "flv" "wmv" "mpg" "mpeg" "mts" "m2ts")

# 照片文件格式（不区分大小写）
PHOTO_EXTENSIONS=("jpg" "jpeg" "png" "heic" "tiff" "tif" "bmp" "gif" "raw" "arw" "cr2" "nef" "dng")

# 输出文件名前缀（统一使用IMG_）
IMAGE_PREFIX="IMG_"

# 自定义元数据标签优先级（按顺序尝试获取）
METADATA_TAGS=("CreationDate" "DateTimeOriginal" "CreateDate" "ModifyDate")

# 是否移动文件到分类目录 (true/false)
MOVE_TO_CATEGORY=true

# 分类目录的基础名称
CATEGORY_BASE_NAME="Photos"

# 文件名时间解析模式（正则表达式）
# 按优先级尝试匹配文件名中的时间信息
FILENAME_TIME_PATTERNS=(
    '([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})'  # YYYYMMDD_HHMMSS
    '([0-9]{4})-([0-9]{2})-([0-9]{2})[ _]([0-9]{2})([0-9]{2})([0-9]{2})'  # YYYY-MM-DD HHMMSS
    '([0-9]{4})-([0-9]{2})-([0-9]{2})[ _]([0-9]{2})\.([0-9]{2})\.([0-9]{2})'  # YYYY-MM-DD HH.MM.SS
    '([0-9]{4})-([0-9]{2})-([0-9]{2})[ _]([0-9]{2}):([0-9]{2}):([0-9]{2})'  # YYYY-MM-DD HH:MM:SS
)

# ======================== 脚本开始 ========================

# 使用方法提示
show_usage() {
    echo "使用方法: $0 <媒体文件目录路径>"
    echo "示例: $0 /path/to/your/media/files"
    echo ""
    echo "注意：按照优先级获取日期字段重命名文件"
    echo "标签优先级: ${METADATA_TAGS[*]}"
    echo "所有文件统一使用 '$IMAGE_PREFIX' 前缀"
    echo "移动文件到分类目录: $MOVE_TO_CATEGORY"
    if [[ "$MOVE_TO_CATEGORY" == "true" ]]; then
        echo "分类目录结构: ../${CATEGORY_BASE_NAME}/年/月/"
    fi
    echo ""
    echo "支持的视频格式: ${VIDEO_EXTENSIONS[*]}"
    echo "支持的照片格式: ${PHOTO_EXTENSIONS[*]}"
    exit 1
}

# 从文件名中提取时间信息的函数
# 参数: 文件名
# 返回值: 如果成功提取时间，输出格式为 "YYYY:MM:DD HH:MM:SS" 的时间字符串
extract_time_from_filename() {
    local filename="$1"
    local time_str=""
    
    # 尝试每个时间模式
    for pattern in "${FILENAME_TIME_PATTERNS[@]}"; do
        if [[ "$filename" =~ $pattern ]]; then
            local year="${BASH_REMATCH[1]}"
            local month="${BASH_REMATCH[2]}"
            local day="${BASH_REMATCH[3]}"
            
            # 去除前导零，避免八进制解释问题
            month="${month#0}"
            day="${day#0}"
            
            # 如果去除前导零后为空字符串，说明原值是"00"，但月份和日期不可能是0
            if [[ -z "$month" ]]; then
                month=0
            fi
            if [[ -z "$day" ]]; then
                day=0
            fi
            
            # 验证日期是否有效（使用十进制比较）
            if (( month < 1 || month > 12 )); then
                continue  # 月份无效，尝试下一个模式
            fi
            if (( day < 1 || day > 31 )); then
                continue  # 日期无效，尝试下一个模式
            fi
            
            # 如果有时间部分
            if [[ ${#BASH_REMATCH[@]} -ge 7 ]]; then
                local hour="${BASH_REMATCH[4]:-00}"
                local minute="${BASH_REMATCH[5]:-00}"
                local second="${BASH_REMATCH[6]:-00}"
                
                # 去除前导零
                hour="${hour#0}"
                minute="${minute#0}"
                second="${second#0}"
                
                # 如果去除前导零后为空字符串，设置为0
                if [[ -z "$hour" ]]; then
                    hour=0
                fi
                if [[ -z "$minute" ]]; then
                    minute=0
                fi
                if [[ -z "$second" ]]; then
                    second=0
                fi
                
                # 验证时间是否有效（使用十进制比较）
                if (( hour > 23 || minute > 59 || second > 59 )); then
                    continue  # 时间无效，尝试下一个模式
                fi
                
                # 格式化输出为两位数字
                time_str="$(printf "%04d:%02d:%02d %02d:%02d:%02d" "$year" "$month" "$day" "$hour" "$minute" "$second")"
            else
                # 只有日期部分，时间设为00:00:00
                time_str="$(printf "%04d:%02d:%02d %02d:%02d:%02d" "$year" "$month" "$day" 0 0 0)"
            fi
            
            # 检查提取的时间是否有效
            if [[ -n "$time_str" ]] && [[ "$time_str" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
                echo "$time_str"
                return 0
            fi
        fi
    done
    
    # 没有找到匹配的时间模式
    echo ""
    return 1
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
echo "基于日期字段重命名媒体文件..."
echo "标签优先级: ${METADATA_TAGS[*]}"
echo "所有文件统一使用 '$IMAGE_PREFIX' 前缀"
if [[ "$MOVE_TO_CATEGORY" == "true" ]]; then
    echo "移动文件到分类目录: 是"
    echo "分类目录结构: ../${CATEGORY_BASE_NAME}/年/月/"
else
    echo "移动文件到分类目录: 否"
fi
echo "========================================"
echo "支持的文件格式:"
echo "  - 视频: ${VIDEO_EXTENSIONS[*]}"
echo "  - 照片: ${PHOTO_EXTENSIONS[*]}"
echo "========================================"

# 计数器
renamed_count=0
skipped_rename_count=0
failed_count=0
no_time_field_count=0
moved_count=0
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
    
    # 使用exiftool按照优先级获取日期字段
    creation_date=""
    used_tag=""

    # 按照METADATA_TAGS数组中的优先级顺序尝试获取日期
    # -s3参数：只输出值，不输出标签
    for tag in "${METADATA_TAGS[@]}"; do
        date_value=$(exiftool -s3 "-${tag}" "$file" 2>/dev/null)
        if [[ -n "$date_value" ]]; then
            creation_date="$date_value"
            used_tag="$tag"
            break
        fi
    done
    
    # 如果没有从元数据标签获取到时间，尝试从文件名中解析
    time_source="元数据"
    if [[ -z "$creation_date" ]]; then
        echo "  ℹ️  无法从元数据标签获取时间，尝试从文件名中解析..."
        filename_time=$(extract_time_from_filename "$file")
        
        if [[ -n "$filename_time" ]]; then
            creation_date="$filename_time"
            used_tag="文件名"
            time_source="文件名"
            echo "  ✅ 从文件名中解析到时间: $creation_date"
        else
            echo "  ❌ 错误: 无法获取任何日期字段（尝试了: ${METADATA_TAGS[*]}和文件名解析），跳过此文件"
            ((no_time_field_count++))
            ((failed_count++))
            echo ""
            continue
        fi
    fi
    
    echo "  使用标签 [$used_tag]: $creation_date"
    
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

    # 提取年和月用于目录分类
    year=${formatted_time:0:4}  # 前4位是年
    month=${formatted_time:4:2} # 第5-6位是月
    
    # 提取日期和时间部分用于调试
    date_part=$(echo "$formatted_time" | cut -d'_' -f1)
    time_part=$(echo "$formatted_time" | cut -d'_' -f2)
    echo "  提取时间: $date_part $time_part"
    echo "  提取年月: $year 年 $month 月"
    echo "  时间来源: $time_source"
    
    # 构建新文件名（统一使用IMG_前缀）
    new_name="${IMAGE_PREFIX}${formatted_time}.${extension_lower}"
    echo "  新文件名: $new_name"

    # 检查原文件名是否已经符合目标格式
    # 将原文件名转为小写进行比较
    file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
    new_name_lower=$(echo "$new_name" | tr '[:upper:]' '[:lower:]')
    
    # 设置最终文件名变量
    final_name=""
    skip_rename=false
    
    # 首先检查原文件名是否已经符合目标格式（无序号）
    if [[ "$file_lower" == "$new_name_lower" ]]; then
        echo "  ℹ️  文件名已符合目标格式，跳过重命名"
        final_name="$file"
        skip_rename=true
        ((skipped_rename_count++))
    else
        # 然后检查原文件名是否符合带序号的目标格式
        # 正则匹配：IMG_YYYYMMDD_HHMMSS_1.jpg, IMG_YYYYMMDD_HHMMSS_2.jpg 等
        # 移除扩展名进行匹配
        file_base="${file_lower%.*}"
        new_base="${new_name_lower%.*}"
        
        # 检查是否匹配 pattern: new_base_数字
        if [[ "$file_base" =~ ^${new_base}_[0-9]+$ ]]; then
            echo "  ℹ️  文件名已符合带序号的目标格式，跳过重命名"
            final_name="$file"
            skip_rename=true
            ((skipped_rename_count++))
        fi
    fi
    
    # 如果文件不符合目标格式，需要进行重命名
    if [[ "$skip_rename" == false ]]; then
        # 如果目标文件名已存在，添加序号
        temp_new_name="$new_name"
        if [[ -f "$new_name" ]]; then
            echo "  ⚠️  注意: 文件 $new_name 已存在，添加序号..."
            counter=2
            original_name="$new_name"
            while [[ -f "$temp_new_name" ]]; do
                # 移除扩展名，添加序号
                base_name="${original_name%.*}"
                # 如果已经有序号，先移除旧的序号
                base_name=$(echo "$base_name" | sed -E 's/_[0-9]+$//')
                temp_new_name="${base_name}_${counter}.${extension_lower}"
                ((counter++))
            done
            echo "  新文件名: $temp_new_name"
        fi
        
        # 重命名文件
        if [[ "$file" != "$temp_new_name" ]]; then
            echo "  ✅ 重命名为: $temp_new_name"
            mv -n "$file" "$temp_new_name"
            if [[ $? -eq 0 ]]; then
                ((renamed_count++))
                final_name="$temp_new_name"
            else
                echo "  ❌ 错误: 重命名失败"
                ((failed_count++))
                echo ""
                continue
            fi
        else
            echo "  ℹ️  文件名已符合格式，跳过重命名"
            final_name="$file"
            ((skipped_rename_count++))
        fi
    fi
    
    # 如果启用移动功能，将文件移动到分类目录
    if [[ "$MOVE_TO_CATEGORY" == "true" ]]; then
        # 获取当前目录的父目录路径
        parent_dir="$(dirname "$(pwd)")"
        
        # 构建目标分类目录路径
        target_dir="${parent_dir}/${CATEGORY_BASE_NAME}/${year}/${month}/"
        
        echo "  目标分类目录: $target_dir"
        
        # 创建目录（如果不存在）
        mkdir -p "$target_dir"
        
        # 检查目标目录中是否已存在同名文件
        target_path="${target_dir}${final_name}"
        if [[ -f "$target_path" ]]; then
            echo "  ⚠️  注意: 目标目录中已存在 $final_name，添加序号..."
            counter=2
            base_name="${final_name%.*}"
            extension="${final_name##*.}"
            # 移除可能已有的序号
            base_name=$(echo "$base_name" | sed -E 's/_[0-9]+$//')
            target_path="${target_dir}${base_name}_${counter}.${extension}"
            
            while [[ -f "$target_path" ]]; do
                ((counter++))
                target_path="${target_dir}${base_name}_${counter}.${extension}"
            done
            echo "  目标文件: $(basename "$target_path")"
        fi
        
        # 移动文件到分类目录
        echo "  📁 移动到分类目录..."
        mv -n "$final_name" "$target_path"
        
        if [[ $? -eq 0 ]]; then
            ((moved_count++))
            echo "  ✅ 移动成功"
        else
            echo "  ❌ 错误: 移动文件失败"
        fi
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
echo "跳过重命名: $skipped_rename_count 个文件"
echo "失败（无时间字段）: $no_time_field_count 个文件"
echo "其他失败: $((failed_count - no_time_field_count)) 个文件"
if [[ "$MOVE_TO_CATEGORY" == "true" ]]; then
    echo "成功移动到分类目录: $moved_count 个文件"
    echo "分类目录位置: $(dirname "$(pwd)")/${CATEGORY_BASE_NAME}/"
fi
echo "总计处理: $((renamed_count + skipped_rename_count + failed_count)) 个文件"
