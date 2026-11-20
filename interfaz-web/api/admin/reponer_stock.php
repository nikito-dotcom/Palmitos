<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();
soloPost();
$datos = leerDatos();
$idProducto = filter_var($datos['id_producto'] ?? null, FILTER_VALIDATE_INT);
$cantidad = filter_var($datos['cantidad'] ?? null, FILTER_VALIDATE_INT);
if (!$idProducto || $idProducto < 1 || !$cantidad || $cantidad < 1) {
    responder(['ok' => false, 'error' => 'Indicá el producto y una cantidad mayor a cero.'], 400);
}

try {
    $pdo = conectar();
    $consulta = $pdo->prepare('CALL sp_reponer_stock(?, ?)');
    $consulta->execute([$idProducto, $cantidad]);
    $consulta->closeCursor();
    responder(['ok' => true]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
