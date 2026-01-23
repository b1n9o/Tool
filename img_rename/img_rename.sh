#!/bin/bash

# 使用方法提示
show_usage() {
    echo "使用方法: $0 <MOV文件目录路径>"
    echo "示例: $0 /path/to/your/mov/files"
    echo "示例: $0 ./ing/p_1"
    echo ""
    echo "注意：仅使用 'Creation Date' 字段重命名文件"
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
echo "基于Creation Date重命名MOV文件..."
echo "注意：仅使用 'Creation Date' 字段"
echo "========================================"

# 设置不区分大小写的扩展名匹配
shopt -s nocaseglob

# 计数器
renamed_count=0
skipped_count=0
failed_count=0
no_creation_date_count=0
total_files=0

# 遍历目录下所有mov文件
for file in *.mov *.MOV; do
    # 跳过不存在的文件（避免空匹配时的错误处理）
    [ -e "$file" ] || continue
    
    ((total_files++))
    echo "处理文件 ($total_files): $file"
    
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
    if [[ ! "$time_str" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "  ❌ 错误: 时间格式不正确，跳过此文件"
        ((failed_count++))
        echo ""
        continue
    fi
    
    # 格式化时间为YYYYMMDD_HHMMSS格式
    # 移除冒号，替换空格为下划线
    formatted_time=$(echo "$time_str" | sed 's/://g' | sed 's/ /_/g')
    
    # 验证最终格式
    if [[ ! "$formatted_time" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        echo "  ❌ 错误: 格式化后的时间格式不正确: $formatted_time，跳过此文件"
        ((failed_count++))
        echo ""
        continue
    fi
    
    # 构建新文件名
    new_name="IMG_${formatted_time}.mov"
    
    # 如果目标文件名已存在，添加序号
    if [[ -f "$new_name" ]]; then
        echo "  ⚠️  注意: 文件 $new_name 已存在，添加序号..."
        counter=2
        original_name="$new_name"
        while [[ -f "$new_name" ]]; do
            # 移除扩展名，添加序号
            base_name="${original_name%.mov}"
            # 如果已经有序号，先移除旧的序号
            base_name=$(echo "$base_name" | sed -E 's/_[0-9]+$//')
            new_name="${base_name}_${counter}.mov"
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
done

# 恢复设置
shopt -u nocaseglob

# 总结报告
echo "========================================"
echo "处理完成！"
echo "目录: $(pwd)"
echo "找到文件: $total_files 个"
echo "成功重命名: $renamed_count 个文件"
echo "跳过（已符合格式）: $skipped_count 个文件"
echo "失败（无Creation Date）: $no_creation_date_count 个文件"
echo "其他失败: $((failed_count - no_creation_date_count)) 个文件"
echo "总计处理: $((renamed_count + skipped_count + failed_count)) 个文件"
