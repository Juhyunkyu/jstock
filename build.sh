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
  --dart-define=MARKETAUX_API_KEY=$MARKETAUX_API_KEY

echo "Build complete! Run with: python3 serve_nocache.py 8080"
