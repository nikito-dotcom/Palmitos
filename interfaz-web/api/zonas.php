<?php
// Barrios para el formulario "Crear una cuenta"
require __DIR__ . '/conexion.php';

$db = conectar();
try {
    $filas = $db->query('SELECT id_zona, nombre, costo_envio FROM zona_envio ORDER BY id_zona')->fetchAll();
} catch (PDOException $e) {
    responderError($e);
}

$zonas = array_map(function ($z) {
    return ['id' => (int) $z['id_zona'], 'nombre' => $z['nombre'], 'costo' => (float) $z['costo_envio']];
}, $filas);

responder(['ok' => true, 'zonas' => $zonas]);
