// VM Detection Service
//
// Detects if the app is running in a virtual machine or emulator.
// Used to prevent unauthorized use of the app in VM environments.
// Developers can bypass this restriction.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result of VM detection check
class VmDetectionResult {
  final bool isVirtualMachine;
  final String? detectedVm;
  final List<String> indicators;

  const VmDetectionResult({
    required this.isVirtualMachine,
    this.detectedVm,
    this.indicators = const [],
  });

  @override
  String toString() {
    if (!isVirtualMachine) return 'VmDetectionResult: Not a VM';
    return 'VmDetectionResult: VM detected ($detectedVm), indicators: $indicators';
  }
}

/// Service to detect virtual machine environments
class VmDetectionService {
  VmDetectionService._();
  static final VmDetectionService instance = VmDetectionService._();

  /// Known VM vendor strings to check against
  /// NOTE: These are checked against BIOS/System manufacturer strings,
  /// NOT general presence on the system. Be careful with generic terms.
  static const List<String> _vmVendors = [
    'vmware',
    'virtualbox',
    'vbox',
    'qemu',
    'xen',
    // Removed 'hyper-v' and 'hyperv' - too many false positives on Windows Pro hosts
    // Hyper-V detection is done separately in _checkHyperV() with guest-specific checks
    // Removed 'microsoft virtual' - can match "Microsoft Corporation" + any model with "virtual"
    'parallels',
    'kvm',
    'bochs',
    // Removed 'virtual machine' - too generic, causes false positives
    'innotek',
    'oracle vm',
  ];

  /// Known VM-related process names
  static const List<String> _vmProcesses = [
    'vmtoolsd.exe',
    'vmwaretray.exe',
    'vmwareuser.exe',
    'vboxservice.exe',
    'vboxtray.exe',
    'vboxclient',
    'xenservice.exe',
    'qemu-ga.exe',
    'prl_tools.exe',
    'prl_cc.exe',
  ];

  /// Known VM-related registry keys (Windows)
  static const List<String> _vmRegistryPaths = [
    r'HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware Tools',
    r'HKEY_LOCAL_MACHINE\SOFTWARE\Oracle\VirtualBox Guest Additions',
    r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters',
    r'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VBoxGuest',
    r'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\vmci',
  ];

  /// MAC address prefixes known to be used by VM software
  /// NOTE: Hyper-V MAC prefixes (00:15:5D, 00:03:FF) are REMOVED because they
  /// appear on Windows HOST machines with virtual switches (Docker, WSL2, Hyper-V).
  /// Hyper-V guest detection is handled by _checkHyperV() via registry keys.
  static const List<String> _vmMacPrefixes = [
    '00:0C:29', // VMware
    '00:50:56', // VMware
    '00:05:69', // VMware
    '08:00:27', // VirtualBox
    '00:1C:42', // Parallels
    '00:16:3E', // Xen
    // '00:15:5D' - Hyper-V - REMOVED: appears on hosts with virtual switches
    '52:54:00', // QEMU
    // '00:03:FF' - Microsoft Hyper-V - REMOVED: same reason
    '00:0F:4B', // Virtual Iron
    // '00:16:3E' - duplicate, already listed above
    '00:1A:4A', // QEMU
    '00:21:F6', // Virtual Iron
  ];

  /// Windows services that indicate GUEST VM environment (not host)
  /// These are Guest Additions/Tools services, not host hypervisor services
  /// IMPORTANT: Hyper-V Integration Services (vmicheartbeat, vmicshutdown, etc.)
  /// are REMOVED because they exist on Windows Pro HOST machines with Hyper-V enabled,
  /// not just inside VMs. Hyper-V guest detection is handled by _checkHyperV()
  /// via the Guest Parameters registry key which is truly guest-only.
  static const List<String> _vmGuestServices = [
    // VMware Guest Tools services (only present inside a VMware VM)
    'vmtools', 'vmhgfs', 'vmmemctl', 'vmrawdsk', 'vmusbmouse', 'vmvss', 'vmscsi',
    'vmxnet', 'vmx_svga',
    // VirtualBox Guest Additions services (only present inside a VirtualBox VM)
    // Note: 'vboxservice' is the guest service, NOT the host VBoxSVC
    'vboxguest', 'vboxsf', 'vboxmouse', 'vboxvideo',
    // Xen Guest services
    'xenevtchn', 'xennet', 'xensvc', 'xenvdb',
    // NOTE: Hyper-V Integration Services (vmicheartbeat, vmicshutdown, vmicexchange,
    // vmictimesync, vmicvss) are NOT included here because they run on Windows HOST
    // machines with Hyper-V enabled (Docker, WSL2, etc.), not just inside VMs.
  ];

