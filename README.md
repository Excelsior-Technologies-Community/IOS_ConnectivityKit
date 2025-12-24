# 📡 ConnectivityKit – Network Connectivity Overlay (SwiftUI + UIKit)

ConnectivityKit provides a **clean, production-ready internet connectivity indicator** for both **SwiftUI** and **UIKit** apps.

### ✨ Features

* Persistent **No Internet Connection** banner (red)
* Auto-dismiss **Internet Connected** banner (green, 2 seconds)
* Works globally across the app
* Separate implementations for **SwiftUI** and **UIKit**
* Zero setup per screen

---

## 📦 Installation (Swift Package Manager)

### Option 1: Local Package

1. Add `ConnectivityKit` folder to your project
2. Open **Xcode → File → Add Packages**
3. Choose **Add Local Package**
4. Select the `ConnectivityKit` directory

### Option 2: Swift Package (Remote)

If hosted on GitHub:

```
https://github.com/yourname/ConnectivityKit
```

---

## 📂 Module Structure

```
ConnectivityKit
├── SwiftUINetworkMonitor.swift
├── NetworkMonitor.swift
├── NetworkBannerManager.swift
└── NetworkBannerView.swift
```

---

# 🧩 SwiftUI Integration

### ✅ Import

```swift
import ConnectivityKit
```

---

### ✅ How It Works

* Uses `SwiftUINetworkMonitor`
* Uses `.swiftUINetworkOverlay()` modifier
* Auto-starts monitoring internally
* No AppDelegate / SceneDelegate needed

---

### ✅ Usage (SwiftUI)

Apply **once**, usually at root view:

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
        .swiftUINetworkOverlay()
    }
}
```

That’s it 🎉
The overlay will appear automatically when:

* Internet disconnects → **Red banner**
* Internet reconnects → **Green banner (2s)**

---

### ✅ SwiftUI States Available (Optional)

```swift
SwiftUINetworkMonitor.shared.isConnected
SwiftUINetworkMonitor.shared.showConnectedBanner
```

---

# 🧩 UIKit Integration

### ✅ Import

```swift
import ConnectivityKit
```

---

### ✅ How It Works

* `NetworkMonitor` → Detects connectivity
* `NetworkBannerManager` → Displays banners
* Uses `NotificationCenter`
* Fully UIKit-safe (Scene-based)

---

### ✅ AppDelegate / SceneDelegate Setup

Call **once**, when app launches.

#### AppDelegate

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    NetworkBannerManager.shared.startMonitoring()
    return true
}
```

#### SceneDelegate (if used)

```swift
func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    NetworkBannerManager.shared.startMonitoring()
}
```

---

### ✅ No ViewController Code Needed

You **do NOT** need to:

* Observe notifications manually
* Add banners per screen
* Write lifecycle code

Everything is handled centrally ✅

---

# 🔔 Notifications (Optional – Advanced)

If you want to listen manually:

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(networkChanged),
    name: .networkStatusChanged,
    object: nil
)
```

UserInfo:

```swift
"isConnected": Bool
"wasConnected": Bool
```

---

# 🚫 Naming Conflicts (Solved)

| Platform | Class                   |
| -------- | ----------------------- |
| SwiftUI  | `SwiftUINetworkMonitor` |
| UIKit    | `NetworkMonitor`        |
| UIKit UI | `NetworkBannerManager`  |

✔️ No shared names
✔️ Safe to use both in same project

---

# 🧪 Tested Behavior

| Scenario          | Result                  |
| ----------------- | ----------------------- |
| App launch        | No banner               |
| Internet lost     | Red banner (persistent) |
| Internet restored | Green banner (2s)       |
| App background    | Safe                    |
| Scene-based apps  | Safe                    |

---

# ✅ Best Practice

* SwiftUI → **Use `.swiftUINetworkOverlay()`**
* UIKit → **Call `startMonitoring()` once**
* Do NOT mix implementations in same screen
 