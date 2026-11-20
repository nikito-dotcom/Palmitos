# 4. Interfaz web

Página para los clientes de la panadería, conectada a la base de datos.

## Archivos

| Archivo | Qué hace |
| --- | --- |
| `index.html` | Toda la interfaz del cliente: HTML, CSS y JavaScript en un solo archivo |
| `api/conexion.php` | Conexión a MySQL con PDO y funciones comunes |
| `api/productos.php` | Lista de productos → `sp_listar_productos` |
| `api/zonas.php` | Barrios de envío con su costo |
| `api/iniciar_sesion.php` | Ingresar con cuenta → `sp_iniciar_sesion` |
| `api/crear_usuario.php` | Crear cuenta → `sp_crear_usuario` |
| `api/entrar_sin_usuario.php` | Entrar sin cuenta → `sp_entrar_sin_usuario` |
| `api/finalizar_compra.php` | Confirmar el pedido → `sp_crear_pedido` + `sp_agregar_producto`, dentro de una transacción |
| `api/cerrar_sesion.php` | Salir |
| `img/` | Fotos propias de los productos (opcional) |

## Pantallas

1. **Inicio:** carrusel de productos y tres opciones: ingresar con cuenta, entrar sin cuenta (solo nombre y teléfono) o crear una cuenta.
2. **Productos:** listado por categoría con foto, descripción, precio y disponibilidad.
3. **Carrito:** agregar, quitar y cambiar cantidades.
4. **Finalizar compra:** envío a domicilio (con el costo según el barrio) o retiro, indicaciones y pago por transferencia.
5. **Confirmación:** número de pedido, total y datos para transferir.

## Cómo funciona

```
Navegador (index.html, fetch)  →  Apache + PHP (api/*.php, PDO)  →  MySQL (stored procedures)
```

- La página nunca se conecta directo a MySQL: le envía JSON a un archivo PHP y recibe JSON.
- Todas las consultas son preparadas (`?`), para evitar inyección SQL.
- El pedido se guarda en la base recién al confirmar la compra. Si falta stock de algún producto, la transacción se deshace y no queda nada a medias.
- Los mensajes de error de la base (por ejemplo, "Stock insuficiente") se muestran tal cual en la pantalla.

## Fotos

Las fotos de los productos son de [Wikimedia Commons](https://commons.wikimedia.org) y se usan según la licencia de cada una (los créditos están en la página). Si se agrega una foto propia en `img/` con el nombre del producto (por ejemplo `img/medialuna-de-manteca.jpg`), se usa esa.
