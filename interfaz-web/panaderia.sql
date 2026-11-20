-- =====================================================================
--  PROYECTO: Sistema de pedidos online para una panadería
--  Materia: Bases de Datos
--  Motor: MySQL 8 (también corre en MariaDB 10.x)
--
--  Contenido:
--    1. Creación de la base y las tablas
--    2. Funciones
--    3. Triggers
--    4. Carga de datos (INSERT)
--    5. Vistas
--    6. Stored procedures
--    7. Consultas con JOIN y pruebas
-- =====================================================================

DROP DATABASE IF EXISTS panaderia;
CREATE DATABASE panaderia CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE panaderia;

-- =====================================================================
-- 1. TABLAS
-- =====================================================================

-- Zonas a las que la panadería hace envíos, cada una con su costo
CREATE TABLE zona_envio (
    id_zona      INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(50)   NOT NULL UNIQUE,
    costo_envio  DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_costo_envio CHECK (costo_envio >= 0)
);

-- Un cliente puede ser 'registrado' (tiene email y contraseña para entrar)
-- o 'invitado' (entró sin usuario: solo deja nombre y teléfono para el pedido)
CREATE TABLE cliente (
    id_cliente   INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(50)  NOT NULL,
    apellido     VARCHAR(50)  NULL,              -- NULL en los invitados
    email        VARCHAR(100) NULL UNIQUE,       -- NULL en los invitados
    contrasena   CHAR(64)     NULL,              -- se guarda cifrada con SHA2, nunca en texto plano
    tipo         ENUM('registrado','invitado') NOT NULL DEFAULT 'registrado',
    telefono     VARCHAR(20),
    domicilio    VARCHAR(150),
    id_zona      INT NULL,                       -- zona de su domicilio
    fecha_alta   DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_cliente_registrado
        CHECK (tipo = 'invitado' OR (apellido IS NOT NULL AND email IS NOT NULL AND contrasena IS NOT NULL)),
    CONSTRAINT fk_cliente_zona FOREIGN KEY (id_zona) REFERENCES zona_envio(id_zona)
);

-- [ADMINISTRACIÓN] Personal autorizado para usar el panel interno.
CREATE TABLE empleado (
    id_empleado INT AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    contrasena  CHAR(64) NOT NULL, -- SHA2(..., 256)
    rol         ENUM('admin','vendedor') NOT NULL DEFAULT 'vendedor',
    activo      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE categoria (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE producto (
    id_producto  INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(80)   NOT NULL,
    descripcion  VARCHAR(200),
    precio       DECIMAL(10,2) NOT NULL,
    stock        INT           NOT NULL DEFAULT 0,
    activo       BOOLEAN       NOT NULL DEFAULT TRUE,  -- si se muestra en la tienda online
    id_categoria INT           NOT NULL,
    CONSTRAINT chk_precio CHECK (precio > 0),
    CONSTRAINT chk_stock  CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
);

CREATE TABLE proveedor (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    cuit         VARCHAR(13)  NOT NULL UNIQUE,
    telefono     VARCHAR(20),
    email        VARCHAR(100)
);

-- Relación SUMINISTRA (M:N) entre proveedor y producto
CREATE TABLE producto_proveedor (
    id_producto  INT NOT NULL,
    id_proveedor INT NOT NULL,
    precio_costo DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_producto, id_proveedor),
    CONSTRAINT chk_precio_costo CHECK (precio_costo > 0),
    CONSTRAINT fk_pp_producto  FOREIGN KEY (id_producto)  REFERENCES producto(id_producto),
    CONSTRAINT fk_pp_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor)
);

-- Relación REALIZA (1:N): un cliente realiza muchos pedidos
CREATE TABLE pedido (
    id_pedido       INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente      INT NOT NULL,
    fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_entrega    ENUM('envio','retiro') NOT NULL,
    direccion_envio VARCHAR(150) NULL,           -- puede ser distinta al domicilio del cliente
    id_zona         INT NULL,
    costo_envio     DECIMAL(10,2) NOT NULL DEFAULT 0,
    estado          ENUM('pendiente','en_preparacion','listo','en_camino','entregado','cancelado')
                    NOT NULL DEFAULT 'pendiente',
    total           DECIMAL(10,2) NOT NULL DEFAULT 0,  -- lo mantienen actualizado los triggers
    forma_pago      ENUM('transferencia') NOT NULL DEFAULT 'transferencia',  -- por ahora, solo transferencia
    estado_pago     ENUM('pendiente','confirmado') NOT NULL DEFAULT 'pendiente',
    fecha_pago      DATETIME NULL,                     -- cuándo se confirmó la transferencia
    observaciones   VARCHAR(200),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente),
    CONSTRAINT fk_pedido_zona    FOREIGN KEY (id_zona)    REFERENCES zona_envio(id_zona)
);

-- Relación CONTIENE (M:N) entre pedido y producto
CREATE TABLE detalle_pedido (
    id_pedido       INT NOT NULL,
    id_producto     INT NOT NULL,
    cantidad        INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0,  -- precio al momento de la compra
    PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT chk_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedido(id_pedido),
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto)
);

-- Tabla de auditoría: guarda cada cambio de estado de un pedido (la llena un trigger)
CREATE TABLE historial_estado_pedido (
    id_historial    INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido       INT NOT NULL,
    estado_anterior VARCHAR(20),
    estado_nuevo    VARCHAR(20) NOT NULL,
    fecha_cambio    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historial_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido)
);


