# Diccionario de datos

Base de datos `panaderia` (MySQL 8 / MariaDB 10.x, `utf8mb4`).

**Convenciones:** PK = clave primaria · FK = clave foránea · NN = NOT NULL · UQ = UNIQUE · AI = AUTO_INCREMENT

| Tabla | Qué guarda |
| --- | --- |
| zona_envio | Barrios donde se hacen envíos y su costo |
| cliente | Personas que compran (con cuenta o invitadas) |
| categoria | Agrupación de los productos |
| producto | Productos que se venden en la tienda online |
| proveedor | Empresas que proveen productos de reventa |
| producto_proveedor | Qué proveedor provee cada producto y a qué costo |
| pedido | Cabecera de cada pedido online |
| detalle_pedido | Productos y cantidades de cada pedido |
| historial_estado_pedido | Registro de cada cambio de estado de un pedido |

## zona_envio

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_zona | INT | PK, AI, NN | Identificador de la zona |
| nombre | VARCHAR(50) | NN, UQ | Nombre del barrio |
| costo_envio | DECIMAL(10,2) | NN, CHECK (>= 0) | Costo del envío a esa zona, en pesos |

## cliente

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_cliente | INT | PK, AI, NN | Identificador del cliente |
| nombre | VARCHAR(50) | NN | Nombre |
| apellido | VARCHAR(50) | Admite NULL (obligatorio para registrados) | Apellido; NULL en los invitados |
| email | VARCHAR(100) | UQ, admite NULL | Email con el que inicia sesión; NULL en los invitados |
| contrasena | CHAR(64) | Admite NULL | Contraseña cifrada con SHA2 (256 bits); NULL en los invitados |
| tipo | ENUM('registrado','invitado') | NN, DEFAULT 'registrado' | Si creó una cuenta o entró sin cuenta |
| telefono | VARCHAR(20) | — | Teléfono de contacto |
| domicilio | VARCHAR(150) | — | Dirección habitual; se usa para el envío si el pedido no indica otra |
| id_zona | INT | FK → zona_envio, admite NULL | Barrio del domicilio |
| fecha_alta | DATE | NN, DEFAULT fecha actual | Fecha de registro |

Restricción: `CHECK (tipo = 'invitado' OR (apellido IS NOT NULL AND email IS NOT NULL AND contrasena IS NOT NULL))`.

## categoria

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_categoria | INT | PK, AI, NN | Identificador de la categoría |
| nombre | VARCHAR(50) | NN, UQ | Nombre de la categoría |

## producto

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_producto | INT | PK, AI, NN | Identificador del producto |
| nombre | VARCHAR(80) | NN | Nombre |
| descripcion | VARCHAR(200) | — | Presentación (unidad, peso, envase) |
| precio | DECIMAL(10,2) | NN, CHECK (> 0) | Precio de venta actual |
| stock | INT | NN, DEFAULT 0, CHECK (>= 0) | Unidades disponibles; lo actualizan los triggers |
| activo | BOOLEAN | NN, DEFAULT TRUE | Si se muestra y se puede pedir |
| id_categoria | INT | NN, FK → categoria | Categoría a la que pertenece |

## proveedor

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_proveedor | INT | PK, AI, NN | Identificador del proveedor |
| razon_social | VARCHAR(100) | NN | Nombre legal de la empresa |
| cuit | VARCHAR(13) | NN, UQ | CUIT con guiones |
| telefono | VARCHAR(20) | — | Teléfono de contacto |
| email | VARCHAR(100) | — | Email de contacto |

## producto_proveedor

Resuelve la relación muchos a muchos *Suministra*. Clave primaria compuesta.

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_producto | INT | PK, FK → producto, NN | Producto que se provee |
| id_proveedor | INT | PK, FK → proveedor, NN | Proveedor que lo vende |
| precio_costo | DECIMAL(10,2) | NN, CHECK (> 0) | Precio al que lo compra la panadería |

## pedido

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_pedido | INT | PK, AI, NN | Identificador del pedido |
| id_cliente | INT | NN, FK → cliente | Cliente que hizo el pedido |
| fecha | DATETIME | NN, DEFAULT fecha y hora actual | Momento del pedido |
| tipo_entrega | ENUM('envio','retiro') | NN | Envío a domicilio o retiro en el local |
| direccion_envio | VARCHAR(150) | Admite NULL | Dirección de entrega; si no se indica, el trigger usa el domicilio del cliente |
| id_zona | INT | FK → zona_envio, admite NULL | Barrio del envío; NULL si es retiro |
| costo_envio | DECIMAL(10,2) | NN, DEFAULT 0 | Lo calcula el trigger según el barrio (0 si es retiro) |
| estado | ENUM('pendiente','en_preparacion','listo','en_camino','entregado','cancelado') | NN, DEFAULT 'pendiente' | Estado actual |
| total | DECIMAL(10,2) | NN, DEFAULT 0 | Productos + envío; lo mantienen los triggers |
| forma_pago | ENUM('transferencia') | NN, DEFAULT 'transferencia' | Medio de pago |
| estado_pago | ENUM('pendiente','confirmado') | NN, DEFAULT 'pendiente' | Si se recibió la transferencia |
| fecha_pago | DATETIME | Admite NULL | Cuándo se confirmó el pago |
| observaciones | VARCHAR(200) | — | Indicaciones del cliente |

