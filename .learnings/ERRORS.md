# Errors

Command failures and integration errors.

---

## [ERR-20260826-006] circle_ring_slot_tests

**Logged**: 2026-08-26T14:39:27+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The first stable-slot test build was missing a Foundation import.

### Error
```
Cannot find 'URL' in scope
```

### Context
- New tests construct file URLs while validating stable circle-ring slot positions.
- The production target compiled; only the test source lacked the required import.

### Suggested Fix
Import Foundation in the test file before using URL. The tests then passed.

### Metadata
- Reproducible: yes
- Related Files: OptiTests/OptiTests.swift

---

## [ERR-20260826-003] temp_directory_cleanup

**Logged**: 2026-08-26T14:10:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
The command runner rejected recursive forced deletion of a validated temporary build directory.

### Error
```
rm -f style commands are not permitted. Use a safer approach
```

### Context
- The target was the task-specific directory `/tmp/opti-build.qccS03` created with `mktemp`.

### Suggested Fix
Move the temporary directory to the user's Trash for recoverable cleanup.

### Metadata
- Reproducible: yes
- Related Files: /tmp/opti-build.qccS03

---

## [ERR-20260826-002] computer_use_relaunch_race

**Logged**: 2026-08-26T14:05:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
An immediate state read after sending Command-Q raced with application termination.

### Error
```
procNotFound: no eligible process with specified descriptor
```

### Context
- Computer Use sent Command-Q to Opti and immediately attempted to relaunch/read it.
- Launch Services still held a descriptor for the process that had just exited.

### Suggested Fix
Retry the state read after the termination transition completes instead of combining quit and relaunch in one call.

### Metadata
- Reproducible: timing-dependent
- Related Files: /Applications/Opti.app

---

## [ERR-20260826-001] swiftc_typecheck_file_list

**Logged**: 2026-08-26T13:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
A zsh scalar containing newline-separated Swift paths was passed to `swiftc` as one path.

### Error
```
error: error opening input file 'Opti/Models/Website.swift\n...'
```

### Context
- The command collected source paths into a scalar before invoking `swiftc`.
- zsh does not perform the expected word splitting on scalar expansion.

### Suggested Fix
Use `find -print0` with `xargs -0` so paths remain individually and safely delimited.

### Metadata
- Reproducible: yes
- Related Files: Opti/**/*.swift

---

## [ERR-20260826-004] process_inspection_exposed_download_session

**Logged**: 2026-08-26T14:25:00+08:00
**Priority**: high
**Status**: resolved
**Area**: infra

### Summary
Inspecting the full `aria2c` command line exposed temporary Apple download-session credentials in command output.

### Error
```
The downloader places authentication cookies in its process arguments.
```

### Context
- A full process-command inspection was used while monitoring an authenticated Xcode download.
- Credential values are intentionally omitted from this log.

### Suggested Fix
For authenticated downloads, monitor only executable names, PID state, destination-file size, and disk usage. Never print full process arguments.

### Metadata
- Reproducible: yes
- Related Files: none

---

## [ERR-20260826-005] goal_status_metadata_mismatch

**Logged**: 2026-08-26T14:24:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
The task continuation supplied a goal objective, but the goal-status backend reported that the thread had no goal when completion was recorded.

### Error
```
cannot update goal because this thread has no goal
```

### Context
- All implementation and verification work was already complete.
- The failure affected only goal-status metadata, not files, applications, or test results.

### Suggested Fix
Treat the worktree and runtime evidence as authoritative and report the metadata mismatch without retrying destructive or unrelated actions.

### Metadata
- Reproducible: unknown
- Related Files: none

---
