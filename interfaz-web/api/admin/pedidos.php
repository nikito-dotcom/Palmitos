<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

try {
    $estado = trim((string)($_GET['estado'] ?? ''));
    $estadoPago = trim((string)($_GET['estado_pago'] ?? ''));
    $tipoEntrega = trim((string)($_GET['tipo_entrega'] ?? ''));
    $pdo = conectar();
    $consulta = $pdo->prepare(
        "SELECT * FROM v_resumen_pedidos
         WHERE (? = '' OR estado = ?)
           AND (? = '' OR estado_pago = ?)
           AND (? = '' OR tipo_entrega = ?)
         ORDER BY fecha DESC, id_pedido DESC"
    );
    $consulta->execute([$estado, $estado, $estadoPago, $estadoPago, $tipoEntrega, $tipoEntrega]);
    responder(['ok' => true, 'pedidos' => $consulta->fetchAll(PDO::FETCH_ASSOC)]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
