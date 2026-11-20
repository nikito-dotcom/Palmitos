<?php
// Botón "Ver productos"  ->  CALL sp_listar_productos()
require __DIR__ . '/conexion.php';

$db = conectar();
try {
    $consulta = $db->query('CALL sp_listar_productos()');
    $filas = $consulta->fetchAll();
    $consulta->closeCursor();
} catch (PDOException $e) {
    responderError($e);
}

$productos = array_map(function ($p) {
    return [
        'id'             => (int) $p['id_producto'],
        'nombre'         => $p['nombre'],
        'descripcion'    => $p['descripcion'],
        'id_categoria'   => (int) $p['id_categoria'],
        'categoria'      => $p['categoria'],
        'precio'         => (float) $p['precio'],
        'disponible'     => $p['disponibilidad'] === 'Disponible',
    ];
}, $filas);

responder(['ok' => true, 'productos' => $productos]);