  /// Directories/files that indicate GUEST VM environment (not host)
  /// These are Guest Additions paths, not host hypervisor installation paths
  static const List<String> _vmGuestPaths = [
    // VMware Tools (Guest Additions) - only inside VMware VMs
    r'C:\Program Files\VMware\VMware Tools',
    // VirtualBox Guest Additions - only inside VirtualBox VMs
    // Note: This is different from C:\Program Files\Oracle\VirtualBox (host installation)
    r'C:\Program Files\Oracle\VirtualBox Guest Additions',
    // VMware guest drivers
    r'C:\Windows\System32\drivers\vmmouse.sys',
    r'C:\Windows\System32\drivers\vmhgfs.sys',
    // VirtualBox guest drivers (only present inside VMs with Guest Additions)
    r'C:\Windows\System32\drivers\VBoxMouse.sys',
    r'C:\Windows\System32\drivers\VBoxGuest.sys',
    r'C:\Windows\System32\drivers\VBoxSF.sys',
    // VirtualBox Guest Additions executables (inside VM only)
    r'C:\Windows\System32\VBoxControl.exe',
    r'C:\Windows\System32\VBoxTray.exe',
  ];

  /// Windows Sandbox specific indicators
  static const List<String> _sandboxIndicators = [
    'WDAGUtilityAccount', // Windows Sandbox user account
    r'C:\Users\WDAGUtilityAccount',
  ];

  /// Roles that are allowed to bypass VM detection
  static const List<String> _bypassRoles = ['developer', 'administrator'];

  /// Storage key for user role (must match AuthService)
  static const String _keyRole = 'a1_tools_role';
  static const _storage = FlutterSecureStorage();

  /// Check if the current user has a role that bypasses VM detection
  Future<bool> hasVmBypass() async {
    try {
      final role = await _storage.read(key: _keyRole);
      if (role == null) return false;
      return _bypassRoles.contains(role.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Perform comprehensive VM detection
  ///
  /// Runs all 14 detection checks in parallel for faster startup time.
  /// Previously sequential execution could block UI on first app launch.
  Future<VmDetectionResult> detect() async {
    if (!Platform.isWindows) {
      // Only implement Windows detection for now
      return const VmDetectionResult(isVirtualMachine: false);
    }

    final indicators = <String>[];
    String? detectedVm;

    try {
      // Run all checks in parallel for faster detection
      final results = await Future.wait([
        _checkWmiBios(),                // 0: BIOS manufacturer
        _checkWmiComputerSystem(),      // 1: System model
        _checkVmProcesses(),            // 2: VM processes
        _checkRegistry(),               // 3: Registry keys
        _checkMacAddress(),             // 4: MAC address prefixes
        _checkDiskDrive(),              // 5: Disk drive model
        _checkVideoAdapter(),           // 6: Video adapter
        _checkVmServices(),             // 7: VM services
        _checkVmPaths(),                // 8: VM file paths
        _checkWindowsSandbox(),         // 9: Windows Sandbox
        _checkHyperV(),                 // 10: Hyper-V guest
        _checkCpuVirtualization(),      // 11: CPU virtualization
        _checkBaseboard(),              // 12: Motherboard/baseboard
        _checkEnvironmentVariables(),   // 13: Environment variables
      ], eagerError: false);

      // Process results in order
      if (results[0] != null) {
        indicators.add('BIOS: ${results[0]}');
        detectedVm ??= results[0];
      }
      if (results[1] != null) {
        indicators.add('System: ${results[1]}');
        detectedVm ??= results[1];
      }
      if (results[2] != null) {
        indicators.add('Process: ${results[2]}');
        detectedVm ??= _getVmNameFromProcess(results[2]!);
      }
      if (results[3] != null) {
        indicators.add('Registry: ${results[3]}');
        detectedVm ??= _getVmNameFromRegistry(results[3]!);
      }
      if (results[4] != null) {
        indicators.add('MAC: ${results[4]}');
        detectedVm ??= _getVmNameFromMac(results[4]!);
      }
      if (results[5] != null) {
        indicators.add('Disk: ${results[5]}');
        detectedVm ??= results[5];
      }
      if (results[6] != null) {
        indicators.add('Video: ${results[6]}');
        detectedVm ??= results[6];
      }
      if (results[7] != null) {
        indicators.add('Service: ${results[7]}');
        detectedVm ??= _getVmNameFromService(results[7]!);
      }
      if (results[8] != null) {
        indicators.add('Path: ${results[8]}');
        detectedVm ??= _getVmNameFromPath(results[8]!);
      }
      if (results[9] != null) {
        indicators.add('Sandbox: ${results[9]}');
        detectedVm ??= 'Windows Sandbox';
      }
      if (results[10] != null) {
        indicators.add('Hyper-V: ${results[10]}');
        detectedVm ??= 'Hyper-V';
      }
      if (results[11] != null) {
        indicators.add('CPU: ${results[11]}');
        detectedVm ??= results[11];
      }
      if (results[12] != null) {
        indicators.add('Baseboard: ${results[12]}');
        detectedVm ??= results[12];
      }
      if (results[13] != null) {
        indicators.add('Environment: ${results[13]}');
        detectedVm ??= results[13];
      }

    } catch (e) {
      // If detection fails, assume not a VM (fail open)
      // This prevents blocking legitimate users due to errors
      debugPrint('[VmDetection] Detection failed: $e');
    }

    return VmDetectionResult(
      isVirtualMachine: indicators.isNotEmpty,
      detectedVm: detectedVm,
      indicators: indicators,
    );
  }

  /// Check BIOS information via WMI
  Future<String?> _checkWmiBios() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_BIOS | Select-Object -ExpandProperty Manufacturer'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase().trim();
        for (final vendor in _vmVendors) {
          if (output.contains(vendor)) {
            return _capitalizeVmName(vendor);
          }
        }
      }
    } catch (e) {
      debugPrint('[VmDetection] BIOS check failed: $e');
    }
    return null;
  }

