<?php
/**
 * File: a1tools_auth_profile_update.php
 * 
 * ADD THIS CODE to your existing a1tools_auth.php file
 * inside the switch statement for actions.
 * 
 * Handles: action = 'update_profile'
 */

// Add this case to your existing switch($action) in a1tools_auth.php:

/*
case 'update_profile':
    $username = $data['username'] ?? '';
    $firstName = $data['first_name'] ?? '';
    $lastName = $data['last_name'] ?? '';
    $email = $data['email'] ?? '';
    $phone = $data['phone'] ?? '';
    $currentPassword = $data['current_password'] ?? '';
    $newPassword = $data['new_password'] ?? '';
    
    if (empty($username)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Username required']);
        exit;
    }
    
    // Get user from database
    $stmt = $pdo->prepare("SELECT * FROM a1tools_users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        http_response_code(404);
        echo json_encode(['success' => false, 'error' => 'User not found']);
        exit;
    }
    
    // If changing password, verify current password
    if (!empty($newPassword)) {
        if (empty($currentPassword)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Current password required to change password']);
            exit;
        }
        
        if (!password_verify($currentPassword, $user['password_hash'])) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Current password is incorrect']);
            exit;
        }
        
        if (strlen($newPassword) < 6) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Password must be at least 6 characters']);
            exit;
        }
        
        // Update with new password
        $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("
            UPDATE a1tools_users 
            SET first_name = ?, last_name = ?, email = ?, phone = ?, password_hash = ?
            WHERE username = ?
        ");
        $stmt->execute([$firstName, $lastName, $email, $phone, $newHash, $username]);
    } else {
        // Update without password change
        $stmt = $pdo->prepare("
            UPDATE a1tools_users 
            SET first_name = ?, last_name = ?, email = ?, phone = ?
            WHERE username = ?
        ");
        $stmt->execute([$firstName, $lastName, $email, $phone, $username]);
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Profile updated successfully',
        'first_name' => $firstName,
        'last_name' => $lastName,
        'email' => $email,
        'phone' => $phone
    ]);
    exit;
*/

// ============================================================
// COMPLETE REPLACEMENT FILE BELOW
// ============================================================
// If you prefer, replace your entire a1tools_auth.php with this:

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Database connection
$dbHost = 'localhost';
$dbName = 'dbe4kgbumifeyv';
$dbUser = 'ub71v2mlpldaj';
$dbPass = 'apqdlia3vkeh';

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4", $dbUser, $dbPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit;
}

// Get input
$data = json_decode(file_get_contents('php://input'), true);
$action = $data['action'] ?? '';

