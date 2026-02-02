// Remote Monitoring Service
// 
// Unified service for:
// - Periodic screenshot capture (every 15 minutes)
// - Real-time screen streaming
// - Remote control (mouse/keyboard input)
// 
// All communication goes through the server via HTTPS - no port forwarding required.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../../config/api_config.dart';
import '../../core/services/version_check_service.dart';
import '../../core/services/websocket_client.dart';
import '../admin/privacy_exclusions_service.dart';
import 'privacy_injection_service.dart';

// =============================================================================
// WINDOWS FFI DEFINITIONS FOR SCREEN CAPTURE
// =============================================================================

// GDI32.dll
typedef _GetDCNative = IntPtr Function(IntPtr hwnd);
typedef _GetDC = int Function(int hwnd);

typedef _ReleaseDCNative = Int32 Function(IntPtr hwnd, IntPtr hdc);
typedef _ReleaseDC = int Function(int hwnd, int hdc);

typedef _CreateCompatibleDCNative = IntPtr Function(IntPtr hdc);
typedef _CreateCompatibleDC = int Function(int hdc);

typedef _DeleteDCNative = Int32 Function(IntPtr hdc);
typedef _DeleteDC = int Function(int hdc);

typedef _CreateCompatibleBitmapNative = IntPtr Function(IntPtr hdc, Int32 width, Int32 height);
typedef _CreateCompatibleBitmap = int Function(int hdc, int width, int height);

typedef _SelectObjectNative = IntPtr Function(IntPtr hdc, IntPtr obj);
typedef _SelectObject = int Function(int hdc, int obj);

typedef _DeleteObjectNative = Int32 Function(IntPtr obj);
typedef _DeleteObject = int Function(int obj);

typedef _BitBltNative = Int32 Function(
  IntPtr hdcDest, Int32 xDest, Int32 yDest, Int32 width, Int32 height,
  IntPtr hdcSrc, Int32 xSrc, Int32 ySrc, Uint32 rop
);
typedef _BitBlt = int Function(
  int hdcDest, int xDest, int yDest, int width, int height,
  int hdcSrc, int xSrc, int ySrc, int rop
);

typedef _GetDIBitsNative = Int32 Function(
  IntPtr hdc, IntPtr hbm, Uint32 start, Uint32 lines,
  Pointer<Void> bits, Pointer<Void> bmi, Uint32 usage
);
typedef _GetDIBits = int Function(
  int hdc, int hbm, int start, int lines,
  Pointer<Void> bits, Pointer<Void> bmi, int usage
);

// User32.dll
typedef _GetSystemMetricsNative = Int32 Function(Int32 index);
typedef _GetSystemMetrics = int Function(int index);

typedef _GetDesktopWindowNative = IntPtr Function();
typedef _GetDesktopWindow = int Function();

typedef _SetCursorPosNative = Int32 Function(Int32 x, Int32 y);
typedef _SetCursorPos = int Function(int x, int y);

typedef _GetCursorPosNative = Int32 Function(Pointer<POINT> point);
typedef _GetCursorPos = int Function(Pointer<POINT> point);

typedef _MouseEventNative = Void Function(Uint32 flags, Uint32 dx, Uint32 dy, Uint32 data, IntPtr extraInfo);
typedef _MouseEvent = void Function(int flags, int dx, int dy, int data, int extraInfo);

typedef _KeybdEventNative = Void Function(Uint8 vk, Uint8 scan, Uint32 flags, IntPtr extraInfo);
typedef _KeybdEvent = void Function(int vk, int scan, int flags, int extraInfo);

typedef _LockWorkStationNative = Int32 Function();
typedef _LockWorkStation = int Function();

typedef _MessageBoxWNative = Int32 Function(IntPtr hwnd, Pointer<Utf16> text, Pointer<Utf16> caption, Uint32 type);
typedef _MessageBoxW = int Function(int hwnd, Pointer<Utf16> text, Pointer<Utf16> caption, int type);

// POINT structure
final class POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

// BITMAPINFOHEADER structure
final class BITMAPINFOHEADER extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

// =============================================================================
// WINDOWS NATIVE SCREEN CAPTURE
// =============================================================================

class WindowsScreenCapture {
  static final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  
  // User32 functions (GetDC and ReleaseDC are in user32, not gdi32!)
  static final _GetDC _getDC = _user32.lookupFunction<_GetDCNative, _GetDC>('GetDC');
  static final _ReleaseDC _releaseDC = _user32.lookupFunction<_ReleaseDCNative, _ReleaseDC>('ReleaseDC');
  static final _GetSystemMetrics _getSystemMetrics = _user32.lookupFunction<_GetSystemMetricsNative, _GetSystemMetrics>('GetSystemMetrics');
  static final _GetDesktopWindow _getDesktopWindow = _user32.lookupFunction<_GetDesktopWindowNative, _GetDesktopWindow>('GetDesktopWindow');
  
  // GDI32 functions
  static final _CreateCompatibleDC _createCompatibleDC = _gdi32.lookupFunction<_CreateCompatibleDCNative, _CreateCompatibleDC>('CreateCompatibleDC');
  static final _DeleteDC _deleteDC = _gdi32.lookupFunction<_DeleteDCNative, _DeleteDC>('DeleteDC');
  static final _CreateCompatibleBitmap _createCompatibleBitmap = _gdi32.lookupFunction<_CreateCompatibleBitmapNative, _CreateCompatibleBitmap>('CreateCompatibleBitmap');
  static final _SelectObject _selectObject = _gdi32.lookupFunction<_SelectObjectNative, _SelectObject>('SelectObject');
  static final _DeleteObject _deleteObject = _gdi32.lookupFunction<_DeleteObjectNative, _DeleteObject>('DeleteObject');
  static final _BitBlt _bitBlt = _gdi32.lookupFunction<_BitBltNative, _BitBlt>('BitBlt');
  static final _GetDIBits _getDIBits = _gdi32.lookupFunction<_GetDIBitsNative, _GetDIBits>('GetDIBits');
  
