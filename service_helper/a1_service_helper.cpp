// A1 Tools Service Helper - Layer 2 of the multi-layered restart system
// Background service component that ensures application availability
// Check interval: 2 minutes
//
// Build with Visual Studio:
// cl /EHsc /O2 /DNDEBUG /MT a1_service_helper.cpp /link /SUBSYSTEM:WINDOWS /OUT:a1_service_helper.exe user32.lib kernel32.lib advapi32.lib shlwapi.lib

#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS

#include <windows.h>
#include <tlhelp32.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <stdio.h>
#include <string>
#include <fstream>
#include <ctime>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")

// Configuration
const int CHECK_INTERVAL_MS = 2 * 60 * 1000;  // 2 minutes
const int UPDATE_LOCK_TIMEOUT_MINUTES = 10;
const int RESTART_LOCK_TIMEOUT_SECONDS = 30;
const wchar_t* APP_EXE_NAME = L"a1_tools.exe";
const wchar_t* SERVICE_HELPER_MUTEX_NAME = L"A1ToolsServiceHelperMutex";
const wchar_t* APP_MUTEX_NAME = L"A1ToolsSingleInstanceMutex";
const wchar_t* UPDATE_LOCK_FILE = L".update_in_progress";
const wchar_t* RESTART_LOCK_FILE = L".restart_pending";
const wchar_t* LOG_FILE_NAME = L"service_helper.log";
const size_t MAX_LOG_SIZE = 1024 * 1024;  // 1MB

// Global variables
std::wstring g_appDataDir;
std::wstring g_logFilePath;
HANDLE g_hMutex = NULL;

// Forward declarations
void Log(const wchar_t* message);
void Log(const std::wstring& message);
bool IsUpdateInProgress();
bool IsRestartPending();
bool IsInstallerRunning();
bool IsAppRunning();
void RecoverApp();
void CreateRestartLock();
void RemoveRestartLock();
std::wstring GetAppDataDir();
void PerformCheck();

// Entry point - Windows subsystem (no console)
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow) {
    // Get AppData directory
    g_appDataDir = GetAppDataDir();
    if (g_appDataDir.empty()) {
        return 1;
    }
    g_logFilePath = g_appDataDir + L"\\" + LOG_FILE_NAME;

    // Check for --check-once or --verify flag (used by Task Scheduler)
    bool checkOnce = false;
    if (lpCmdLine != nullptr) {
        std::wstring cmdLine(lpCmdLine);
        if (cmdLine.find(L"--check-once") != std::wstring::npos ||
            cmdLine.find(L"--verify") != std::wstring::npos) {
            checkOnce = true;
        }
    }

    // Try to acquire mutex (prevent multiple instances)
    g_hMutex = CreateMutexW(NULL, TRUE, SERVICE_HELPER_MUTEX_NAME);
    if (g_hMutex == NULL || GetLastError() == ERROR_ALREADY_EXISTS) {
        if (g_hMutex) CloseHandle(g_hMutex);
        Log(L"Service helper already running, exiting");
        return 0;
    }

    Log(L"A1 Tools Service Helper started");

    if (checkOnce) {
        Log(L"Running in verify mode");
        PerformCheck();
        CloseHandle(g_hMutex);
        return 0;
    }

    // Main service loop
    while (true) {
        PerformCheck();
        Sleep(CHECK_INTERVAL_MS);
    }

    CloseHandle(g_hMutex);
    return 0;
}

// Get the AppData\Local\A1 Tools directory
std::wstring GetAppDataDir() {
    wchar_t path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, path))) {
        std::wstring appDataPath(path);
        appDataPath += L"\\A1 Tools";

        // Create directory if it doesn't exist
        CreateDirectoryW(appDataPath.c_str(), NULL);

        return appDataPath;
    }
    return L"";
}

// Log a message to the log file
void Log(const wchar_t* message) {
    Log(std::wstring(message));
}

