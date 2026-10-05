#!/bin/bash
# 生成 App Store 截图：5 语言 × 4 界面，iPhone 16 Pro Max（6.9"、1320×2868）
# 依赖：已安装到模拟器的 DEBUG 构建（含 DemoSupport 演示参数）
set -euo pipefail

UDID="${UDID:-4513AEAC-7011-42C9-AC4B-8D61A882A525}"  # iPhone 16 Pro Max (iOS 18.6)
OUT="$(cd "$(dirname "$0")/.." && pwd)/Design/Screenshots"
BUNDLE="me.snaptext.app"

mkdir -p "$OUT"

shoot() { # $1=语言 $2=locale $3=界面 $4=输出文件 [$5=引导页序号]
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  if [ "$3" = "list" ]; then
    xcrun simctl launch "$UDID" "$BUNDLE" -AppleLanguages "($1)" -AppleLocale "$2" >/dev/null
  elif [ "$3" = "onboarding" ]; then
    xcrun simctl launch "$UDID" "$BUNDLE" -SnapTextDemoScreen "onboarding" \
      -SnapTextDemoOnboardingPage "${5:-0}" \
      -AppleLanguages "($1)" -AppleLocale "$2" >/dev/null
  else
    xcrun simctl launch "$UDID" "$BUNDLE" -SnapTextDemoScreen "$3" \
      -AppleLanguages "($1)" -AppleLocale "$2" >/dev/null
  fi
  sleep 11
  xcrun simctl io "$UDID" screenshot "$4"
}

for entry in "zh-Hans:zh_CN:zh-Hans" "en:en_US:en" "ja:ja_JP:ja" "ko:ko_KR:ko" "es:es_ES:es"; do
  IFS=":" read -r lang locale dir <<< "$entry"
  mkdir -p "$OUT/$dir"
  shoot "$lang" "$locale" list     "$OUT/$dir/01-archive-list.png"
  shoot "$lang" "$locale" bigbang  "$OUT/$dir/02-bigbang.png"
  shoot "$lang" "$locale" capture  "$OUT/$dir/03-capture.png"
  shoot "$lang" "$locale" settings "$OUT/$dir/04-settings.png"
  shoot "$lang" "$locale" onboarding "$OUT/$dir/05-onboarding.png" 1
  echo "== $dir 完成"
done

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "全部完成 → $OUT"
ls -R "$OUT" | head -30
