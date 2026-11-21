"""
Genera un dataset sintético (reproducible) de una tienda online de mobiliario
y lo carga en una base de datos SQLite + CSV.

Uso:  python src/generar_datos.py
"""
from pathlib import Path
import sqlite3
import numpy as np
import pandas as pd

RNG = np.random.default_rng(42)
BASE = Path(__file__).resolve().parents[1]
RAW = BASE / "data" / "raw"
RAW.mkdir(parents=True, exist_ok=True)

# ---------------- Productos ----------------
categorias = {
    "Sala": [("Sofá 3 puestos", 2_400_000), ("Sofá cama", 1_900_000), ("Mesa de centro", 450_000), ("Poltrona", 780_000)],
    "Comedor": [("Comedor 4 puestos", 1_600_000), ("Comedor 6 puestos", 2_300_000), ("Silla comedor", 210_000)],
    "Alcoba": [("Cama doble", 1_350_000), ("Mesa de noche", 260_000), ("Closet 3 puertas", 1_750_000), ("Colchón doble", 1_100_000)],
    "Oficina": [("Escritorio", 620_000), ("Silla ergonómica", 690_000), ("Biblioteca", 480_000)],
    "Decoración": [("Lámpara de pie", 230_000), ("Espejo", 180_000), ("Tapete", 320_000), ("Cojín decorativo", 55_000)],
}
rows = []
pid = 1
for cat, items in categorias.items():
    for nombre, precio in items:
        rows.append({"producto_id": pid, "nombre": nombre, "categoria": cat,
                     "precio_lista": precio, "costo_unitario": round(precio * RNG.uniform(0.45, 0.65), -3)})
        pid += 1
productos = pd.DataFrame(rows)

# ---------------- Clientes ----------------
ciudades = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Bucaramanga", "Pereira", "Cartagena"]
pesos_ciudad = [0.32, 0.2, 0.18, 0.1, 0.08, 0.06, 0.06]
canales = ["Orgánico (SEO)", "Redes sociales", "Google Ads", "Referido", "Email"]
pesos_canal = [0.3, 0.27, 0.23, 0.1, 0.1]
n_clientes = 2500
fechas_registro = pd.to_datetime("2024-01-01") + pd.to_timedelta(RNG.integers(0, 640, n_clientes), unit="D")
clientes = pd.DataFrame({
    "cliente_id": np.arange(1, n_clientes + 1),
    "ciudad": RNG.choice(ciudades, n_clientes, p=pesos_ciudad),
    "canal_adquisicion": RNG.choice(canales, n_clientes, p=pesos_canal),
    "fecha_registro": fechas_registro.date,
})

# ---------------- Pedidos ----------------
pedidos, detalle = [], []
oid = 1
fin = pd.Timestamp("2025-12-31")
estacionalidad = {1: .8, 2: .75, 3: .85, 4: .9, 5: 1.05, 6: 1.0, 7: .95, 8: .9, 9: .95, 10: 1.0, 11: 1.35, 12: 1.5}
for c in clientes.itertuples():
    lealtad = RNG.gamma(1.3, 1.4)  # algunos clientes compran mucho más
    if c.canal_adquisicion == "Referido":
        lealtad *= 1.4
    n_ped = RNG.poisson(lealtad)
    reg = pd.Timestamp(c.fecha_registro)
    dias_disp = (fin - reg).days
    if dias_disp <= 0:
        continue
    for _ in range(n_ped):
        f = reg + pd.Timedelta(days=int(RNG.integers(0, dias_disp)))
        if RNG.random() > estacionalidad[f.month] / 1.5:
            continue
        estado = RNG.choice(["Entregado", "Cancelado", "Devuelto"], p=[0.88, 0.07, 0.05])
        pedidos.append({"pedido_id": oid, "cliente_id": c.cliente_id, "fecha_pedido": f.date(),
                        "estado": estado, "metodo_pago": RNG.choice(["Tarjeta crédito", "PSE", "Contraentrega", "Nequi"], p=[.42, .3, .15, .13])})
        for p in RNG.choice(productos.producto_id, size=RNG.integers(1, 4), replace=False):
            precio = productos.loc[productos.producto_id == p, "precio_lista"].iloc[0]
            desc = RNG.choice([0, 0, 0, 0.05, 0.1, 0.15]) + (0.1 if f.month == 11 and f.day >= 20 else 0)
            detalle.append({"pedido_id": oid, "producto_id": int(p), "cantidad": int(RNG.choice([1, 1, 1, 2, 4], p=[.5, .2, .15, .1, .05])),
                            "precio_unitario": precio, "descuento": round(desc, 2)})
        oid += 1

pedidos = pd.DataFrame(pedidos).sort_values("fecha_pedido").reset_index(drop=True)
detalle = pd.DataFrame(detalle)

# ---------------- Guardar ----------------
for nombre, df in {"productos": productos, "clientes": clientes, "pedidos": pedidos, "detalle_pedidos": detalle}.items():
    df.to_csv(RAW / f"{nombre}.csv", index=False, encoding="utf-8")

db = BASE / "data" / "ecommerce.db"
db.unlink(missing_ok=True)
with sqlite3.connect(db) as con:
    con.executescript((BASE / "sql" / "01_schema.sql").read_text(encoding="utf-8"))
    for nombre, df in {"productos": productos, "clientes": clientes, "pedidos": pedidos, "detalle_pedidos": detalle}.items():
        df.to_sql(nombre, con, if_exists="append", index=False)

print(f"Productos: {len(productos)} | Clientes: {len(clientes)} | Pedidos: {len(pedidos)} | Líneas: {len(detalle)}")
print(f"Base de datos creada en {db.relative_to(BASE)}")
