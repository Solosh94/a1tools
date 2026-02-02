// A1 Tools Service Helper - Layer 2 of the multi-layered restart system
// Background service component that ensures application availability
// Check interval: 2 minutes
//
// Build: go build -ldflags "-H=windowsgui -s -w" -o a1_service_helper.exe a1_service_helper.go
// The -H=windowsgui flag hides the console window
// The -s -w flags strip debug info for smaller binary

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

const (
	// Check interval - how often to verify app availability
	checkInterval = 2 * time.Minute

	// App executable name
	appExeName = "a1_tools.exe"

	// Service helper mutex name (to prevent multiple instances)
	serviceHelperMutexName = "A1ToolsServiceHelperMutex"

	// App mutex name (used by the app to prevent multiple instances)
	appMutexName = "A1ToolsSingleInstanceMutex"

	// Lock file names
	updateLockFile  = ".update_in_progress"
	restartLockFile = ".restart_pending"

	// Stale lock timeout
	updateLockTimeout  = 10 * time.Minute
	restartLockTimeout = 30 * time.Second

	// Log file name
	logFileName = "service_helper.log"

	// Max log file size (1MB)
	maxLogSize = 1024 * 1024
)

var (
	kernel32                     = syscall.NewLazyDLL("kernel32.dll")
	procCreateMutex              = kernel32.NewProc("CreateMutexW")
	procOpenMutex                = kernel32.NewProc("OpenMutexW")
	procCloseHandle              = kernel32.NewProc("CloseHandle")
	procCreateToolhelp32Snapshot = kernel32.NewProc("CreateToolhelp32Snapshot")
	procProcess32First           = kernel32.NewProc("Process32FirstW")
	procProcess32Next            = kernel32.NewProc("Process32NextW")

	// Mutex synchronization access rights
	MUTEX_ALL_ACCESS = uint32(0x1F0001)
	SYNCHRONIZE      = uint32(0x00100000)

	// Toolhelp32 constants
	TH32CS_SNAPPROCESS = uint32(0x00000002)
)

// PROCESSENTRY32W structure for process enumeration
type PROCESSENTRY32W struct {
	Size            uint32
	Usage           uint32
	ProcessID       uint32
	DefaultHeapID   uintptr
	ModuleID        uint32
	Threads         uint32
	ParentProcessID uint32
	PriClassBase    int32
	Flags           uint32
	ExeFile         [260]uint16
}

// UpdateLockData represents the data in the update lock file
type UpdateLockData struct {
	StartedAt string `json:"started_at"`
	Version   string `json:"version"`
	PID       int    `json:"pid"`
}

var (
	appDataDir string
	logFile    *os.File
)

func main() {
	// Get AppData directory
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		localAppData = os.Getenv("APPDATA")
	}
	appDataDir = filepath.Join(localAppData, "A1 Tools")

	// Check for --check-once flag (used by Task Scheduler fallback)
	checkOnce := false
	for _, arg := range os.Args[1:] {
		if arg == "--check-once" || arg == "--verify" {
			checkOnce = true
			break
		}
	}

	// Initialize logging
	initLogging()
	defer closeLogging()

	// Try to acquire service helper mutex (prevent multiple instances)
	mutexHandle, err := createMutex(serviceHelperMutexName)
	if err != nil {
		log("Service helper already running, exiting")
		return
	}
	defer closeMutex(mutexHandle)

	log("A1 Tools Service Helper started")
	log(fmt.Sprintf("Check interval: %v", checkInterval))
	log(fmt.Sprintf("App data dir: %s", appDataDir))

	if checkOnce {
		// Single check mode (for scheduled verification)
		log("Running in verify mode")
		performCheck()
		return
	}

	// Main service loop
	for {
		performCheck()
		time.Sleep(checkInterval)
	}
}

