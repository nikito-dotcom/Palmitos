<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();
soloPost();
$datos = leerDatos();
$idPedido = filter_var($datos['id_pedido'] ?? null, FILTER_VALIDATE_INT);
if (!$idPedido || $idPedido < 1) {
    responder(['ok' => false, 'error' => 'El número de pedido no es válido.'], 400);
}

try {
    $pdo = conectar();
    $consulta = $pdo->prepare('CALL sp_confirmar_pago(?)');
    $consulta->execute([$idPedido]);
    $consulta->closeCursor();
    responder(['ok' => true]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