  /// Check computer system info via WMI
  Future<String?> _checkWmiComputerSystem() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer,Model | Format-List'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        for (final vendor in _vmVendors) {
          if (output.contains(vendor)) {
            return _capitalizeVmName(vendor);
          }
        }
      }
    } catch (e) {
      debugPrint('[VmDetection] Computer system check failed: $e');
    }
    return null;
  }

  /// Check for VM-related processes
  Future<String?> _checkVmProcesses() async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FO', 'CSV', '/NH'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        for (final process in _vmProcesses) {
          if (output.contains(process.toLowerCase())) {
            return process;
          }
        }
      }
    } catch (e) {
      debugPrint('[VmDetection] Process check failed: $e');
    }
    return null;
  }

  /// Check Windows registry for VM software
  Future<String?> _checkRegistry() async {
    for (final path in _vmRegistryPaths) {
      try {
        final result = await Process.run(
          'reg',
          ['query', path],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          return path;
        }
      } catch (e) {
        debugPrint('[VmDetection] Registry check failed for $path: $e');
      }
    }
    return null;
  }

  /// Check MAC address prefixes
  Future<String?> _checkMacAddress() async {
    try {
      final result = await Process.run(
        'getmac',
        ['/FO', 'CSV', '/NH'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toUpperCase();
        for (final prefix in _vmMacPrefixes) {
          // Convert prefix to format without colons for matching
          final prefixNoColons = prefix.replaceAll(':', '-');
          if (output.contains(prefixNoColons) || output.contains(prefix)) {
            return prefix;
          }
        }
      }
    } catch (e) {
      debugPrint('[VmDetection] MAC address check failed: $e');
    }
    return null;
  }

  /// Check disk drive model
  Future<String?> _checkDiskDrive() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_DiskDrive | Select-Object -ExpandProperty Model'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        for (final vendor in _vmVendors) {
          if (output.contains(vendor)) {
            return _capitalizeVmName(vendor);
          }
        }
        // Additional disk-specific checks - be precise
        if (output.contains('vbox harddisk')) return 'VirtualBox';
        if (output.contains('vmware virtual')) return 'VMware';
        if (output.contains('qemu harddisk')) return 'QEMU';
        // Note: Removed 'virtual hd' check - too generic
        // Hyper-V virtual disks are detected via other means (guest registry keys)
        // and "virtual hd" could match other scenarios
        if (output.contains('msft virtual disk')) return 'Hyper-V';
      }
    } catch (e) {
      debugPrint('[VmDetection] Disk drive check failed: $e');
    }
    return null;
  }

  /// Check video adapter
  Future<String?> _checkVideoAdapter() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        if (output.contains('vmware svga')) return 'VMware';
        if (output.contains('virtualbox graphics')) return 'VirtualBox';
        if (output.contains('hyper-v video')) return 'Hyper-V';
        if (output.contains('microsoft basic display')) {
          // Could be VM but not definitive - check in combination with others
        }
        if (output.contains('qxl')) return 'QEMU/KVM';
        if (output.contains('parallels')) return 'Parallels';
      }
    } catch (e) {
      debugPrint('[VmDetection] Video adapter check failed: $e');
    }
    return null;
  }

  /// Get VM name from process
  String _getVmNameFromProcess(String process) {
    final p = process.toLowerCase();
    if (p.contains('vmware') || p.contains('vmtool')) return 'VMware';
    if (p.contains('vbox')) return 'VirtualBox';
    if (p.contains('xen')) return 'Xen';
    if (p.contains('qemu')) return 'QEMU';
    if (p.contains('prl_')) return 'Parallels';
    return 'Unknown VM';
  }

  /// Get VM name from registry path
  String _getVmNameFromRegistry(String path) {
    final p = path.toLowerCase();
    if (p.contains('vmware')) return 'VMware';
    if (p.contains('virtualbox')) return 'VirtualBox';
    if (p.contains('virtual machine\\guest')) return 'Hyper-V';
    if (p.contains('vboxguest')) return 'VirtualBox';
    if (p.contains('vmci')) return 'VMware';
    return 'Unknown VM';
  }

  /// Get VM name from MAC prefix
  String _getVmNameFromMac(String prefix) {
    switch (prefix) {
      case '00:0C:29':
      case '00:50:56':
      case '00:05:69':
        return 'VMware';
      case '08:00:27':
        return 'VirtualBox';
      case '00:1C:42':
        return 'Parallels';
      case '00:16:3E':
        return 'Xen';
      case '52:54:00':
      case '00:1A:4A':
        return 'QEMU';
      case '00:0F:4B':
      case '00:21:F6':
        return 'Virtual Iron';
      default:
        return 'Unknown VM';
    }
  }

  /// Capitalize VM vendor name for display
  String _capitalizeVmName(String vendor) {
    switch (vendor.toLowerCase()) {
      case 'vmware':
        return 'VMware';
      case 'virtualbox':
      case 'vbox':
        return 'VirtualBox';
      case 'hyper-v':
      case 'hyperv':
        return 'Hyper-V';
      case 'qemu':
        return 'QEMU';
      case 'xen':
        return 'Xen';
      case 'parallels':
        return 'Parallels';
      case 'kvm':
        return 'KVM';
      default:
        return vendor;
    }
  }

  /// Check for VM Guest services (Guest Additions/Tools, not host hypervisor)
  Future<String?> _checkVmServices() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-Service | Select-Object -ExpandProperty Name'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        for (final service in _vmGuestServices) {
          if (output.contains(service.toLowerCase())) {
            return service;
          }
        }
      }
    } catch (e) {
      debugPrint('[VmDetection] Services check failed: $e');
    }
    return null;
  }

  /// Check for VM Guest file paths (Guest Additions, not host hypervisor)
  Future<String?> _checkVmPaths() async {
    for (final path in _vmGuestPaths) {
      try {
        if (await Directory(path).exists() || await File(path).exists()) {
          return path;
        }
      } catch (e) {
        // Path doesn't exist or not accessible
      }
    }
    return null;
  }

  /// Check for Windows Sandbox environment
  Future<String?> _checkWindowsSandbox() async {
    try {
      // Check for WDAGUtilityAccount user
      final userResult = await Process.run(
        'powershell',
        ['-Command', r'$env:USERNAME'],
        runInShell: true,
      );

      if (userResult.exitCode == 0) {
        final username = userResult.stdout.toString().trim();
        if (username.toLowerCase() == 'wdagutilityaccount') {
          return 'WDAGUtilityAccount user detected';
        }
      }

      // Check for sandbox user profile directory
      for (final indicator in _sandboxIndicators) {
        if (indicator.startsWith(r'C:\')) {
          if (await Directory(indicator).exists()) {
            return indicator;
          }
        }
      }

      // Check for Windows Sandbox container ID
      final containerResult = await Process.run(
        'powershell',
        ['-Command', r'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ContainerIDs" -ErrorAction SilentlyContinue'],
        runInShell: true,
      );

      if (containerResult.exitCode == 0 && containerResult.stdout.toString().trim().isNotEmpty) {
        return 'Container ID detected';
      }
    } catch (e) {
      debugPrint('[VmDetection] Sandbox check failed: $e');
    }
    return null;
  }

  /// Check for Hyper-V GUEST indicators (running inside a Hyper-V VM)
  /// Note: HypervisorPresent=true on a Windows Pro HOST just means Hyper-V is enabled
  /// We need to check for GUEST-specific indicators
  Future<String?> _checkHyperV() async {
    try {
      // Check for Hyper-V Guest Parameters registry key
      // This key ONLY exists inside a Hyper-V VM, not on the host
      final vmGenResult = await Process.run(
        'powershell',
        ['-Command', r'Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty VirtualMachineName'],
        runInShell: true,
      );

      if (vmGenResult.exitCode == 0 && vmGenResult.stdout.toString().trim().isNotEmpty) {
        return 'Hyper-V Guest: ${vmGenResult.stdout.toString().trim()}';
      }

      // Check for Hyper-V Guest Parameters HostName (another guest-only indicator)
      final regResult = await Process.run(
        'reg',
        ['query', r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters', '/v', 'HostName'],
        runInShell: true,
      );

      if (regResult.exitCode == 0) {
        return 'Hyper-V Guest Parameters found';
      }

      // Note: We removed the HypervisorPresent check because it's true on HOST machines
      // with Hyper-V enabled, not just inside VMs

      // Note: Integration services check is now in _checkVmServices() since those
      // services (vmicheartbeat, etc.) only run inside Hyper-V guests
    } catch (e) {
      debugPrint('[VmDetection] Hyper-V check failed: $e');
    }
    return null;
  }

  /// Check CPU virtualization indicators
  /// Note: This check is conservative to avoid false positives
  Future<String?> _checkCpuVirtualization() async {
    try {
      // Check processor name for VM indicators
      // Only trigger on EXPLICIT VM CPU names, not just "virtual" anywhere
      final cpuResult = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Name'],
        runInShell: true,
      );

      if (cpuResult.exitCode == 0) {
        final cpuName = cpuResult.stdout.toString().toLowerCase();
        // Be specific - "Intel... with virtualization" is not a VM
        // Only trigger on QEMU virtual CPU names which are explicit
        if (cpuName.contains('qemu virtual')) {
          return 'QEMU Virtual CPU';
        }
      }

      // Note: Removed the Win32_ComputerSystem check from here since it's
      // already done in _checkWmiComputerSystem() and was causing duplicates
      // The Manufacturer check for "Microsoft Corporation" + "Virtual" model
      // is too broad - many real Surface/OEM devices have Microsoft firmware

    } catch (e) {
      debugPrint('[VmDetection] CPU check failed: $e');
    }
    return null;
  }

  /// Check baseboard/motherboard information
  Future<String?> _checkBaseboard() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-WmiObject Win32_BaseBoard | Select-Object Manufacturer,Product | Format-List'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        for (final vendor in _vmVendors) {
          if (output.contains(vendor)) {
            return _capitalizeVmName(vendor);
          }
        }
        // Note: Removed generic "none" + "virtual" check - too many false positives
        // Some real machines report "None" for baseboard and might have "virtual"
        // elsewhere in their system info
      }
    } catch (e) {
      debugPrint('[VmDetection] Baseboard check failed: $e');
    }
    return null;
  }

  /// Check environment variables for VM GUEST indicators
  /// Note: We only check for guest-specific env vars, not host installations
  Future<String?> _checkEnvironmentVariables() async {
    try {
      final envVars = Platform.environment;

      // Note: VBOX_MSI_INSTALL_PATH is set on HOST machines with VirtualBox installed
      // This is NOT a VM indicator - it just means VirtualBox is installed
      // We removed this check to prevent false positives on host machines

      // Check PROCESSOR_IDENTIFIER for VM indicators
      // This is set by the hypervisor and indicates virtualized CPU
      final processorId = envVars['PROCESSOR_IDENTIFIER'] ?? '';
      if (processorId.toLowerCase().contains('virtual') ||
          processorId.toLowerCase().contains('qemu')) {
        return 'Virtual Processor ID';
      }

      // Note: Having Hyper-V in PATH on a Windows Pro machine doesn't mean
      // we're in a VM - it just means Hyper-V is enabled as a feature
      // We removed this check to prevent false positives on host machines
    } catch (e) {
      debugPrint('[VmDetection] Environment check failed: $e');
    }
    return null;
  }

  /// Get VM name from service name
  String _getVmNameFromService(String service) {
    final s = service.toLowerCase();
    if (s.contains('vmware') || s.contains('vmtools') || s.contains('vmx')) return 'VMware';
    if (s.contains('vbox')) return 'VirtualBox';
    if (s.contains('xen')) return 'Xen';
    return 'Unknown VM';
  }

  /// Get VM name from file path
  String _getVmNameFromPath(String path) {
    final p = path.toLowerCase();
    if (p.contains('vmware')) return 'VMware';
    if (p.contains('virtualbox') || p.contains('vbox')) return 'VirtualBox';
    return 'Unknown VM';
  }
}
