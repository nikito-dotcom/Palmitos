<?php
// Botón "Confirmar pedido"
//   ->  CALL sp_crear_pedido(...)       crea el pedido
//   ->  CALL sp_agregar_producto(...)   una vez por cada producto del carrito
// Todo va dentro de una TRANSACCIÓN: si un producto falla (por ejemplo, sin stock),
// se deshace todo y no queda un pedido a medias en la base.
require __DIR__ . '/conexion.php';
soloPost();

if (empty($_SESSION['id_cliente'])) {
    responder(['ok' => false, 'error' => 'Tu sesión terminó. Volvé a ingresar para confirmar el pedido.'], 401);
}

$datos = leerDatos();
$items = $datos['items'] ?? [];
if (!is_array($items) || count($items) === 0) {
    responder(['ok' => false, 'error' => 'El carrito está vacío.'], 400);
}

$tipoEntrega = $datos['tipo_entrega'] ?? '';
$direccion   = $tipoEntrega === 'envio' ? textoONulo($datos['direccion'] ?? null) : null;
$zona        = $tipoEntrega === 'envio' ? textoONulo($datos['zona'] ?? null) : null;

$db = conectar();
$productoActual = null;
try {
    $db->beginTransaction();

    // 1. Crear el pedido (el trigger completa la dirección, la zona y el costo de envío)
    $llamada = $db->prepare('CALL sp_crear_pedido(?, ?, ?, ?, ?, @id_pedido)');
    $llamada->execute([
        $_SESSION['id_cliente'],
        $tipoEntrega,
        $direccion,
        $zona === null ? null : (int) $zona,
        textoONulo($datos['observaciones'] ?? null),
    ]);
    $llamada->closeCursor();
    $idPedido = (int) $db->query('SELECT @id_pedido AS id')->fetch()['id'];

    // 2. Agregar cada producto (los triggers controlan el stock, fijan el precio y suman al total)
    $agregar = $db->prepare('CALL sp_agregar_producto(?, ?, ?)');
    foreach ($items as $item) {
        $productoActual = (int) ($item['id'] ?? 0);
        $agregar->execute([$idPedido, $productoActual, (int) ($item['cantidad'] ?? 0)]);
        $agregar->closeCursor();
    }
    $productoActual = null;

    // 3. Todo salió bien: se guarda
    $db->commit();
} catch (PDOException $e) {
    if ($db->inTransaction()) {
        $db->rollBack();   // se deshace el pedido completo
    }
    // Si falló un producto, se dice cuál
    $info = $e->errorInfo ?? [];
    if ($productoActual !== null && ($info[0] ?? '') === '45000') {
        $consulta = $db->prepare('SELECT nombre FROM producto WHERE id_producto = ?');
        $consulta->execute([$productoActual]);
        $nombre = $consulta->fetchColumn();
        if ($nombre) {
            responder(['ok' => false, 'error' => $nombre . ': ' . $info[2]], 400);
        }
    }
    responderError($e);
}

// 4. Devolver el pedido como quedó en la base (con los precios y el total que calculó MySQL)
$cabecera = $db->prepare(
    'SELECT id_pedido, tipo_entrega, zona, direccion_envio, subtotal, costo_envio, total, forma_pago, estado_pago
     FROM v_resumen_pedidos WHERE id_pedido = ?'
);
$cabecera->execute([$idPedido]);
$pedido = $cabecera->fetch();

responder([
    'ok'     => true,
    'pedido' => [
        'id'           => (int) $pedido['id_pedido'],
        'tipo_entrega' => $pedido['tipo_entrega'],
        'zona'         => $pedido['zona'],
        'direccion'    => $pedido['direccion_envio'],
        'subtotal'     => (float) $pedido['subtotal'],
        'costo_envio'  => (float) $pedido['costo_envio'],
        'total'        => (float) $pedido['total'],
        'forma_pago'   => $pedido['forma_pago'],
        'estado_pago'  => $pedido['estado_pago'],
    ],
], 201);
