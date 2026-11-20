<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

try {
    $pdo = conectar();
    $consulta = $pdo->prepare('SELECT * FROM v_envios_pendientes ORDER BY zona, fecha, id_pedido');
    $consulta->execute();
    responder(['ok' => true, 'envios' => $consulta->fetchAll(PDO::FETCH_ASSOC)]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
