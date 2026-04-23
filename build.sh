#!/bin/bash
# Alpha Cycle 빌드 스크립트
# .env 파일에서 API 키를 읽어 빌드합니다.

set -e

# .env 파일 로드
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env 파일이 없습니다."
  echo ".env.example을 복사해서 .env를 만들어주세요:"
  echo "  cp .env.example .env"
  exit 1
fi

# 키 확인
if [ -z "$FINNHUB_API_KEY" ] || [ -z "$TWELVE_DATA_API_KEY" ] || [ -z "$MARKETAUX_API_KEY" ]; then
  echo "Error: .env에 API 키가 비어있습니다."
  exit 1
fi

echo "Building Alpha Cycle (release)..."

/home/dandy02/flutter/bin/flutter build web --release --pwa-strategy=offline-first \
  --dart-define=FINNHUB_API_KEY=$FINNHUB_API_KEY \
  --dart-define=TWELVE_DATA_API_KEY=$TWELVE_DATA_API_KEY \
  --dart-define=MARKETAUX_API_KEY=$MARKETAUX_API_KEY \
  --dart-define=DEEPL_API_KEY=$DEEPL_API_KEY \
  --dart-define=FRED_API_KEY=$FRED_API_KEY \
  --dart-define=FMP_API_KEY=$FMP_API_KEY \
  ${PROXY_BASE_URL:+--dart-define=PROXY_BASE_URL=$PROXY_BASE_URL} \
  ${APP_TOKEN:+--dart-define=APP_TOKEN=$APP_TOKEN} \
  ${VAPID_PUBLIC_KEY:+--dart-define=VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY}

# Push notification 핸들러를 Service Worker에 추가
if [ -f web/push-sw-handlers.js ]; then
  cat web/push-sw-handlers.js >> build/web/flutter_service_worker.js
  echo "Push handlers appended to flutter_service_worker.js"

  # Verify push handler was appended successfully
  # (set -e 하에서 grep 실패가 바로 exit 되지 않도록 if 조건으로 감쌈)
  if ! grep -q "addEventListener('push'" build/web/flutter_service_worker.js; then
    echo "ERROR: Push handler missing from built SW — build failed" >&2
    exit 1
  fi
  echo "[build] Push handler verified in SW"
fi

echo "Build complete! Run with: python3 serve_nocache.py 8080"
