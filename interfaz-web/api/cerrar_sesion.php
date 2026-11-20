<?php
// Botón "Salir": borra la sesión
require __DIR__ . '/conexion.php';
soloPost();

$_SESSION = [];
session_destroy();
responder(['ok' => true]);