  // Constants - Windows API names (ignore: constant_identifier_names)
  // ignore: constant_identifier_names
  static const int SM_CXSCREEN = 0;
  // ignore: constant_identifier_names
  static const int SM_CYSCREEN = 1;
  // ignore: constant_identifier_names
  static const int SRCCOPY = 0x00CC0020;
  // ignore: constant_identifier_names
  static const int DIB_RGB_COLORS = 0;
  // ignore: constant_identifier_names
  static const int BI_RGB = 0;
  
  /// Capture the screen and return raw BMP pixel data
  static Uint8List? captureScreen() {
    try {
      final screenWidth = _getSystemMetrics(SM_CXSCREEN);
      final screenHeight = _getSystemMetrics(SM_CYSCREEN);
      
      if (screenWidth <= 0 || screenHeight <= 0) {
        debugPrint('[WindowsScreenCapture] Invalid screen dimensions');
        return null;
      }
      
      final hwndDesktop = _getDesktopWindow();
      final hdcScreen = _getDC(hwndDesktop);
      if (hdcScreen == 0) {
        debugPrint('[WindowsScreenCapture] Failed to get screen DC');
        return null;
      }
      
      final hdcMem = _createCompatibleDC(hdcScreen);
      final hBitmap = _createCompatibleBitmap(hdcScreen, screenWidth, screenHeight);
      final hOldBitmap = _selectObject(hdcMem, hBitmap);
      
      // Copy screen to bitmap
      _bitBlt(hdcMem, 0, 0, screenWidth, screenHeight, hdcScreen, 0, 0, SRCCOPY);
      
      // Prepare BITMAPINFOHEADER
      final bmiSize = sizeOf<BITMAPINFOHEADER>() + 4; // Extra space
      final bmi = calloc<Uint8>(bmiSize);
      final header = bmi.cast<BITMAPINFOHEADER>();
      header.ref.biSize = sizeOf<BITMAPINFOHEADER>();
      header.ref.biWidth = screenWidth;
      header.ref.biHeight = -screenHeight; // Top-down DIB
      header.ref.biPlanes = 1;
      header.ref.biBitCount = 24; // 24-bit RGB
      header.ref.biCompression = BI_RGB;
      
      // Calculate row size (must be DWORD aligned)
      final rowSize = ((screenWidth * 3 + 3) & ~3);
      final imageSize = rowSize * screenHeight;
      
      // Allocate buffer for pixel data
      final pixels = calloc<Uint8>(imageSize);
      
      // Get the bits
      final result = _getDIBits(
        hdcMem, hBitmap, 0, screenHeight,
        pixels.cast<Void>(), bmi.cast<Void>(), DIB_RGB_COLORS
      );
      
      Uint8List? pixelData;
      if (result > 0) {
        // Copy to Dart Uint8List
        pixelData = Uint8List(imageSize);
        for (int i = 0; i < imageSize; i++) {
          pixelData[i] = pixels[i];
        }
      }
      
      // Cleanup
      calloc.free(pixels);
      calloc.free(bmi);
      _selectObject(hdcMem, hOldBitmap);
      _deleteObject(hBitmap);
      _deleteDC(hdcMem);
      _releaseDC(hwndDesktop, hdcScreen);
      
      if (pixelData != null) {
        // Create BMP file in memory
        return _createBmpFile(pixelData, screenWidth, screenHeight, rowSize);
      }
      
      return null;
    } catch (e) {
      debugPrint('[WindowsScreenCapture] Error: $e');
      return null;
    }
  }
  
  /// Create a BMP file from raw pixel data
  static Uint8List _createBmpFile(Uint8List pixels, int width, int height, int rowSize) {
    final imageSize = pixels.length;
    final fileSize = 54 + imageSize; // Header (54 bytes) + pixel data
    
    final bmp = ByteData(fileSize);
    
    // BMP File Header (14 bytes)
    bmp.setUint8(0, 0x42); // 'B'
    bmp.setUint8(1, 0x4D); // 'M'
    bmp.setUint32(2, fileSize, Endian.little);
    bmp.setUint16(6, 0, Endian.little); // Reserved
    bmp.setUint16(8, 0, Endian.little); // Reserved
    bmp.setUint32(10, 54, Endian.little); // Pixel data offset
    
    // DIB Header (40 bytes)
    bmp.setUint32(14, 40, Endian.little); // Header size
    bmp.setInt32(18, width, Endian.little);
    bmp.setInt32(22, -height, Endian.little); // Negative for top-down
    bmp.setUint16(26, 1, Endian.little); // Planes
    bmp.setUint16(28, 24, Endian.little); // Bits per pixel
    bmp.setUint32(30, 0, Endian.little); // Compression (none)
    bmp.setUint32(34, imageSize, Endian.little);
    bmp.setInt32(38, 2835, Endian.little); // X pixels per meter
    bmp.setInt32(42, 2835, Endian.little); // Y pixels per meter
    bmp.setUint32(46, 0, Endian.little); // Colors used
    bmp.setUint32(50, 0, Endian.little); // Important colors
    
    // Copy pixel data (BGR format)
    final result = bmp.buffer.asUint8List();
    result.setRange(54, fileSize, pixels);
    
    return result;
  }
  
  /// Get screen dimensions
  static (int width, int height) getScreenSize() {
    return (_getSystemMetrics(SM_CXSCREEN), _getSystemMetrics(SM_CYSCREEN));
  }
}

// =============================================================================
// WINDOWS INPUT SIMULATION
// =============================================================================

