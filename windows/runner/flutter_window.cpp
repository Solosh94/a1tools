#include "flutter_window.h"

#include <optional>
#include <vector>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "privacy_injector.h"

// Helper function to convert UTF-8 std::string to std::wstring
static std::wstring Utf8ToWstring(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
        static_cast<int>(str.size()), nullptr, 0);
    std::wstring result(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
        static_cast<int>(str.size()), &result[0], size_needed);
    return result;
}

// Helper function to convert std::wstring to UTF-8 std::string
static std::string WstringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(),
        static_cast<int>(wstr.size()), nullptr, 0, nullptr, nullptr);
    std::string result(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(),
        static_cast<int>(wstr.size()), &result[0], size_needed, nullptr, nullptr);
    return result;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Set up method channel for capture protection toggle
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.a1chimney.a1tools/capture_protection",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setCaptureProtection") {
          const auto* args = std::get_if<bool>(call.arguments());
          if (args) {
            this->SetCaptureProtection(*args);
            result->Success();
          } else {
            result->Error("INVALID_ARGUMENT", "Expected boolean argument");
          }
        } else {
          result->NotImplemented();
        }
      });

  // Set up method channel for privacy injection (hide other windows from capture)
  auto privacyChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.a1chimney.a1tools/privacy_injection",
      &flutter::StandardMethodCodec::GetInstance());

  // Initialize privacy injector with DLL path
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  std::wstring exeDir(exePath);
  size_t lastSlash = exeDir.find_last_of(L"\\/");
  if (lastSlash != std::wstring::npos) {
    exeDir = exeDir.substr(0, lastSlash + 1);
  }
  std::wstring dllPath = exeDir + L"privacy_payload.dll";
  PrivacyInjector::GetInstance().Initialize(dllPath);

  privacyChannel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (call.method_name() == "hideProcessWindows") {
          // Expected args: {"processName": "notepad", "hide": true}
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto nameIt = args->find(flutter::EncodableValue("processName"));
            auto hideIt = args->find(flutter::EncodableValue("hide"));

            if (nameIt != args->end() && hideIt != args->end()) {
              const auto* name = std::get_if<std::string>(&nameIt->second);
              const auto* hide = std::get_if<bool>(&hideIt->second);

              if (name && hide) {
                // Convert UTF-8 string to wstring
                std::wstring wname = Utf8ToWstring(*name);
                int affected = PrivacyInjector::GetInstance().HideProcessWindows(wname, *hide);
                result->Success(flutter::EncodableValue(affected));
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENT", "Expected {processName: string, hide: bool}");

        } else if (call.method_name() == "hideMultipleProcesses") {
          // Expected args: {"processes": ["notepad", "chrome"], "hide": true}
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto processesIt = args->find(flutter::EncodableValue("processes"));
            auto hideIt = args->find(flutter::EncodableValue("hide"));

            if (processesIt != args->end() && hideIt != args->end()) {
              const auto* processes = std::get_if<flutter::EncodableList>(&processesIt->second);
              const auto* hide = std::get_if<bool>(&hideIt->second);

              if (processes && hide) {
                int totalAffected = 0;
                for (const auto& proc : *processes) {
                  const auto* name = std::get_if<std::string>(&proc);
                  if (name) {
                    std::wstring wname = Utf8ToWstring(*name);
                    totalAffected += PrivacyInjector::GetInstance().HideProcessWindows(wname, *hide);
                  }
                }
                result->Success(flutter::EncodableValue(totalAffected));
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENT", "Expected {processes: string[], hide: bool}");

        } else if (call.method_name() == "getHiddenProcesses") {
          auto hiddenList = PrivacyInjector::GetInstance().GetHiddenProcesses();
          flutter::EncodableList encodedList;
          for (const auto& name : hiddenList) {
            encodedList.push_back(flutter::EncodableValue(WstringToUtf8(name)));
          }
          result->Success(flutter::EncodableValue(encodedList));

        } else if (call.method_name() == "restoreAll") {
          PrivacyInjector::GetInstance().RestoreAll();
          result->Success();

        } else if (call.method_name() == "isProcessHidden") {
          const auto* args = std::get_if<std::string>(call.arguments());
          if (args) {
            std::wstring wname = Utf8ToWstring(*args);
            bool hidden = PrivacyInjector::GetInstance().IsProcessHidden(wname);
            result->Success(flutter::EncodableValue(hidden));
          } else {
            result->Error("INVALID_ARGUMENT", "Expected process name string");
          }

        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
