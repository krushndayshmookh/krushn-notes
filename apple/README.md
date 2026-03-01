# krushn-notes — Apple

SwiftUI apps for iOS, iPadOS, macOS, + WidgetKit.

**Minimum deployment:** iOS 17.0 / macOS 14.0 (required for SwiftData)

---

## Targets

| Target | Platform | Bundle ID |
|--------|----------|-----------|
| krushn-notes | iOS + iPadOS | `com.krushn.notes` |
| krushn-notes macOS | macOS | `com.krushn.notes.mac` |
| krushnNotesWidget | iOS extension | `com.krushn.notes.widget` |

---

## First-time Xcode setup

### 1. Open the project

```bash
open apple/krushn-notes.xcodeproj
```

### 2. Set your development team

- Select each target → **Signing & Capabilities**
- Set your **Team** (your Apple Developer account) for all three targets

### 3. Create Config.xcconfig

```bash
cp apple/krushn-notes/Config.xcconfig.template apple/krushn-notes/Config.xcconfig
```

Edit `Config.xcconfig`:
```
API_BASE_URL   = https://your-backend.vercel.app
PUSHER_KEY     = your_pusher_key
PUSHER_CLUSTER = us2
```

For local dev against a local backend, use your Mac's LAN IP:
```
API_BASE_URL = http://192.168.1.x:3000
```

In Xcode: select each target → **Build Settings** → search "Configuration File" → set to `Config.xcconfig` for both Debug and Release.

### 4. Wire up the iOS entitlements

In the **krushn-notes** (iOS) target → **Signing & Capabilities**:
- Add **App Groups** → add `group.com.krushn.notes`
- Set `CODE_SIGN_ENTITLEMENTS` to `krushn-notes/iOS/krushn-notes-iOS.entitlements`

In the **krushnNotesWidget** target:
- Add the same App Group `group.com.krushn.notes`
- This allows `AppGroupStore` to share task data between main app and widget

### 5. Add PusherSwift via Swift Package Manager

- **File → Add Package Dependencies…**
- URL: `https://github.com/pusher/pusher-websocket-swift`
- Version: Up To Next Major from `10.1.5`
- Add to targets: **krushn-notes** and **krushn-notes macOS**

After adding, open `Shared/PusherManager.swift` and uncomment:
- `import PusherSwift`
- The `pusher`/`channel` properties
- Body of `connect(userId:)` and `bindEvents()`
- `PusherDelegate` extension and `PusherAuthBuilder` class

---

## Running

### iOS
1. Select scheme **krushn-notes** → iPhone Simulator → ⌘R
2. Tap "Continue with GitHub" → authenticate → main UI loads

### macOS
1. Select scheme **krushn-notes macOS** → My Mac → ⌘R
2. Click "Continue with GitHub" → main 3-column window opens
3. Press **⌘⌥T** to toggle the floating task panel

### Widget (Simulator)
1. Build and run the **krushn-notes** iOS scheme
2. Long-press the home screen → tap **+** → search "krushn notes"
3. Add the small, medium, or large widget
4. Tap a task checkbox — `ToggleTaskIntent` fires and updates via API

---

## Project structure