class WindowsInputSimulator {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  
  static final _SetCursorPos _setCursorPos = _user32.lookupFunction<_SetCursorPosNative, _SetCursorPos>('SetCursorPos');
  static final _GetCursorPos _getCursorPos = _user32.lookupFunction<_GetCursorPosNative, _GetCursorPos>('GetCursorPos');
  static final _MouseEvent _mouseEvent = _user32.lookupFunction<_MouseEventNative, _MouseEvent>('mouse_event');
  static final _KeybdEvent _keybdEvent = _user32.lookupFunction<_KeybdEventNative, _KeybdEvent>('keybd_event');
  static final _LockWorkStation _lockWorkStation = _user32.lookupFunction<_LockWorkStationNative, _LockWorkStation>('LockWorkStation');
  static final _MessageBoxW _messageBoxW = _user32.lookupFunction<_MessageBoxWNative, _MessageBoxW>('MessageBoxW');
  
  // Mouse event flags - Windows API names (ignore: constant_identifier_names)
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_MOVE = 0x0001;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_LEFTDOWN = 0x0002;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_LEFTUP = 0x0004;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_RIGHTUP = 0x0010;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_MIDDLEUP = 0x0040;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_WHEEL = 0x0800;
  // ignore: constant_identifier_names
  static const int MOUSEEVENTF_ABSOLUTE = 0x8000;

  // Keyboard event flags - Windows API names (ignore: constant_identifier_names)
  // ignore: constant_identifier_names
  static const int KEYEVENTF_KEYUP = 0x0002;
  // ignore: constant_identifier_names
  static const int KEYEVENTF_EXTENDEDKEY = 0x0001;
  
  /// Move mouse to absolute position
  static void moveMouse(int x, int y) {
    _setCursorPos(x, y);
  }
  
  /// Get current mouse position
  static (int x, int y) getMousePosition() {
    final point = calloc<POINT>();
    _getCursorPos(point);
    final x = point.ref.x;
    final y = point.ref.y;
    calloc.free(point);
    return (x, y);
  }
  
  /// Click mouse button
  static void mouseClick(int x, int y, {String button = 'left', bool doubleClick = false}) {
    moveMouse(x, y);
    
    int downFlag, upFlag;
    switch (button) {
      case 'right':
        downFlag = MOUSEEVENTF_RIGHTDOWN;
        upFlag = MOUSEEVENTF_RIGHTUP;
        break;
      case 'middle':
        downFlag = MOUSEEVENTF_MIDDLEDOWN;
        upFlag = MOUSEEVENTF_MIDDLEUP;
        break;
      default:
        downFlag = MOUSEEVENTF_LEFTDOWN;
        upFlag = MOUSEEVENTF_LEFTUP;
    }
    
    _mouseEvent(downFlag, 0, 0, 0, 0);
    _mouseEvent(upFlag, 0, 0, 0, 0);
    
    if (doubleClick) {
      _mouseEvent(downFlag, 0, 0, 0, 0);
      _mouseEvent(upFlag, 0, 0, 0, 0);
    }
  }
  
  /// Mouse button down
  static void mouseDown({String button = 'left'}) {
    int flag;
    switch (button) {
      case 'right':
        flag = MOUSEEVENTF_RIGHTDOWN;
        break;
      case 'middle':
        flag = MOUSEEVENTF_MIDDLEDOWN;
        break;
      default:
        flag = MOUSEEVENTF_LEFTDOWN;
    }
    _mouseEvent(flag, 0, 0, 0, 0);
  }
  
  /// Mouse button up
  static void mouseUp({String button = 'left'}) {
    int flag;
    switch (button) {
      case 'right':
        flag = MOUSEEVENTF_RIGHTUP;
        break;
      case 'middle':
        flag = MOUSEEVENTF_MIDDLEUP;
        break;
      default:
        flag = MOUSEEVENTF_LEFTUP;
    }
    _mouseEvent(flag, 0, 0, 0, 0);
  }
  
  /// Scroll mouse wheel
  static void mouseScroll(int delta) {
    _mouseEvent(MOUSEEVENTF_WHEEL, 0, 0, delta * 120, 0);
  }
  
  /// Press a key (down then up)
  static void keyPress(int vkCode, {bool extended = false}) {
    keyDown(vkCode, extended: extended);
    keyUp(vkCode, extended: extended);
  }
  
  /// Key down
  static void keyDown(int vkCode, {bool extended = false}) {
    final flags = extended ? KEYEVENTF_EXTENDEDKEY : 0;
    _keybdEvent(vkCode, 0, flags, 0);
  }
  
  /// Key up
  static void keyUp(int vkCode, {bool extended = false}) {
    final flags = KEYEVENTF_KEYUP | (extended ? KEYEVENTF_EXTENDEDKEY : 0);
    _keybdEvent(vkCode, 0, flags, 0);
  }
  
  /// Type a string of text using key presses
  static void typeText(String text) {
    for (final char in text.codeUnits) {
      // Simple ASCII typing - for special chars, use VkKeyScan
      if (char >= 32 && char <= 126) {
        final vk = _charToVk(char);
        if (vk != null) {
          if (vk.$2) keyDown(0x10); // Shift
          keyPress(vk.$1);
          if (vk.$2) keyUp(0x10);
        }
      }
    }
  }
  
  /// Convert character to virtual key code
  static (int vk, bool shift)? _charToVk(int charCode) {
    // Numbers
    if (charCode >= 48 && charCode <= 57) return (charCode, false);
    // Lowercase letters
    if (charCode >= 97 && charCode <= 122) return (charCode - 32, false);
    // Uppercase letters
    if (charCode >= 65 && charCode <= 90) return (charCode, true);
    // Space
    if (charCode == 32) return (0x20, false);
    // Common punctuation
    switch (charCode) {
      case 46: return (0xBE, false); // .
      case 44: return (0xBC, false); // ,
      case 45: return (0xBD, false); // -
      case 61: return (0xBB, false); // =
      case 59: return (0xBA, false); // ;
      case 39: return (0xDE, false); // '
      case 91: return (0xDB, false); // [
      case 93: return (0xDD, false); // ]
      case 92: return (0xDC, false); // \
      case 47: return (0xBF, false); // /
      case 96: return (0xC0, false); // `
      // Shifted punctuation
      case 33: return (0x31, true); // !
      case 64: return (0x32, true); // @
      case 35: return (0x33, true); // #
      case 36: return (0x34, true); // $
      case 37: return (0x35, true); // %
      case 94: return (0x36, true); // ^
      case 38: return (0x37, true); // &
      case 42: return (0x38, true); // *
      case 40: return (0x39, true); // (
      case 41: return (0x30, true); // )
      case 95: return (0xBD, true); // _
      case 43: return (0xBB, true); // +
      case 58: return (0xBA, true); // :
      case 34: return (0xDE, true); // "
      case 60: return (0xBC, true); // <
      case 62: return (0xBE, true); // >
      case 63: return (0xBF, true); // ?
      case 123: return (0xDB, true); // {
      case 125: return (0xDD, true); // }
      case 124: return (0xDC, true); // |
      case 126: return (0xC0, true); // ~
    }
    return null;
  }
  