void Log(const std::wstring& message) {
    if (g_logFilePath.empty()) return;

    // Check log file size and rotate if needed
    WIN32_FILE_ATTRIBUTE_DATA fileInfo;
    if (GetFileAttributesExW(g_logFilePath.c_str(), GetFileExInfoStandard, &fileInfo)) {
        if (fileInfo.nFileSizeLow > MAX_LOG_SIZE) {
            std::wstring backupPath = g_logFilePath + L".old";
            DeleteFileW(backupPath.c_str());
            MoveFileW(g_logFilePath.c_str(), backupPath.c_str());
        }
    }

    // Get current time
    time_t now = time(nullptr);
    struct tm timeinfo;
    localtime_s(&timeinfo, &now);
    wchar_t timestamp[32];
    wcsftime(timestamp, 32, L"%Y-%m-%d %H:%M:%S", &timeinfo);

    // Write to log file
    FILE* file = _wfopen(g_logFilePath.c_str(), L"a, ccs=UTF-8");
    if (file) {
        fwprintf(file, L"[%s] %s\n", timestamp, message.c_str());
        fclose(file);
    }
}

// Perform the availability check
void PerformCheck() {
    Log(L"Performing availability check...");

    // Check if update is in progress
    if (IsUpdateInProgress()) {
        Log(L"Update in progress, skipping check");
        return;
    }

    // Check if a restart is already pending
    if (IsRestartPending()) {
        Log(L"Restart already pending, skipping");
        return;
    }

    // Check if the installer is running
    if (IsInstallerRunning()) {
        Log(L"Installer is running, skipping check");
        return;
    }

    // Check if app is running
    if (!IsAppRunning()) {
        Log(L"App is NOT running, initiating recovery...");
        RecoverApp();
    } else {
        Log(L"App is running normally");
    }
}

// Check if an update is in progress
bool IsUpdateInProgress() {
    std::wstring lockPath = g_appDataDir + L"\\" + UPDATE_LOCK_FILE;

    WIN32_FILE_ATTRIBUTE_DATA fileInfo;
    if (!GetFileAttributesExW(lockPath.c_str(), GetFileExInfoStandard, &fileInfo)) {
        return false;  // File doesn't exist
    }

    // Check if lock file is stale
    FILETIME now;
    GetSystemTimeAsFileTime(&now);

    ULARGE_INTEGER lockTime, currentTime;
    lockTime.LowPart = fileInfo.ftLastWriteTime.dwLowDateTime;
    lockTime.HighPart = fileInfo.ftLastWriteTime.dwHighDateTime;
    currentTime.LowPart = now.dwLowDateTime;
    currentTime.HighPart = now.dwHighDateTime;

    // Convert to minutes
    ULONGLONG diffMinutes = (currentTime.QuadPart - lockTime.QuadPart) / (10000000ULL * 60);

    if (diffMinutes > UPDATE_LOCK_TIMEOUT_MINUTES) {
        Log(L"Update lock file is stale, removing");
        DeleteFileW(lockPath.c_str());
        return false;
    }

    Log(L"Update in progress detected");
    return true;
}

// Check if a restart is pending
bool IsRestartPending() {
    std::wstring lockPath = g_appDataDir + L"\\" + RESTART_LOCK_FILE;

    WIN32_FILE_ATTRIBUTE_DATA fileInfo;
    if (!GetFileAttributesExW(lockPath.c_str(), GetFileExInfoStandard, &fileInfo)) {
        return false;
    }

    // Check if lock file is stale
    FILETIME now;
    GetSystemTimeAsFileTime(&now);

    ULARGE_INTEGER lockTime, currentTime;
    lockTime.LowPart = fileInfo.ftLastWriteTime.dwLowDateTime;
    lockTime.HighPart = fileInfo.ftLastWriteTime.dwHighDateTime;
    currentTime.LowPart = now.dwLowDateTime;
    currentTime.HighPart = now.dwHighDateTime;

    // Convert to seconds
    ULONGLONG diffSeconds = (currentTime.QuadPart - lockTime.QuadPart) / 10000000ULL;

    if (diffSeconds > RESTART_LOCK_TIMEOUT_SECONDS) {
        Log(L"Restart lock file is stale, removing");
        DeleteFileW(lockPath.c_str());
        return false;
    }

    return true;
}

