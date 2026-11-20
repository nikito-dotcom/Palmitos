<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

$idPedido = filter_input(INPUT_GET, 'id_pedido', FILTER_VALIDATE_INT);
if (!$idPedido || $idPedido < 1) {
    responder(['ok' => false, 'error' => 'El número de pedido no es válido.'], 400);
}

try {
    $pdo = conectar();
    $llamada = $pdo->prepare('CALL sp_ver_pedido(?)');
    $llamada->execute([$idPedido]);
    $pedido = $llamada->fetch(PDO::FETCH_ASSOC);
    $llamada->nextRowset();
    $productos = $llamada->fetchAll(PDO::FETCH_ASSOC);
    $llamada->closeCursor();

    $historialConsulta = $pdo->prepare(
        'SELECT estado_anterior, estado_nuevo, fecha_cambio
         FROM historial_estado_pedido WHERE id_pedido = ? ORDER BY fecha_cambio, id_historial'
    );
    $historialConsulta->execute([$idPedido]);
    responder([
        'ok' => true,
        'pedido' => $pedido,
        'productos' => $productos,
        'historial' => $historialConsulta->fetchAll(PDO::FETCH_ASSOC)
    ]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
