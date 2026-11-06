# UIScroller

Automatic scrolling for lists, articles and other scrollable pages in iOS apps.

## Install

Download the package matching your jailbreak environment from the [1.0.7 beta1 prerelease](https://github.com/zhuxian89/UIScroller/releases/tag/v1.0.7-beta1), install it with your package manager, and reopen the target app. This compatibility release targets **iOS / iPadOS 15 or later**.

The earlier [1.0.6 stable release](https://github.com/zhuxian89/UIScroller/releases/tag/v1.0.6) remains available for **iOS 17+ / RootHide**. The beta has not been tested on physical iOS 15/16 devices or standard rootful/rootless jailbreaks; see the validation scope below.

## iOS 15 compatibility build

The current source is **1.0.7 beta1**, targeting **iOS 15 or later**, with separate **rootful, rootless and RootHide** packages. The published 1.0.6 stable release remains the RootHide-only build with an iOS 17 minimum.

Choose the package for your jailbreak environment:

| Environment | Package filename suffix |
| --- | --- |
| Standard rootful | `_iphoneos-arm.deb` |
| Standard rootless | `_iphoneos-arm64.deb` |
| RootHide | `_iphoneos-arm64e.deb` |

These suffixes identify packaging schemes; do not choose solely by the device's CPU. All three builds contain arm64 and arm64e slices and share the same functionality.

The compatibility build uses the older trait-change callback for text-size updates. iOS 16+ retains the existing compact panel with custom height; iOS 15 opens the standard expanded sheet so the main controls are easy to find. Speed, timers, screen-idle handling and per-app settings are unchanged.

Strict iOS 15 API availability checks and package checks for all three schemes passed, including both CPU architectures, signatures, installation paths and loader dependencies. The modern panel and the iOS 15 panel branch were exercised in an iOS 27 UIKit fixture (the latter forced in a temporary test copy), including live text-size changes. Actual iOS 15/16 device validation remains outstanding.

## Use

1. Long-press the content you want to scroll with **two fingers**.
2. Choose a speed and, optionally, a stop timer.
3. Tap **开始滚动** (Start scrolling). The panel closes before scrolling starts.

Tap or drag the active content, or reopen the panel and tap **停止滚动** (Stop scrolling), to stop. Manual swipes never start automatic scrolling. Reopening or closing the panel does not stop an existing session.

The menu is shared across supported apps: its app name comes from the current app, and each app saves its own speed, duration and enable switch. It selects the nearest enabled vertical scroll container at the long-press location. Standard UIKit scroll containers use the generic scrolling logic; custom page implementations may require additional adaptation. If Start is unavailable, long-press inside the scrollable content.

## What's new in 1.0.6

- Native control panel with a system-material frosted background, dark appearance, Dynamic Type, keyboard support and a compact iPad form sheet.
- Four speed choices, 5/15/30-minute presets, and a custom duration of 1–180 minutes.
- Remaining-time display, in-panel Stop, and a separate More page for per-app settings.
- Speed and duration persist for each app. Changing duration during a session starts a new countdown; selecting the same duration, changing speed, or reopening the panel preserves its deadline. **关闭** (Off) cancels only the countdown.
- The screen stays awake while scrolling. Every stop restores the app's previous idle-timer setting, including when the app enters the background, the page leaves the window, the timer expires or the content boundary is reached.
- Fixes for nested text views with tiny rounding overflow and LINUX DO post-reading anchors. No raw host private-field reads or writes are used.

The frosted material also works on iOS 15. The [interactive HTML preview](design/menu-preview.html) demonstrates the layout and interactions separately from the tweak.

## LINUX DO compatibility and diagnostics

The specific post-reader adapter targets **LINUX DO 1.0.3 (build 6)**. During the host's synchronous `scrollViewDidScroll:` callback caused by a UIScroller offset write, a scoped public `isDecelerating` getter reports scrolling so the host clears its own old reading anchor. Outside that callback the native state is returned. The adapter does not access the host's private memory layout or synthesize a drag lifecycle.

LINUX DO also exposes **更多设置 → 复制诊断信息** (More → Copy diagnostics). Reports include scroll-view geometry, timer state and the last 32 scroll events held in memory. They do not read post text or account information, and are copied only when requested; nothing is uploaded.

## Build

Use a RootHide-compatible Theos installation with the standard rootful/rootless schemes available. The current Makefile defaults to RootHide with an iOS 15 deployment target:

```sh
make clean package
```

To build all three variants sequentially:

```sh
./build.sh -j2
```

The script passes each scheme directly to `make`, cleans between builds, stops on failure, and does not edit the Makefile. For a single standard rootless package, run `make clean THEOS_PACKAGE_SCHEME=rootless` followed by `make package THEOS_PACKAGE_SCHEME=rootless`; use an empty scheme for rootful.

Builds were checked with Xcode 27. The 1.0.7 beta1 release contains all three variants plus `SHA256SUMS-1.0.7-beta1.txt`.

## Validation

For 1.0.7 beta1, one modern-panel XCTest flow and one forced iOS 15-panel flow passed on iOS 27 Simulator. Both paths also handled live system text-size changes while the panel stayed open. The legacy test changed only the availability conditions in a temporary source copy; it did not run an iOS 15 runtime. Package verification does not establish successful injection on physical rootful/rootless devices.

For the 1.0.6 baseline, the native menu passed two real-touch XCTest flows. Timer and screen-idle restoration passed 46 checks, and the reader adapter passed 22 checks. Automated runtime checks used an isolated UIKit fixture on the available iOS 27 Simulator, not the original LINUX DO binary. These checks do not establish compatibility with every app or replace iOS 17 RootHide device testing.

This fork retains the original project's license and author attribution.