func performCheck() {
	log("Performing availability check...")

	// Check if update is in progress
	if isUpdateInProgress() {
		log("Update in progress, skipping check")
		return
	}

	// Check if a restart is already pending
	if isRestartPending() {
		log("Restart already pending, skipping")
		return
	}

	// Check if the installer is running
	if isInstallerRunning() {
		log("Installer is running, skipping check")
		return
	}

	// Check if app is running using multiple methods
	appRunning := isAppRunning()

	if !appRunning {
		log("App is NOT running, initiating recovery...")
		recoverApp()
	} else {
		log("App is running normally")
	}
}

func isUpdateInProgress() bool {
	lockPath := filepath.Join(appDataDir, updateLockFile)

	info, err := os.Stat(lockPath)
	if os.IsNotExist(err) {
		return false
	}
	if err != nil {
		log(fmt.Sprintf("Error checking update lock: %v", err))
		return false
	}

	// Check if lock file is stale
	if time.Since(info.ModTime()) > updateLockTimeout {
		log("Update lock file is stale, removing")
		os.Remove(lockPath)
		return false
	}

	// Read and validate lock file
	data, err := os.ReadFile(lockPath)
	if err != nil {
		log(fmt.Sprintf("Error reading update lock: %v", err))
		return true // Assume update in progress if we can't read
	}

	var lockData UpdateLockData
	if err := json.Unmarshal(data, &lockData); err != nil {
		log(fmt.Sprintf("Error parsing update lock: %v", err))
		return true
	}

	log(fmt.Sprintf("Update in progress: version %s, started at %s", lockData.Version, lockData.StartedAt))
	return true
}

func isRestartPending() bool {
	lockPath := filepath.Join(appDataDir, restartLockFile)

	info, err := os.Stat(lockPath)
	if os.IsNotExist(err) {
		return false
	}
	if err != nil {
		return false
	}

	// Check if lock file is stale
	if time.Since(info.ModTime()) > restartLockTimeout {
		log("Restart lock file is stale, removing")
		os.Remove(lockPath)
		return false
	}

	return true
}

func isInstallerRunning() bool {
	// Check for common installer process names
	installerNames := []string{
		"a1-tools-setup",
		"a1tools_update",
		"a1_tools_setup",
	}

	processes, err := getProcessList()
	if err != nil {
		log(fmt.Sprintf("Error getting process list: %v", err))
		return false
	}

	for _, proc := range processes {
		procLower := strings.ToLower(proc)
		for _, installer := range installerNames {
			if strings.Contains(procLower, installer) {
				log(fmt.Sprintf("Found installer process: %s", proc))
				return true
			}
		}
	}

	return false
}

func isAppRunning() bool {
	// Method 1: Check via mutex
	mutexRunning := checkMutex(appMutexName)
	if mutexRunning {
		log("App detected via mutex")
		return true
	}

	// Method 2: Check via process list
	processes, err := getProcessList()
	if err != nil {
		log(fmt.Sprintf("Error getting process list: %v", err))
		return false
	}

	for _, proc := range processes {
		if strings.EqualFold(proc, appExeName) {
			log("App detected via process list")
			return true
		}
	}

	log("App not detected by any method")
	return false
}

func recoverApp() {
	// Create restart lock
	createRestartLock()

	appPath := filepath.Join(appDataDir, appExeName)

	// Check if executable exists
	if _, err := os.Stat(appPath); os.IsNotExist(err) {
		log(fmt.Sprintf("App executable not found at: %s", appPath))
		removeRestartLock()
		return
	}

	log(fmt.Sprintf("Starting app: %s", appPath))

	// Start the app with service-restart flag
	cmd := exec.Command(appPath, "--auto-start", "--service-restart")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP | 0x00000010, // DETACHED_PROCESS
	}

	if err := cmd.Start(); err != nil {
		log(fmt.Sprintf("Failed to start app: %v", err))
		removeRestartLock()
		return
	}

	log(fmt.Sprintf("App started with PID: %d", cmd.Process.Pid))

	// Wait a moment for the app to initialize
	time.Sleep(5 * time.Second)

	// Verify the app started successfully
	if isAppRunning() {
		log("App recovery successful")
	} else {
		log("App may not have started properly")
	}

	removeRestartLock()
}

