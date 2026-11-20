# Instalación

## Requisitos

- [XAMPP](https://www.apachefriends.org) (Apache + PHP 8 + MariaDB)
- HeidiSQL o phpMyAdmin para ejecutar el script

## Pasos

1. Iniciar **Apache** y **MySQL** desde el XAMPP Control Panel.
2. Ejecutar completo `base-de-datos/panaderia.sql` (en HeidiSQL: Archivo → Cargar archivo SQL, y F9).
   Para comprobar, `CALL sp_listar_productos();` tiene que devolver 13 productos.
3. Crear la carpeta `htdocs/panaderia` dentro de XAMPP y copiar ahí todo el contenido de `interfaz-web/`
   (`index.html`, `api/` e `img/`).
4. Si MySQL tiene contraseña, ponerla en `api/conexion.php`, en la línea `DB_CLAVE`.
   En XAMPP, por defecto, el usuario es `root` y la contraseña está vacía.
5. Probar `http://localhost/panaderia/api/productos.php`: tiene que mostrar `{"ok":true,...}`.
6. Abrir `http://localhost/panaderia/`.

La página tiene que abrirse desde `http://localhost`, no con doble clic en el archivo: los archivos PHP solo se ejecutan a través de Apache.

## Problemas comunes

| Mensaje | Solución |
| --- | --- |
| "No hay conexión con el servidor" | Abrir la página desde `http://localhost/panaderia/` con Apache iniciado |
| "MySQL no está iniciado" | Iniciar MySQL en el XAMPP Control Panel |
| "La base "panaderia" no existe" | Ejecutar `panaderia.sql` |
| "El usuario o la contraseña… no son correctos" | Revisar `DB_USUARIO` y `DB_CLAVE` en `api/conexion.php` |
| "La base tiene una versión vieja de los procedures" | Volver a ejecutar el `panaderia.sql` de este repositorio |