  /// Lock the workstation
  static void lockWorkstation() {
    _lockWorkStation();
  }
  
  /// Show a message box
  static void showMessageBox(String title, String message) {
    final titlePtr = title.toNativeUtf16();
    final messagePtr = message.toNativeUtf16();
    _messageBoxW(0, messagePtr, titlePtr, 0x40); // MB_ICONINFORMATION
    calloc.free(titlePtr);
    calloc.free(messagePtr);
  }
  
  /// Common virtual key codes
  static const Map<String, int> vkCodes = {
    'backspace': 0x08,
    'tab': 0x09,
    'enter': 0x0D,
    'shift': 0x10,
    'ctrl': 0x11,
    'alt': 0x12,
    'pause': 0x13,
    'capslock': 0x14,
    'escape': 0x1B,
    'space': 0x20,
    'pageup': 0x21,
    'pagedown': 0x22,
    'end': 0x23,
    'home': 0x24,
    'left': 0x25,
    'up': 0x26,
    'right': 0x27,
    'down': 0x28,
    'printscreen': 0x2C,
    'insert': 0x2D,
    'delete': 0x2E,
    'win': 0x5B,
    'f1': 0x70, 'f2': 0x71, 'f3': 0x72, 'f4': 0x73,
    'f5': 0x74, 'f6': 0x75, 'f7': 0x76, 'f8': 0x77,
    'f9': 0x78, 'f10': 0x79, 'f11': 0x7A, 'f12': 0x7B,
    'numlock': 0x90,
    'scrolllock': 0x91,
  };
}

// =============================================================================
// REMOTE MONITORING SERVICE
// =============================================================================

class RemoteMonitoringService {
  static String get _baseUrl => ApiConfig.remoteMonitoring;
  
  static RemoteMonitoringService? _instance;
  static RemoteMonitoringService get instance => _instance ??= RemoteMonitoringService._();
  
  RemoteMonitoringService._();
  
  // Configuration
  String? _computerName;
  String? _username;
  int _screenshotIntervalMinutes = 15;
  bool _isRunning = false;
  
  // Timers
  Timer? _screenshotTimer;
  Timer? _heartbeatTimer;
  Timer? _commandPollTimer;  // Fallback polling when WebSocket unavailable
  Timer? _streamTimer;
  Timer? _exclusionRefreshTimer;

  // WebSocket for real-time commands (faster than polling)
  WebSocketClient? _commandWebSocket;
  final bool _useWebSocketForCommands = true;  // Prefer WebSocket over polling

  // Streaming state
  bool _isStreaming = false;
  int _streamFps = 2;
  int _streamQuality = 50;

  // Audio streaming state
  bool _isAudioStreaming = false;
  Process? _audioProcess;
  Timer? _audioTimer;

  // Callbacks
  void Function(String message)? onLog;
  void Function(String error)? onError;
  void Function(bool isStreaming)? onStreamingChanged;
  void Function(bool isAudioStreaming)? onAudioStreamingChanged;
  
  /// Initialize the service
  Future<void> initialize({
    required String computerName,
    required String username,
    int screenshotIntervalMinutes = 15,
  }) async {
    _computerName = computerName;
    _username = username;
    _screenshotIntervalMinutes = screenshotIntervalMinutes;
    
    _log('=== INITIALIZATION ===');
    _log('Computer: $computerName');
    _log('Username: $username');
    _log('Screenshot interval: $screenshotIntervalMinutes minutes');
    _log('Platform: ${Platform.operatingSystem}');
    _log('Is Windows: ${Platform.isWindows}');
  }
  
  /// Start all monitoring services
  Future<void> start() async {
    if (_isRunning) {
      _log('Already running, skipping start');
      return;
    }
    if (_computerName == null || _username == null) {
      _log('ERROR: Cannot start - not initialized (computerName=$_computerName, username=$_username)');
      return;
    }

    _isRunning = true;
    _log('=== STARTING SERVICES ===');

    // Apply privacy exclusions at startup (they stay applied continuously)
    _log('Applying privacy exclusions...');
    await _applyPrivacyExclusions();

    // Start periodic exclusion refresh (every 2 minutes to pick up new exclusions)
    _log('Starting exclusion refresh timer...');
    _startExclusionRefreshTimer();

    // Start heartbeat (every 30 seconds)
    _log('Starting heartbeat timer...');
    _startHeartbeat();

    // Start periodic screenshots
    _log('Starting screenshot timer (every $_screenshotIntervalMinutes minutes)...');
    _startScreenshotTimer();

    // Start command polling (every 500ms for responsiveness)
    _log('Starting command polling...');
    _startCommandPolling();

    // Take initial screenshot
    _log('Taking initial screenshot...');
    final success = await _captureAndUploadScreenshot();
    _log('Initial screenshot result: ${success ? "SUCCESS" : "FAILED"}');

    _log('=== SERVICES STARTED ===');
  }
  
