#include "privacy_injector.h"
#include <tlhelp32.h>
#include <psapi.h>
#include <cwctype>

#pragma comment(lib, "psapi.lib")

// Function pointer type for SetWindowVisibility in the payload DLL
typedef BOOL(__cdecl* SetWindowVisibilityFunc)(HWND hwnd, BOOL hide);

// Helper to convert string to lowercase
static std::wstring ToLowerCase(const std::wstring& str) {
    std::wstring result;
    result.reserve(str.size());
    for (wchar_t c : str) {
        result.push_back(static_cast<wchar_t>(towlower(static_cast<wint_t>(c))));
    }
    return result;
}

// Callback data for EnumWindows
struct EnumWindowsData {
    DWORD targetPid;
    std::vector<HWND>* windows;
};

// EnumWindows callback to find windows by PID
static BOOL CALLBACK EnumWindowsCallback(HWND hwnd, LPARAM lParam) {
    auto* data = reinterpret_cast<EnumWindowsData*>(lParam);
    DWORD windowPid = 0;
    GetWindowThreadProcessId(hwnd, &windowPid);

    if (windowPid == data->targetPid && IsWindowVisible(hwnd)) {
        data->windows->push_back(hwnd);
    }
    return TRUE;
}

PrivacyInjector& PrivacyInjector::GetInstance() {
    static PrivacyInjector instance;
    return instance;
}

PrivacyInjector::PrivacyInjector() : initialized_(false) {}

PrivacyInjector::~PrivacyInjector() {
    RestoreAll();
}

bool PrivacyInjector::Initialize(const std::wstring& payloadDllPath) {
    // Verify the DLL exists
    DWORD attrs = GetFileAttributesW(payloadDllPath.c_str());
    if (attrs == INVALID_FILE_ATTRIBUTES) {
        OutputDebugStringW(L"[PrivacyInjector] Payload DLL not found\n");
        return false;
    }

    payload_dll_path_ = payloadDllPath;
    initialized_ = true;
    OutputDebugStringW(L"[PrivacyInjector] Initialized\n");
    return true;
}

std::vector<DWORD> PrivacyInjector::GetProcessIdsByName(const std::wstring& processName) {
    std::vector<DWORD> pids;
    std::wstring lowerName = ToLowerCase(processName);

    // Add .exe if not present
    if (lowerName.find(L".exe") == std::wstring::npos) {
        lowerName += L".exe";
    }

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        return pids;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(pe32);

    if (Process32FirstW(snapshot, &pe32)) {
        do {
            std::wstring exeName = ToLowerCase(pe32.szExeFile);
            if (exeName == lowerName || exeName.find(lowerName) != std::wstring::npos) {
                pids.push_back(pe32.th32ProcessID);
            }
        } while (Process32NextW(snapshot, &pe32));
    }

    CloseHandle(snapshot);
    return pids;
}

std::vector<HWND> PrivacyInjector::GetProcessWindows(DWORD pid) {
    std::vector<HWND> windows;
    EnumWindowsData data = { pid, &windows };
    EnumWindows(EnumWindowsCallback, reinterpret_cast<LPARAM>(&data));
    return windows;
}

bool PrivacyInjector::InjectDll(DWORD pid) {
    if (payload_dll_path_.empty()) {
        return false;
    }

    // Check if already injected
    if (injected_processes_.find(pid) != injected_processes_.end()) {
        return true;
    }

    // Open target process
    HANDLE hProcess = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ,
        FALSE, pid);

    if (!hProcess) {
        OutputDebugStringW(L"[PrivacyInjector] Failed to open process\n");
        return false;
    }

    // Allocate memory in target process for DLL path
    size_t dllPathSize = (payload_dll_path_.size() + 1) * sizeof(wchar_t);
    LPVOID remotePath = VirtualAllocEx(hProcess, nullptr, dllPathSize,
        MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    if (!remotePath) {
        CloseHandle(hProcess);
        return false;
    }

    // Write DLL path to target process
    if (!WriteProcessMemory(hProcess, remotePath, payload_dll_path_.c_str(), dllPathSize, nullptr)) {
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return false;
    }

    // Get LoadLibraryW address
    HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
    FARPROC loadLibrary = GetProcAddress(kernel32, "LoadLibraryW");

    if (!loadLibrary) {
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return false;
    }

    // Create remote thread to load DLL
    HANDLE hThread = CreateRemoteThread(hProcess, nullptr, 0,
        reinterpret_cast<LPTHREAD_START_ROUTINE>(loadLibrary),
        remotePath, 0, nullptr);

    if (!hThread) {
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return false;
    }

    // Wait for DLL to load
    WaitForSingleObject(hThread, 5000);

    // Get the loaded DLL's handle
    DWORD exitCode = 0;
    GetExitCodeThread(hThread, &exitCode);
    HMODULE remoteModule = reinterpret_cast<HMODULE>(static_cast<ULONG_PTR>(exitCode));

    CloseHandle(hThread);
    VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
    CloseHandle(hProcess);

    if (remoteModule) {
        injected_processes_[pid] = remoteModule;
        OutputDebugStringW(L"[PrivacyInjector] DLL injected successfully\n");
        return true;
    }

    return false;
}

