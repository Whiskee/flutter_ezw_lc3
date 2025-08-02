#!/bin/bash

# 准备 Archive 的脚本
# 这个脚本会处理 liblc3.dylib 的符号问题

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRAMEWORK_DIR="${SCRIPT_DIR}/../Classes/framework"
DYLIB_PATH="${FRAMEWORK_DIR}/liblc3.dylib"
BACKUP_PATH="${FRAMEWORK_DIR}/liblc3.dylib.backup"

echo "Preparing for iOS Archive..."

# 备份原始文件
if [ -f "$DYLIB_PATH" ]; then
    cp "$DYLIB_PATH" "$BACKUP_PATH"
    echo "Backed up original dylib to: $BACKUP_PATH"
    
    # 创建一个空的 dSYM 目录结构
    DSYM_PATH="${DYLIB_PATH}.dSYM"
    mkdir -p "${DSYM_PATH}/Contents/Resources/DWARF"
    
    # 创建 Info.plist
    cat > "${DSYM_PATH}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.fzfstudio.liblc3</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF
    
    # 复制 dylib 到 dSYM（作为占位符）
    cp "$DYLIB_PATH" "${DSYM_PATH}/Contents/Resources/DWARF/liblc3.dylib"
    
    echo "Created placeholder dSYM at: $DSYM_PATH"
    echo ""
    echo "注意：这是一个占位符 dSYM 文件，因为原始 dylib 不包含调试符号。"
    echo "这应该能够解决 Archive 时的错误，但不会提供实际的调试信息。"
else
    echo "Error: liblc3.dylib not found at: $DYLIB_PATH"
    exit 1
fi

echo ""
echo "准备完成！现在可以尝试 Archive 了。"