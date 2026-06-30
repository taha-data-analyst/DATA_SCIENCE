
use project;
select * from orders;
select * from routes;
select * from delivery_agents;
select * from shipment_tracking;
select * from warehouses;
-- Task 1.1  Identify and delete duplicate Order_ID records
SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1;
-- Task 1.2 Replace null Traffic_Delay_Min with the average delay for that route.
SELECT * FROM routes WHERE  traffic_delay_min IS NULL;
update routes r 
JOIN ( select avg(Traffic_Delay_Min) AS avg_delay from routes ) t 
SET r.Traffic_Delay_Min = t.avg_delay 
WHERE r.Traffic_Delay_Min IS NULL;

-- Task 1.3 Convert all date columns into YYYY-MM-DD format using SQL functions.
UPDATE orders SET order_date = DATE(order_date);
UPDATE orders SET expected_delivery_date = DATE(expected_delivery_date);
UPDATE orders SET actual_delivery_date = DATE(actual_delivery_date);

-- Task 1.4 Ensure that no Actual_Delivery_Date is before Order_Date (flag such records).
SELECT * FROM orders WHERE actual_delivery_date < order_date;
-- ALTER TABLE orders ADD COLUMN invalid_delivery_flag VARCHAR(10);
-- UPDATE orders SET invalid_delivery_flag = 'INVALID' WHERE actual_delivery_date < order_date;

-- Task 2: Delivery Delay Analysis
-- Task 2.1 Calculate delivery delay (in days) for each order
SELECT  order_id,route_id, warehouse_id,
DATEDIFF(actual_delivery_date, expected_delivery_date) AS delay_days
FROM orders
WHERE actual_delivery_date > expected_delivery_date;

-- Find Top 10 delayed routes based on average delay days.
SELECT route_id, AVG(DATEDIFF(actual_delivery_date, expected_delivery_date)) AS avg_delay_days
FROM orders GROUP BY route_id
ORDER BY avg_delay_days DESC
LIMIT 10;

-- Task 2.3 Use window functions to rank all orders by delay within each warehouse.
SELECT order_id, warehouse_id, route_id,
DATEDIFF(actual_delivery_date, expected_delivery_date) AS delay_days,
RANK() OVER (PARTITION BY warehouse_id ORDER BY DATEDIFF(actual_delivery_date, expected_delivery_date) DESC) AS delay_rank 
FROM orders;

-- Task 3: Route Optimization Insights (10 Marks)
-- Task 3.1.1  Average delivery time (in days).
SELECT route_id, 
AVG(DATEDIFF(actual_delivery_date, order_date)) 
AS avg_delivery_time_days 
FROM orders GROUP BY route_id;
-- Task 3.1.2 Average traffic delay
SELECT route_id,
AVG(traffic_delay_min) AS avg_traffic_delay
FROM routes
GROUP BY route_id;

-- Task 3.1.3 Distance-to-time efficiency ratio: Distance_KM / Average_Travel_Time_Min.
SELECT route_id, distance_km,average_travel_time_min,
(distance_km / average_travel_time_min) AS efficiency_ratio
FROM routes;
-- Task 3.2 Identify 3 routes with the worst efficiency ratio.
SELECT route_id,distance_km,
average_travel_time_min,
(distance_km / average_travel_time_min) AS efficiency_ratio
FROM routes
ORDER BY efficiency_ratio ASC
LIMIT 3;

-- Task 3.3 Find routes with >20% delayed shipments
SELECT route_id,
AVG(actual_delivery_date > expected_delivery_date) * 100 AS delay_percentage
FROM orders GROUP BY route_id HAVING delay_percentage > 20;

-- Task 4: Warehouse Performance (10 Marks)
-- Task 4.1: Find the top 3 warehouses with the highest average processing time.
SELECT warehouse_id,location,processing_time_min
FROM warehouses
ORDER BY processing_time_min DESC
LIMIT 3;

