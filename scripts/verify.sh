#!/bin/bash
# scripts/verify.sh — ISeeImageViewer 机械自检
#   ./scripts/verify.sh              mechanical only (~30-60s)
#   ./scripts/verify.sh --with-codex  加 codex 全项目审查 (~2-5min, costs $)
# 返回 0 = 全过；非 0 = 有失败项

set -u

WITH_CODEX=0
for arg in "$@"; do
  case "$arg" in
    --with-codex) WITH_CODEX=1 ;;
    -h|--help)
      sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

PASS=0
FAIL=0
pass() { printf '  [\xe2\x9c\x93] %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  [\xe2\x9c\x97] %s\n' "$1"; FAIL=$((FAIL+1)); }

SRC=$(find ISeeImageViewer -name '*.swift' 2>/dev/null)

echo "=== /go verify ==="

# ── 1. build ──────────────────────────────────────────────
echo
echo "1. make build"
LOG=$(mktemp -t verify-build.XXXXXX)
# 源码级 warning/error 才算数：匹配 <file>.swift|m|mm|h:<line>:<col>: warning|error:
# 其他（如 appintentsmetadataprocessor 的 toolchain 提示）忽略。
if make build >"$LOG" 2>&1; then
  CODE_WARNS=$(grep -cE '\.(swift|m|mm|h):[0-9]+:[0-9]+: warning: ' "$LOG" || true)
  CODE_WARNS=${CODE_WARNS:-0}
  if [ "$CODE_WARNS" -eq 0 ]; then
    TOTAL_WARNS=$(grep -cE ' warning: ' "$LOG" || true)
    TOTAL_WARNS=${TOTAL_WARNS:-0}
    NON_CODE=$((TOTAL_WARNS - CODE_WARNS))
    if [ "$NON_CODE" -gt 0 ]; then
      pass "build: 0 errors, 0 code warnings (${NON_CODE} non-code toolchain warnings ignored)"
    else
      pass "build: 0 errors, 0 warnings"
    fi
  else
    fail "build: $CODE_WARNS code warnings"
    grep -E '\.(swift|m|mm|h):[0-9]+:[0-9]+: warning: ' "$LOG" | head -5 | sed 's/^/      /'
  fi
else
  fail "build: xcodebuild exited non-zero"
  tail -20 "$LOG" | sed 's/^/      /'
fi
rm -f "$LOG"

# ── 2. code rules (grep) ─────────────────────────────────
echo
echo "2. code rules"

TB=$(grep -nE 'try!' $SRC 2>/dev/null || true)
if [ -z "$TB" ]; then pass "no try!"; else fail "try! found"; printf '%s\n' "$TB" | sed 's/^/      /'; fi

AB=$(grep -nE '\bas![^=]' $SRC 2>/dev/null || true)
if [ -z "$AB" ]; then pass "no as!"; else fail "as! found"; printf '%s\n' "$AB" | sed 's/^/      /'; fi

BT=$(grep -nE '//[[:space:]]*TODO:' $SRC 2>/dev/null \
     | grep -vE '//[[:space:]]*TODO:[[:space:]]*\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' || true)
if [ -z "$BT" ]; then
  pass "TODO format: all match // TODO: [YYYY-MM-DD]"
else
  fail "TODO format violations"
  printf '%s\n' "$BT" | sed 's/^/      /'
fi

APPLE='^(SwiftUI|Foundation|AppKit|Combine|ImageIO|UniformTypeIdentifiers|CoreGraphics|CoreImage|CoreText|CoreFoundation|CoreServices|OSLog|Security|IOKit|QuartzCore|Metal|AVFoundation|AVKit|MapKit|PhotosUI|Photos|PDFKit|WebKit|StoreKit|LocalAuthentication|AuthenticationServices|Network|NetworkExtension|SystemConfiguration|UserNotifications|EventKit|Contacts|Intents|CoreLocation|CoreBluetooth|CoreMotion|CoreML|Vision|NaturalLanguage|Speech|Accelerate|simd|os|Darwin|Dispatch|XCTest)$'
IMPS=$(grep -hE '^import ' $SRC 2>/dev/null | awk '{print $2}' | sort -u)
BAD_IMPS=$(printf '%s\n' "$IMPS" | grep -vE "$APPLE" | grep -v '^$' || true)
if [ -z "$BAD_IMPS" ]; then
  NUM=$(printf '%s\n' "$IMPS" | sed '/^$/d' | wc -l | tr -d ' ')
  pass "imports: Apple frameworks only ($NUM unique)"
else
  fail "non-Apple imports"
  printf '%s\n' "$BAD_IMPS" | sed 's/^/      /'
fi

