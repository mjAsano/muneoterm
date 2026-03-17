# 아키텍처 문서

## 개요

MuneoTerm은 SwiftUI와 AppKit을 혼합 사용하는 macOS 네이티브 터미널 에뮬레이터입니다. SwiftUI가 전체 앱 프레임워크와 상위 UI를 담당하고, AppKit(NSView)이 터미널 렌더링과 분할 레이아웃의 세밀한 제어를 담당합니다.

## 레이어 구조

```
┌─────────────────────────────────────────────┐
│  SwiftUI Layer                              │
│  App.swift, MainWindowView, TabBarView,     │
│  SettingsView                               │
├─────────────────────────────────────────────┤
│  Bridge Layer                               │
│  SplitContainerRepresentable                │
│  (NSViewRepresentable)                      │
├─────────────────────────────────────────────┤
│  AppKit Layer                               │
│  SplitContainerNSView, SplitPairView,       │
│  DividerView, TerminalPanelWrapper          │
├─────────────────────────────────────────────┤
│  Terminal Engine                             │
│  SwiftTerm (LocalProcessTerminalView)       │
└─────────────────────────────────────────────┘
```

## 핵심 컴포넌트

### 1. AppState (중앙 상태 관리)

**파일**: `Sources/State/AppState.swift`

앱 전체의 단일 진실 소스(Single Source of Truth)입니다. `@Observable` 매크로를 사용하는 싱글턴으로, 모든 뷰가 이 상태를 관찰합니다.

**주요 책임**:
- 탭 배열(`tabs`) 관리 - 생성, 삭제, 전환
- 활성 세션(`activeSessionID`) 추적
- 분할/닫기/네비게이션 동작 조율
- 현재 테마 관리
- `TerminalSessionManager`를 통한 세션 생명주기 위임

**상태 흐름**:
```
사용자 입력 (키보드/마우스)
    → AppState 메서드 호출
    → SplitNode 트리 변경
    → SwiftUI 뷰 자동 업데이트
    → SplitContainerNSView 재구성
```

### 2. SplitNode (이진 트리 레이아웃)

**파일**: `Sources/Models/SplitNode.swift`

패널 레이아웃을 재귀적 이진 트리로 표현하는 `indirect enum`입니다.

```swift
enum SplitNode {
    case leaf(sessionID: UUID)
    case split(first: SplitNode, second: SplitNode, axis: Axis, ratio: CGFloat)
}
```

**트리 구조 예시** (2x2 레이아웃):
```
split(vertical, 0.5)
├── split(horizontal, 0.5)
│   ├── leaf(A)
│   └── leaf(B)
└── split(horizontal, 0.5)
    ├── leaf(C)
    └── leaf(D)
```

**핵심 연산**:
- `splitLeaf()`: 리프 노드를 찾아 분할 노드로 교체
- `removeLeaf()`: 리프 노드 제거 후 형제 노드를 부모 위치로 승격
- `updateRatio()`: 분할 비율 변경
- `navigateFrom()`: 2D 그리드 기반 방향 네비게이션
- `allSessionIDs`: 모든 리프의 세션 ID 수집

### 3. TerminalSessionManager (세션 관리)

**파일**: `Sources/State/TerminalSessionManager.swift`

터미널 세션의 생성과 소멸을 관리합니다.

**주요 책임**:
- `LocalProcessTerminalView` 인스턴스 생성
- 셸 프로세스 시작 (PTY 할당)
- 테마 적용 (색상, 폰트, ANSI 팔레트)
- 델리게이트를 통한 프로세스 종료 감지
- 명령 브로드캐스트 (Claude 8x 기능)

**세션 생명주기**:
```
createSession()
    → LocalProcessTerminalView 생성
    → 테마 적용 (색상, 폰트, ANSI 팔레트 변환)
    → 셸 프로세스 시작 (startProcess)
    → SessionInfo에 저장
    → ... 사용 중 ...
    → processTerminated (델리게이트 콜백)
    → 패널 닫기 시 제거
```

### 4. 뷰 계층

#### MainWindowView
메인 윈도우의 루트 뷰. `TabBarView`와 `SplitContainerRepresentable`을 수직으로 배치합니다.

#### TabBarView
탭 목록, 새 탭 버튼(+), Claude 8x 버튼을 수평으로 배치합니다. 각 탭은 `TabItemView`로 렌더링되며, 호버 시 닫기 버튼이 표시됩니다.

#### SplitContainerRepresentable (브릿지)
`NSViewRepresentable` 프로토콜을 구현하여 SwiftUI와 AppKit를 연결합니다. `SplitNode` 트리가 변경되면 `updateNSView()`에서 `SplitContainerNSView`를 재구성합니다.

#### SplitContainerNSView
`SplitNode` 트리를 재귀적으로 순회하여 NSView 계층을 구성합니다.

- `.leaf` → `TerminalPanelWrapper` (터미널 뷰 래퍼)
- `.split` → `SplitPairView` (두 자식 + 구분선)

#### SplitPairView + DividerView
두 자식 뷰와 드래그 가능한 구분선으로 구성됩니다. `DividerView`는 1px 시각적 너비에 8px 히트 영역을 가지며, 마우스 드래그로 분할 비율을 실시간 조절합니다.

#### TerminalPanelWrapper
터미널 뷰를 감싸는 데코레이션 뷰입니다. 활성 상태에 따라 테두리 색상이 변경되며, 마우스 클릭으로 해당 세션을 활성화합니다.

## 데이터 흐름

### 패널 분할 흐름
```
1. 사용자: Cmd+D 입력
2. App.swift TerminalCommands → AppState.splitCurrentPanel(.horizontal)
3. AppState: 현재 활성 세션의 SplitNode.leaf를 찾아 .split으로 교체
4. AppState: TerminalSessionManager.createSession()으로 새 세션 생성
5. SwiftUI: @Observable 변경 감지 → SplitContainerRepresentable.updateNSView()
6. SplitContainerNSView: NSView 트리 재구성
7. 결과: 기존 패널 옆에 새 터미널 패널 표시
```

### 테마 적용 흐름
```
1. 사용자: 설정에서 테마 선택
2. AppState.currentTheme 변경
3. TerminalSessionManager: 모든 활성 세션에 새 테마 적용
4. 각 LocalProcessTerminalView: 배경색, 전경색, ANSI 팔레트 업데이트
5. ANSI 색상: CGFloat(0.0~1.0) → SwiftTerm UInt16(0~65535) 변환
```

## 영속성

| 대상 | 방식 | 경로 |
|---|---|---|
| 탭 레이아웃 | JSON (SessionStore) | `~/Library/Application Support/HosunTerminal/session.json` |
| 커스텀 테마 | JSON 파일 (ThemeManager) | `~/Library/Application Support/HosunTerminal/Themes/*.json` |
| 윈도우 크기/위치 | macOS 기본 (WindowGroup) | 시스템 관리 |

## 메모리 관리

- 델리게이트에서 `weak` 참조 사용으로 순환 참조 방지
- `TerminalPanelWrapper`를 세션 ID별로 캐싱하여 재사용
- NSView 트리 재구성 시 이전 래퍼 정리
