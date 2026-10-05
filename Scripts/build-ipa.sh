#!/bin/bash
# 拾文 · SnapText IPA 打包脚本
#
# 用法：
#   ./Scripts/build-ipa.sh                      # 无签名 ipa（配合 Sideloadly / AltStore 侧载）
#   TEAM_ID=XXXXXXXXXX ./Scripts/build-ipa.sh   # 个人团队签名（连接手机后可直接安装，7 天有效）
#
# 产物：build/ipa/SnapText.ipa
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build

# 内置快捷指令配方缺失时自动重建（签名产物曾被系统服务延迟回收，脚本自愈）
if [ ! -f "SnapText/Resources/Shortcuts/拾文·大爆炸.shortcut" ] || [ ! -f "SnapText/Resources/Shortcuts/拾文·静默归档.shortcut" ]; then
  echo "==> 配方文件缺失，运行 Scripts/build-shortcuts.py 重新生成"
  python3 Scripts/build-shortcuts.py
fi

if [ -n "${TEAM_ID:-}" ]; then
  echo "==> 使用团队 $TEAM_ID 签名归档（Release）"
  xcodebuild archive \
    -project SnapText.xcodeproj \
    -scheme SnapText \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/SnapText.xcarchive \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic
else
  echo "==> 无签名归档（Release），适合 Sideloadly / AltStore 侧载"
  xcodebuild archive \
    -project SnapText.xcodeproj \
    -scheme SnapText \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/SnapText.xcarchive \
    CODE_SIGNING_ALLOWED=NO
fi

APP=$(ls -d build/SnapText.xcarchive/Products/Applications/*.app | head -1)
echo "==> 打包 $APP"

rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry SnapText.ipa Payload)

echo "==> 完成: $(pwd)/build/ipa/SnapText.ipa"
unzip -l build/ipa/SnapText.ipa | head -12