switch ($action) {
    case 'login':
        $usernameOrEmail = $data['username'] ?? '';
        $password = $data['password'] ?? '';

        if (empty($usernameOrEmail) || empty($password)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Username/email and password required']);
            exit;
        }

        // Check if input is an email (contains @) or username
        // Try to find user by username OR email
        $stmt = $pdo->prepare("SELECT * FROM a1tools_users WHERE username = ? OR email = ?");
        $stmt->execute([$usernameOrEmail, $usernameOrEmail]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user || !password_verify($password, $user['password_hash'])) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Invalid username/email or password']);
            exit;
        }

        echo json_encode([
            'success' => true,
            'user_id' => $user['id'],
            'username' => $user['username'],
            'first_name' => $user['first_name'] ?? '',
            'last_name' => $user['last_name'] ?? '',
            'email' => $user['email'] ?? '',
            'phone' => $user['phone'] ?? '',
            'role' => $user['role'] ?? 'dispatcher',
            'birthday' => $user['birthday'] ?? null
        ]);
        break;
        
    case 'register':
        $username = trim($data['username'] ?? '');
        $password = $data['password'] ?? '';
        $firstName = $data['first_name'] ?? '';
        $lastName = $data['last_name'] ?? '';
        $email = $data['email'] ?? '';
        $phone = $data['phone'] ?? '';
        $role = strtolower($data['role'] ?? 'dispatcher');
        $birthday = $data['birthday'] ?? null;
        
        // Validate birthday format if provided
        if ($birthday !== null && $birthday !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birthday)) {
            $birthday = null;
        }
        
        // Public registration can only create dispatcher or technician
        if (!in_array($role, ['dispatcher', 'technician'])) {
            $role = 'dispatcher';
        }
        
        if (empty($username) || empty($password)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Username and password required']);
            exit;
        }
        
        if (strlen($password) < 6) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Password must be at least 6 characters']);
            exit;
        }
        
        // Check if username exists
        $stmt = $pdo->prepare("SELECT id FROM a1tools_users WHERE username = ?");
        $stmt->execute([$username]);
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['success' => false, 'error' => 'Username already exists']);
            exit;
        }
        
        // Create user
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("
            INSERT INTO a1tools_users (username, password_hash, first_name, last_name, email, phone, role, birthday, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([$username, $hash, $firstName, $lastName, $email, $phone, $role, $birthday]);
        
        $userId = $pdo->lastInsertId();
        
        echo json_encode([
            'success' => true,
            'user_id' => $userId,
            'username' => $username,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'email' => $email,
            'phone' => $phone,
            'role' => $role,
            'birthday' => $birthday
        ]);
        break;
        
    case 'update_profile':
        $username = $data['username'] ?? '';
        $firstName = $data['first_name'] ?? '';
        $lastName = $data['last_name'] ?? '';
        $email = $data['email'] ?? '';
        $phone = $data['phone'] ?? '';
        $birthday = $data['birthday'] ?? null;
        $currentPassword = $data['current_password'] ?? '';
        $newPassword = $data['new_password'] ?? '';
        
        // Validate birthday format if provided
        if ($birthday !== null && $birthday !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birthday)) {
            $birthday = null;
        }
        
        if (empty($username)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Username required']);
            exit;
        }
        
        // Get user from database
        $stmt = $pdo->prepare("SELECT * FROM a1tools_users WHERE username = ?");
        $stmt->execute([$username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            http_response_code(404);
            echo json_encode(['success' => false, 'error' => 'User not found']);
            exit;
        }
        
        // If changing password, verify current password
        if (!empty($newPassword)) {
            if (empty($currentPassword)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'error' => 'Current password required to change password']);
                exit;
            }
            
            if (!password_verify($currentPassword, $user['password_hash'])) {
                http_response_code(401);
                echo json_encode(['success' => false, 'error' => 'Current password is incorrect']);
                exit;
            }
            
            if (strlen($newPassword) < 6) {
                http_response_code(400);
                echo json_encode(['success' => false, 'error' => 'Password must be at least 6 characters']);
                exit;
            }
            
            // Update with new password
            $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare("
                UPDATE a1tools_users 
                SET first_name = ?, last_name = ?, email = ?, phone = ?, birthday = ?, password_hash = ?
                WHERE username = ?
            ");
            $stmt->execute([$firstName, $lastName, $email, $phone, $birthday, $newHash, $username]);
        } else {
            // Update without password change
            $stmt = $pdo->prepare("
                UPDATE a1tools_users 
                SET first_name = ?, last_name = ?, email = ?, phone = ?, birthday = ?
                WHERE username = ?
            ");
            $stmt->execute([$firstName, $lastName, $email, $phone, $birthday, $username]);
        }
        
        echo json_encode([
            'success' => true,
            'message' => 'Profile updated successfully',
            'first_name' => $firstName,
            'last_name' => $lastName,
            'email' => $email,
            'phone' => $phone,
            'birthday' => $birthday
        ]);
        break;
        
    case 'delete_user':
        $adminUsername = $data['admin_username'] ?? '';
        $adminPassword = $data['admin_password'] ?? '';
        $deleteUserId = $data['delete_user_id'] ?? 0;
        
        // Verify admin
        $stmt = $pdo->prepare("SELECT * FROM a1tools_users WHERE username = ?");
        $stmt->execute([$adminUsername]);
        $admin = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$admin || !password_verify($adminPassword, $admin['password_hash'])) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Invalid admin credentials']);
            exit;
        }
        
        if (!in_array($admin['role'], ['admin', 'developer'])) {
            http_response_code(403);
            echo json_encode(['success' => false, 'error' => 'Admin privileges required']);
            exit;
        }
        
        // Delete user
        $stmt = $pdo->prepare("DELETE FROM a1tools_users WHERE id = ?");
        $stmt->execute([$deleteUserId]);
        
        echo json_encode(['success' => true, 'message' => 'User deleted']);
        break;
        
    case 'admin_create_user':
        $adminUsername = $data['admin_username'] ?? '';
        $adminPassword = $data['admin_password'] ?? '';
        $username = trim($data['username'] ?? '');
        $password = $data['password'] ?? '';
        $firstName = $data['first_name'] ?? '';
        $lastName = $data['last_name'] ?? '';
        $email = $data['email'] ?? '';
        $phone = $data['phone'] ?? '';
        $role = strtolower($data['role'] ?? 'dispatcher');
        
        // Verify admin
        $stmt = $pdo->prepare("SELECT * FROM a1tools_users WHERE username = ?");
        $stmt->execute([$adminUsername]);
        $admin = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$admin || !password_verify($adminPassword, $admin['password_hash'])) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Invalid admin credentials']);
            exit;
        }
        
        if (!in_array($admin['role'], ['admin', 'developer'])) {
            http_response_code(403);
            echo json_encode(['success' => false, 'error' => 'Admin privileges required']);
            exit;
        }
        
        // Validate role
        $allowedRoles = ['dispatcher', 'technician', 'manager', 'marketing', 'admin', 'developer'];
        if (!in_array($role, $allowedRoles)) {
            $role = 'dispatcher';
        }
        
        if (empty($username) || empty($password)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Username and password required']);
            exit;
        }
        
        // Check if username exists
        $stmt = $pdo->prepare("SELECT id FROM a1tools_users WHERE username = ?");
        $stmt->execute([$username]);
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['success' => false, 'error' => 'Username already exists']);
            exit;
        }
        
        // Create user
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("
            INSERT INTO a1tools_users (username, password_hash, first_name, last_name, email, phone, role, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([$username, $hash, $firstName, $lastName, $email, $phone, $role]);
        
        $userId = $pdo->lastInsertId();
        
        echo json_encode([
            'success' => true,
            'user_id' => $userId,
            'username' => $username,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'email' => $email,
            'phone' => $phone,
            'role' => $role
        ]);
        break;
        
    case 'list_users':
        // Return list of all users (for admin user management)
        $stmt = $pdo->query("SELECT id, username, first_name, last_name, email, phone, role, created_at FROM a1tools_users ORDER BY username");
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true,
            'users' => $users
        ]);
        break;
        
    default:
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}
