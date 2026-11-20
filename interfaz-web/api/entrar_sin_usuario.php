<?php
// Botón "Entrar sin cuenta"  ->  CALL sp_entrar_sin_usuario(nombre, telefono, @id)
require __DIR__ . '/conexion.php';
soloPost();

$datos = leerDatos();
$db = conectar();
try {
    $llamada = $db->prepare('CALL sp_entrar_sin_usuario(?, ?, @id_cliente)');
    $llamada->execute([
        textoONulo($datos['nombre'] ?? null),
        textoONulo($datos['telefono'] ?? null),
    ]);
    $llamada->closeCursor();

    $id = $db->query('SELECT @id_cliente AS id')->fetch()['id'];
    responder(['ok' => true, 'cliente' => iniciarSesion($db, $id)], 201);
} catch (PDOException $e) {
    responderError($e);
}
