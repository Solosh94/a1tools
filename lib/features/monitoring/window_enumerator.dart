import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Information about a window
class WindowInfo {
  final int hwnd;
  final String title;
  final String processName;
  final int processId;
  final bool isVisible;

  WindowInfo({
    required this.hwnd,
    required this.title,
    required this.processName,
    required this.processId,
    required this.isVisible,
  });

  @override
  String toString() =>
      'WindowInfo(hwnd: $hwnd, title: "$title", process: "$processName", pid: $processId, visible: $isVisible)';
}

// ===========================================================================
// FFI TYPE DEFINITIONS
// ===========================================================================

// EnumWindows callback
typedef _EnumWindowsCallbackNative = Int32 Function(IntPtr hwnd, IntPtr lParam);

// EnumWindows
typedef _EnumWindowsNative = Int32 Function(
    Pointer<NativeFunction<_EnumWindowsCallbackNative>> lpEnumFunc, IntPtr lParam);
typedef _EnumWindows = int Function(
    Pointer<NativeFunction<_EnumWindowsCallbackNative>> lpEnumFunc, int lParam);

// GetWindowTextW
typedef _GetWindowTextWNative = Int32 Function(
    IntPtr hwnd, Pointer<Utf16> lpString, Int32 nMaxCount);
typedef _GetWindowTextW = int Function(int hwnd, Pointer<Utf16> lpString, int nMaxCount);

// GetWindowTextLengthW
typedef _GetWindowTextLengthWNative = Int32 Function(IntPtr hwnd);
typedef _GetWindowTextLengthW = int Function(int hwnd);

// IsWindowVisible
typedef _IsWindowVisibleNative = Int32 Function(IntPtr hwnd);
typedef _IsWindowVisible = int Function(int hwnd);

