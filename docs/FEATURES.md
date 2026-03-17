# 기능 상세 문서

## 1. 터미널 에뮬레이션

### 핵심 엔진
- **SwiftTerm** 라이브러리의 `LocalProcessTerminalView`를 사용
- xterm-256color 터미널 타입으로 동작
- 사용자의 기본 셸(`$SHELL` 환경변수)을 자동 감지하여 실행
- 셸 미설정 시 `/bin/zsh`를 기본값으로 사용

### PTY 관리
- 각 터미널 패널마다 독립적인 PTY(의사 터미널) 할당
- 부모 프로세스의 환경변수 상속
- `TERM` 환경변수를 `xterm-256color`로 오버라이드

### 프로세스 생명주기
- 셸 프로세스 시작 시 `startProcess()` 호출
- 프로세스 종료 감지: `TerminalSessionDelegate.processTerminated()` 콜백
- 터미널 제목 변경: 셸의 이스케이프 시퀀스를 통해 자동 업데이트

---

## 2. 다중 탭 시스템

### 탭 모델 (`TabModel`)
```swift
struct TabModel: Identifiable {
    let id: UUID
    var title: String
    var rootNode: SplitNode      // 이 탭의 분할 레이아웃 트리
    var activeSessionID: UUID?   // 이 탭에서 활성화된 세션
}
```

### 기능
| 동작 | 단축키 | 설명 |
|---|---|---|
| 새 탭 생성 | `Cmd+T` | 기본 8패널(2x4) 레이아웃으로 생성 |
| 다음 탭 | `Cmd+Shift+]` | 순환 이동 |
| 이전 탭 | `Cmd+Shift+[` | 순환 이동 |
| 탭 닫기 | - | 마지막 패널 닫기 시 자동 |

### 동작 규칙
- 각 탭은 완전히 독립적인 분할 레이아웃 보유
- 탭 전환 시 해당 탭의 `rootNode`와 `activeSessionID`로 복원
- 모든 탭이 닫히면 새 탭을 자동 생성 (빈 상태 방지)
- 탭 바는 스크롤 가능하여 많은 수의 탭 지원

---

## 3. 분할 패널 시스템

### SplitNode 이진 트리

패널 레이아웃은 재귀적 이진 트리(`SplitNode`)로 표현됩니다.

```
indirect enum SplitNode {
    case leaf(sessionID: UUID)
    case split(first: SplitNode, second: SplitNode, axis: Axis, ratio: CGFloat)
}
```

### 분할 동작

| 동작 | 단축키 | 결과 |
|---|---|---|
| 수평 분할 | `Cmd+D` | 현재 패널을 좌/우로 분할 |
| 수직 분할 | `Cmd+Shift+D` | 현재 패널을 상/하로 분할 |
| 패널 닫기 | `Cmd+W` | 현재 패널 제거, 형제 노드 승격 |

### 제한 사항
- 탭당 최대 **16개** 패널
- 패널 최소 크기: **80px**
- 분할 비율: 0.0~1.0 범위, 기본값 0.5

### 드래그 가능한 구분선
- **시각적 너비**: 1px
- **인터랙션 영역**: 8px (쉬운 드래그를 위해)
- 수평 분할 시: 좌우 리사이즈 커서
- 수직 분할 시: 상하 리사이즈 커서
- 드래그 중 실시간 레이아웃 업데이트

### 기본 시작 레이아웃
앱 시작 시 **2행 x 4열** (총 8패널) 레이아웃을 자동 생성합니다.

```
┌──────┬──────┬──────┬──────┐
│  1   │  2   │  3   │  4   │
├──────┼──────┼──────┼──────┤
│  5   │  6   │  7   │  8   │
└──────┴──────┴──────┴──────┘
```

---

## 4. 패널 네비게이션

### 번호 직접 이동
- `Cmd+1` ~ `Cmd+8`: 패널 번호로 즉시 이동
- 패널 번호는 `allSessionIDs` 배열의 인덱스 순서

### 2D 방향 네비게이션
- `Cmd+Option+←`: 왼쪽 패널
- `Cmd+Option+→`: 오른쪽 패널
- `Cmd+Option+↑`: 위쪽 패널
- `Cmd+Option+↓`: 아래쪽 패널
- 최대 4열 기준 그리드 계산, 가장자리에서 순환 이동

### 순차 네비게이션
- `Ctrl+Tab`: 다음 패널 (리프 순서)
- `Ctrl+Shift+Tab`: 이전 패널 (리프 순서)

### 활성 패널 표시
- **활성 패널**: 2px 악센트 색상 테두리 (60% 불투명도)
- **비활성 패널**: 1px 구분선 색상 테두리 (20% 불투명도)
- 패널 모서리 반경: 2px

---