// Check if installer is running
bool IsInstallerRunning() {
    const wchar_t* installerNames[] = {
        L"a1-tools-setup",
        L"a1tools_update",
        L"a1_tools_setup",
        L"A1-Tools-Setup"
    };

    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(pe32);

    if (Process32FirstW(hSnapshot, &pe32)) {
        do {
            std::wstring procName(pe32.szExeFile);
            // Convert to lowercase for comparison
            for (auto& c : procName) c = towlower(c);

            for (const auto& installer : installerNames) {
                std::wstring installerLower(installer);
                for (auto& c : installerLower) c = towlower(c);

                if (procName.find(installerLower) != std::wstring::npos) {
                    CloseHandle(hSnapshot);
                    Log(L"Found installer process running");
                    return true;
                }
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }

    CloseHandle(hSnapshot);
    return false;
}

// Check if the app is running
bool IsAppRunning() {
    // Method 1: Check via mutex
    HANDLE hMutex = OpenMutexW(SYNCHRONIZE, FALSE, APP_MUTEX_NAME);
    if (hMutex != NULL) {
        CloseHandle(hMutex);
        Log(L"App detected via mutex");
        return true;
    }

    // Method 2: Check via process list
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(pe32);

    if (Process32FirstW(hSnapshot, &pe32)) {
        do {
            if (_wcsicmp(pe32.szExeFile, APP_EXE_NAME) == 0) {
                CloseHandle(hSnapshot);
                Log(L"App detected via process list");
                return true;
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }

    CloseHandle(hSnapshot);
    Log(L"App not detected by any method");
    return false;
}

// Create restart lock file
void CreateRestartLock() {
    std::wstring lockPath = g_appDataDir + L"\\" + RESTART_LOCK_FILE;

    HANDLE hFile = CreateFileW(lockPath.c_str(), GENERIC_WRITE, 0, NULL,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile != INVALID_HANDLE_VALUE) {
        // Write timestamp
        time_t now = time(nullptr);
        char buffer[64];
        sprintf_s(buffer, "{\"timestamp\":%lld,\"pid\":%lu}", (long long)now, GetCurrentProcessId());
        DWORD written;
        WriteFile(hFile, buffer, (DWORD)strlen(buffer), &written, NULL);
        CloseHandle(hFile);
    }
}

// Remove restart lock file
void RemoveRestartLock() {
    std::wstring lockPath = g_appDataDir + L"\\" + RESTART_LOCK_FILE;
    DeleteFileW(lockPath.c_str());
}

// Recover/restart the app
void RecoverApp() {
    CreateRestartLock();

    std::wstring appPath = g_appDataDir + L"\\" + APP_EXE_NAME;

    // Check if executable exists
    if (GetFileAttributesW(appPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
        Log(L"App executable not found at: " + appPath);
        RemoveRestartLock();
        return;
    }

    Log(L"Starting app: " + appPath);

    // Start the app with service-restart flag
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;

    std::wstring cmdLine = L"\"" + appPath + L"\" --auto-start --service-restart";

    // CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS
    if (CreateProcessW(NULL, &cmdLine[0], NULL, NULL, FALSE,
                       CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS,
                       NULL, NULL, &si, &pi)) {

        wchar_t msg[128];
        swprintf_s(msg, L"App started with PID: %lu", pi.dwProcessId);
        Log(msg);

        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);

        // Wait a moment for the app to initialize
        Sleep(5000);

        // Verify the app started successfully
        if (IsAppRunning()) {
            Log(L"App recovery successful");
        } else {
            Log(L"App may not have started properly");
        }
    } else {
        DWORD error = GetLastError();
        wchar_t msg[128];
        swprintf_s(msg, L"Failed to start app, error: %lu", error);
        Log(msg);
    }

    RemoveRestartLock();
}
