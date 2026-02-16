# 알파 사이클 (Alpha Cycle) 프로젝트 지침

## 빌드 방법

**반드시 `./build.sh`를 사용할 것** — API 키를 `.env`에서 읽어 `--dart-define`으로 주입합니다.

```bash
# 빌드 (API 키 자동 주입)
./build.sh

# 서버 시작 (Playwright 캐시 문제 방지)
python3 /home/dandy02/possible/stocktrading/serve_nocache.py 8080 &
```

### 코드 수정 후
코드를 수정할 때마다 빌드를 다시 해야 합니다:
```bash
./build.sh
```

### API 키 관리
- API 키는 `.env` 파일에 저장 (gitignore됨, GitHub에 올라가지 않음)
- `.env.example`은 키 템플릿 (Git에 포함)
- `app_config.dart`의 defaultValue는 빈 문자열 — `.env` 없이 빌드하면 API 미작동

### 절대 하지 말 것
- `app_config.dart`에 API 키 직접 하드코딩 금지
- `python3 -m http.server` 사용 금지 (Playwright MCP 캐시 문제)
- `flutter build web` 직접 호출 금지 (API 키 누락됨) → 반드시 `./build.sh` 사용

## Flutter Web + Playwright MCP 사용 지침

### 왜 릴리즈 빌드인가?
- `flutter run -d chrome`: Playwright와 호환 안됨
- `flutter run -d web-server`: DDC 컴파일러 → 스크립트 에러
- `flutter build web --release`: 정적 파일 → 모든 브라우저 동일 동작 ✅

### 주의사항
- Hot Reload 사용 불가 (매번 빌드 필요)
- 웹 서버(8080번 포트)가 실행 중이어야 앱 접속 가능
- **반드시 `serve_nocache.py`를 사용할 것**

## 프로젝트 구조
- Flutter Web 앱 (Riverpod 상태관리)
- Hive (IndexedDB) 로컬 저장소
- **Finnhub API** (실시간 WebSocket + REST API)
- **Twelve Data API** (차트 OHLC 데이터)
- **open.er-api.com + Frankfurter** (환율)
- **MarketAux + MyMemory** (뉴스 + 번역)
- **CNN Fear & Greed** (공포탐욕지수)
- go_router 라우팅

## Flutter 명령어
이 프로젝트에서는 Flutter 전체 경로 사용:
```bash
/home/dandy02/flutter/bin/flutter [명령어]
```