## detalle_pedido

Resuelve la relación muchos a muchos *Contiene*. Clave primaria compuesta.

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_pedido | INT | PK, FK → pedido, NN | Pedido al que pertenece |
| id_producto | INT | PK, FK → producto, NN | Producto pedido |
| cantidad | INT | NN, CHECK (> 0) | Unidades |
| precio_unitario | DECIMAL(10,2) | NN, DEFAULT 0 | Precio al momento de la compra; lo copia el trigger |

## historial_estado_pedido

Tabla de auditoría que llena el trigger `trg_pedido_after_update`.

| Campo | Tipo | Restricciones | Descripción |
| --- | --- | --- | --- |
| id_historial | INT | PK, AI, NN | Identificador del registro |
| id_pedido | INT | NN, FK → pedido | Pedido que cambió de estado |
| estado_anterior | VARCHAR(20) | — | Estado antes del cambio |
| estado_nuevo | VARCHAR(20) | NN | Estado después del cambio |
| fecha_cambio | DATETIME | NN, DEFAULT fecha y hora actual | Momento del cambio |

## Relaciones

| Tabla (FK) | Campo | Referencia | Relación del DER |
| --- | --- | --- | --- |
| cliente | id_zona | zona_envio(id_zona) | Vive en (N:1) |
| pedido | id_cliente | cliente(id_cliente) | Realiza (1:N) |
| pedido | id_zona | zona_envio(id_zona) | Se envía a (N:1) |
| detalle_pedido | id_pedido | pedido(id_pedido) | Contiene (N:M) |
| detalle_pedido | id_producto | producto(id_producto) | Contiene (N:M) |
| producto | id_categoria | categoria(id_categoria) | Pertenece (N:1) |
| producto_proveedor | id_producto | producto(id_producto) | Suministra (N:M) |
| producto_proveedor | id_proveedor | proveedor(id_proveedor) | Suministra (N:M) |
| historial_estado_pedido | id_pedido | pedido(id_pedido) | Registra (1:N) |

## Objetos programados

| Tipo | Nombre | Qué hace |
| --- | --- | --- |
| Función | fn_costo_envio | Costo de envío de una zona |
| Función | fn_subtotal_pedido | Suma de los productos de un pedido |
| Función | fn_total_pedido | Subtotal más envío |
| Función | fn_total_gastado_cliente | Total gastado por un cliente (sin cancelados) |
| Trigger | trg_pedido_before_insert | Completa dirección y barrio, y calcula el envío |
| Trigger | trg_detalle_before_insert | Controla estado, pago y stock; copia el precio |
| Trigger | trg_detalle_after_insert | Descuenta stock y suma al total |
| Trigger | trg_detalle_before_update | Controla la nueva cantidad y mantiene el precio |
| Trigger | trg_detalle_after_update | Ajusta stock y total por la diferencia |
| Trigger | trg_detalle_before_delete | Solo deja quitar productos de pedidos pendientes y sin pagar |
| Trigger | trg_detalle_after_delete | Devuelve el stock y resta del total |
| Trigger | trg_pedido_before_update | Valida los cambios de estado |
| Trigger | trg_pedido_after_update | Guarda el historial y devuelve el stock si se cancela |
| Procedure | sp_crear_usuario | Crea una cuenta con contraseña cifrada |
| Procedure | sp_iniciar_sesion | Comprueba email y contraseña |
| Procedure | sp_entrar_sin_usuario | Crea un cliente invitado (nombre y teléfono) |
| Procedure | sp_listar_productos | Productos activos por categoría |
| Procedure | sp_crear_pedido | Crea un pedido con entrega, dirección, barrio e indicaciones |
| Procedure | sp_agregar_producto | Agrega un producto (o suma cantidad) |
| Procedure | sp_quitar_producto | Quita unidades o el producto entero |
| Procedure | sp_ver_pedido | Cabecera y productos de un pedido |
| Procedure | sp_pedidos_cliente | Pedidos de un cliente |
| Procedure | sp_confirmar_pago | Marca la transferencia como recibida |
| Procedure | sp_cambiar_estado | Cambia el estado de un pedido |
| Procedure | sp_reponer_stock | Suma stock a un producto |
| Vista | v_resumen_pedidos | Pedidos con cliente, barrio, pago y totales |
| Vista | v_detalle_pedidos | Una fila por producto de cada pedido |
| Vista | v_envios_pendientes | Envíos todavía no entregados |
| Vista | v_productos_stock_bajo | Productos con menos de 15 unidades |
| Vista | v_ranking_productos | Unidades vendidas y recaudación por producto |
| Vista | v_productos_proveedores | Costo, precio de venta y margen por proveedor |