```
apple/
├── krushn-notes.xcodeproj/
│   └── project.pbxproj          ← 3 targets: iOS, macOS, Widget
└── krushn-notes/
    ├── Info.plist                ← shared plist (API_BASE_URL, PUSHER_KEY injected)
    ├── Config.xcconfig.template  ← copy to Config.xcconfig (gitignored)
    ├── Shared/                   ← compiled into iOS + macOS targets
    │   ├── Models.swift          ← SwiftData @Model classes + Codable DTOs
    │   ├── Keychain.swift        ← JWT in Keychain (shared via App Group keychain)
    │   ├── APIClient.swift       ← async/await HTTP, all CRUD
    │   ├── SyncManager.swift     ← offline queue + delta sync + widget data write
    │   ├── PusherManager.swift   ← real-time event → SwiftData upserts
    │   ├── AuthManager.swift     ← ASWebAuthenticationSession GitHub OAuth
    │   ├── MarkdownRenderer.swift← AttributedString(markdown:)
    │   └── WidgetSharedModels.swift ← WidgetTask, WidgetTaskData, AppGroupStore
    │                                   (also compiled into Widget target)
    ├── iOS/
    │   ├── krushn-notes-iOS.entitlements
    │   ├── krushnNotesApp.swift  ← @main, ModelContainer
    │   ├── RootView.swift        ← auth gate
    │   ├── LoginView.swift
    │   ├── ContentView.swift     ← TabView (Notes + Tasks)
    │   ├── SettingsView.swift
    │   └── Views/
    │       ├── Notes/
    │       │   ├── NotesTab.swift         ← NavigationSplitView
    │       │   ├── NotesSidebar.swift     ← folders + tags
    │       │   ├── NoteListView.swift     ← filtered list
    │       │   └── NoteDetailView.swift   ← editor + markdown toggle
    │       └── Tasks/
    │           ├── TasksTab.swift
    │           └── TaskListView.swift     ← checkbox rows + reorder
    ├── macOS/
    │   ├── krushn-notes-macOS.entitlements
    │   ├── krushnNotesApp_macOS.swift  ← @main + ⌘⌥T command
    │   ├── MacRootView.swift
    │   ├── MacLoginView.swift
    │   ├── MacContentView.swift        ← 3-column NavigationSplitView
    │   ├── MacSidebarColumn.swift      ← column 1: section + folders/tags/lists
    │   ├── MacSettingsView.swift
    │   ├── Views/
    │   │   ├── Notes/
    │   │   │   ├── MacNoteListView.swift
    │   │   │   └── MacNoteDetailView.swift  ← VSplitView header + editor
    │   │   └── Tasks/
    │   │       └── MacTaskListView.swift    ← inline tasks (no detail column)
    │   └── FloatingPanel/
    │       ├── FloatingPanel.swift      ← NSPanel subclass (.floating level)
    │       └── FloatingPanelView.swift  ← SwiftUI content (default task list)
    └── Widget/
        ├── Widget-Info.plist
        ├── TaskWidget.swift       ← Provider + small/medium/large views + @main bundle
        └── ToggleTaskIntent.swift ← AppIntent: toggles task + calls API + reloads timeline
```

---

## Data flow: Widget

```
SyncManager.deltaSync()
    └── updateWidgetData(ctx:)
            ├── reads default TaskList + its Tasks from SwiftData
            ├── writes WidgetTaskData to App Group container (JSON file)
            └── WidgetCenter.shared.reloadAllTimelines()

TaskWidgetProvider.getTimeline()
    └── AppGroupStore.load()   ← reads from App Group container (no network)
            └── returns TaskWidgetEntry with up to 5 tasks

User taps checkbox on widget
    └── ToggleTaskIntent.perform()
            ├── toggles completed in AppGroupStore JSON
            ├── PUT /api/tasks/:id  (network, best-effort)
            └── WidgetCenter.shared.reloadAllTimelines()
```

---

## Phase status

| Phase | Status | Notes |
|-------|--------|-------|
| 4 | ✅ Done | iOS + iPadOS |
| 5 | ✅ Done | macOS 3-column + floating panel |
| 6 | ✅ Done | WidgetKit + App Intents |
| 7 | ✅ Done | macOS floating NSPanel (included in Phase 5) |

---

## Troubleshooting

**"No such module 'PusherSwift'"**
→ Add via File → Add Package Dependencies (URL above)

**Widget shows empty / stale data**
→ App Group must be enabled on both the main app and widget targets with the same ID (`group.com.krushn.notes`). Verify in Signing & Capabilities.

**Keychain access group error**
→ The keychain access group uses `$(AppIdentifierPrefix)` which requires a real provisioning profile. For Simulator-only dev, you can remove the `kSecAttrAccessGroup` key from `Keychain.swift` temporarily.

**OAuth callback not received**
→ Verify the `krushnnotes` URL scheme is in Info.plist. Backend must redirect to `krushnnotes://auth?token=...`.

**SwiftData migration error**
→ Delete the app from Simulator (clears the store), then re-run.

**Can't reach local backend from Simulator**
→ Use Mac's LAN IP (`192.168.x.x:3000`) not `localhost`.

**macOS sandbox network error**
→ Ensure `com.apple.security.network.client` is in the macOS entitlements (it is by default in the provided file).