func createRestartLock() {
	lockPath := filepath.Join(appDataDir, restartLockFile)
	data := fmt.Sprintf(`{"timestamp":"%s","pid":%d}`, time.Now().Format(time.RFC3339), os.Getpid())
	os.WriteFile(lockPath, []byte(data), 0644)
}

func removeRestartLock() {
	lockPath := filepath.Join(appDataDir, restartLockFile)
	os.Remove(lockPath)
}

// Mutex functions using Windows API

func createMutex(name string) (syscall.Handle, error) {
	namePtr, err := syscall.UTF16PtrFromString(name)
	if err != nil {
		return 0, err
	}

	handle, _, err := procCreateMutex.Call(
		0,
		1, // bInitialOwner = TRUE
		uintptr(unsafe.Pointer(namePtr)),
	)

	if handle == 0 {
		return 0, fmt.Errorf("CreateMutex failed: %v", err)
	}

	// Check if mutex already exists
	if err.(syscall.Errno) == syscall.ERROR_ALREADY_EXISTS {
		procCloseHandle.Call(handle)
		return 0, fmt.Errorf("mutex already exists")
	}

	return syscall.Handle(handle), nil
}

func checkMutex(name string) bool {
	namePtr, err := syscall.UTF16PtrFromString(name)
	if err != nil {
		return false
	}

	handle, _, _ := procOpenMutex.Call(
		uintptr(SYNCHRONIZE),
		0, // bInheritHandle = FALSE
		uintptr(unsafe.Pointer(namePtr)),
	)

	if handle != 0 {
		procCloseHandle.Call(handle)
		return true
	}

	return false
}

func closeMutex(handle syscall.Handle) {
	if handle != 0 {
		procCloseHandle.Call(uintptr(handle))
	}
}

// Process enumeration using Toolhelp32

func getProcessList() ([]string, error) {
	snapshot, _, err := procCreateToolhelp32Snapshot.Call(uintptr(TH32CS_SNAPPROCESS), 0)
	if snapshot == uintptr(syscall.InvalidHandle) {
		return nil, fmt.Errorf("CreateToolhelp32Snapshot failed: %v", err)
	}
	defer procCloseHandle.Call(snapshot)

	var processes []string
	var pe32 PROCESSENTRY32W
	pe32.Size = uint32(unsafe.Sizeof(pe32))

	ret, _, _ := procProcess32First.Call(snapshot, uintptr(unsafe.Pointer(&pe32)))
	if ret == 0 {
		return nil, fmt.Errorf("Process32First failed")
	}

	for {
		processName := syscall.UTF16ToString(pe32.ExeFile[:])
		processes = append(processes, processName)

		ret, _, _ = procProcess32Next.Call(snapshot, uintptr(unsafe.Pointer(&pe32)))
		if ret == 0 {
			break
		}
	}

	return processes, nil
}

// Logging functions

func initLogging() {
	logPath := filepath.Join(appDataDir, logFileName)

	// Check if log file is too large
	info, err := os.Stat(logPath)
	if err == nil && info.Size() > maxLogSize {
		// Rotate log file
		backupPath := logPath + ".old"
		os.Remove(backupPath)
		os.Rename(logPath, backupPath)
	}

	// Open log file for appending
	logFile, err = os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		// Can't log, continue anyway
		logFile = nil
	}
}

func closeLogging() {
	if logFile != nil {
		logFile.Close()
	}
}

func log(message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	logMessage := fmt.Sprintf("[%s] %s\n", timestamp, message)

	if logFile != nil {
		logFile.WriteString(logMessage)
	}
}
