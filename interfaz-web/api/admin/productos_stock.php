<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

try {
    $pdo = conectar();
    $consulta = $pdo->prepare(
        "SELECT p.id_producto, p.nombre, c.nombre AS categoria, p.stock, p.activo,
                IF(b.id_producto IS NULL, 0, 1) AS stock_bajo
         FROM producto p
         JOIN categoria c ON c.id_categoria = p.id_categoria
         LEFT JOIN v_productos_stock_bajo b ON b.id_producto = p.id_producto
         ORDER BY p.nombre"
    );
    $consulta->execute();
    responder(['ok' => true, 'productos' => $consulta->fetchAll(PDO::FETCH_ASSOC)]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
