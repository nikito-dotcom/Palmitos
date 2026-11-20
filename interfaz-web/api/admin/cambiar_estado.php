<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();
soloPost();
$datos = leerDatos();
$idPedido = filter_var($datos['id_pedido'] ?? null, FILTER_VALIDATE_INT);
$estado = textoONulo($datos['estado'] ?? null);
if (!$idPedido || $idPedido < 1 || $estado === null) {
    responder(['ok' => false, 'error' => 'Completá el pedido y el nuevo estado.'], 400);
}

try {
    $pdo = conectar();
    $consulta = $pdo->prepare('CALL sp_cambiar_estado(?, ?)');
    $consulta->execute([$idPedido, $estado]);
    $consulta->closeCursor();
    responder(['ok' => true]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
