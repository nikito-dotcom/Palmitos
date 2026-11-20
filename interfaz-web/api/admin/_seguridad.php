<?php
declare(strict_types=1);

function asegurarSesionEmpleado(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (empty($_SESSION['id_empleado'])) {
        responder(['ok' => false, 'error' => 'Acceso no autorizado. Iniciá sesión como personal.'], 401);
    }
}

function responderErrorProcedimiento(PDOException $error): void
{
    responderError($error);
}

// Si alguien abre este archivo directamente, también debe pasar por el control de sesión.
if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    require_once __DIR__ . '/../conexion.php';
    asegurarSesionEmpleado();
    responder(['ok' => true]);
}