  /// Stop all monitoring services
  Future<void> stop() async {
    _isRunning = false;

    _screenshotTimer?.cancel();
    _heartbeatTimer?.cancel();
    _commandPollTimer?.cancel();
    _streamTimer?.cancel();
    _exclusionRefreshTimer?.cancel();

    _screenshotTimer = null;
    _heartbeatTimer = null;
    _commandPollTimer = null;
    _streamTimer = null;
    _exclusionRefreshTimer = null;

    // Dispose WebSocket command listener
    await _commandWebSocket?.dispose();
    _commandWebSocket = null;

    _isStreaming = false;

    // Stop audio streaming
    await _stopAudioStreaming();

    // Remove all privacy exclusions (restore windows to normal state)
    try {
      await PrivacyInjectionService.removeAllExclusions();
    } catch (e) {
      _log('Warning: Failed to remove privacy exclusions: $e');
    }

    _log('Remote monitoring services stopped');
  }

  /// Dispose the service and release all resources
  /// Resets the singleton instance for clean re-initialization
  Future<void> dispose() async {
    await stop();
    _computerName = null;
    _username = null;
    onLog = null;
    onError = null;
    onStreamingChanged = null;
    onAudioStreamingChanged = null;
  }

  /// Dispose and reset the singleton instance
  /// Call this when the user logs out or the app is closing
  static Future<void> disposeInstance() async {
    if (_instance != null) {
      await _instance!.dispose();
      _instance = null;
    }
  }
  
  /// Capture and upload a screenshot immediately
  Future<bool> captureNow() async {
    return await _captureAndUploadScreenshot();
  }
  
  // ===========================================================================
  // PRIVATE METHODS
  // ===========================================================================
  
  void _log(String message) {
    debugPrint('[RemoteMonitoring] $message');
    onLog?.call(message);
  }

  /// Apply privacy exclusions from the server
  /// This makes windows from excluded programs invisible to screen capture
  Future<void> _applyPrivacyExclusions() async {
    if (!Platform.isWindows) return;

    try {
      // Invalidate the cache to get fresh exclusions from server
      PrivacyExclusionsService.invalidateCache();

      final exclusions = await PrivacyExclusionsService.getExcludedProgramNames();
      if (exclusions.isEmpty) {
        _log('No privacy exclusions configured');
        return;
      }

      _log('Applying ${exclusions.length} privacy exclusions: $exclusions');

      // Use updateExclusions to handle adding/removing properly
      await PrivacyInjectionService.updateExclusions(exclusions);
    } catch (e) {
      _log('Error applying privacy exclusions: $e');
    }
  }

  /// Start periodic refresh of privacy exclusions
  /// This ensures new exclusions added via management are picked up
  /// AND catches newly opened instances of excluded programs
  void _startExclusionRefreshTimer() {
    _exclusionRefreshTimer?.cancel();
    // Refresh every 5 minutes to:
    // 1. Pick up new exclusions added via management
    // 2. Apply exclusions to newly opened program instances
    _exclusionRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _applyPrivacyExclusions(),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
    _sendHeartbeat(); // Send immediately
  }
  
