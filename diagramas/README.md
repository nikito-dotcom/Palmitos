# 1. Diagramas

El archivo [`Diagrama_der_panaderia.drawio`](Diagrama_der_panaderia.drawio) tiene, en una sola hoja:

- **DER (modelo entidad-relación):** 7 entidades (Cliente, Pedido, Producto, Categoría, Proveedor, Zona_Envío e Historial_Estado_Pedido) y 7 relaciones (Realiza, Contiene, Suministra, Pertenece, Vive en, Se envía a y Registra), con atributos, claves primarias subrayadas y cardinalidades.
- **Modelo relacional:** las 9 tablas que salen del DER, con sus claves primarias (PK) y foráneas (FK) conectadas.

Se abre en [app.diagrams.net](https://app.diagrams.net) (Archivo → Abrir desde → Dispositivo) o en draw.io de escritorio.

## Decisiones de diseño

- Las relaciones muchos a muchos se resolvieron con tablas intermedias:
  - **Contiene** (pedido ↔ producto) → `detalle_pedido`, con `cantidad` y `precio_unitario`.
  - **Suministra** (proveedor ↔ producto) → `producto_proveedor`, con `precio_costo`.
- Los productos no se guardan dentro de la tabla `pedido`: un pedido puede tener muchos productos y una columna no puede guardar una lista (primera forma normal). Por eso la cabecera va en `pedido` y cada producto es una fila de `detalle_pedido`.
- `precio_unitario` se guarda en el detalle para conservar el precio del momento de la compra aunque después cambie el precio del producto.
