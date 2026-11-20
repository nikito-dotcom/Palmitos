# 2. Base de datos

El script [`panaderia.sql`](panaderia.sql) crea la base `panaderia` desde cero (MySQL 8 o MariaDB 10.x). Se ejecuta completo (en HeidiSQL, con F9).

## Contenido del script

| Sección | Qué tiene |
| --- | --- |
| 1. Tablas | 9 tablas con claves primarias, foráneas, `CHECK`, `UNIQUE` y `ENUM` |
| 2. Funciones | `fn_costo_envio`, `fn_subtotal_pedido`, `fn_total_pedido`, `fn_total_gastado_cliente` |
| 3. Triggers | 9 triggers que calculan el envío, controlan y descuentan el stock, fijan precios, mantienen el total y guardan el historial de estados |
| 4. Datos de prueba | Barrios, clientes, categorías, productos, proveedores y pedidos |
| 5. Vistas | `v_resumen_pedidos`, `v_detalle_pedidos`, `v_envios_pendientes`, `v_productos_stock_bajo`, `v_ranking_productos`, `v_productos_proveedores` |
| 6. Stored procedures | 12 procedures: ingreso de clientes, productos, pedidos, pagos y stock |
| 7. Consultas y pruebas | JOINs, uso de vistas y funciones, flujo completo de un pedido y pruebas de validaciones |

## Reglas que controla la base

- El costo de envío se calcula según el barrio; si el pedido es para retirar, no se cobra.
- No se puede vender más que el stock disponible; al vender se descuenta y al cancelar se devuelve.
- El precio de cada producto lo toma la base, no la página.
- Un pedido no pasa a preparación hasta que se confirma el pago.
- Un pedido pagado, entregado o cancelado ya no se puede modificar.
- Un pedido para retirar no puede estar "en camino".
- Cada cambio de estado queda registrado en `historial_estado_pedido`.
- Las contraseñas se guardan cifradas con `SHA2`.

Cuando algo no se permite, los procedures y triggers responden con `SIGNAL SQLSTATE '45000'` y un mensaje claro.

## Clientes de prueba

| Email | Contraseña |
| --- | --- |
| lucia.gomez@mail.com | lucia123 |
| martin.fer@mail.com | martin123 |
