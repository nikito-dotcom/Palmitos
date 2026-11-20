# Pruebas para la administración de Palmitos

Ejecutar luego de importar `panaderia.sql` desde cero e iniciar Apache y MariaDB en XAMPP.

## Instalación

Colocar `admin.html` junto al `index.html` del cliente y copiar `api/admin/` dentro de la carpeta `api/` existente. Los endpoints requieren el `api/conexion.php` del proyecto y sus funciones `conectar()`, `leerDatos()`, `soloPost()`, `responder()`, `responderError()` y `textoONulo()`.

1. **Inicio de sesión válido:** ingresar a `admin.html` con `admin@palmitos.com` / `admin123`. Debe abrir el panel y dejar una sesión de empleado activa.
2. **Inicio inválido:** probar una contraseña incorrecta. Debe mostrarse el mensaje del procedimiento y no crearse `$_SESSION['id_empleado']`.
3. **PHP sin sesión:** abrir `api/admin/pedidos.php` sin iniciar sesión. Debe responder HTTP `401` y JSON con `ok: false`.
4. **Listas y filtros:** comprobar que pedidos se ordene del más nuevo al más antiguo y que los tres filtros actualicen la lista. Verificar que los envíos se agrupen por barrio y muestren dirección, teléfono e indicaciones.
5. **Confirmar pago:** confirmar el pago del pedido 7 (pendiente de pago y con productos en los datos de prueba). Debe quedar confirmado. Repetir la acción: mostrar el error devuelto por `sp_confirmar_pago`.
6. **Cambiar estado sin pago confirmado:** antes de confirmar el pago del pedido 7, ejecutar `CALL sp_cambiar_estado(7, 'en_preparacion');`. Debe fallar con SQLSTATE `45000` y el mensaje del trigger indicando que no se puede preparar hasta confirmar el pago.
7. **Cancelar un pedido entregado:** ejecutar `CALL sp_cambiar_estado(1, 'cancelado');`. Debe fallar con SQLSTATE `45000` porque el pedido está entregado.
8. **Pedido de retiro en camino:** ejecutar `CALL sp_crear_pedido(1, 'retiro', NULL, NULL, 'Prueba de estado', @p); CALL sp_agregar_producto(@p, 1, 1); CALL sp_confirmar_pago(@p); CALL sp_cambiar_estado(@p, 'en_camino');`. El último llamado debe fallar con el mensaje del trigger que impide poner un retiro en camino.
9. **Reposición de stock:** sumar una cantidad positiva y comprobar el nuevo stock. Probar cantidad `0` o negativa: el procedure debe devolver su error y el stock no debe cambiar.
10. **Historial y reportes:** avanzar un pedido válido y volver a abrirlo; el historial debe reflejar el cambio. Comparar cada reporte con sus vistas/función de origen.

## Límite de verificación en este entorno

La sintaxis JavaScript de `admin.html` se comprobó con `node --check`. No hay PHP, MySQL ni MariaDB instalados en el entorno de edición, así que la importación desde cero y las pruebas de endpoints/procedimientos quedan pendientes de ejecutar en XAMPP.
