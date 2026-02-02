#ifndef PRIVACY_INJECTOR_H_
#define PRIVACY_INJECTOR_H_

#include <windows.h>
#include <string>
#include <vector>
#include <map>

// Privacy Injector
// Injects privacy_payload.dll into target processes to hide their windows
// from screen capture using SetWindowDisplayAffinity

class PrivacyInjector {
public:
    static PrivacyInjector& GetInstance();

    // Initialize the injector with the path to privacy_payload.dll
    bool Initialize(const std::wstring& payloadDllPath);

    // Hide windows of a specific process by name (e.g., "notepad")
    // Returns number of processes affected
    int HideProcessWindows(const std::wstring& processName, bool hide);

    // Hide windows of a specific process by PID
    bool HideProcessWindowsByPid(DWORD pid, bool hide);

    // Get list of hidden processes
    std::vector<std::wstring> GetHiddenProcesses() const;

    // Check if a process is currently hidden
    bool IsProcessHidden(const std::wstring& processName) const;

    // Restore all hidden processes
    void RestoreAll();

private:
    PrivacyInjector();
    ~PrivacyInjector();

    // Disable copy
    PrivacyInjector(const PrivacyInjector&) = delete;
    PrivacyInjector& operator=(const PrivacyInjector&) = delete;

    // Inject DLL into a process
    bool InjectDll(DWORD pid);

    // Call SetWindowVisibility in the injected DLL
    bool CallSetWindowVisibility(DWORD pid, HWND hwnd, bool hide);

    // Find all windows belonging to a process
    std::vector<HWND> GetProcessWindows(DWORD pid);

    // Find all PIDs for a process name
    std::vector<DWORD> GetProcessIdsByName(const std::wstring& processName);

    std::wstring payload_dll_path_;
    std::map<DWORD, HMODULE> injected_processes_; // PID -> remote DLL handle
    std::map<std::wstring, bool> hidden_process_names_; // lowercase name -> hidden state
    bool initialized_;
};

#endif  // PRIVACY_INJECTOR_H_
