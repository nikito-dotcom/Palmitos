<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

try {
    $pdo = conectar();
    $consulta = $pdo->prepare('SELECT id_empleado, nombre, rol FROM empleado WHERE id_empleado = ? AND activo = TRUE');
    $consulta->execute([(int)$_SESSION['id_empleado']]);
    $empleado = $consulta->fetch(PDO::FETCH_ASSOC);
    if (!$empleado) {
        responder(['ok' => false, 'error' => 'La cuenta de personal está inactiva.'], 401);
    }
    responder(['ok' => true, 'empleado' => $empleado]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
