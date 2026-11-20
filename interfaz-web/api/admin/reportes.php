<?php
declare(strict_types=1);

require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/_seguridad.php';
asegurarSesionEmpleado();

try {
    $pdo = conectar();
    $rankingConsulta = $pdo->prepare('SELECT * FROM v_ranking_productos ORDER BY unidades_vendidas DESC, nombre');
    $rankingConsulta->execute();
    $ranking = $rankingConsulta->fetchAll(PDO::FETCH_ASSOC);

    $barriosConsulta = $pdo->prepare(
        "SELECT z.nombre AS barrio, COUNT(*) AS pedidos, SUM(p.total) AS recaudado
         FROM pedido p
         JOIN zona_envio z ON z.id_zona = p.id_zona
         WHERE p.estado <> 'cancelado' AND p.estado_pago = 'confirmado'
         GROUP BY z.id_zona, z.nombre
         ORDER BY recaudado DESC, z.nombre"
    );
    $barriosConsulta->execute();

    $clientesConsulta = $pdo->prepare(
        "SELECT c.id_cliente, CONCAT_WS(' ', c.nombre, c.apellido) AS cliente, c.email,
                fn_total_gastado_cliente(c.id_cliente) AS total_gastado
         FROM cliente c
         ORDER BY total_gastado DESC, cliente
         LIMIT 10"
    );
    $clientesConsulta->execute();

    $proveedoresConsulta = $pdo->prepare('SELECT * FROM v_productos_proveedores ORDER BY margen DESC, producto, proveedor');
    $proveedoresConsulta->execute();
    $proveedores = $proveedoresConsulta->fetchAll(PDO::FETCH_ASSOC);
    responder([
        'ok' => true,
        'ranking' => $ranking,
        'barrios' => $barriosConsulta->fetchAll(PDO::FETCH_ASSOC),
        'clientes' => $clientesConsulta->fetchAll(PDO::FETCH_ASSOC),
        'proveedores' => $proveedores
    ]);
} catch (PDOException $e) {
    responderErrorProcedimiento($e);
}
