<?php
// Botón "Crear cuenta"
//   ->  CALL sp_crear_usuario(nombre, apellido, email, contrasena, telefono, domicilio, id_zona, @id)
require __DIR__ . '/conexion.php';
soloPost();

$datos = leerDatos();
$zona = textoONulo($datos['zona'] ?? null);

$db = conectar();
try {
    $llamada = $db->prepare('CALL sp_crear_usuario(?, ?, ?, ?, ?, ?, ?, @id_cliente)');
    $llamada->execute([
        textoONulo($datos['nombre'] ?? null),
        textoONulo($datos['apellido'] ?? null),
        textoONulo($datos['email'] ?? null),
        $datos['contrasena'] ?? null,
        textoONulo($datos['telefono'] ?? null),
        textoONulo($datos['domicilio'] ?? null),
        $zona === null ? null : (int) $zona,
    ]);
    $llamada->closeCursor();

    $id = $db->query('SELECT @id_cliente AS id')->fetch()['id'];
    responder(['ok' => true, 'cliente' => iniciarSesion($db, $id)], 201);
} catch (PDOException $e) {
    responderError($e);
}