// GetWindowThreadProcessId
typedef _GetWindowThreadProcessIdNative = Uint32 Function(
    IntPtr hwnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessId = int Function(int hwnd, Pointer<Uint32> lpdwProcessId);

// ShowWindow
typedef _ShowWindowNative = Int32 Function(IntPtr hwnd, Int32 nCmdShow);
typedef _ShowWindow = int Function(int hwnd, int nCmdShow);

// GetWindowLongPtrW (for window styles)
typedef _GetWindowLongPtrWNative = IntPtr Function(IntPtr hwnd, Int32 nIndex);
typedef _GetWindowLongPtrW = int Function(int hwnd, int nIndex);

// OpenProcess
typedef _OpenProcessNative = IntPtr Function(
    Uint32 dwDesiredAccess, Int32 bInheritHandle, Uint32 dwProcessId);
typedef _OpenProcess = int Function(int dwDesiredAccess, int bInheritHandle, int dwProcessId);

// CloseHandle
typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandle = int Function(int hObject);

// GetModuleBaseNameW (psapi.dll)
typedef _GetModuleBaseNameWNative = Uint32 Function(
    IntPtr hProcess, IntPtr hModule, Pointer<Utf16> lpBaseName, Uint32 nSize);
typedef _GetModuleBaseNameW = int Function(
    int hProcess, int hModule, Pointer<Utf16> lpBaseName, int nSize);

// ===========================================================================
// CONSTANTS - Windows API constants (names match Windows SDK for clarity)
// ===========================================================================

// ignore: constant_identifier_names
const int SW_HIDE = 0;
// ignore: constant_identifier_names
const int SW_MINIMIZE = 6;
// ignore: constant_identifier_names
const int SW_RESTORE = 9;
// ignore: constant_identifier_names
const int SW_SHOW = 5;
// ignore: constant_identifier_names
const int SW_SHOWNA = 8; // Show without activating

// ignore: constant_identifier_names
const int GWL_STYLE = -16;
// ignore: constant_identifier_names
const int GWL_EXSTYLE = -20;

// ignore: constant_identifier_names
const int WS_VISIBLE = 0x10000000;
// ignore: constant_identifier_names
const int WS_MINIMIZE = 0x20000000;

// ignore: constant_identifier_names
const int PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
// ignore: constant_identifier_names
const int PROCESS_QUERY_INFORMATION = 0x0400;
// ignore: constant_identifier_names
const int PROCESS_VM_READ = 0x0010;

// ===========================================================================
// WINDOW ENUMERATOR SERVICE
// ===========================================================================

/// Service for enumerating and manipulating Windows windows
/// Used to hide excluded windows during screenshot capture
class WindowEnumerator {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
  static DynamicLibrary? _psapi;

  // Lazy load psapi.dll
  static DynamicLibrary get psapi {
    _psapi ??= DynamicLibrary.open('psapi.dll');
    return _psapi!;
  }

  // User32 functions
  static final _EnumWindows _enumWindows =
      _user32.lookupFunction<_EnumWindowsNative, _EnumWindows>('EnumWindows');

  static final _GetWindowTextW _getWindowTextW =
      _user32.lookupFunction<_GetWindowTextWNative, _GetWindowTextW>('GetWindowTextW');

  static final _GetWindowTextLengthW _getWindowTextLengthW = _user32
      .lookupFunction<_GetWindowTextLengthWNative, _GetWindowTextLengthW>(
          'GetWindowTextLengthW');

  static final _IsWindowVisible _isWindowVisible =
      _user32.lookupFunction<_IsWindowVisibleNative, _IsWindowVisible>('IsWindowVisible');

  static final _GetWindowThreadProcessId _getWindowThreadProcessId =
      _user32.lookupFunction<_GetWindowThreadProcessIdNative, _GetWindowThreadProcessId>(
          'GetWindowThreadProcessId');

  static final _ShowWindow _showWindow =
      _user32.lookupFunction<_ShowWindowNative, _ShowWindow>('ShowWindow');

  static final _GetWindowLongPtrW _getWindowLongPtrW =
      _user32.lookupFunction<_GetWindowLongPtrWNative, _GetWindowLongPtrW>('GetWindowLongPtrW');

  // Kernel32 functions
  static final _OpenProcess _openProcess =
      _kernel32.lookupFunction<_OpenProcessNative, _OpenProcess>('OpenProcess');

  static final _CloseHandle _closeHandle =
      _kernel32.lookupFunction<_CloseHandleNative, _CloseHandle>('CloseHandle');

  // PSAPI function (lazy loaded)
  static _GetModuleBaseNameW? _getModuleBaseNameFn;
  static _GetModuleBaseNameW get _getModuleBaseName {
    _getModuleBaseNameFn ??=
        psapi.lookupFunction<_GetModuleBaseNameWNative, _GetModuleBaseNameW>(
            'GetModuleBaseNameW');
    return _getModuleBaseNameFn!;
  }

  // Storage for enumerated windows (used by callback)
  static final List<int> _enumeratedHwnds = [];

  /// Callback for EnumWindows
  static int _enumWindowsCallback(int hwnd, int lParam) {
    _enumeratedHwnds.add(hwnd);
    return 1; // Continue enumeration
  }

  /// Get window title by HWND
  static String getWindowTitle(int hwnd) {
    final length = _getWindowTextLengthW(hwnd);
    if (length == 0) return '';

    final buffer = calloc<Uint16>(length + 1);
    try {
      _getWindowTextW(hwnd, buffer.cast(), length + 1);
      return buffer.cast<Utf16>().toDartString();
    } finally {
      calloc.free(buffer);
    }
  }

  /// Get process ID from window
  static int getProcessId(int hwnd) {
    final pidPtr = calloc<Uint32>();
    try {
      _getWindowThreadProcessId(hwnd, pidPtr);
      return pidPtr.value;
    } finally {
      calloc.free(pidPtr);
    }
  }

  /// Get process name from process ID
  static String getProcessName(int processId) {
    // Try with limited information first (works even without admin)
    var hProcess = _openProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, 0, processId);

    if (hProcess == 0) {
      // Try with query information
      hProcess = _openProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, 0, processId);
    }

    if (hProcess == 0) {
      return '';
    }

    final buffer = calloc<Uint16>(260); // MAX_PATH
    try {
      final result = _getModuleBaseName(hProcess, 0, buffer.cast(), 260);
      if (result > 0) {
        String name = buffer.cast<Utf16>().toDartString();
        // Remove .exe extension for easier matching
        if (name.toLowerCase().endsWith('.exe')) {
          name = name.substring(0, name.length - 4);
        }
        return name;
      }
      return '';
    } finally {
      _closeHandle(hProcess);
      calloc.free(buffer);
    }
  }

  /// Check if window is visible
  static bool isWindowVisible(int hwnd) {
    return _isWindowVisible(hwnd) != 0;
  }

  /// Check if window is minimized
  static bool isWindowMinimized(int hwnd) {
    final style = _getWindowLongPtrW(hwnd, GWL_STYLE);
    return (style & WS_MINIMIZE) != 0;
  }

  /// Get all visible top-level windows with their process information
  static List<WindowInfo> getVisibleWindows() {
    if (!Platform.isWindows) return [];

    _enumeratedHwnds.clear();

    // Create callback pointer
    final callback = Pointer.fromFunction<_EnumWindowsCallbackNative>(
      _enumWindowsCallback,
      0,
    );

    // Enumerate all windows
    _enumWindows(callback, 0);

    final windows = <WindowInfo>[];

    for (final hwnd in _enumeratedHwnds) {
      // Skip invisible windows
      if (!isWindowVisible(hwnd)) continue;

      final title = getWindowTitle(hwnd);
      // Skip windows with no title (system windows)
      if (title.isEmpty) continue;

      final processId = getProcessId(hwnd);
      final processName = getProcessName(processId);

      windows.add(WindowInfo(
        hwnd: hwnd,
        title: title,
        processName: processName,
        processId: processId,
        isVisible: true,
      ));
    }

    return windows;
  }

  /// Find windows matching the given program names
  static List<WindowInfo> findWindowsByProcessNames(List<String> programNames) {
    final allWindows = getVisibleWindows();
    final matchingWindows = <WindowInfo>[];

    for (final window in allWindows) {
      final lowerProcessName = window.processName.toLowerCase();

      for (final program in programNames) {
        final lowerProgram = program.toLowerCase();

        // Check if process name contains the exclusion pattern
        if (lowerProcessName.contains(lowerProgram) || lowerProgram.contains(lowerProcessName)) {
          matchingWindows.add(window);
          break; // Don't add same window twice
        }
      }
    }

    return matchingWindows;
  }

  /// Minimize a window
  static bool minimizeWindow(int hwnd) {
    return _showWindow(hwnd, SW_MINIMIZE) != 0;
  }

  /// Restore a window (from minimized state)
  static bool restoreWindow(int hwnd) {
    return _showWindow(hwnd, SW_RESTORE) != 0;
  }

  /// Hide a window completely
  static bool hideWindow(int hwnd) {
    return _showWindow(hwnd, SW_HIDE) != 0;
  }

  /// Show a window
  static bool showWindow(int hwnd) {
    return _showWindow(hwnd, SW_SHOW) != 0;
  }

  /// Show window without activating it
  static bool showWindowNoActivate(int hwnd) {
    return _showWindow(hwnd, SW_SHOWNA) != 0;
  }

  /// Temporarily hide windows matching exclusion list, capture operation, then restore
  /// Returns a record of windows that were hidden (their original states)
  static List<(int hwnd, bool wasMinimized)> hideExcludedWindows(List<String> exclusions) {
    if (exclusions.isEmpty) return [];

    debugPrint('[WindowEnumerator] Hiding windows matching: $exclusions');

    final matchingWindows = findWindowsByProcessNames(exclusions);
    final hiddenWindows = <(int, bool)>[];

    for (final window in matchingWindows) {
      // Skip already minimized windows
      final wasMinimized = isWindowMinimized(window.hwnd);

      if (!wasMinimized && window.isVisible) {
        debugPrint('[WindowEnumerator] Minimizing: ${window.processName} - "${window.title}"');
        minimizeWindow(window.hwnd);
        hiddenWindows.add((window.hwnd, wasMinimized));
      }
    }

    debugPrint('[WindowEnumerator] Hidden ${hiddenWindows.length} windows');
    return hiddenWindows;
  }

  /// Restore previously hidden windows
  static void restoreHiddenWindows(List<(int hwnd, bool wasMinimized)> hiddenWindows) {
    for (final (hwnd, wasMinimized) in hiddenWindows) {
      if (!wasMinimized) {
        debugPrint('[WindowEnumerator] Restoring window: $hwnd');
        restoreWindow(hwnd);
      }
    }
    debugPrint('[WindowEnumerator] Restored ${hiddenWindows.length} windows');
  }
}