VIEWER_FILES=""
[ -d ISeeImageViewer/QuickViewer ] && VIEWER_FILES="$VIEWER_FILES $(ls ISeeImageViewer/QuickViewer/*.swift 2>/dev/null)"
[ -d ISeeImageViewer/ImageViewer ] && VIEWER_FILES="$VIEWER_FILES $(ls ISeeImageViewer/ImageViewer/*.swift 2>/dev/null)"
if [ -n "$(echo $VIEWER_FILES | tr -d ' ')" ]; then
  SP=$(grep -nE '\.spring\(' $VIEWER_FILES 2>/dev/null || true)
  if [ -z "$SP" ]; then
    pass ".spring: none in viewer-family files"
  else
    fail ".spring in viewer files (use DS.Anim.*)"
    printf '%s\n' "$SP" | sed 's/^/      /'
  fi
fi

IPV=ISeeImageViewer/ImageViewer/ImagePreviewView.swift
if [ -f "$IPV" ]; then
  HC=$(grep -nE 'Color\.(white|black)\b|\.foregroundColor\(\.(white|black)\)|\.foregroundStyle\(\.(white|black)\)' "$IPV" 2>/dev/null || true)
  if [ -z "$HC" ]; then
    pass "ImagePreviewView: no hardcoded .white/.black"
  else
    fail "ImagePreviewView: hardcoded .white/.black"
    printf '%s\n' "$HC" | sed 's/^/      /'
  fi
fi

# ── 3. doc sync ──────────────────────────────────────────
echo
echo "3. doc sync"

RM=specs/Roadmap.md
if [ -f "$RM" ]; then
  MH=$(awk '
    /^## 已完成模块/ { i=1; next }
    /^## / && i { i=0 }
    i && /^\| / && !/^\| 模块/ && !/^\|---/ && !/^\|:---/ {
      n=split($0, a, "|"); if (n<5) next
      h=a[4]; gsub(/^ +| +$/, "", h)
      if (h=="" || h !~ /^[0-9a-f]{6,}$/) print NR": "a[2]"—hash=["h"]"
    }
  ' "$RM")
  if [ -z "$MH" ]; then
    pass "Roadmap 已完成 rows have commit hashes"
  else
    fail "Roadmap rows missing hash"
    printf '%s\n' "$MH" | sed 's/^/      /'
  fi

  MS=$(awk -F'|' '/^## 已完成模块/{i=1;next} /^## /&&i{i=0} i&&/^\|/&&!/^\| 模块/&&!/^\|---/&&!/^\|:---/{s=$3;gsub(/^ +| +$/,"",s); if(s~/\.md$/) print s}' "$RM" | sort -u)
  MISSING=""
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    if [ ! -f "specs/$s" ] && [ ! -f "docs/archive/$s" ]; then
      MISSING="$MISSING$s\n"
    fi
  done <<< "$MS"
  if [ -z "$MISSING" ]; then
    pass "all Roadmap-referenced specs exist"
  else
    fail "missing specs"
    printf '%b' "$MISSING" | sed 's/^/      /'
  fi
else
  fail "$RM not found"
fi

# ── 4. git hygiene ───────────────────────────────────────
echo
echo "4. git hygiene"
HP=$(git config --get core.hooksPath 2>/dev/null || echo "")
if [ "$HP" = ".githooks" ]; then
  pass "core.hooksPath=.githooks"
else
  fail "core.hooksPath not set — run: make hooks-install"
fi
if [ -x .githooks/pre-push ]; then
  pass ".githooks/pre-push executable"
else
  fail ".githooks/pre-push not executable — run: make hooks-install"
fi

# ── 5. optional codex audit ──────────────────────────────
if [ "$WITH_CODEX" -eq 1 ]; then
  echo
  echo "5. codex full-project audit (slow)"
  if ! command -v codex >/dev/null 2>&1; then
    fail "codex binary not found"
  else
    RF=$(mktemp -t verify-codex.XXXXXX)
    TO=""
    command -v timeout >/dev/null 2>&1 && TO="timeout 600"
    PROMPT='Audit the current working tree of ISeeImageViewer against CLAUDE.md + specs/UI.md hard rules. Output ONLY issues, one per line:
[P1|P2] <path>:<line> — <issue>
If no issues: output exactly: CLEAN

Focus on: force unwrap / magic numbers / single public type per file / TODO format / non-Apple imports / async-await compliance / DS.* usage in UI constants / .spring in viewer-family / hardcoded .white or .black in ImagePreviewView / QuickViewerOverlay dark-only colors.'
    if $TO codex exec -s read-only --ephemeral --color never \
        -o "$RF" -c 'model_reasoning_effort="high"' "$PROMPT" >/dev/null 2>&1; then
      R=$(cat "$RF")
      if [ -z "$R" ]; then
        fail "codex returned empty output"
      elif printf '%s\n' "$R" | grep -q '\[P1\]'; then
        fail "codex found [P1] issues"
        printf '%s\n' "$R" | sed 's/^/      /'
      elif printf '%s\n' "$R" | grep -q '\[P2\]'; then
        pass "codex: no [P1]"
        echo "      [P2] warnings:"
        printf '%s\n' "$R" | grep '\[P2\]' | sed 's/^/        /'
      else
        pass "codex: CLEAN"
      fi
    else
      fail "codex exec failed or timed out"
    fi
    rm -f "$RF"
  fi
fi

echo
echo "=== summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
