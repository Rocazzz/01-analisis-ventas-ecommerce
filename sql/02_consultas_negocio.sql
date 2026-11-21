-- =====================================================================
-- Consultas de negocio · Análisis de ventas e-commerce
-- Técnicas: JOINs, CTEs, agregaciones, funciones de ventana, CASE
-- =====================================================================

-- Vista base: ventas netas solo de pedidos entregados
DROP VIEW IF EXISTS v_ventas;
CREATE VIEW v_ventas AS
SELECT  p.pedido_id,
        p.cliente_id,
        DATE(p.fecha_pedido)                                   AS fecha,
        STRFTIME('%Y-%m', p.fecha_pedido)                      AS mes,
        pr.categoria,
        pr.nombre                                              AS producto,
        d.cantidad,
        d.cantidad * d.precio_unitario * (1 - d.descuento)     AS venta_neta,
        d.cantidad * pr.costo_unitario                         AS costo
FROM pedidos p
JOIN detalle_pedidos d ON d.pedido_id  = p.pedido_id
JOIN productos pr      ON pr.producto_id = d.producto_id
WHERE p.estado = 'Entregado';

-- Q1. KPIs generales
SELECT  COUNT(DISTINCT pedido_id)                         AS pedidos,
        COUNT(DISTINCT cliente_id)                        AS clientes_compradores,
        ROUND(SUM(venta_neta))                            AS ventas_netas,
        ROUND(SUM(venta_neta) / COUNT(DISTINCT pedido_id)) AS ticket_promedio,
        ROUND(100.0 * (SUM(venta_neta) - SUM(costo)) / SUM(venta_neta), 1) AS margen_bruto_pct
FROM v_ventas;

-- Q2. Ventas mensuales y crecimiento mes a mes (LAG)
WITH mensual AS (
    SELECT mes, SUM(venta_neta) AS ventas
    FROM v_ventas GROUP BY mes
)
SELECT  mes,
        ROUND(ventas) AS ventas,
        ROUND(100.0 * (ventas - LAG(ventas) OVER (ORDER BY mes)) / LAG(ventas) OVER (ORDER BY mes), 1) AS crecimiento_mom_pct
FROM mensual
ORDER BY mes;

-- Q3. Top 3 productos por categoría (RANK)
WITH prod AS (
    SELECT categoria, producto, SUM(venta_neta) AS ventas
    FROM v_ventas GROUP BY categoria, producto
)
SELECT * FROM (
    SELECT categoria, producto, ROUND(ventas) AS ventas,
           RANK() OVER (PARTITION BY categoria ORDER BY ventas DESC) AS ranking
    FROM prod
) WHERE ranking <= 3
ORDER BY categoria, ranking;

-- Q4. Rendimiento por canal de adquisición
SELECT  c.canal_adquisicion,
        COUNT(DISTINCT v.cliente_id)                                   AS clientes,
        ROUND(SUM(v.venta_neta))                                       AS ventas,
        ROUND(SUM(v.venta_neta) / COUNT(DISTINCT v.cliente_id))        AS ventas_por_cliente,
        ROUND(1.0 * COUNT(DISTINCT v.pedido_id) / COUNT(DISTINCT v.cliente_id), 2) AS pedidos_por_cliente
FROM v_ventas v
JOIN clientes c ON c.cliente_id = v.cliente_id
GROUP BY c.canal_adquisicion
ORDER BY ventas DESC;

-- Q5. Tasa de cancelación y devolución por método de pago
SELECT  metodo_pago,
        COUNT(*)                                                           AS pedidos,
        ROUND(100.0 * SUM(CASE WHEN estado = 'Cancelado' THEN 1 ELSE 0 END) / COUNT(*), 1) AS cancelacion_pct,
        ROUND(100.0 * SUM(CASE WHEN estado = 'Devuelto'  THEN 1 ELSE 0 END) / COUNT(*), 1) AS devolucion_pct
FROM pedidos
GROUP BY metodo_pago
ORDER BY cancelacion_pct DESC;

-- Q6. Clientes recurrentes vs. de una sola compra
WITH compras AS (
    SELECT cliente_id, COUNT(DISTINCT pedido_id) AS n
    FROM v_ventas GROUP BY cliente_id
)
SELECT  CASE WHEN n = 1 THEN 'Una compra' ELSE 'Recurrente' END AS tipo_cliente,
        COUNT(*) AS clientes,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM compras
GROUP BY tipo_cliente;

-- Q7. Participación acumulada de ventas por categoría (Pareto)
WITH cat AS (
    SELECT categoria, SUM(venta_neta) AS ventas FROM v_ventas GROUP BY categoria
)
SELECT  categoria,
        ROUND(ventas) AS ventas,
        ROUND(100.0 * SUM(ventas) OVER (ORDER BY ventas DESC) / SUM(ventas) OVER (), 1) AS pct_acumulado
FROM cat
ORDER BY ventas DESC;
