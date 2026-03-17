# 문어텀 iOS — 원격 컨트롤러 앱 기획

## 컨셉
**"주머니 속의 8개 AI"** — Mac에서 돌아가는 문어텀 8분할 Claude 세션을 iPhone/iPad에서 실시간 모니터링하고 제어하는 원격 앱.

## 핵심 제약
- iOS에서는 PTY/fork 불가 (Apple 정책)
- 따라서 **Mac = 서버, iOS = 클라이언트** 구조 필수
- SwiftTerm에 `iOSTerminalView` 이미 존재 → 렌더링 재활용 가능

---

## 아키텍처

```
┌─────────────────────────────────┐     ┌──────────────────────────┐
│        Mac (문어텀 서버)          │     │     iOS (문어텀 리모트)     │
│                                 │     │                          │
│  ┌───────────┐  ┌────────────┐  │     │  ┌────────────────────┐  │
│  │ PTY Shell │  │ PTY Shell  │  │     │  │  iOSTerminalView   │  │
│  │ (x8)      │  │ Manager    │  │     │  │  (SwiftTerm)       │  │
│  └─────┬─────┘  └──────┬─────┘  │     │  └────────┬───────────┘  │
│        │               │        │     │           │              │
│  ┌─────▼───────────────▼─────┐  │     │  ┌────────▼───────────┐  │
│  │     MuneoServer           │  │     │  │   MuneoClient      │  │
│  │  - WebSocket Server       │◀─┼─────┼─▶│  - WebSocket Client│  │
│  │  - Terminal Output Stream │  │     │  │  - Input Relay     │  │
│  │  - Input Relay            │  │ Net │  │  - State Sync      │  │
│  │  - State Sync             │  │     │  └────────────────────┘  │
│  └───────────────────────────┘  │     │                          │
│                                 │     │  ┌────────────────────┐  │
│  ┌───────────────────────────┐  │     │  │  8-Panel Grid View │  │
│  │  Bonjour Advertisement    │  │     │  │  Tab Bar           │  │
│  │  (자동 디스커버리)          │  │     │  │  Command Input     │  │
│  └───────────────────────────┘  │     │  └────────────────────┘  │
└─────────────────────────────────┘     └──────────────────────────┘
```

## 네트워크 프로토콜 후보

| 방식 | 장점 | 단점 |
|------|------|------|
| **Bonjour + WebSocket** | 자동 디스커버리, 로컬 빠름 | 같은 네트워크만 |
| **Multipeer Connectivity** | P2P, Wi-Fi Direct 가능 | API 제한적, 대역폭 |
| **직접 WebSocket (IP)** | 단순, 원격 가능 | 수동 설정, NAT |

**추천**: Bonjour 디스커버리 + WebSocket 통신 (Phase 1은 로컬 네트워크)

---

## 공유 가능한 기존 코드

| 모듈 | 파일 | iOS 재활용 |
|------|------|-----------|
| 패널 레이아웃 모델 | `SplitNode.swift` | ✅ 그대로 |
| 탭 모델 | `TabModel.swift` | ✅ 그대로 |
| 테마 시스템 | `Theme.swift` | ✅ (NSColor → UIColor 변환 필요) |
| 네비게이션 로직 | `AppState.swift` 일부 | ✅ 2D 그리드 로직 |
| 세션 매니저 | `TerminalSessionManager.swift` | ❌ PTY 기반, 서버에만 |
| 터미널 뷰 | SwiftTerm | ✅ `iOSTerminalView` 존재 |

→ **Swift Package로 공유 모델 분리** 권장:
```
MuneoShared/
├── Models/
│   ├── SplitNode.swift
│   ├── TabModel.swift
│   └── Theme.swift
├── Protocol/
│   ├── MuneoMessage.swift    (WebSocket 메시지 타입)
│   └── StreamProtocol.swift  (터미널 출력 인코딩)
```

---

## iOS 앱 기능 (Phase별)

### Phase 1: 기본 원격 뷰어
- [ ] Bonjour로 Mac 문어텀 자동 발견
- [ ] 연결 시 8패널 상태 동기화
- [ ] 실시간 터미널 출력 스트리밍 (SwiftTerm iOS)
- [ ] 패널 탭해서 포커스 전환
- [ ] 텍스트 입력 → Mac 패널로 전송
- [ ] 탭 전환
- [ ] iPhone: 1패널 풀스크린 + 스와이프 전환
- [ ] iPad: 실제 8분할 그리드 (화면 충분)

### Phase 2: 스마트 컨트롤
- [ ] Push 알림 — Claude가 질문하면, 에러나면, 작업 완료되면
- [ ] 빠른 명령 팔레트 — 자주 쓰는 명령 즐겨찾기
- [ ] 브로드캐스트 — 전체 패널에 명령 일괄 전송
- [ ] 세션 스냅샷 — 특정 시점 터미널 상태 캡처
- [ ] 연결 끊김 시 자동 재연결 + 버퍼 재동기화