## 5. 테마 시스템

### 내장 테마

| 테마명 | 특징 |
|---|---|
| **Default Dark** | 다크 배경(#1E1E2E), 밝은 전경(#CDD6F4) |
| **Ocean** | 깊은 남색 배경(#0A1628), 은색 전경(#C0C8D8) |
| **Monokai** | 클래식 Monokai 색상 팔레트 |

### Theme 모델
```swift
struct Theme {
    var name: String
    var backgroundColor: (CGFloat, CGFloat, CGFloat, CGFloat)  // RGBA
    var foregroundColor: (CGFloat, CGFloat, CGFloat, CGFloat)
    var cursorColor: (CGFloat, CGFloat, CGFloat, CGFloat)
    var selectionColor: (CGFloat, CGFloat, CGFloat, CGFloat)
    var ansiColors: [(CGFloat, CGFloat, CGFloat, CGFloat)]     // 16색 ANSI 팔레트
    var fontName: String
    var fontSize: CGFloat
    var backgroundOpacity: CGFloat
}
```

### 커스텀 테마 생성

**경로**: `~/Library/Application Support/HosunTerminal/Themes/`

JSON 파일 형식:
```json
{
  "name": "테마 이름",
  "backgroundColor": [R, G, B, A],
  "foregroundColor": [R, G, B, A],
  "cursorColor": [R, G, B, A],
  "selectionColor": [R, G, B, A],
  "ansiColors": [
    [R, G, B, A],   // 0: Black
    [R, G, B, A],   // 1: Red
    [R, G, B, A],   // 2: Green
    [R, G, B, A],   // 3: Yellow
    [R, G, B, A],   // 4: Blue
    [R, G, B, A],   // 5: Magenta
    [R, G, B, A],   // 6: Cyan
    [R, G, B, A],   // 7: White
    [R, G, B, A],   // 8: Bright Black
    [R, G, B, A],   // 9: Bright Red
    [R, G, B, A],   // 10: Bright Green
    [R, G, B, A],   // 11: Bright Yellow
    [R, G, B, A],   // 12: Bright Blue
    [R, G, B, A],   // 13: Bright Magenta
    [R, G, B, A],   // 14: Bright Cyan
    [R, G, B, A]    // 15: Bright White
  ],
  "fontName": "MesloLGS-Regular",
  "fontSize": 13.0,
  "backgroundOpacity": 1.0
}
```

### ANSI 색상 변환
SwiftTerm은 16비트 색상값(0~65535)을 사용합니다. Theme의 CGFloat(0.0~1.0) 값은 자동 변환됩니다:
```
SwiftTerm UInt16 = CGFloat × 65535
```

---

## 6. Claude 8x 일괄 실행

### 기능
탭 바의 **"Claude 8x"** 버튼을 클릭하면, 현재 탭의 모든 터미널 패널에 Claude AI 명령을 동시에 전송합니다.

### 동작 흐름
1. 버튼 클릭
2. `AppState.broadcastClaudeToActiveTab()` 호출
3. 현재 탭의 `rootNode`에서 모든 세션 ID 수집
4. 각 세션의 `LocalProcessTerminalView`에 명령 문자열 전송
5. 전송 명령: `claude --dangerously-skip-permissions\n`

### UI
- 주황색 배경의 버튼
- 탭 바 우측에 위치

---

## 7. 설정 화면

### 외관 (Appearance)
- 사용 가능한 테마 목록 표시
- 각 테마의 색상 미리보기 (40x30px 색상 샘플에 "A" 문자)
- 테마 선택 시 즉시 적용

### 폰트 (Font)
- 현재 활성 테마의 폰트 이름 표시
- 현재 활성 테마의 폰트 크기 표시
- 폰트 변경은 테마 설정을 통해 수행

### 단축키 (Shortcuts)
- 전체 키보드 바인딩을 카테고리별로 정리하여 표시
- 참조 전용 (변경 불가)

---

## 8. 세션 영속성

### SessionStore
**저장 경로**: `~/Library/Application Support/HosunTerminal/session.json`

### 저장 데이터
- 탭 배열의 구조 정보
- 각 탭의 `SplitNode` 트리 구조
- 분할 비율 정보

### 복구 메커니즘
- JSON 파싱 실패 시 자동으로 파일 삭제
- 손상된 세션 파일에 대한 안전한 폴백
- 파일 없음 상태는 정상 처리 (새 세션 시작)

---

## 9. 윈도우 설정

| 속성 | 값 |
|---|---|
| 기본 크기 | 1000 x 700 px |
| 최소 크기 | 600 x 400 px |
| 타이틀 바 | 숨김 |
| 배경 | 반투명 (Ultra Thin Material) |
| 마지막 윈도우 닫기 | 앱 종료 |
