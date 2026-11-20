<?php
// =====================================================================
// Conexión a la base de datos "panaderia"
// Si tu MySQL / MariaDB usa otro usuario o contraseña, cambialos acá.
// (En XAMPP y Laragon, por defecto el usuario es root y la contraseña está vacía.)
// =====================================================================
const DB_HOST    = '127.0.0.1';
const DB_PUERTO  = 3306;
const DB_NOMBRE  = 'panaderia';
const DB_USUARIO = 'root';
const DB_CLAVE   = '';

session_start();
header('Content-Type: application/json; charset=utf-8');

// Devuelve una respuesta en formato JSON y termina el script
function responder($datos, $codigo = 200)
{
    http_response_code($codigo);
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

// Abre la conexión. Si falla, avisa con un mensaje claro.
function conectar()
{
    try {
        $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PUERTO . ';dbname=' . DB_NOMBRE . ';charset=utf8mb4';
        return new PDO($dsn, DB_USUARIO, DB_CLAVE, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => true,   // necesario para CALL con parámetros OUT (@variables)
        ]);
    } catch (PDOException $e) {
        // Mensaje según la causa, para saber qué arreglar
        $codigo = $e->errorInfo[1] ?? $e->getCode();
        if ($codigo == 1045 || $codigo == 1698) {
            $mensaje = 'El usuario o la contraseña de api/conexion.php no son correctos.';
        } elseif ($codigo == 1049) {
            $mensaje = 'La base "panaderia" no existe. Ejecutá panaderia.sql en HeidiSQL.';
        } elseif ($codigo == 2002) {
            $mensaje = 'MySQL no está iniciado. Prendelo en el XAMPP Control Panel.';
        } else {
            $mensaje = 'No se pudo conectar a la base de datos (' . $e->getMessage() . ').';
        }
        responder(['ok' => false, 'error' => $mensaje], 500);
    }
}

// Lee los datos que manda la página (en formato JSON)
function leerDatos()
{
    $datos = json_decode(file_get_contents('php://input'), true);
    return is_array($datos) ? $datos : [];
}

// Los textos vacíos se guardan como NULL
function textoONulo($valor)
{
    $valor = trim((string) ($valor ?? ''));
    return $valor === '' ? null : $valor;
}

// Solo se aceptan pedidos POST (para los formularios)
function soloPost()
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        responder(['ok' => false, 'error' => 'Método no permitido'], 405);
    }
}

// Traduce un error de la base a un mensaje para el usuario.
// Los errores de nuestros procedures (SIGNAL SQLSTATE '45000') ya traen un mensaje claro.
function responderError(PDOException $e)
{
    $info = $e->errorInfo ?? [];
    if (($info[0] ?? '') === '45000' && !empty($info[2])) {
        responder(['ok' => false, 'error' => $info[2]], 400);
    }
    // 1318: cantidad de parámetros distinta / 1305: procedure inexistente / 1054: columna inexistente
    // Pasan cuando la base tiene una versión vieja del script
    $codigo = $info[1] ?? 0;
    if (in_array($codigo, [1318, 1305, 1054], true)) {
        responder([
            'ok'    => false,
            'error' => 'La base tiene una versión vieja de los procedures. Ejecutá de nuevo panaderia.sql en HeidiSQL. (Detalle: ' . ($info[2] ?? '') . ')',
        ], 500);
    }
    $detalle = $info[2] ?? $e->getMessage();
    responder(['ok' => false, 'error' => 'Ocurrió un error en la base de datos: ' . $detalle], 500);
}

// Guarda en la sesión quién entró y devuelve sus datos
function iniciarSesion(PDO $db, $idCliente)
{
    $consulta = $db->prepare('SELECT id_cliente, nombre, tipo, domicilio, id_zona FROM cliente WHERE id_cliente = ?');
    $consulta->execute([$idCliente]);
    $cliente = $consulta->fetch();

    $_SESSION['id_cliente'] = (int) $cliente['id_cliente'];
    return [
        'id'        => (int) $cliente['id_cliente'],
        'nombre'    => $cliente['nombre'],
        'tipo'      => $cliente['tipo'],
        'domicilio' => $cliente['domicilio'],   // para completar solo el formulario de envío
        'id_zona'   => $cliente['id_zona'] === null ? null : (int) $cliente['id_zona'],
    ];
}
