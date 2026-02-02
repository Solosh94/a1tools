#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <wchar.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ******** SINGLE INSTANCE GUARD ********
  // Use a unique, stable name for your app's mutex
  const wchar_t* kMutexName = L"A1ToolsSingleInstanceMutex";

  // Create (or open if it already exists) a named mutex
  HANDLE hMutex = ::CreateMutexW(nullptr, FALSE, kMutexName);

  if (hMutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running.

    // Try to find the existing window by its title and bring it to front.
    // IMPORTANT: this must match the title you use in window.Create(...)
    HWND existing = ::FindWindowW(nullptr, L"A1 Tools");
    if (existing != nullptr) {
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }

    // Close our handle (we don't own the mutex) and exit.
    ::CloseHandle(hMutex);
    return 0;
  }
  // ******** END SINGLE INSTANCE GUARD ********

  // Detect launch source from command line flags
  bool autoStart = false;
  bool crashRestart = false;
  bool serviceRestart = false;

  if (command_line != nullptr) {
    // Check for auto-start flag (from Windows startup)
    if (wcsstr(command_line, L"--auto-start") != nullptr) {
      autoStart = true;
    }
    // Check for crash restart flag (from in-app crash recovery - Layer 1)
    if (wcsstr(command_line, L"--crash-restart") != nullptr) {
      crashRestart = true;
    }
    // Check for service restart flag (from service helper - Layer 2)
    if (wcsstr(command_line, L"--service-restart") != nullptr) {
      serviceRestart = true;
    }
  }

  // Log restart source for debugging (only when console is available)
  if (crashRestart || serviceRestart) {
    // App was restarted by the multi-layer restart system
    // The Dart code will read these flags to track restart telemetry
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"A1 Tools", origin, size)) {
    ::CoUninitialize();
    if (hMutex) {
      ::CloseHandle(hMutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // If we were launched by Windows auto-start or a restart mechanism, minimize the window
  // This keeps the app running in the system tray without interrupting the user
  if (autoStart || crashRestart || serviceRestart) {
    HWND hwnd = ::FindWindowW(nullptr, L"A1 Tools");
    if (hwnd != nullptr) {
      ::ShowWindow(hwnd, SW_MINIMIZE);
    }
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();

  // Clean up our mutex handle before exiting
  if (hMutex) {
    ::CloseHandle(hMutex);
  }

  return EXIT_SUCCESS;
}