bool PrivacyInjector::CallSetWindowVisibility(DWORD pid, HWND hwnd, bool hide) {
    // SetWindowDisplayAffinity MUST be called from the process that owns the window
    // So we need to inject our DLL and call the function remotely

    // First, make sure DLL is injected
    if (!InjectDll(pid)) {
        OutputDebugStringW(L"[PrivacyInjector] Failed to inject DLL\n");
        return false;
    }

    // Open target process
    HANDLE hProcess = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ,
        FALSE, pid);

    if (!hProcess) {
        OutputDebugStringW(L"[PrivacyInjector] Failed to open process for remote call\n");
        return false;
    }

    // Find the injected DLL in the target process
    HMODULE hMods[1024];
    DWORD cbNeeded;
    HMODULE targetModule = nullptr;

    if (EnumProcessModules(hProcess, hMods, sizeof(hMods), &cbNeeded)) {
        for (unsigned int i = 0; i < (cbNeeded / sizeof(HMODULE)); i++) {
            wchar_t modName[MAX_PATH];
            if (GetModuleFileNameExW(hProcess, hMods[i], modName, MAX_PATH)) {
                std::wstring modNameStr(modName);
                if (modNameStr.find(L"privacy_payload.dll") != std::wstring::npos) {
                    targetModule = hMods[i];
                    break;
                }
            }
        }
    }

    if (!targetModule) {
        OutputDebugStringW(L"[PrivacyInjector] Could not find injected DLL in target process\n");
        CloseHandle(hProcess);
        return false;
    }

    // Load the DLL locally to find the function offset for HideAllProcessWindows
    // We use HideAllProcessWindows because it only takes one param (compatible with CreateRemoteThread)
    HMODULE localDll = LoadLibraryW(payload_dll_path_.c_str());
    if (!localDll) {
        OutputDebugStringW(L"[PrivacyInjector] Failed to load DLL locally\n");
        CloseHandle(hProcess);
        return false;
    }

    FARPROC localHideAll = GetProcAddress(localDll, "HideAllProcessWindows");
    if (!localHideAll) {
        OutputDebugStringW(L"[PrivacyInjector] HideAllProcessWindows not found in DLL\n");
        FreeLibrary(localDll);
        CloseHandle(hProcess);
        return false;
    }

    // Calculate offset of function within DLL
    DWORD_PTR hideAllOffset = reinterpret_cast<DWORD_PTR>(localHideAll) - reinterpret_cast<DWORD_PTR>(localDll);
    FreeLibrary(localDll);

    FARPROC remoteHideAll = reinterpret_cast<FARPROC>(reinterpret_cast<DWORD_PTR>(targetModule) + hideAllOffset);

    // Create remote thread to call HideAllProcessWindows(hide)
    HANDLE hThread = CreateRemoteThread(hProcess, nullptr, 0,
        reinterpret_cast<LPTHREAD_START_ROUTINE>(remoteHideAll),
        reinterpret_cast<LPVOID>(static_cast<DWORD_PTR>(hide ? TRUE : FALSE)),
        0, nullptr);

    if (!hThread) {
        wchar_t msg[256];
        swprintf_s(msg, L"[PrivacyInjector] CreateRemoteThread failed: %lu\n", GetLastError());
        OutputDebugStringW(msg);
        CloseHandle(hProcess);
        return false;
    }

    // Wait for thread to complete
    WaitForSingleObject(hThread, 5000);

    DWORD exitCode = 0;
    GetExitCodeThread(hThread, &exitCode);

    CloseHandle(hThread);
    CloseHandle(hProcess);

    wchar_t msg[256];
    swprintf_s(msg, L"[PrivacyInjector] Remote call completed, windows affected: %lu\n", exitCode);
    OutputDebugStringW(msg);

    return exitCode > 0;
}

int PrivacyInjector::HideProcessWindows(const std::wstring& processName, bool hide) {
    if (!initialized_) {
        return 0;
    }

    std::wstring lowerName = ToLowerCase(processName);
    std::vector<DWORD> pids = GetProcessIdsByName(processName);
    int totalAffected = 0;

    for (DWORD pid : pids) {
        if (HideProcessWindowsByPid(pid, hide)) {
            totalAffected++;
        }
    }

    if (totalAffected > 0) {
        hidden_process_names_[lowerName] = hide;
    }

    return totalAffected;
}

bool PrivacyInjector::HideProcessWindowsByPid(DWORD pid, bool hide) {
    // SetWindowDisplayAffinity MUST be called from within the process that owns the window
    // So we inject our payload DLL and call HideAllProcessWindows from there

    std::vector<HWND> windows = GetProcessWindows(pid);
    if (windows.empty()) {
        wchar_t msg[256];
        swprintf_s(msg, L"[PrivacyInjector] No visible windows found for PID %lu\n", pid);
        OutputDebugStringW(msg);
        return false;
    }

    wchar_t msg[256];
    swprintf_s(msg, L"[PrivacyInjector] Found %zu windows for PID %lu, attempting injection\n",
        windows.size(), pid);
    OutputDebugStringW(msg);

    // Use injection to call the function from within the target process
    return CallSetWindowVisibility(pid, windows[0], hide);
}

std::vector<std::wstring> PrivacyInjector::GetHiddenProcesses() const {
    std::vector<std::wstring> result;
    for (const auto& pair : hidden_process_names_) {
        if (pair.second) {
            result.push_back(pair.first);
        }
    }
    return result;
}

bool PrivacyInjector::IsProcessHidden(const std::wstring& processName) const {
    std::wstring lowerName = ToLowerCase(processName);
    auto it = hidden_process_names_.find(lowerName);
    return it != hidden_process_names_.end() && it->second;
}

void PrivacyInjector::RestoreAll() {
    for (auto& pair : hidden_process_names_) {
        if (pair.second) {
            HideProcessWindows(pair.first, false);
        }
    }
    hidden_process_names_.clear();
    injected_processes_.clear();
}