-- Task 4.2: Calculate total vs. delayed shipments for each warehouse.
SELECT  warehouse_id, COUNT(*) AS total_shipments,
SUM(actual_delivery_date > expected_delivery_date) AS delayed_shipments
FROM orders GROUP BY warehouse_id;

-- Task 4.3 Use CTEs to find bottleneck warehouses where processing time > global average.
WITH avg_processing AS
 (SELECT AVG(processing_time_min) AS global_avg FROM warehouses)
SELECT warehouse_id,location,processing_time_min
FROM warehouses, avg_processing WHERE processing_time_min > global_avg;

-- Task 4.4 Rank warehouses based on on-time delivery percentage.
SELECT warehouse_id,
AVG(actual_delivery_date <= expected_delivery_date) * 100 AS on_time_percentage,
RANK() OVER(
ORDER BY AVG(actual_delivery_date <= expected_delivery_date) DESC
) AS warehouse_rank
FROM orders
GROUP BY warehouse_id;

-- Task 5: Delivery Agent Performance
-- Task 5.1 Rank agents (per route) by on-time delivery percentage
SELECT agent_id,route_id,on_time_percentage,
RANK() OVER(
PARTITION BY route_id
ORDER BY on_time_percentage DESC
) AS agent_rank
FROM delivery_agents;

-- Task 5.2 Find agents with on-time % < 80%.
SELECT agent_id, route_id, on_time_percentage FROM delivery_agents WHERE on_time_percentage < 80;

-- Task 5.3 Compare average speed of top 5 vs bottom 5 agents using subqueries.
SELECT (SELECT AVG(avg_speed_km_hr)
 FROM (SELECT avg_speed_km_hr FROM delivery_agents
  ORDER BY avg_speed_km_hr DESC
  LIMIT 5) AS top_agents) AS avg_top_speed,
(SELECT AVG(avg_speed_km_hr)
 FROM (SELECT avg_speed_km_hr
  FROM delivery_agents
  ORDER BY avg_speed_km_hr ASC
  LIMIT 5) AS bottom_agents) AS avg_bottom_speed;
  
 -- Task 6: Shipment Tracking Analytics (15 Marks)
-- Task 6.1 For each order, list the last checkpoint and time.
SELECT 
order_id,
MAX(checkpoint_time) AS last_checkpoint_time
FROM shipment_tracking
GROUP BY order_id;

-- Task 6.2 Find the most common delay reasons (excluding None).
SELECT 
delay_reason,
COUNT(*) AS delay_count
FROM shipment_tracking
WHERE delay_reason <> 'None'
GROUP BY delay_reason
ORDER BY delay_count DESC;

-- Task 6.3 Identify orders with >2 delayed checkpoints
SELECT 
order_id,
COUNT(*) AS delayed_checkpoints
FROM shipment_tracking
WHERE delay_reason <> 'None'
GROUP BY order_id
HAVING COUNT(*) > 2;

-- Task 7: Advanced KPI Reporting (10 Marks)
-- Task 7.1 Average Delivery Delay per Region (Start_Location).
SELECT 
r.start_location,
AVG(DATEDIFF(o.actual_delivery_date, o.expected_delivery_date)) 
AS avg_delivery_delay_days
FROM orders o
JOIN routes r
ON o.route_id = r.route_id
GROUP BY r.start_location;
-- Certain regions experience higher delivery delays compared to others,which may indicate route congestion or operational challenges.

-- Task 7.2 On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100.
SELECT 
COUNT(*) AS total_deliveries,
SUM(actual_delivery_date <= expected_delivery_date) 
AS on_time_deliveries,
(SUM(actual_delivery_date <= expected_delivery_date) 
/ COUNT(*)) * 100 AS on_time_delivery_percentage
FROM orders;

-- Task 7.3 Average Traffic Delay per Route.
SELECT 
route_id,
AVG(traffic_delay_min) AS avg_traffic_delay
FROM routes
GROUP BY route_id;
