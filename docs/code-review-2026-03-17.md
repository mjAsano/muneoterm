# 코드 리뷰 — 8hosun-terminal

**날짜:** 2026-03-17
**대상:** 전체 소스 코드 (Sources/)
**브랜치:** main

---

## CRITICAL (크래시 가능)

### 1. 메모리 누수 — 이벤트 모니터 해제 안됨

**파일:** `Sources/Views/MainWindowView.swift:7`

`NSEvent.addLocalMonitorForEvents`의 리턴값을 저장하지 않아 해제 불가. 윈도우가 닫히고 다시 열릴 때마다 모니터가 중복 등록된다.

```swift
// 현재: 리턴값 무시, 해제 불가
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in ...}
```

**수정 방향:** 리턴값을 저장하고, `onDisappear`에서 `NSEvent.removeMonitor()`를 호출해야 한다.

---

### 2. panelWrappers 메모리 누수

**파일:** `Sources/Views/AppKit/SplitContainerNSView.swift:74-91`

`panelWrappers` 딕셔너리에 캐시된 wrapper가 세션 삭제 시 자동으로 제거되지 않는다. `removePanelWrapper(for:)`가 정의되어 있지만 아무 곳에서도 호출되지 않는다.

**수정 방향:** `rebuildHierarchy()` 시점에 현재 노드의 `allSessionIDs`에 없는 wrapper를 정리하거나, 세션 삭제 시 명시적으로 `removePanelWrapper`를 호출해야 한다.

---

### 3. 프로세스 정리 안됨

**파일:** `Sources/State/TerminalSessionManager.swift:53-55`

`removeSession`이 딕셔너리에서만 제거하고 실행 중인 셸 프로세스를 종료하지 않는다. 탭 닫을 때 좀비 프로세스가 남을 수 있다.

```swift
func removeSession(_ sessionID: UUID) {
    // terminalView의 프로세스를 먼저 종료해야 함
    sessions.removeValue(forKey: sessionID)
}
```

**수정 방향:** 제거 전에 `terminalView`에 SIGHUP 또는 프로세스 종료 시그널을 보내야 한다.

---

## HIGH

### 4. removeLeaf 로직 버그

**파일:** `Sources/Models/SplitNode.swift:53-65`

`removeLeaf`에서 `firstRemoved == nil`일 때 `secondRemoved ?? second`를 반환하는데, `secondRemoved`가 nil이 아니면 수정된 트리를 반환하지만, 원본 `second`를 반환하는 경우는 의미가 불분명하다. 특히 first가 삭제 대상이면서 second도 변경된 경우 원래 second의 변경분이 무시될 수 있다.

**수정 방향:** 삭제 대상이 first의 직접 leaf인 경우와 second의 직접 leaf인 경우를 명확하게 분리해서 처리해야 한다.

---

### 5. Cancellable 누적

**파일:** `Sources/State/AppState.swift:269-275`

`observeTab`으로 탭을 구독하지만, 탭이 닫힐 때 해당 구독을 해제하지 않는다. `cancellables`에 계속 쌓이면서 닫힌 탭의 `objectWillChange`가 계속 불필요하게 전파된다.

**수정 방향:** 탭별로 cancellable을 관리하는 딕셔너리를 사용하고, `closeTab` 시 해당 cancellable을 cancel하고 제거해야 한다.

---

### 6. 앱 종료 시 세션 저장 안됨

**파일:** `Sources/App.swift:130-132`

`applicationShouldTerminate`에서 `terminateNow`를 바로 반환하지만, `appState.saveSession()`을 호출하지 않는다. 세션 지속성 기능(`SessionStore`)이 사실상 작동하지 않는다.

**수정 방향:** `AppDelegate`에서 `appState` 참조를 갖고, `applicationShouldTerminate`에서 세션 저장 후 종료해야 한다.

---

## MEDIUM

### 7. 환경변수 중복

**파일:** `Sources/State/TerminalSessionManager.swift:25-29`

`Terminal.getEnvironmentVariables`가 이미 기본 환경변수를 설정하는데, `ProcessInfo.processInfo.environment`의 모든 변수를 추가로 append한다. 같은 키가 여러 번 들어갈 수 있어 셸 동작이 예측 불가할 수 있다.

**수정 방향:** 딕셔너리로 먼저 머지한 후 배열로 변환해야 한다.

---

### 8. 네비게이션 dead code

**파일:** `Sources/Models/SplitNode.swift:113-142`

`SplitNode.navigateFrom`은 단순 순서 기반(left/up = 이전, right/down = 다음)이지만 실제로 사용되지 않는다. `AppState.navigatePanel`은 별도의 2D 그리드 로직을 쓴다. `navigateFrom` 및 관련 private 메서드는 dead code이다.

---

### 9. DividerView tracking area 범위 문제

**파일:** `Sources/Views/AppKit/SplitPairView.swift:167-197`

`updateTrackingAreas`에서 확장된 rect로 tracking area를 등록하지만, 이 rect가 부모 뷰 bounds 밖으로 나가면 이벤트가 전달되지 않을 수 있다.

---

### 10. TabModel decode 시 id 유실

**파일:** `Sources/Models/TabModel.swift:24-31`

`init(from decoder:)`에서 `id`를 디코딩하지 않고, `self.init(sessionID:title:)` 호출 시 새 UUID가 생성된다. 저장된 탭 ID가 복원 후 달라진다.

---

## LOW

### 11. 하드코딩된 폰트

`MesloLGS-NF-Regular`가 설치되지 않은 맥에서는 시스템 모노스페이스 폰트로 fallback되지만 사용자에게 알림이 없다.

### 12. 함수명 부정확

**파일:** `Sources/Models/SplitNode.swift:128`

`collectLeavesWithFrames`는 실제로 frame 정보를 수집하지 않는다. `collectOrderedLeaves`가 더 적절하다.

### 13. 설정 변경 미저장

테마 변경이 디스크에 저장되지 않아 앱 재시작 시 기본 테마로 돌아간다.

---

## 요약

| 심각도 | 개수 |
|--------|------|
| Critical | 3 |
| High | 3 |
| Medium | 4 |
| Low | 3 |
| **합계** | **13** |
