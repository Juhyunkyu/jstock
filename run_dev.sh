#!/bin/bash
# Alpha Cycle 개발 서버 실행 스크립트
# Flutter 웹 앱을 릴리즈 빌드로 실행합니다.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   알파 사이클 개발 서버 시작${NC}"
echo -e "${BLUE}========================================${NC}"

# 기존 프로세스 종료
cleanup() {
    echo -e "\n${YELLOW}서버 종료 중...${NC}"
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
    fi
    # 남은 프로세스도 정리
    pkill -f "python3 -m http.server 8080" 2>/dev/null || true
    echo -e "${GREEN}종료 완료${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 이미 실행 중인 프로세스 종료
echo -e "${YELLOW}기존 프로세스 정리 중...${NC}"
pkill -f "python3 -m http.server 8080" 2>/dev/null || true
sleep 1

# Flutter 경로 찾기
FLUTTER_PATH=""
if [ -f "$HOME/flutter/bin/flutter" ]; then
    FLUTTER_PATH="$HOME/flutter/bin/flutter"
elif command -v flutter &> /dev/null; then
    FLUTTER_PATH="flutter"
elif [ -f "/opt/flutter/bin/flutter" ]; then
    FLUTTER_PATH="/opt/flutter/bin/flutter"
else
    echo -e "${RED}Flutter를 찾을 수 없습니다.${NC}"
    exit 1
fi

# 1. 릴리즈 빌드
echo -e "${GREEN}[1/2] Flutter 웹 앱 빌드 중...${NC}"
echo -e "${YELLOW}  (최초 실행 시 1-2분 소요)${NC}"
$FLUTTER_PATH build web --release

if [ $? -ne 0 ]; then
    echo -e "${RED}  ✗ 빌드 실패${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ 빌드 완료${NC}"

# 2. 정적 파일 서버 시작
echo -e "${GREEN}[2/2] 웹 서버 시작 (포트 8080)...${NC}"
cd "$PROJECT_DIR/build/web"
python3 -m http.server 8080 &
SERVER_PID=$!
sleep 2

# 서버 헬스 체크
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 웹 서버 정상 작동${NC}"
else
    echo -e "${RED}  ✗ 웹 서버 시작 실패${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  서버 시작 완료!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  ${GREEN}앱 URL:${NC}  http://localhost:8080"
echo ""
echo -e "  ${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
echo ""

# 프로세스 유지
wait $SERVER_PID