### Phase 3: 딜라이트
- [ ] Haptic feedback — 패널 전환 시 탭틱 진동
- [ ] Dynamic Island / Live Activity — 활성 Claude 수 표시
- [ ] Siri Shortcut — "문어야 전체 Claude 실행해"
- [ ] 3D Touch/Long Press — 패널 미리보기 팝업
- [ ] 홈 위젯 — 8개 패널 상태 한눈에 (Small/Medium/Large)
- [ ] Apple Watch — 작업 완료 알림 + 간단 제어

---

## WebSocket 메시지 프로토콜 (초안)

```swift
// MuneoMessage.swift (공유)
enum MuneoMessage: Codable {
    // Mac → iOS
    case sync(SyncPayload)              // 전체 상태 동기화
    case terminalOutput(SessionOutput)   // 터미널 출력 delta
    case sessionEvent(SessionEvent)      // 세션 생성/종료/타이틀 변경
    case notification(NotificationInfo)  // Push 알림 트리거

    // iOS → Mac
    case input(SessionInput)            // 키 입력
    case command(CommandRequest)         // 브로드캐스트, Claude 실행 등
    case focusPanel(PanelFocus)         // 포커스 변경
    case requestSync                    // 전체 재동기화 요청
}

struct SyncPayload: Codable {
    let tabs: [TabModel]
    let activeTabIndex: Int
    let activeSessionID: UUID
    let theme: Theme
    // 각 세션의 현재 터미널 버퍼 스냅샷
    let buffers: [UUID: Data]
}

struct SessionOutput: Codable {
    let sessionID: UUID
    let data: Data          // 터미널 출력 바이트
    let timestamp: Date
}

struct SessionInput: Codable {
    let sessionID: UUID
    let data: Data          // 키 입력 바이트
}
```

---

## Mac 서버 컴포넌트 (기존 앱에 추가)

```swift
// MuneoServer.swift (Mac 앱에 추가)
class MuneoServer {
    // Bonjour 광고
    let bonjourService: NetService

    // WebSocket 서버 (NWListener)
    let listener: NWListener

    // 터미널 출력 → WebSocket 브릿지
    func bridgeTerminalOutput(sessionID: UUID, data: Data)

    // WebSocket 입력 → PTY 릴레이
    func relayInput(sessionID: UUID, data: Data)

    // 상태 변경 → 클라이언트 동기화
    func syncState()
}
```

기존 `TerminalSessionManager`에 output delegate 추가 필요:
- 현재: 터미널 출력이 `LocalProcessTerminalView`로 직접 감
- 변경: 출력을 가로채서 WebSocket으로도 전송

---

## 프로젝트 구조 (예상)

```
8hosun-terminal/
├── Package.swift                    (기존 Mac 앱)
├── Sources/                         (Mac 앱 소스)
│   └── Server/
│       ├── MuneoServer.swift
│       └── BonjourAdvertiser.swift
├── MuneoShared/                     (공유 Swift Package)
│   ├── Package.swift
│   └── Sources/
│       ├── Models/
│       ├── Protocol/
│       └── Extensions/
└── MuneoRemote/                     (iOS 앱 — 별도 Xcode 프로젝트 or SPM)
    ├── MuneoRemoteApp.swift
    ├── Views/
    │   ├── ConnectionView.swift     (Bonjour 디스커버리)
    │   ├── GridView.swift           (8분할 그리드)
    │   ├── PanelView.swift          (개별 터미널 뷰)
    │   └── CommandPalette.swift     (빠른 명령)
    ├── State/
    │   ├── RemoteAppState.swift
    │   └── MuneoClient.swift        (WebSocket 클라이언트)
    └── Resources/
        └── Assets.xcassets          (문어 아이콘 iOS 버전)
```

---

## 핵심 기술 결정 사항 (미결)

1. **네트워크**: Bonjour + WebSocket (NWListener/NWConnection) vs Multipeer Connectivity?
2. **터미널 버퍼 동기화**: 전체 버퍼 전송 vs delta only? (대역폭 vs 복잡도)
3. **SwiftTerm iOS 뷰**: 읽기전용 모드? 아니면 입력도 직접 받을?
4. **프로젝트 구조**: 모노레포(같은 Package.swift) vs 별도 Xcode 프로젝트?
5. **최소 iOS 버전**: iOS 17? (Live Activity 등 최신 API 위해)

---

## 리스크

| 리스크 | 심각도 | 대응 |
|--------|--------|------|
| SwiftTerm iOS 뷰가 원격 데이터 피드에 맞지 않을 수 있음 | 높음 | PoC 먼저 |
| 8개 터미널 동시 스트리밍 대역폭 | 중간 | delta 전송 + 비활성 패널 스로틀링 |
| Bonjour가 일부 네트워크(회사 등)에서 차단 | 중간 | 수동 IP 입력 폴백 |
| Mac 앱에 서버 추가 시 기존 코드 영향 | 낮음 | 서버를 opt-in 토글로 |

---

## Dream State Delta

```
현재 → Phase 1 후:  Mac 앞에 안 앉아도 8개 Claude 모니터링 가능 (같은 네트워크)
Phase 1 → 12개월 후: 어디서든 접속, Watch 알림, 위젯, Siri — "AI 오케스트레이션 리모컨"
```

---

*생성일: 2026-03-17*
*상태: 기획 초안 — 미결 사항 논의 후 구현 시작*
