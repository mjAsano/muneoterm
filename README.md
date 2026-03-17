# MuneoTerm (8hosun Terminal)

SwiftUI + AppKit 기반 macOS 네이티브 터미널 에뮬레이터. 다중 탭, 분할 패널, 테마 커스터마이징, 그리고 Claude AI 일괄 실행 기능을 지원합니다.

## 시스템 요구사항

- macOS 14.0 (Sonoma) 이상
- Swift 5.9+
- Xcode 15+

## 빌드 & 실행

```bash
# 빌드
swift build

# 실행
swift run

# Xcode에서 열기
open Package.swift
```

## 주요 기능

### 터미널 에뮬레이션
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 기반 완전한 터미널 에뮬레이션
- xterm-256color 지원
- 사용자 기본 셸 자동 감지 (`$SHELL`, 기본값 `/bin/zsh`)
- PTY(의사 터미널) 관리 및 환경 변수 설정

### 다중 탭 시스템
| 단축키 | 기능 |
|---|---|
| `Cmd+T` | 새 탭 생성 |
| `Cmd+Shift+]` | 다음 탭 |
| `Cmd+Shift+[` | 이전 탭 |

- 각 탭은 독립적인 분할 레이아웃 유지
- 마지막 탭을 닫으면 새 탭 자동 생성

### 분할 패널
| 단축키 | 기능 |
|---|---|
| `Cmd+D` | 수평 분할 (좌/우) |
| `Cmd+Shift+D` | 수직 분할 (상/하) |
| `Cmd+W` | 현재 패널 닫기 |

- 탭당 최대 16개 패널
- 드래그로 분할 비율 조절 (패널 최소 80px)
- 이진 트리 구조로 자유로운 레이아웃 구성
- 기본 시작 레이아웃: 2행 x 4열 (8패널)

### 패널 네비게이션
| 단축키 | 기능 |
|---|---|
| `Cmd+1` ~ `Cmd+8` | 패널 번호로 직접 이동 |
| `Cmd+Option+←/→` | 좌/우 패널 이동 |
| `Cmd+Option+↑/↓` | 상/하 패널 이동 |
| `Ctrl+Tab` | 다음 패널 |
| `Ctrl+Shift+Tab` | 이전 패널 |

- 활성 패널은 색상 테두리로 강조 표시

### 테마 시스템
- **내장 테마**: Default Dark, Ocean, Monokai
- **커스텀 테마**: JSON 파일로 사용자 정의 테마 추가 가능
- **커스터마이징 가능 항목**: 배경색, 전경색, 커서색, 선택 영역색, 16색 ANSI 팔레트, 폰트, 배경 투명도
- 테마 파일 경로: `~/Library/Application Support/HosunTerminal/Themes/`

### Claude 8x 일괄 실행
- 탭 바의 **"Claude 8x"** 버튼 클릭
- 현재 탭의 모든 패널에 `claude --dangerously-skip-permissions` 명령 동시 전송
- 8개 터미널에서 Claude AI를 병렬 실행

### 설정 (Preferences)
- **외관**: 테마 선택 및 미리보기
- **폰트**: 현재 폰트 정보 표시
- **단축키**: 전체 키보드 바인딩 참조

### 세션 저장/복원
- 탭 레이아웃 구조를 JSON으로 자동 저장
- 저장 경로: `~/Library/Application Support/HosunTerminal/session.json`
- 손상된 세션 파일 자동 복구

## 프로젝트 구조

```
Sources/
├── App.swift                          # 앱 진입점, AppDelegate, 메뉴 커맨드
├── Models/
│   ├── SplitNode.swift                # 분할 레이아웃 이진 트리 모델
│   ├── TabModel.swift                 # 탭 데이터 모델
│   └── Theme.swift                    # 테마 정의 (색상, 폰트, ANSI 팔레트)
├── Services/
│   ├── SessionStore.swift             # 세션 저장/복원 (JSON 파일 I/O)
│   └── ThemeManager.swift             # 테마 로딩 (내장 + 커스텀)
├── State/
│   ├── AppState.swift                 # 중앙 상태 관리 (@Observable 싱글턴)
│   └── TerminalSessionManager.swift   # 터미널 세션 생명주기 관리
└── Views/
    ├── AppKit/
    │   ├── SplitContainerNSView.swift # AppKit 분할 컨테이너 (NSView 트리 구성)
    │   └── SplitPairView.swift        # 이중 분할 뷰 + 드래그 가능한 구분선
    ├── MainWindowView.swift           # 메인 윈도우 (탭바 + 터미널 영역)
    ├── SettingsView.swift             # 설정 화면 (외관/폰트/단축키)
    ├── SplitContainerRepresentable.swift # SwiftUI ↔ AppKit 브릿지
    └── TabBarView.swift               # 탭 바 UI (탭 목록 + Claude 8x 버튼)
```

## 의존성

| 패키지 | 버전 | 용도 |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.2.0+ | 터미널 에뮬레이션, PTY 관리, 텍스트 렌더링 |

## 아키텍처

```
AppState (싱글턴, @Observable)
├── tabs: [TabModel]
│   └── rootNode: SplitNode (이진 트리)
│       └── .leaf(sessionID) | .split(first, second, axis, ratio)
├── TerminalSessionManager
│   └── sessions: [UUID: SessionInfo]
│       └── LocalProcessTerminalView + Delegate
└── currentTheme: Theme

뷰 계층:
MainWindowView (SwiftUI)
├── TabBarView
└── SplitContainerRepresentable (SwiftUI → AppKit 브릿지)
    └── SplitContainerNSView
        └── SplitPairView (재귀적 구성)
            └── TerminalPanelWrapper → LocalProcessTerminalView
```

## 커스텀 테마 만들기

`~/Library/Application Support/HosunTerminal/Themes/` 경로에 JSON 파일을 생성합니다.

```json
{
  "name": "My Theme",
  "backgroundColor": [0.1, 0.1, 0.1, 1.0],
  "foregroundColor": [0.9, 0.9, 0.9, 1.0],
  "cursorColor": [1.0, 1.0, 1.0, 1.0],
  "selectionColor": [0.3, 0.3, 0.5, 0.5],
  "ansiColors": [
    [0.0, 0.0, 0.0, 1.0],
    [0.8, 0.0, 0.0, 1.0],
    ...
  ],
  "fontName": "MesloLGS-Regular",
  "fontSize": 13.0,
  "backgroundOpacity": 1.0
}
```

색상값은 `[R, G, B, A]` 형식이며, 각 값은 0.0~1.0 범위입니다.

## 라이선스

MIT License
