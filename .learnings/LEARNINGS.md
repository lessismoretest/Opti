# Learnings

Corrections, insights, and knowledge gaps captured during development.

**Categories**: correction | insight | knowledge_gap | best_practice

---

## [LRN-20260826-002] correction

**Logged**: 2026-08-26T14:37:09+08:00
**Priority**: high
**Status**: resolved
**Area**: frontend

### Summary
Unavailable circle-ring applications must keep their configured slots instead of being silently filtered and reordered.

### Details
Filtering unresolved bundle identifiers made the visible list and configured list appear aligned, but changed the user's configured layout. The required invariant is that every circle sector keeps its original configured index. An unavailable application remains in that position, is visibly marked as unavailable, and cannot launch another application.

### Suggested Action
Use one stable slot model for rendering and selection, preserve unavailable and empty slots, and show explicit feedback when a non-launchable slot is selected.

### Metadata
- Source: user_feedback
- Related Files: Opti/Models/AppInfo.swift, Opti/Models/CircleRingMode.swift, Opti/Views/CircleRingView.swift
- Tags: circle-ring, stable-order, unavailable-app, user-intent

### Resolution
- **Resolved**: 2026-08-26T14:41:00+08:00
- **Notes**: Added a shared stable-slot model, retained unavailable and empty sectors, displayed an unavailable marker, blocked invalid launches, and added regression tests for the user's 12-slot layout.

---

## [LRN-20260826-001] correction

**Logged**: 2026-08-26T14:20:00+08:00
**Priority**: high
**Status**: pending
**Area**: backend

### Summary
Replacing the deprecated application activation option did not restore Opti's Option application shortcuts.

### Details
The modern `NSWorkspace.OpenConfiguration` path compiled, installed, and independently activated Finder on macOS 27, but the user confirmed the actual Option shortcuts still do nothing. The failure therefore occurs before application activation, most likely during hotkey registration, event delivery, or the `activeOptionKeyCode` gate.

### Suggested Action
Instrument and test the registration and event-handler path directly before changing application activation again.

### Metadata
- Source: user_feedback
- Related Files: Opti/Utilities/HotKeyManager.swift
- Tags: hotkey, macos27, diagnosis

---
