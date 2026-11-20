<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';

soloPost();
$datos = leerDatos();
$email = strtolower(trim((string)($datos['email'] ?? '')));
$contrasena = (string)($datos['contrasena'] ?? '');

if ($email === '' || $contrasena === '') {
    responder(['ok' => false, 'error' => 'Escribí tu email y contraseña.'], 400);
}

try {
    $pdo = conectar();
    $llamada = $pdo->prepare('CALL sp_iniciar_sesion_empleado(?, ?, @id_empleado)');
    $llamada->execute([$email, $contrasena]);
    $filas = [];
    do {
        $resultado = $llamada->fetchAll(PDO::FETCH_ASSOC);
        if ($resultado) {
            $filas = $resultado;
        }
    } while ($llamada->nextRowset());
    $llamada->closeCursor();

    $consultaSalida = $pdo->prepare('SELECT @id_empleado AS id_empleado');
    $consultaSalida->execute();
    $salida = $consultaSalida->fetch(PDO::FETCH_ASSOC);
    $idEmpleado = (int)($salida['id_empleado'] ?? 0);
    if ($idEmpleado < 1) {
        responder(['ok' => false, 'error' => 'Email o contraseña incorrectos.'], 401);
    }

    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }
    session_regenerate_id(true);
    $_SESSION['id_empleado'] = $idEmpleado;
    $empleado = $filas[0] ?? ['id_empleado' => $idEmpleado, 'nombre' => 'Personal'];
    responder(['ok' => true, 'empleado' => [
        'id_empleado' => $idEmpleado,
        'nombre' => (string)($empleado['nombre'] ?? 'Personal'),
        'rol' => (string)($empleado['rol'] ?? 'vendedor')
    ]]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
