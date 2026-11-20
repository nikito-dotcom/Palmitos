# Palmitos: sistema de pedidos online para una panadería

Proyecto final de la materia **Bases de Datos**.

**Grupo:** Palmitos

**Integrantes:**
- Diaz Nicolas
- Anahi Lezcano
- Mauro Mendoza
- Sofia Gauna
- Sayro Yabar

## El problema

Muchas panaderías de barrio toman pedidos por WhatsApp o por teléfono: los pedidos se pierden, el stock no se actualiza y el costo de envío se calcula a ojo. Este sistema permite que los clientes hagan su pedido online, con **envío a domicilio** (el costo depende del barrio) o **retiro en el local**, y pago por **transferencia**. La base de datos controla el stock, los precios, los totales y el estado de cada pedido.

## Partes del proyecto

| Parte | Carpeta | Contenido |
| --- | --- | --- |
| 1. Diagramas | [`diagramas/`](diagramas/) | DER (modelo entidad-relación) y modelo relacional con las tablas |
| 2. Base de datos | [`base-de-datos/`](base-de-datos/) | Script MySQL: tablas, datos de prueba, funciones, triggers, vistas y stored procedures |
| 3. Documentación | [`documentacion/`](documentacion/) | Diccionario de datos e instrucciones de instalación |
| 4. Interfaz web | [`interfaz-web/`](interfaz-web/) | Página del cliente (HTML, CSS y JavaScript) y conexión con la base en PHP |

## Tecnologías

- **MySQL / MariaDB** (probado en MariaDB 10.x con XAMPP)
- **PHP 8** con PDO
- **HTML, CSS y JavaScript** sin frameworks
- **draw.io** para los diagramas

## Cómo ejecutarlo

1. Instalar XAMPP e iniciar **Apache** y **MySQL**.
2. Ejecutar `base-de-datos/panaderia.sql` en HeidiSQL o phpMyAdmin.
3. Copiar el contenido de `interfaz-web/` a `htdocs/panaderia/`.
4. Abrir `http://localhost/panaderia/`.

Las instrucciones completas están en [`documentacion/instalacion.md`](documentacion/instalacion.md).