-- =====================================================================
-- 2. FUNCIONES
-- =====================================================================
DELIMITER $$

-- Devuelve el costo de envío de una zona (0 si no existe)
CREATE FUNCTION fn_costo_envio(p_id_zona INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_costo DECIMAL(10,2);
    SELECT costo_envio INTO v_costo FROM zona_envio WHERE id_zona = p_id_zona;
    RETURN IFNULL(v_costo, 0);
END$$

-- Suma de los productos de un pedido (sin el envío)
CREATE FUNCTION fn_subtotal_pedido(p_id_pedido INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(10,2);
    SELECT SUM(cantidad * precio_unitario) INTO v_subtotal
    FROM detalle_pedido
    WHERE id_pedido = p_id_pedido;
    RETURN IFNULL(v_subtotal, 0);
END$$

-- Total del pedido = subtotal + costo de envío
CREATE FUNCTION fn_total_pedido(p_id_pedido INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_envio DECIMAL(10,2);
    SELECT costo_envio INTO v_envio FROM pedido WHERE id_pedido = p_id_pedido;
    RETURN fn_subtotal_pedido(p_id_pedido) + IFNULL(v_envio, 0);
END$$

-- Cuánto gastó un cliente en total (no cuenta pedidos cancelados)
CREATE FUNCTION fn_total_gastado_cliente(p_id_cliente INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);
    SELECT SUM(total) INTO v_total
    FROM pedido
    WHERE id_cliente = p_id_cliente AND estado <> 'cancelado';
    RETURN IFNULL(v_total, 0);
END$$

DELIMITER ;


-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================
DELIMITER $$

-- Al crear un pedido: completa los datos de envío o los limpia si es retiro
CREATE TRIGGER trg_pedido_before_insert
BEFORE INSERT ON pedido
FOR EACH ROW
BEGIN
    IF NEW.tipo_entrega = 'retiro' THEN
        SET NEW.direccion_envio = NULL;
        SET NEW.id_zona = NULL;
        SET NEW.costo_envio = 0;
    ELSE
        -- si no se indicó dirección o zona, se toman las del cliente
        IF NEW.direccion_envio IS NULL THEN
            SET NEW.direccion_envio = (SELECT domicilio FROM cliente WHERE id_cliente = NEW.id_cliente);
        END IF;
        IF NEW.id_zona IS NULL THEN
            SET NEW.id_zona = (SELECT id_zona FROM cliente WHERE id_cliente = NEW.id_cliente);
        END IF;
        IF NEW.direccion_envio IS NULL OR NEW.id_zona IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Para un envío a domicilio hace falta dirección y zona';
        END IF;
        SET NEW.costo_envio = fn_costo_envio(NEW.id_zona);
    END IF;
    SET NEW.total = NEW.costo_envio;   -- arranca solo con el envío; los productos se suman después
END$$

-- Antes de agregar un producto: valida estado del pedido y stock, y fija el precio
CREATE TRIGGER trg_detalle_before_insert
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    DECLARE v_activo BOOLEAN;
    DECLARE v_estado VARCHAR(20);
    DECLARE v_pago   VARCHAR(20);

    SELECT estado, estado_pago INTO v_estado, v_pago FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_estado <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden agregar productos a pedidos pendientes';
    END IF;
    IF v_pago = 'confirmado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pedido ya fue pagado, no se puede modificar';
    END IF;

    SELECT stock, activo INTO v_stock, v_activo FROM producto WHERE id_producto = NEW.id_producto;
    IF v_activo = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no está disponible';
    END IF;
    IF v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para el producto';
    END IF;

    -- el precio se toma siempre de la tabla producto
    SET NEW.precio_unitario = (SELECT precio FROM producto WHERE id_producto = NEW.id_producto);
END$$

-- Después de agregar un producto: descuenta stock y actualiza el total
CREATE TRIGGER trg_detalle_after_insert
AFTER INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE producto
       SET stock = stock - NEW.cantidad
     WHERE id_producto = NEW.id_producto;

    UPDATE pedido
       SET total = total + NEW.cantidad * NEW.precio_unitario
     WHERE id_pedido = NEW.id_pedido;
END$$

-- Antes de quitar un producto: solo se permite si el pedido sigue pendiente
CREATE TRIGGER trg_detalle_before_delete
BEFORE DELETE ON detalle_pedido
FOR EACH ROW
BEGIN
    IF (SELECT estado FROM pedido WHERE id_pedido = OLD.id_pedido) <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden quitar productos de pedidos pendientes';
    END IF;
    IF (SELECT estado_pago FROM pedido WHERE id_pedido = OLD.id_pedido) = 'confirmado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pedido ya fue pagado, no se puede modificar';
    END IF;
END$$

-- Después de quitar un producto: devuelve el stock y resta del total
CREATE TRIGGER trg_detalle_after_delete
AFTER DELETE ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE producto
       SET stock = stock + OLD.cantidad
     WHERE id_producto = OLD.id_producto;

    UPDATE pedido
       SET total = total - OLD.cantidad * OLD.precio_unitario
     WHERE id_pedido = OLD.id_pedido;
END$$

-- Antes de cambiar la cantidad de un producto: valida estado del pedido y stock
CREATE TRIGGER trg_detalle_before_update
BEFORE UPDATE ON detalle_pedido
FOR EACH ROW
BEGIN
    IF NEW.id_pedido <> OLD.id_pedido OR NEW.id_producto <> OLD.id_producto THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el pedido o el producto de una línea';
    END IF;
    IF (SELECT estado FROM pedido WHERE id_pedido = NEW.id_pedido) <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden modificar pedidos pendientes';
    END IF;
    IF (SELECT estado_pago FROM pedido WHERE id_pedido = NEW.id_pedido) = 'confirmado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pedido ya fue pagado, no se puede modificar';
    END IF;
    -- si aumenta la cantidad, tiene que alcanzar el stock para la diferencia
    IF NEW.cantidad > OLD.cantidad AND
       (SELECT stock FROM producto WHERE id_producto = NEW.id_producto) < NEW.cantidad - OLD.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para el producto';
    END IF;
    -- se mantiene el precio con el que se agregó el producto
    SET NEW.precio_unitario = OLD.precio_unitario;
END$$

-- Después de cambiar la cantidad: ajusta el stock y el total por la diferencia
CREATE TRIGGER trg_detalle_after_update
AFTER UPDATE ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE producto
       SET stock = stock - (NEW.cantidad - OLD.cantidad)
     WHERE id_producto = NEW.id_producto;

    UPDATE pedido
       SET total = total + (NEW.cantidad - OLD.cantidad) * NEW.precio_unitario
     WHERE id_pedido = NEW.id_pedido;
END$$

-- Antes de modificar un pedido: valida los cambios de estado
CREATE TRIGGER trg_pedido_before_update
BEFORE UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF OLD.estado IN ('entregado','cancelado') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un pedido entregado o cancelado no se puede modificar';
    END IF;
    IF NEW.estado = 'en_camino' AND NEW.tipo_entrega = 'retiro' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un pedido para retirar no puede estar en camino';
    END IF;
    -- el pedido se empieza a preparar recién cuando se confirma la transferencia
    IF NEW.estado IN ('en_preparacion','listo','en_camino','entregado')
       AND NEW.estado_pago <> 'confirmado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pedido no se puede preparar hasta confirmar el pago';
    END IF;
END$$

-- Después de modificar un pedido: registra el historial y, si se cancela, devuelve el stock
CREATE TRIGGER trg_pedido_after_update
AFTER UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO historial_estado_pedido (id_pedido, estado_anterior, estado_nuevo)
        VALUES (NEW.id_pedido, OLD.estado, NEW.estado);
    END IF;

    IF NEW.estado = 'cancelado' AND OLD.estado <> 'cancelado' THEN
        UPDATE producto p
          JOIN detalle_pedido d ON d.id_producto = p.id_producto
           SET p.stock = p.stock + d.cantidad
         WHERE d.id_pedido = NEW.id_pedido;
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 4. CARGA DE DATOS
-- =====================================================================

INSERT INTO zona_envio (nombre, costo_envio) VALUES
('Almagro',      1200.00),
('Villa Crespo', 1300.00),
('Palermo',      1500.00),
('Caballito',    1800.00),
('Belgrano',     2200.00);

INSERT INTO cliente (nombre, apellido, email, contrasena, telefono, domicilio, id_zona, fecha_alta) VALUES
('Lucía',    'Gómez',     'lucia.gomez@mail.com',  SHA2('lucia123', 256),  '11-4567-8901', 'Av. Corrientes 3850, 4°B',  1, '2026-08-02'),
('Martín',   'Fernández', 'martin.fer@mail.com',   SHA2('martin123', 256), '11-5123-4455', 'Thames 1120',               3, '2026-08-15'),
('Sofía',    'Pereyra',   'sofi.pereyra@mail.com', SHA2('sofia123', 256),  '11-6789-0011', 'Acoyte 540, 2°A',           4, '2026-09-01'),
('Diego',    'Romero',    'diego.romero@mail.com', SHA2('diego123', 256),  '11-4321-9876', 'Juramento 2200',            5, '2026-09-20'),
('Valentina','Castro',    'vale.castro@mail.com',  SHA2('vale123', 256),   '11-5987-1234', 'Av. Scalabrini Ortiz 450',  2, '2026-10-05'),
('Joaquín',  'Ruiz',      'joaco.ruiz@mail.com',   SHA2('joaco123', 256),  '11-6012-3344', NULL,                        NULL, '2026-11-01');
-- (Joaquín todavía no hizo pedidos: sirve para probar el LEFT JOIN)

-- [ADMINISTRACIÓN] Cuenta de demostración solicitada para probar el panel.
INSERT INTO empleado (nombre, email, contrasena, rol, activo)
VALUES ('Administración Palmitos', 'admin@palmitos.com', SHA2('admin123', 256), 'admin', TRUE);

INSERT INTO categoria (nombre) VALUES
('Panes'), ('Facturas'), ('Tortas y budines'), ('Alfajores y masas'), ('Bebidas'), ('Almacén');

INSERT INTO producto (nombre, descripcion, precio, stock, id_categoria) VALUES
('Pan francés (1 kg)',         'Pan del día',                         3500.00, 40, 1),
('Pan lactal',                 'Pan de molde casero',                 4000.00, 20, 1),
('Prepizza',                   'Prepizza con salsa',                  2500.00, 25, 1),
('Medialuna de manteca',       'Unidad',                               800.00, 120, 2),
('Medialuna de grasa',         'Unidad',                               700.00, 100, 2),
('Vigilante',                  'Con membrillo, unidad',                750.00, 60, 2),
('Torta de ricota',            'Entera, 8 porciones',                14000.00, 6, 3),
('Budín de limón',             'Con glaseado',                        6500.00, 12, 3),
('Alfajor de maicena',         'Con dulce de leche y coco',           1200.00, 50, 4),
('Gaseosa cola 500 ml',        'Botella',                             2000.00, 30, 5),
('Agua mineral 500 ml',        'Botella',                             1500.00, 30, 5),
('Leche chocolatada 1 L',      'Cartón',                              1800.00, 10, 5),
('Dulce de leche 400 g',       'Pote',                                3800.00, 8, 6);

INSERT INTO proveedor (razon_social, cuit, telefono, email) VALUES
('Bebidas del Plata S.A.',      '30-71234567-1', '11-4000-1000', 'ventas@bebidasdelplata.com'),
('Lácteos La Pradera S.R.L.',   '30-70987654-3', '11-4000-2000', 'pedidos@lapradera.com'),
('Distribuidora Sur S.A.',      '30-71555444-9', '11-4000-3000', 'contacto@distrisur.com');

-- Solo los productos de reventa tienen proveedor; lo demás se elabora en la panadería
INSERT INTO producto_proveedor (id_producto, id_proveedor, precio_costo) VALUES
(10, 1, 1300.00),
(10, 3, 1350.00),
(11, 1,  900.00),
(12, 2, 1150.00),
(12, 3, 1200.00),
(13, 2, 2600.00);

-- Pedidos (los triggers completan dirección, zona, costo de envío y total)
INSERT INTO pedido (id_cliente, fecha, tipo_entrega, direccion_envio, id_zona, observaciones) VALUES
(1, '2026-11-10 08:15:00', 'envio',  NULL, NULL, 'Tocar timbre 4B'),
(2, '2026-11-10 09:30:00', 'retiro', NULL, NULL, NULL),
(3, '2026-11-12 17:45:00', 'envio',  NULL, NULL, NULL),
(1, '2026-11-14 10:00:00', 'envio',  'Av. Rivadavia 4500 (oficina)', 4, 'Entregar en recepción'),
(4, '2026-11-15 11:20:00', 'envio',  NULL, NULL, NULL),
(5, '2026-11-16 07:50:00', 'retiro', NULL, NULL, 'Retira a las 9'),
(2, '2026-11-17 08:05:00', 'envio',  NULL, NULL, NULL);

-- Detalle de los pedidos (los triggers fijan el precio, descuentan stock y suman al total)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad) VALUES
(1, 4, 12), (1, 10, 2),
(2, 1, 1),  (2, 6, 6),
(3, 7, 1),  (3, 12, 2),
(4, 4, 24), (4, 5, 12), (4, 11, 4),
(5, 8, 2),  (5, 9, 6),
(6, 3, 3),  (6, 13, 1),
(7, 4, 6),  (7, 9, 4);

-- Pagos por transferencia confirmados (el pedido 7 todavía no pagó)
UPDATE pedido
   SET estado_pago = 'confirmado', fecha_pago = fecha + INTERVAL 15 MINUTE
 WHERE id_pedido IN (1,2,3,4,5,6);

-- Avance de estados (el trigger guarda cada cambio en el historial)
UPDATE pedido SET estado = 'en_preparacion' WHERE id_pedido IN (1,2,3,4,5,6);
UPDATE pedido SET estado = 'en_camino'      WHERE id_pedido IN (1,3,4);
UPDATE pedido SET estado = 'listo'          WHERE id_pedido = 2;
UPDATE pedido SET estado = 'entregado'      WHERE id_pedido IN (1,2,3);
UPDATE pedido SET estado = 'cancelado'      WHERE id_pedido = 5;   -- devuelve el stock


-- =====================================================================
-- 5. VISTAS
-- =====================================================================

-- Resumen de cada pedido con datos del cliente y la zona
CREATE VIEW v_resumen_pedidos AS
SELECT  p.id_pedido,
        p.fecha,
        CONCAT_WS(' ', c.nombre, c.apellido)  AS cliente,
        c.telefono,
        p.tipo_entrega,
        z.nombre                           AS zona,
        p.direccion_envio,
        p.estado,
        p.forma_pago,
        p.estado_pago,
        fn_subtotal_pedido(p.id_pedido)    AS subtotal,
        p.costo_envio,
        p.total
FROM pedido p
JOIN cliente c         ON c.id_cliente = p.id_cliente
LEFT JOIN zona_envio z ON z.id_zona    = p.id_zona;      -- LEFT: los retiros no tienen zona

-- Envíos que todavía no se entregaron (para el repartidor)
CREATE VIEW v_envios_pendientes AS
SELECT  p.id_pedido,
        p.fecha,
        z.nombre AS zona,
        p.direccion_envio,
        CONCAT_WS(' ', c.nombre, c.apellido) AS cliente,
        c.telefono,
        p.estado,
        p.total,
        p.observaciones
FROM pedido p
JOIN cliente c    ON c.id_cliente = p.id_cliente
JOIN zona_envio z ON z.id_zona    = p.id_zona
WHERE p.tipo_entrega = 'envio'
  AND p.estado IN ('pendiente','en_preparacion','listo','en_camino');

-- Productos con poco stock
CREATE VIEW v_productos_stock_bajo AS
SELECT  pr.id_producto, pr.nombre, ca.nombre AS categoria, pr.stock
FROM producto pr
JOIN categoria ca ON ca.id_categoria = pr.id_categoria
WHERE pr.stock < 15 AND pr.activo = TRUE;

-- Ranking de productos más vendidos (sin contar pedidos cancelados)
CREATE VIEW v_ranking_productos AS
SELECT  pr.id_producto,
        pr.nombre,
        ca.nombre                                      AS categoria,
        IFNULL(SUM(d.cantidad), 0)                     AS unidades_vendidas,
        IFNULL(SUM(d.cantidad * d.precio_unitario), 0) AS recaudado
FROM producto pr
JOIN categoria ca           ON ca.id_categoria = pr.id_categoria
LEFT JOIN detalle_pedido d  ON d.id_producto   = pr.id_producto
     AND d.id_pedido IN (SELECT id_pedido FROM pedido WHERE estado <> 'cancelado')
GROUP BY pr.id_producto, pr.nombre, ca.nombre;

-- Pedidos detallados: una fila por cada producto de cada pedido
CREATE VIEW v_detalle_pedidos AS
SELECT  p.id_pedido,
        p.fecha,
        CONCAT_WS(' ', c.nombre, c.apellido)    AS cliente,
        p.tipo_entrega,
        p.estado,
        pr.nombre                            AS producto,
        d.cantidad,
        d.precio_unitario,
        d.cantidad * d.precio_unitario       AS subtotal
FROM pedido p
JOIN cliente c        ON c.id_cliente   = p.id_cliente
JOIN detalle_pedido d ON d.id_pedido    = p.id_pedido
JOIN producto pr      ON pr.id_producto = d.id_producto;

-- Productos de reventa con sus proveedores y margen de ganancia
CREATE VIEW v_productos_proveedores AS
SELECT  pr.nombre        AS producto,
        pv.razon_social  AS proveedor,
        pp.precio_costo,
        pr.precio        AS precio_venta,
        pr.precio - pp.precio_costo AS margen
FROM producto_proveedor pp
JOIN producto  pr ON pr.id_producto  = pp.id_producto
JOIN proveedor pv ON pv.id_proveedor = pp.id_proveedor;


-- =====================================================================
-- 6. STORED PROCEDURES
-- =====================================================================
DELIMITER $$

-- ---------------------------------------------------------------------
-- 6.1 Procedures de la interfaz (uno por cada botón)
--
--   Pantalla de inicio:
--     [ Crear usuario ]       -> sp_crear_usuario
--     [ Iniciar sesión ]      -> sp_iniciar_sesion
--     [ Entrar sin usuario ]  -> sp_entrar_sin_usuario
--   Dentro del sistema (cliente):
--     [ Ver productos ]       -> sp_listar_productos
--     [ Agregar al carrito ]  -> (se guarda en la página)
--     [ Confirmar pedido ]    -> sp_crear_pedido + sp_agregar_producto (en una transacción)
--     [ Quitar ]              -> sp_quitar_producto
--     [ Ver mi pedido ]       -> sp_ver_pedido
--     [ Mis pedidos ]         -> sp_pedidos_cliente
--   Panadería (administración):
--     [ Confirmar pago ]      -> sp_confirmar_pago
--     [ Cambiar estado ]      -> sp_cambiar_estado
--     [ Reponer stock ]       -> sp_reponer_stock
-- ---------------------------------------------------------------------

-- Botón "Crear usuario": registra un cliente nuevo y devuelve su id
CREATE PROCEDURE sp_crear_usuario(
    IN  p_nombre      VARCHAR(50),
    IN  p_apellido    VARCHAR(50),
    IN  p_email       VARCHAR(100),
    IN  p_contrasena  VARCHAR(50),
    IN  p_telefono    VARCHAR(20),
    IN  p_domicilio   VARCHAR(150),
    IN  p_id_zona     INT,
    OUT p_id_cliente  INT
)
BEGIN
    IF p_nombre IS NULL OR p_apellido IS NULL OR TRIM(p_nombre) = '' OR TRIM(p_apellido) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre y el apellido son obligatorios';
    END IF;

    IF p_email IS NULL OR TRIM(p_email) NOT LIKE '%_@_%._%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El email no es válido';
    END IF;

    IF EXISTS (SELECT 1 FROM cliente WHERE email = LOWER(TRIM(p_email))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un usuario con ese email';
    END IF;

    IF p_contrasena IS NULL OR CHAR_LENGTH(p_contrasena) < 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contraseña debe tener al menos 6 caracteres';
    END IF;

    IF p_id_zona IS NOT NULL AND NOT EXISTS (SELECT 1 FROM zona_envio WHERE id_zona = p_id_zona) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La zona indicada no existe';
    END IF;

    INSERT INTO cliente (nombre, apellido, email, contrasena, tipo, telefono, domicilio, id_zona)
    VALUES (TRIM(p_nombre), TRIM(p_apellido), LOWER(TRIM(p_email)), SHA2(p_contrasena, 256),
            'registrado', p_telefono, p_domicilio, p_id_zona);

    SET p_id_cliente = LAST_INSERT_ID();
END$$

-- Botón "Iniciar sesión": comprueba email y contraseña y devuelve el id del cliente
CREATE PROCEDURE sp_iniciar_sesion(
    IN  p_email       VARCHAR(100),
    IN  p_contrasena  VARCHAR(50),
    OUT p_id_cliente  INT
)
BEGIN
    SET p_id_cliente = NULL;

    -- la contraseña ingresada se cifra igual que al registrarse y se comparan los dos cifrados
    SELECT id_cliente INTO p_id_cliente
    FROM cliente
    WHERE email = LOWER(TRIM(p_email))
      AND contrasena = SHA2(p_contrasena, 256)
      AND tipo = 'registrado';

    IF p_id_cliente IS NULL THEN
        -- no se dice cuál de los dos está mal, para no dar pistas
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email o contraseña incorrectos';
    END IF;

    SELECT id_cliente, CONCAT('Hola, ', nombre, '!') AS mensaje
    FROM cliente
    WHERE id_cliente = p_id_cliente;
END$$

-- [ADMINISTRACIÓN] Inicio de sesión separado de las cuentas de clientes.
CREATE PROCEDURE sp_iniciar_sesion_empleado(
    IN  p_email       VARCHAR(100),
    IN  p_contrasena  VARCHAR(50),
    OUT p_id_empleado INT
)
BEGIN
    SET p_id_empleado = NULL;

    SELECT id_empleado INTO p_id_empleado
    FROM empleado
    WHERE email = LOWER(TRIM(p_email))
      AND contrasena = SHA2(p_contrasena, 256)
      AND activo = TRUE;

    IF p_id_empleado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email o contraseña incorrectos';
    END IF;

    SELECT id_empleado, nombre, rol
    FROM empleado
    WHERE id_empleado = p_id_empleado;
END$$

-- Botón "Entrar sin usuario": crea un cliente invitado (sin apellido, email ni contraseña).
-- Pide solo nombre y teléfono, porque un pedido necesita saber
-- a quién entregarlo y a quién llamar.
CREATE PROCEDURE sp_entrar_sin_usuario(
    IN  p_nombre      VARCHAR(50),
    IN  p_telefono    VARCHAR(20),
    OUT p_id_cliente  INT
)
BEGIN
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre es obligatorio';
    END IF;

    IF p_telefono IS NULL OR TRIM(p_telefono) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El teléfono es obligatorio para hacer pedidos';
    END IF;

    INSERT INTO cliente (nombre, tipo, telefono)
    VALUES (TRIM(p_nombre), 'invitado', TRIM(p_telefono));

    SET p_id_cliente = LAST_INSERT_ID();
END$$

-- Botón "Ver productos": lista los productos que se pueden pedir
CREATE PROCEDURE sp_listar_productos()
BEGIN
    SELECT  p.id_producto,
            p.nombre,
            p.descripcion,
            c.id_categoria,
            c.nombre AS categoria,
            p.precio,
            IF(p.stock > 0, 'Disponible', 'Sin stock') AS disponibilidad
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.activo = TRUE
    ORDER BY c.id_categoria, p.id_producto;
END$$

-- ---------------------------------------------------------------------
-- 6.2 Procedures de pedidos, pagos y stock
-- ---------------------------------------------------------------------

-- Botón "Confirmar pedido": crea un pedido vacío y devuelve su id
CREATE PROCEDURE sp_crear_pedido(
    IN  p_id_cliente     INT,
    IN  p_tipo_entrega   VARCHAR(10),
    IN  p_direccion      VARCHAR(150),
    IN  p_id_zona        INT,
    IN  p_observaciones  VARCHAR(200),
    OUT p_id_pedido      INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe';
    END IF;

    IF p_tipo_entrega IS NULL OR p_tipo_entrega NOT IN ('envio','retiro') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de entrega debe ser envío o retiro';
    END IF;

    IF p_id_zona IS NOT NULL AND NOT EXISTS (SELECT 1 FROM zona_envio WHERE id_zona = p_id_zona) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La zona indicada no existe';
    END IF;

    INSERT INTO pedido (id_cliente, tipo_entrega, direccion_envio, id_zona, observaciones)
    VALUES (p_id_cliente, p_tipo_entrega, p_direccion, p_id_zona, p_observaciones);

    SET p_id_pedido = LAST_INSERT_ID();
END$$

-- Botón "Agregar": agrega un producto al pedido. Si ya estaba, suma la cantidad.
CREATE PROCEDURE sp_agregar_producto(
    IN p_id_pedido   INT,
    IN p_id_producto INT,
    IN p_cantidad    INT
)
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor a cero';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = p_id_pedido) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;

    -- el estado del pedido, el stock y el precio los controlan los triggers
    IF EXISTS (SELECT 1 FROM detalle_pedido
               WHERE id_pedido = p_id_pedido AND id_producto = p_id_producto) THEN
        UPDATE detalle_pedido
           SET cantidad = cantidad + p_cantidad
         WHERE id_pedido = p_id_pedido AND id_producto = p_id_producto;
    ELSE
        INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad)
        VALUES (p_id_pedido, p_id_producto, p_cantidad);
    END IF;
END$$

-- Botón "Quitar": quita unidades de un producto del pedido.
-- Si p_cantidad es NULL o es mayor o igual a lo que hay, quita el producto entero.
CREATE PROCEDURE sp_quitar_producto(
    IN p_id_pedido   INT,
    IN p_id_producto INT,
    IN p_cantidad    INT
)
BEGIN
    DECLARE v_cant_actual INT DEFAULT NULL;

    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = p_id_pedido) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no existe';
    END IF;

    SELECT cantidad INTO v_cant_actual
    FROM detalle_pedido
    WHERE id_pedido = p_id_pedido AND id_producto = p_id_producto;

    IF v_cant_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese producto no está en el pedido';
    END IF;

    IF p_cantidad IS NOT NULL AND p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad a quitar debe ser mayor a cero';
    END IF;

    -- los triggers devuelven el stock y actualizan el total
    IF p_cantidad IS NULL OR p_cantidad >= v_cant_actual THEN
        DELETE FROM detalle_pedido
        WHERE id_pedido = p_id_pedido AND id_producto = p_id_producto;
    ELSE
        UPDATE detalle_pedido
           SET cantidad = cantidad - p_cantidad
         WHERE id_pedido = p_id_pedido AND id_producto = p_id_producto;
    END IF;
END$$

-- Botón "Ver mi pedido": muestra la cabecera y después los productos
CREATE PROCEDURE sp_ver_pedido(IN p_id_pedido INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = p_id_pedido) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no existe';
    END IF;

    -- Cabecera del pedido
    SELECT id_pedido, fecha, cliente, tipo_entrega, zona, direccion_envio,
           estado, forma_pago, estado_pago, subtotal, costo_envio, total
    FROM v_resumen_pedidos
    WHERE id_pedido = p_id_pedido;

    -- Productos del pedido
    SELECT producto, cantidad, precio_unitario, subtotal
    FROM v_detalle_pedidos
    WHERE id_pedido = p_id_pedido;
END$$

-- Botón "Mis pedidos": lista los pedidos de un cliente
CREATE PROCEDURE sp_pedidos_cliente(IN p_id_cliente INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe';
    END IF;

    SELECT id_pedido, fecha, tipo_entrega, estado, estado_pago, total
    FROM pedido
    WHERE id_cliente = p_id_cliente
    ORDER BY fecha DESC;
END$$

-- Botón "Confirmar pago" (panadería): marca que llegó la transferencia
CREATE PROCEDURE sp_confirmar_pago(IN p_id_pedido INT)
BEGIN
    DECLARE v_estado      VARCHAR(20);
    DECLARE v_estado_pago VARCHAR(20);

    SELECT estado, estado_pago INTO v_estado, v_estado_pago
    FROM pedido
    WHERE id_pedido = p_id_pedido;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no existe';
    END IF;

    IF v_estado = 'cancelado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede confirmar el pago de un pedido cancelado';
    END IF;

    IF v_estado_pago = 'confirmado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pago de este pedido ya estaba confirmado';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_pedido = p_id_pedido) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no tiene productos';
    END IF;

    UPDATE pedido
       SET estado_pago = 'confirmado', fecha_pago = NOW()
     WHERE id_pedido = p_id_pedido;
END$$

-- Botón "Cambiar estado" (panadería). Las reglas de negocio están en el trigger.
CREATE PROCEDURE sp_cambiar_estado(
    IN p_id_pedido INT,
    IN p_estado    VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = p_id_pedido) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no existe';
    END IF;

    IF p_estado IS NULL OR p_estado NOT IN
       ('pendiente','en_preparacion','listo','en_camino','entregado','cancelado') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estado no válido';
    END IF;

    UPDATE pedido SET estado = p_estado WHERE id_pedido = p_id_pedido;
END$$

-- Botón "Reponer stock" (panadería)
CREATE PROCEDURE sp_reponer_stock(IN p_id_producto INT, IN p_cantidad INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor a cero';
    END IF;

    UPDATE producto SET stock = stock + p_cantidad WHERE id_producto = p_id_producto;
END$$

DELIMITER ;


-- =====================================================================
-- 7. CONSULTAS CON JOIN Y PRUEBAS
-- =====================================================================

-- [ADMINISTRACIÓN] Ejemplos para ejecutar manualmente después de importar.
-- Se dejan fuera de la carga para evitar errores de phpMyAdmin al procesar CALL.
/*

-- 7.1 INNER JOIN: productos con su categoría
SELECT pr.nombre, ca.nombre AS categoria, pr.precio, pr.stock
FROM producto pr
INNER JOIN categoria ca ON ca.id_categoria = pr.id_categoria
ORDER BY ca.nombre, pr.nombre;

-- 7.2 JOIN de 4 tablas: detalle completo de un pedido
SELECT p.id_pedido, CONCAT_WS(' ', c.nombre, c.apellido) AS cliente,
       pr.nombre AS producto, d.cantidad, d.precio_unitario,
       d.cantidad * d.precio_unitario AS subtotal_linea
FROM pedido p
JOIN cliente c         ON c.id_cliente   = p.id_cliente
JOIN detalle_pedido d  ON d.id_pedido    = p.id_pedido
JOIN producto pr       ON pr.id_producto = d.id_producto
WHERE p.id_pedido = 4;

-- 7.3 LEFT JOIN: clientes y cantidad de pedidos (incluye los que nunca compraron)
SELECT c.id_cliente, CONCAT_WS(' ', c.nombre, c.apellido) AS cliente,
       COUNT(p.id_pedido) AS cantidad_pedidos
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY cantidad_pedidos DESC;

-- 7.4 Recaudación por zona de envío (pedidos no cancelados)
SELECT z.nombre AS zona, COUNT(p.id_pedido) AS envios, SUM(p.total) AS recaudado
FROM zona_envio z
LEFT JOIN pedido p ON p.id_zona = z.id_zona AND p.estado <> 'cancelado'
GROUP BY z.id_zona, z.nombre
ORDER BY recaudado DESC;

-- 7.5 Uso de funciones
SELECT id_cliente, CONCAT_WS(' ', nombre, apellido) AS cliente,
       fn_total_gastado_cliente(id_cliente) AS total_gastado
FROM cliente
ORDER BY total_gastado DESC;

-- 7.6 Uso de vistas
SELECT * FROM v_resumen_pedidos ORDER BY fecha;
SELECT * FROM v_envios_pendientes;
SELECT * FROM v_productos_stock_bajo;
SELECT * FROM v_ranking_productos ORDER BY unidades_vendidas DESC LIMIT 5;
SELECT * FROM v_productos_proveedores;

-- 7.7 Flujo completo de un pedido online usando los procedures
CALL sp_crear_pedido(6, 'retiro', NULL, NULL, NULL, @nuevo);   -- Joaquín hace su primer pedido
CALL sp_agregar_producto(@nuevo, 4, 6);                  -- 6 medialunas
CALL sp_agregar_producto(@nuevo, 4, 6);                  -- 6 más (la misma línea pasa a 12)
CALL sp_agregar_producto(@nuevo, 8, 1);                  -- 1 budín
CALL sp_agregar_producto(@nuevo, 10, 2);                 -- 2 gaseosas
CALL sp_quitar_producto(@nuevo, 4, 2);                   -- quita 2 medialunas (quedan 10)
CALL sp_quitar_producto(@nuevo, 10, NULL);               -- quita las gaseosas del pedido
CALL sp_ver_pedido(@nuevo);
CALL sp_confirmar_pago(@nuevo);                          -- llegó la transferencia
CALL sp_cambiar_estado(@nuevo, 'en_preparacion');
CALL sp_pedidos_cliente(6);

-- Pedidos con sus productos detallados
SELECT * FROM v_detalle_pedidos ORDER BY id_pedido;
CALL sp_ver_pedido(4);        -- pedido de Lucía con 3 productos distintos

-- 7.8 Botones de la interfaz
-- Botón "Crear usuario"
CALL sp_crear_usuario('Camila', 'Sosa', 'camila.sosa@mail.com', 'camila2026',
                      '11-6543-2100', 'Gascón 850', 3, @id_camila);
SELECT id_cliente, nombre, apellido, email, tipo, contrasena FROM cliente WHERE id_cliente = @id_camila;

-- Botón "Iniciar sesión"
CALL sp_iniciar_sesion('camila.sosa@mail.com', 'camila2026', @sesion);

-- Botón "Entrar sin usuario" y pedido del invitado (como no tiene domicilio, lo indica en el pedido)
CALL sp_entrar_sin_usuario('Tomás', '11-6111-2233', @id_invitado);
CALL sp_crear_pedido(@id_invitado, 'envio', 'Billinghurst 1200', 1, 'Tocar timbre 2', @pedido_invitado);
CALL sp_agregar_producto(@pedido_invitado, 6, 4);
SELECT * FROM v_resumen_pedidos WHERE id_pedido = @pedido_invitado;

-- Botón "Ver productos"
CALL sp_listar_productos();

-- 7.9 Historial de estados (lo llena el trigger)
SELECT * FROM historial_estado_pedido ORDER BY id_pedido, id_historial;

-- 7.10 Pruebas de validaciones (descomentar de a una: cada una debe dar error)
-- CALL sp_crear_usuario('Ana', 'Paz', 'lucia.gomez@mail.com', 'clave123', NULL, NULL, NULL, @x); -- Email repetido
-- CALL sp_crear_usuario('Ana', 'Paz', 'ana.paz', 'clave123', NULL, NULL, NULL, @x);              -- Email no valido
-- CALL sp_crear_usuario('Ana', 'Paz', 'ana@mail.com', '123', NULL, NULL, NULL, @x);              -- Contrasena corta
-- CALL sp_iniciar_sesion('lucia.gomez@mail.com', 'otraclave', @x);                               -- Contrasena incorrecta
-- CALL sp_entrar_sin_usuario('Ana', NULL, @x);                                                   -- Falta telefono
-- CALL sp_agregar_producto(999, 4, 1);                -- El pedido no existe
-- CALL sp_agregar_producto(7, 999, 1);                -- El producto no existe
-- CALL sp_agregar_producto(7, 4, 0);                  -- Cantidad no valida
-- CALL sp_agregar_producto(7, 7, 50);                 -- Stock insuficiente
-- CALL sp_quitar_producto(7, 1, NULL);                -- Ese producto no está en el pedido
-- CALL sp_cambiar_estado(7, 'en_preparacion');        -- Falta confirmar el pago
-- CALL sp_cambiar_estado(7, 'volando');               -- Estado no válido
-- CALL sp_confirmar_pago(5);                          -- Pedido cancelado
-- CALL sp_agregar_producto(@nuevo, 9, 1);            -- Pedido ya pagado, no se modifica
-- CALL sp_cambiar_estado(@nuevo, 'en_camino');        -- Un retiro no puede estar en camino
-- CALL sp_cambiar_estado(1, 'pendiente');             -- Pedido entregado, no se modifica
-- CALL sp_crear_pedido(6, 'envio', NULL, NULL, NULL, @x);   -- Joaquín no tiene domicilio cargado
*/
