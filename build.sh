#!/bin/bash
# 构建和打包 Omit 应用脚本

set -e

echo "🔨 开始构建 Omit..."

# 1. 清理之前的构建
echo "清理旧构建..."
rm -rf build/
rm -rf dist/
mkdir -p dist/

# 2. 构建应用
echo "编译应用..."
xcodebuild \
    -project Omit.xcodeproj \
    -scheme Omit \
    -configuration Release \
    -derivedDataPath build \
    -arch arm64 \
    -arch x86_64

echo "✅ 编译完成"

# 3. 查找编译后的 .app
APP_PATH="build/Build/Products/Release/Omit.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 找不到应用文件，编译可能失败"
    exit 1
fi

# 4. 自签名
echo "🔐 进行自签名..."
codesign --force --deep --sign - "$APP_PATH"
echo "✅ 自签名完成"

# 5. 创建 DMG
echo "📦 打包为 DMG..."
DMG_PATH="dist/Omit.dmg"

# 创建临时目录
TEMP_DMG_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DMG_DIR" EXIT

# 复制应用到临时目录
cp -r "$APP_PATH" "$TEMP_DMG_DIR/"

# 创建 DMG（无压缩，更快）
hdiutil create -volname "Omit" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "✅ DMG 创建完成: $DMG_PATH"

# 6. 获取应用版本
VERSION=$(mdls -name kMDItemVersion "$APP_PATH" | cut -d'"' -f2)
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
fi

echo ""
echo "=========================================="
echo "🎉 构建完成！"
echo "=========================================="
echo "应用版本: $VERSION"
echo "输出文件: $DMG_PATH"
echo "文件大小: $(du -h $DMG_PATH | cut -f1)"
echo ""
echo "下一步:"
echo "1. 测试应用是否能正常运行"
echo "2. 上传 $DMG_PATH 到 GitHub Releases"
echo "=========================================="
