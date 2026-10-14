<?php
// انسخ هذا الملف إلى config.php واملأ القيم الحقيقية على الخادم فقط.
// config.php مستثنى في .gitignore ولا يجوز رفعه إلى GitHub.
return [
    'app' => [
        'name'         => 'She Grows for Development',
        'base_url'     => 'https://example.com',
        'env'          => 'production',   // production | testing
        'default_lang' => 'ar',
    ],
    'db' => [
        'host'    => 'sqlXXX.example.com',
        'name'    => 'DB_NAME',
        'user'    => 'DB_USER',
        'pass'    => 'DB_PASSWORD',
        'charset' => 'utf8mb4',
    ],
    'security' => [
        'session_name'       => 'sg_session',
        'login_max_attempts' => 5,
        'login_lock_minutes' => 15,
        'upload_max_bytes'   => 5 * 1024 * 1024,
        'upload_allowed'     => ['pdf', 'jpg', 'jpeg', 'png'],
    ],
];