  Future<void> _sendHeartbeat() async {
    if (!_isRunning) return;

    try {
      _log('Sending heartbeat...');
      final screenSize = Platform.isWindows ? WindowsScreenCapture.getScreenSize() : (0, 0);
      _log('Screen size: ${screenSize.$1}x${screenSize.$2}');

      final localIp = await _getLocalIp();
      _log('Local IP: $localIp');

      // Get app version from VersionCheckService (dynamically from pubspec.yaml)
      final appVersion = VersionCheckService.instance.currentVersion;

      final url = '$_baseUrl?action=heartbeat';
      _log('Heartbeat URL: $url');

      final response = await http.post(
        Uri.parse(url),
        body: {
          'computer_name': _computerName!,
          'username': _username!,
          'local_ip': localIp,
          'os_version': Platform.operatingSystemVersion,
          'app_version': appVersion,
          'screen_width': screenSize.$1.toString(),
          'screen_height': screenSize.$2.toString(),
        },
      ).timeout(const Duration(seconds: 10));
      
      _log('Heartbeat response: ${response.statusCode}');
      _log('Heartbeat body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _log('Heartbeat SUCCESS - stream_requested: ${data['stream_requested']}');
        } else {
          _log('Heartbeat FAILED: ${data['error']}');
        }
        
        // Check if streaming is requested
        if (data['stream_requested'] == true && !_isStreaming) {
          _streamFps = data['stream_fps'] ?? 2;
          _streamQuality = data['stream_quality'] ?? 50;
          _startStreaming();
        } else if (data['stream_requested'] == false && _isStreaming) {
          _stopStreaming();
        }

        // Check if audio streaming is requested
        if (data['audio_requested'] == true && !_isAudioStreaming) {
          _startAudioStreaming();
        } else if (data['audio_requested'] == false && _isAudioStreaming) {
          _stopAudioStreaming();
        }
      } else {
        _log('Heartbeat HTTP error: ${response.statusCode}');
      }
    } catch (e, stack) {
      _log('Heartbeat exception: $e');
      _log('Stack: $stack');
    }
  }
  
  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
  debugPrint('[RemoteMonitoringService] Error: $e');
}
    return 'unknown';
  }
  
  void _startScreenshotTimer() {
    _screenshotTimer?.cancel();
    _screenshotTimer = Timer.periodic(
      Duration(minutes: _screenshotIntervalMinutes),
      (_) => _captureAndUploadScreenshot(),
    );
  }
  
  Future<bool> _captureAndUploadScreenshot() async {
    _log('=== SCREENSHOT CAPTURE START ===');

    if (!_isRunning) {
      _log('ERROR: Service not running');
      return false;
    }

    if (!Platform.isWindows) {
      _log('ERROR: Not Windows platform');
      return false;
    }

    try {
      // Privacy exclusions are applied continuously at startup and refreshed every 2 minutes
      // Windows with WDA_EXCLUDEFROMCAPTURE will automatically appear black in screenshots

      _log('Step 1: Capturing screen via FFI...');

      // Capture screen
      Uint8List? bmpData;
      try {
        bmpData = WindowsScreenCapture.captureScreen();
      } catch (e, stack) {
        _log('FFI capture exception: $e');
        _log('Stack: $stack');
        return false;
      }

      if (bmpData == null) {
        _log('ERROR: FFI capture returned null');
        return false;
      }

      _log('Step 2: BMP captured, size: ${bmpData.length} bytes');

      // Convert to JPEG for smaller file size
      _log('Step 3: Converting BMP to JPEG...');
      Uint8List? jpgData;
      try {
        jpgData = await _convertBmpToJpg(bmpData);
      } catch (e, stack) {
        _log('JPEG conversion exception: $e');
        _log('Stack: $stack');
        return false;
      }

      if (jpgData == null) {
        _log('ERROR: JPEG conversion returned null');
        return false;
      }

      _log('Step 4: JPEG ready, size: ${jpgData.length} bytes');

      // Upload to server
      _log('Step 5: Uploading to server...');
      final url = '$_baseUrl?action=upload_screenshot';
      _log('Upload URL: $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['computer_name'] = _computerName!;
      request.fields['username'] = _username!;
      request.files.add(http.MultipartFile.fromBytes('screenshot', jpgData, filename: 'screenshot.jpg'));

      _log('Sending request...');
      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      _log('Upload response status: ${response.statusCode}');
      _log('Upload response body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data['success'] == true) {
          _log('=== SCREENSHOT SUCCESS ===');
          return true;
        } else {
          _log('ERROR: Server returned success=false: ${data['error']}');
        }
      } else {
        _log('ERROR: HTTP ${response.statusCode}');
      }

      return false;
    } catch (e, stack) {
      _log('Screenshot exception: $e');
      _log('Stack: $stack');
      onError?.call('Screenshot failed: $e');
      return false;
    }
  }
  
  /// Convert BMP to JPEG using the image package (pure Dart, no external processes)
  /// This is significantly faster than spawning PowerShell for each conversion
  Future<Uint8List?> _convertBmpToJpg(Uint8List bmpData, {int quality = 75}) async {
    _log('Converting BMP (${bmpData.length} bytes) to JPEG using image package...');

    try {
      // Use compute to run the CPU-intensive conversion on a background isolate
      final result = await compute(_convertBmpToJpgIsolate, _BmpConversionParams(
        bmpData: bmpData,
        quality: quality,
      ));

      if (result != null) {
        _log('JPEG conversion complete: ${result.length} bytes');
      } else {
        _log('JPEG conversion returned null');
      }

      return result;
    } catch (e, stack) {
      _log('BMP to JPG exception: $e');
      _log('Stack: $stack');

      // Fallback to PowerShell if the image package fails
      _log('Falling back to PowerShell conversion...');
      return _convertBmpToJpgPowerShell(bmpData, quality: quality);
    }
  }

  /// Fallback PowerShell conversion (slower but more compatible)
  Future<Uint8List?> _convertBmpToJpgPowerShell(Uint8List bmpData, {int quality = 75}) async {
    String? bmpPath;
    String? jpgPath;

    try {
      final tempDir = await getTemporaryDirectory();
      bmpPath = '${tempDir.path}\\temp_screenshot.bmp';
      jpgPath = '${tempDir.path}\\temp_screenshot.jpg';

      await File(bmpPath).writeAsBytes(bmpData);

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '''
        Add-Type -AssemblyName System.Drawing
        \$bmp = [System.Drawing.Image]::FromFile('$bmpPath')
        \$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { \$_.MimeType -eq 'image/jpeg' }
        \$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
        \$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $quality)
        \$bmp.Save('$jpgPath', \$encoder, \$params)
        \$bmp.Dispose()
        '''
      ]).timeout(const Duration(seconds: 15));

      if (result.exitCode == 0 && await File(jpgPath).exists()) {
        return await File(jpgPath).readAsBytes();
      }
      return null;
    } catch (e) {
      _log('PowerShell fallback failed: $e');
      return null;
    } finally {
      await _cleanupTempFile(bmpPath);
      await _cleanupTempFile(jpgPath);
    }
  }

  /// Safely delete a temp file, ignoring errors
  Future<void> _cleanupTempFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[RemoteMonitoringService] Failed to cleanup temp file $path: $e');
    }
  }

  /// Start command listener - prefers WebSocket for real-time responsiveness,
  /// falls back to HTTP polling if WebSocket unavailable
  void _startCommandPolling() {
    if (_useWebSocketForCommands) {
      _startCommandWebSocket();
    } else {
      _startCommandPollingFallback();
    }
  }

  /// Start WebSocket connection for real-time command reception
  void _startCommandWebSocket() {
    _log('Starting WebSocket command listener...');

    // Build WebSocket URL from the HTTP API endpoint
    // Convert https://tools.a-1chimney.com/api/remote_monitoring.php
    // to wss://tools.a-1chimney.com/api/ws/commands.php
    final httpUrl = Uri.parse(_baseUrl);
    final wsUrl = 'wss://${httpUrl.host}/api/ws/commands.php?computer=${Uri.encodeComponent(_computerName!)}';

    _commandWebSocket = WebSocketClient(
      url: wsUrl,
      config: const WebSocketConfig(
        reconnectDelay: Duration(seconds: 5),
        maxReconnectDelay: Duration(seconds: 30),
        pingInterval: Duration(seconds: 15),
      ),
    );

    // Listen for incoming commands
    _commandWebSocket!.messageStream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString());
          if (data is Map<String, dynamic>) {
            _handleWebSocketCommand(data);
          }
        } catch (e) {
          _log('Error parsing WebSocket command: $e');
        }
      },
      onError: (error) {
        _log('WebSocket command error: $error');
        // Fall back to polling on WebSocket errors
        _startCommandPollingFallback();
      },
      onDone: () {
        _log('WebSocket command connection closed');
        // Reconnect will be handled automatically by WebSocketClient
      },
    );

    // Start connection
    _commandWebSocket!.connect().then((connected) {
      if (connected) {
        _log('WebSocket command connection established');
        // Stop any fallback polling since WebSocket is working
        _commandPollTimer?.cancel();
        _commandPollTimer = null;
      } else {
        _log('WebSocket connection failed, using polling fallback');
        _startCommandPollingFallback();
      }
    });
  }

  /// Handle a command received via WebSocket
  void _handleWebSocketCommand(Map<String, dynamic> data) {
    final commandType = data['type'] ?? data['command_type'];
    if (commandType == null) return;

    _log('Received WebSocket command: $commandType');

    // Convert WebSocket format to expected command format
    final cmd = {
      'id': data['id'],
      'command_type': commandType,
      'command_data': data['data'] ?? data['command_data'] ?? {},
    };

    _executeCommand(cmd);
  }

  /// Fallback to HTTP polling (slower but more compatible)
  void _startCommandPollingFallback() {
    _commandPollTimer?.cancel();
    _commandPollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollCommands(),
    );
  }

  Future<void> _pollCommands() async {
    if (!_isRunning || !Platform.isWindows) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get_commands&computer=${Uri.encodeComponent(_computerName!)}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final commands = data['commands'] as List? ?? [];
          for (final cmd in commands) {
            await _executeCommand(cmd);
          }
        }
      }
    } catch (e) {
      // Command polling failures are not critical
    }
  }
  
  Future<void> _executeCommand(Map<String, dynamic> cmd) async {
    final commandId = cmd['id'];
    final commandType = cmd['command_type'] as String;
    final commandData = cmd['command_data'] as Map<String, dynamic>? ?? {};
    
    _log('Executing command: $commandType');
    
    try {
      switch (commandType) {
        case 'mouse_move':
          final x = commandData['x'] as int? ?? 0;
          final y = commandData['y'] as int? ?? 0;
          WindowsInputSimulator.moveMouse(x, y);
          break;
          
        case 'mouse_click':
          final x = commandData['x'] as int? ?? 0;
          final y = commandData['y'] as int? ?? 0;
          final button = commandData['button'] as String? ?? 'left';
          WindowsInputSimulator.mouseClick(x, y, button: button);
          break;
          
        case 'mouse_double':
          final x = commandData['x'] as int? ?? 0;
          final y = commandData['y'] as int? ?? 0;
          WindowsInputSimulator.mouseClick(x, y, doubleClick: true);
          break;
          
        case 'mouse_down':
          final button = commandData['button'] as String? ?? 'left';
          WindowsInputSimulator.mouseDown(button: button);
          break;
          
        case 'mouse_up':
          final button = commandData['button'] as String? ?? 'left';
          WindowsInputSimulator.mouseUp(button: button);
          break;
          
        case 'mouse_scroll':
          final delta = commandData['delta'] as int? ?? 0;
          WindowsInputSimulator.mouseScroll(delta);
          break;
          
        case 'key_press':
          final key = commandData['key'] as String? ?? '';
          final vk = WindowsInputSimulator.vkCodes[key.toLowerCase()];
          if (vk != null) {
            WindowsInputSimulator.keyPress(vk);
          }
          break;
          
        case 'key_down':
          final key = commandData['key'] as String? ?? '';
          final vk = WindowsInputSimulator.vkCodes[key.toLowerCase()];
          if (vk != null) {
            WindowsInputSimulator.keyDown(vk);
          }
          break;
          
        case 'key_up':
          final key = commandData['key'] as String? ?? '';
          final vk = WindowsInputSimulator.vkCodes[key.toLowerCase()];
          if (vk != null) {
            WindowsInputSimulator.keyUp(vk);
          }
          break;
          
        case 'key_combo':
          final keys = commandData['keys'] as List? ?? [];
          // Press all keys down
          for (final key in keys) {
            final vk = WindowsInputSimulator.vkCodes[key.toString().toLowerCase()];
            if (vk != null) WindowsInputSimulator.keyDown(vk);
          }
          // Release all keys
          for (final key in keys.reversed) {
            final vk = WindowsInputSimulator.vkCodes[key.toString().toLowerCase()];
            if (vk != null) WindowsInputSimulator.keyUp(vk);
          }
          break;
          
        case 'type_text':
          final text = commandData['text'] as String? ?? '';
          WindowsInputSimulator.typeText(text);
          break;
          
        case 'screenshot_now':
          await _captureAndUploadScreenshot();
          break;
          
        case 'lock_screen':
          WindowsInputSimulator.lockWorkstation();
          break;
          
        case 'message_box':
          final title = commandData['title'] as String? ?? 'A1 Tools';
          final message = commandData['message'] as String? ?? '';
          WindowsInputSimulator.showMessageBox(title, message);
          break;
      }
      
      // Acknowledge command
      await _acknowledgeCommand(commandId);
    } catch (e) {
      _log('Command execution failed: $e');
    }
  }
  
  Future<void> _acknowledgeCommand(dynamic commandId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl?action=ack_command'),
        body: {'command_id': commandId.toString()},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
  debugPrint('[RemoteMonitoringService] Error: $e');
}
  }
  
  void _startStreaming() {
    if (_isStreaming) {
      _log('Already streaming, skipping start');
      return;
    }
    
    _isStreaming = true;
    onStreamingChanged?.call(true);
    _log('=== STARTING LIVE STREAM ===');
    _log('FPS: $_streamFps, Quality: $_streamQuality');
    
    final intervalMs = (1000 / _streamFps).round();
    _log('Frame interval: ${intervalMs}ms');
    _streamTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _captureAndStreamFrame());
  }
  
  void _stopStreaming() {
    if (!_isStreaming) return;
    
    _streamTimer?.cancel();
    _streamTimer = null;
    _isStreaming = false;
    onStreamingChanged?.call(false);
    _log('=== STOPPED LIVE STREAM ===');
  }
  
  Future<void> _captureAndStreamFrame() async {
    if (!_isStreaming || !Platform.isWindows) return;

    try {
      // Privacy exclusions are applied continuously at startup
      // Windows with WDA_EXCLUDEFROMCAPTURE will automatically appear black

      final bmpData = WindowsScreenCapture.captureScreen();
      if (bmpData == null) {
        _log('Stream frame: capture failed');
        return;
      }

      final jpgData = await _convertBmpToJpg(bmpData, quality: _streamQuality);
      if (jpgData == null) {
        _log('Stream frame: conversion failed');
        return;
      }

      // Upload frame
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl?action=stream_frame'));
      request.fields['computer_name'] = _computerName!;
      request.files.add(http.MultipartFile.fromBytes('frame', jpgData, filename: 'frame.jpg'));

      final response = await request.send().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        _log('Stream frame upload failed: ${response.statusCode}');
      }
    } catch (e) {
      _log('Stream frame error: $e');
    }
  }

  // ===========================================================================
  // AUDIO STREAMING
  // ===========================================================================

  Future<void> _startAudioStreaming() async {
    if (_isAudioStreaming) {
      _log('Already audio streaming, skipping start');
      return;
    }

    if (!Platform.isWindows) {
      _log('Audio streaming only supported on Windows');
      return;
    }

    _isAudioStreaming = true;
    onAudioStreamingChanged?.call(true);
    _log('=== STARTING AUDIO STREAM ===');

    // Use a timer to capture and upload audio chunks periodically
    _audioTimer = Timer.periodic(const Duration(seconds: 2), (_) => _captureAndUploadAudio());

    // Initial capture
    _captureAndUploadAudio();
  }

  Future<void> _stopAudioStreaming() async {
    if (!_isAudioStreaming) return;

    _log('=== STOPPING AUDIO STREAM ===');

    _audioTimer?.cancel();
    _audioTimer = null;

    _audioProcess?.kill();
    _audioProcess = null;

    _isAudioStreaming = false;
    onAudioStreamingChanged?.call(false);
  }

  Future<void> _captureAndUploadAudio() async {
    if (!_isAudioStreaming || !Platform.isWindows) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final audioPath = '${tempDir.path}\\audio_chunk.wav';

      // Find ffmpeg.exe - it's bundled in the app directory
      final exePath = Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;
      final ffmpegPath = '$appDir\\ffmpeg.exe';

      // Check if bundled ffmpeg exists
      if (!await File(ffmpegPath).exists()) {
        _log('FFmpeg not found at: $ffmpegPath');
        return;
      }

      // Use PowerShell to find and capture from the default audio output device
      // This uses FFmpeg's dshow to capture the "Stereo Mix" or similar loopback device
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '''
# Get list of audio devices from FFmpeg
\$ffmpegOutput = & "$ffmpegPath" -list_devices true -f dshow -i dummy 2>&1 | Out-String

# Find a suitable audio capture device (prefer Stereo Mix, then any audio device)
\$audioDevice = \$null

# Look for Stereo Mix first (best for capturing system audio)
if (\$ffmpegOutput -match '"(Stereo Mix[^"]*)"') {
    \$audioDevice = \$Matches[1]
}
# Try "What U Hear" (Realtek)
elseif (\$ffmpegOutput -match '"(What U Hear[^"]*)"') {
    \$audioDevice = \$Matches[1]
}
# Try any loopback device
elseif (\$ffmpegOutput -match '"([^"]*[Ll]oopback[^"]*)"') {
    \$audioDevice = \$Matches[1]
}
# Try virtual audio cable
elseif (\$ffmpegOutput -match '"(CABLE Output[^"]*)"') {
    \$audioDevice = \$Matches[1]
}
# Fallback to microphone (won't capture system audio but better than nothing)
elseif (\$ffmpegOutput -match '"(Microphone[^"]*)"') {
    \$audioDevice = \$Matches[1]
}

if (\$audioDevice) {
    # Capture 2 seconds of audio
    & "$ffmpegPath" -y -f dshow -i "audio=\$audioDevice" -t 2 -acodec pcm_s16le -ar 22050 -ac 1 "$audioPath" 2>\$null
    if (Test-Path "$audioPath") {
        exit 0
    }
}

# If no device found or capture failed, exit with error
exit 1
'''
      ]).timeout(const Duration(seconds: 8));

      if (result.exitCode != 0) {
        _log('Audio capture failed: ${result.stderr}');
        return;
      }

      // Check if audio file was created
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        _log('Audio file not created');
        return;
      }

      final audioData = await audioFile.readAsBytes();
      if (audioData.isEmpty) {
        _log('Audio file is empty');
        return;
      }

      _log('Audio captured: ${audioData.length} bytes');

      // Upload audio chunk
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl?action=audio_frame'));
      request.fields['computer_name'] = _computerName!;
      request.files.add(http.MultipartFile.fromBytes('audio', audioData, filename: 'audio.wav'));

      final response = await request.send().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _log('Audio chunk uploaded successfully');
      } else {
        _log('Audio upload failed: ${response.statusCode}');
      }

      // Cleanup
      try {
        await audioFile.delete();
      } catch (e) {
  debugPrint('[RemoteMonitoringService] Error: $e');
}
    } catch (e) {
      _log('Audio capture error: $e');
    }
  }
}

// =============================================================================
// IMAGE CONVERSION HELPERS (outside class for use with compute/isolate)
// =============================================================================

/// Parameters for BMP to JPEG conversion in isolate
class _BmpConversionParams {
  final Uint8List bmpData;
  final int quality;

  _BmpConversionParams({required this.bmpData, required this.quality});
}

/// Convert BMP to JPEG in a background isolate (top-level function for compute)
/// Using the image package for pure-Dart conversion (faster than PowerShell)
Uint8List? _convertBmpToJpgIsolate(_BmpConversionParams params) {
  try {
    // Decode the BMP data
    final image = img.decodeBmp(params.bmpData);
    if (image == null) {
      return null;
    }

    // Encode as JPEG with specified quality
    return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
  } catch (e) {
    // Return null on error - the caller will handle fallback
    return null;
  }
}
