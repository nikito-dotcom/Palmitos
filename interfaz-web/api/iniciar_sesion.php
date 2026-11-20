<?php
// Botón "Ingresar con mi cuenta"  ->  CALL sp_iniciar_sesion(email, contrasena, @id)
require __DIR__ . '/conexion.php';
soloPost();

$datos = leerDatos();
$db = conectar();
try {
    $llamada = $db->prepare('CALL sp_iniciar_sesion(?, ?, @id_cliente)');
    $llamada->execute([trim($datos['email'] ?? ''), $datos['contrasena'] ?? '']);
    $llamada->closeCursor();   // el procedure devuelve un SELECT de bienvenida; hay que cerrarlo antes de seguir

    $id = $db->query('SELECT @id_cliente AS id')->fetch()['id'];
    responder(['ok' => true, 'cliente' => iniciarSesion($db, $id)]);
} catch (PDOException $e) {
    responderError($e);
}
