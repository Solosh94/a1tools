// Privacy Payload DLL
// This DLL is injected into target processes to control window visibility
// It calls SetWindowDisplayAffinity from within the target process context

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

// Redefine WDA_EXCLUDEFROMCAPTURE in case SDK is older
#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

#ifndef WDA_NONE
#define WDA_NONE 0x00000000
#endif

// Export function to set window visibility (hide from screen capture)
// hwnd: Window handle to modify
// hide: true to hide from capture, false to show
// Returns: true on success, false on failure
extern "C" __declspec(dllexport) BOOL SetWindowVisibility(HWND hwnd, BOOL hide) {
    if (!hwnd || !IsWindow(hwnd)) {
        return FALSE;
    }

    DWORD affinity = hide ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE;
    return SetWindowDisplayAffinity(hwnd, affinity);
}

// Structure for passing data to EnumWindows callback
struct HideWindowsData {
    DWORD targetPid;
    BOOL hide;
    int count;
};

// EnumWindows callback for hiding windows
static BOOL CALLBACK EnumWindowsHideCallback(HWND hwnd, LPARAM lParam) {
    auto* data = reinterpret_cast<HideWindowsData*>(lParam);
    DWORD windowPid = 0;
    GetWindowThreadProcessId(hwnd, &windowPid);

    if (windowPid == data->targetPid && IsWindowVisible(hwnd)) {
        DWORD affinity = data->hide ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE;
        if (SetWindowDisplayAffinity(hwnd, affinity)) {
            data->count++;
        }
    }
    return TRUE;
}

// Export function to enumerate and hide all windows of this process
// This is called via CreateRemoteThread, so the parameter is passed as LPVOID
// The parameter is interpreted as BOOL (0 = show, non-0 = hide)
extern "C" __declspec(dllexport) DWORD WINAPI HideAllProcessWindows(LPVOID lpParam) {
    BOOL hide = (lpParam != nullptr);
    DWORD currentPid = GetCurrentProcessId();

    HideWindowsData data;
    data.targetPid = currentPid;
    data.hide = hide;
    data.count = 0;

    EnumWindows(EnumWindowsHideCallback, reinterpret_cast<LPARAM>(&data));

    return static_cast<DWORD>(data.count);
}

// DLL entry point
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    switch (ul_reason_for_call) {
    case DLL_PROCESS_ATTACH:
        // Disable thread attach/detach notifications for performance
        DisableThreadLibraryCalls(hModule);
        break;
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}
