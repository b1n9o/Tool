#!/bin/bash

# 移动文件到平铺目录的脚本
# 用法：./flatten_files.sh <源目录> [目标目录]
# 如果未指定目标目录，则默认使用源目录同级别下的DEFAULT_FOLDER文件夹

# 配置变量 - 可在此处修改默认文件夹名称
DEFAULT_FOLDER="Photos"

# 检查参数数量
if [ $# -lt 1 ]; then
    echo "错误：参数数量不正确"
    echo "用法：$0 <源目录路径> [目标目录路径]"
    echo "注意：如果未指定目标目录，将使用源目录同级下的${DEFAULT_FOLDER}文件夹"
    exit 1
fi

SOURCE_DIR="$1"

# 设置默认目标目录
if [ $# -eq 2 ]; then
    DEST_DIR="$2"
else
    # 获取源目录的父目录
    SOURCE_PARENT=$(dirname "$SOURCE_DIR")
    # 设置默认目标目录为父目录下的DEFAULT_FOLDER文件夹
    DEST_DIR="$SOURCE_PARENT/$DEFAULT_FOLDER"
fi

echo "源目录: $SOURCE_DIR"
echo "目标目录: $DEST_DIR"
echo ""

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误：源目录 '$SOURCE_DIR' 不存在"
    exit 1
fi

# 检查源目录是否为空
if [ -z "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]; then
    echo "警告：源目录 '$SOURCE_DIR' 为空"
    exit 0
fi

# 检查目标目录是否已存在
if [ -d "$DEST_DIR" ]; then
    echo "错误：目标目录 '$DEST_DIR' 已存在"
    exit 1
fi

# 创建目标目录
mkdir -p "$DEST_DIR"

# 检查是否成功创建目标目录
if [ ! -d "$DEST_DIR" ]; then
    echo "错误：无法创建目标目录 '$DEST_DIR'"
    exit 1
fi

# 统计移动的文件数量
count=0
skipped=0

# 使用find命令查找所有文件（不包括目录）
echo "正在移动文件..."
while IFS= read -r -d '' file; do
    # 获取文件名（不包含路径）
    filename=$(basename "$file")
    
    # 跳过.DS_Store文件
    if [ "$filename" = ".DS_Store" ]; then
        continue
    fi
    
    # 构建目标文件路径
    dest_file="$DEST_DIR/$filename"
    
    # 检查目标文件是否已存在
    if [ -e "$dest_file" ]; then
        # 如果文件已存在，创建唯一的文件名
        name="${filename%.*}"
        extension="${filename##*.}"
        
        # 如果文件没有扩展名
        if [ "$name" = "$extension" ]; then
            name="$filename"
            extension=""
        fi
        
        # 添加时间戳避免冲突
        timestamp=$(date +%s%N)
        
        # 使用简化方法生成随机数
        random=$((1000 + RANDOM % 9000))
        
        if [ -n "$extension" ]; then
            new_filename="${name}_${timestamp}_${random}.${extension}"
        else
            new_filename="${name}_${timestamp}_${random}"
        fi
        
        dest_file="$DEST_DIR/$new_filename"
    fi
    
    # 移动文件
    if mv "$file" "$dest_file" 2>/dev/null; then
        ((count++))
    else
        ((skipped++))
    fi
done < <(find "$SOURCE_DIR" -type f -print0)

# 显示统计信息
echo ""
echo "========================"
echo "操作完成"
echo "成功移动文件数: $count"

if [ $skipped -gt 0 ]; then
    echo "未能移动文件数: $skipped"
fi
