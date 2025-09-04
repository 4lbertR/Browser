- Developer Specification: Private Non-WebKit iOS Browser

**Project Goal:**  
Create a private iOS browser app for EU-region devices (iOS 17.4+) that uses a non-WebKit engine and does not implement Apple’s Screen Time restriction APIs, thus bypassing system web content controls.

---

## 1. **Target Environment**

- **Device:** iPhone/iPad, region set to EU country
- **iOS Version:** 17.4 or higher
- **Distribution:** Sideload via Xcode (private, not App Store)
- **Developer Account:** Apple Developer Program ($99/year)
- **Workstations:** Windows for code editing, Mac for Xcode build/run
- **Source Control:** GitHub (private repo recommended)

---

## 2. **Architecture Overview**

- **Frontend/UI:** Swift (UIKit or SwiftUI) for basic browser UI
- **Rendering Engine:** Chromium/Blink or Gecko, compiled for iOS
- **Engine Integration:** Native C++/Rust engine bridged to Swift via Objective-C++ or Swift FFI
- **Networking:** Direct HTTP/S via engine, not relying on iOS APIs that enforce restrictions
- **No Apple Content APIs:** Do **not** use WKWebView, SFAuthenticationSession, ASWebAuthenticationSession, or Screen Time APIs

---

## 3. **Key Features**

- Simple address bar (URL input)
- Navigation controls (Back, Forward, Reload)
- Page rendering via non-WebKit engine surface
- History/bookmarks (optional, for minimal privacy)
- No telemetry, analytics, or third-party tracking
- No Apple parental/content restriction APIs

---

## 4. **Development Workflow**

### **On Windows:**
- Write Swift, Objective-C++, and C++/Rust code
- Maintain project files, source code, and documentation
- Use Git for commits/pushing to repo

### **On Mac:**
- Clone/pull repository
- Open `.xcworkspace` or `.xcodeproj` in Xcode
- Build and run app on physical device (provisioned with dev account)
- Test browser functionality and restriction bypass

---

## 5. **Project Structure**

```
/browser-app/
  /Engine/
    - Chromium/Gecko source & build scripts
    - iOS build output (static/dynamic library)
  /App/
    - Swift/Objective-C++ frontend
    - Engine integration layer
    - UI assets
    - Info.plist, entitlements
  /Scripts/
    - Build automation, dependency setup
  /Docs/
    - This DEV_SPEC, setup guides
  .gitignore
  README.md
  LICENSE
```

---

## 6. **Technical Implementation**

### **A. Engine Porting/Integration**
- Obtain Chromium/Blink or Gecko source
- Cross-compile for iOS (arm64); produce static/dynamic library (e.g., `libblink.a`)
- Expose minimal API: load URL, render to surface, handle navigation

### **B. Swift UI App**
- Create basic `BrowserViewController`
- Use `UIView` or Metal/OpenGL surface for engine rendering
- Wire address bar and navigation buttons to engine API

### **C. Bridging**
- Use Objective-C++ (`.mm` files) or Swift FFI to bridge between engine (C++/Rust) and UI (Swift)

### **D. Restriction Bypass**
- Do **not** call any Apple content restriction APIs
- Do **not** use WebKit or related views/components
- Ensure all rendering and navigation is handled by your engine

### **E. Privacy**
- Do not log user activity
- No external network calls except for loading web pages

---

## 7. **Build & Sideload Instructions**

1. On Windows:
   - Write/update code
   - Commit/push to GitHub

2. On Mac:
   - Pull repo
   - Run engine build scripts (if needed)
   - Open Xcode project/workspace
   - Build and run on device (use developer provisioning)
   - Test unrestricted browsing

---

## 8. **Testing**

- Verify loading of websites blocked by Screen Time on Safari
- Confirm no content filtering occurs
- Test navigation, rendering, and stability
- Test on multiple iOS devices/versions (iOS 17.4+)

---

## 9. **Risks & Considerations**

- **Apple OS Updates:** Future iOS versions may enforce system-wide restrictions, even for non-WebKit browsers
- **Legal/Ethical:** This app is for private use only; do not distribute in violation of Apple policies or local laws
- **Stability:** Non-WebKit engine integration may be complex and unstable on iOS

---

## 10. **References & Resources**

- [Chromium for iOS (docs)](https://chromium.googlesource.com/chromium/src/+/main/docs/ios/)
- [Mozilla GeckoView](https://mozilla.github.io/geckoview/)
- [Swift/Objective-C++ bridging](https://developer.apple.com/documentation/swift/importing-objective-c-into-swift)
- [Apple Developer: iOS App Sideloading](https://developer.apple.com/documentation/xcode/installing-your-app-on-a-device)

---

## 11. **Sample README Section**

````markdown
# Private Non-WebKit iOS Browser

**Summary:**  
A custom browser for iOS 17.4+ (EU region) using a non-WebKit engine, intended for private use and unrestricted browsing.

**How to build:**  
1. Clone repo on Mac  
2. Run engine build script (see /Engine/README.md)  
3. Open in Xcode, build & run on device  
4. Enjoy unrestricted web access!

**Note:**  
This project is for personal/private use only. Do not distribute or use to violate laws or policies.