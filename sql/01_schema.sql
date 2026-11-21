-- Modelo relacional de la tienda online (SQLite)
DROP TABLE IF EXISTS detalle_pedidos;
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS productos;

CREATE TABLE productos (
    producto_id     INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    categoria       TEXT NOT NULL,
    precio_lista    REAL NOT NULL,
    costo_unitario  REAL NOT NULL
);

CREATE TABLE clientes (
    cliente_id         INTEGER PRIMARY KEY,
    ciudad             TEXT,
    canal_adquisicion  TEXT,
    fecha_registro     DATE
);

CREATE TABLE pedidos (
    pedido_id     INTEGER PRIMARY KEY,
    cliente_id    INTEGER NOT NULL REFERENCES clientes(cliente_id),
    fecha_pedido  DATE NOT NULL,
    estado        TEXT CHECK (estado IN ('Entregado','Cancelado','Devuelto')),
    metodo_pago   TEXT
);

CREATE TABLE detalle_pedidos (
    pedido_id        INTEGER NOT NULL REFERENCES pedidos(pedido_id),
    producto_id      INTEGER NOT NULL REFERENCES productos(producto_id),
    cantidad         INTEGER NOT NULL,
    precio_unitario  REAL NOT NULL,
    descuento        REAL DEFAULT 0
);

CREATE INDEX idx_pedidos_fecha   ON pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX idx_detalle_pedido  ON detalle_pedidos(pedido_id);
