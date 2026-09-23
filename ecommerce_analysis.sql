-- ============================================================================
-- E-COMMERCE DATABASE ANALYSIS
-- ============================================================================

-- 1. CREATE DATABASE AND SWITCH TO IT
-- ============================================================================
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;


-- 2. CREATE TABLES WITH PROPER SCHEMA
-- ============================================================================

-- Customers Table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    country VARCHAR(50),
    registration_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products Table
CREATE TABLE Products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders Table
CREATE TABLE Orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    order_date DATE NOT NULL,
    quantity INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE RESTRICT
);

-- Create indexes for performance
CREATE INDEX idx_customer_id ON Orders(customer_id);
CREATE INDEX idx_product_id ON Orders(product_id);
CREATE INDEX idx_order_date ON Orders(order_date);


-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample customers
INSERT INTO Customers (customer_name, email, country, registration_date) VALUES
('John Smith', 'john.smith@email.com', 'USA', '2023-01-15'),
('Sarah Johnson', 'sarah.j@email.com', 'UK', '2023-02-20'),
('Maria Garcia', 'maria.garcia@email.com', 'Spain', '2023-03-10'),
('David Chen', 'david.chen@email.com', 'Canada', '2023-04-05'),
('Emma Wilson', 'emma.wilson@email.com', 'Australia', '2023-05-12'),
('James Brown', 'james.brown@email.com', 'USA', '2023-06-01'),
('Lisa Anderson', 'lisa.anderson@email.com', 'USA', '2024-01-15'),
('Michael Davis', 'michael.d@email.com', 'UK', '2024-02-10');

-- Insert sample products
INSERT INTO Products (product_name, category, price, stock_quantity) VALUES
('Laptop Pro', 'Electronics', 1299.99, 50),
('Wireless Mouse', 'Electronics', 29.99, 200),
('USB-C Cable', 'Accessories', 12.99, 500),
('Monitor 4K', 'Electronics', 399.99, 30),
('Keyboard Mechanical', 'Accessories', 89.99, 100),
('Webcam HD', 'Electronics', 59.99, 75),
('Phone Stand', 'Accessories', 19.99, 150),
('Desk Lamp LED', 'Accessories', 39.99, 120);

-- Insert sample orders
INSERT INTO Orders (customer_id, product_id, order_date, quantity, total_amount) VALUES
(1, 1, '2024-01-10', 1, 1299.99),
(1, 2, '2024-02-15', 2, 59.98),
(2, 4, '2024-01-20', 1, 399.99),
(2, 5, '2024-03-05', 1, 89.99),
(3, 1, '2024-02-01', 1, 1299.99),
(3, 6, '2024-04-10', 2, 119.98),
(4, 3, '2024-01-15', 5, 64.95),
(4, 5, '2024-02-28', 1, 89.99),
(5, 2, '2024-03-12', 3, 89.97),
(5, 7, '2024-04-08', 2, 39.98),
(6, 1, '2024-01-05', 1, 1299.99),
(6, 4, '2024-02-10', 1, 399.99),
(6, 6, '2024-03-22', 1, 59.99),
(7, 2, '2023-12-20', 1, 29.99),
(8, 5, '2023-10-15', 1, 89.99);


-- ============================================================================
-- 3. TOTAL REVENUE, TOTAL ORDERS, AND AVERAGE ORDER VALUE (AOV)
-- ============================================================================

SELECT
    COUNT(DISTINCT order_id) AS Total_Orders,
    SUM(total_amount) AS Total_Revenue,
    ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2) AS Average_Order_Value_AOV,
    ROUND(AVG(total_amount), 2) AS Avg_Amount_Per_Row
FROM Orders;


-- ============================================================================
-- 4. CUSTOMER CHURN DETECTION (DATEDIFF - Last Order > 90 days)
-- ============================================================================

SELECT
    c.customer_id,
    c.customer_name,
    c.email,
    MAX(o.order_date) AS Last_Order_Date,
    DATEDIFF(CURDATE(), MAX(o.order_date)) AS Days_Since_Last_Order,
    CASE
        WHEN DATEDIFF(CURDATE(), MAX(o.order_date)) > 90 THEN 'Churned'
        WHEN DATEDIFF(CURDATE(), MAX(o.order_date)) > 30 THEN 'At Risk'
        ELSE 'Active'
    END AS Customer_Status
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name, c.email
ORDER BY Days_Since_Last_Order DESC;


-- ============================================================================
-- 5. TOP 5% SPENDING CUSTOMERS (CTE + DENSE_RANK)
-- ============================================================================

WITH customer_spending AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.email,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_spent,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value
    FROM Customers c
    LEFT JOIN Orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_name, c.email
),
customer_rank AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY total_spent DESC) AS spending_rank,
        ROUND(100 * DENSE_RANK() OVER (ORDER BY total_spent DESC) / 
            COUNT(*) OVER (), 2) AS percentile
    FROM customer_spending
)
SELECT
    customer_id,
    customer_name,
    email,
    total_orders,
    total_spent,
    avg_order_value,
    spending_rank,
    'Top 5%' AS segment
FROM customer_rank
WHERE percentile <= 5
ORDER BY total_spent DESC;


-- ============================================================================
-- 6. MONTH-OVER-MONTH (MoM) REVENUE GROWTH (CTE + LAG Window Function)
-- ============================================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC(order_date, MONTH) AS revenue_month,
        DATE_FORMAT(order_date, '%Y-%m') AS month_year,
        SUM(total_amount) AS monthly_revenue
    FROM Orders
    GROUP BY DATE_TRUNC(order_date, MONTH), DATE_FORMAT(order_date, '%Y-%m')
),
revenue_with_lag AS (
    SELECT
        revenue_month,
        month_year,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS previous_month_revenue,
        LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS prev_month_rev
    FROM monthly_revenue
)
SELECT
    month_year,
    monthly_revenue,
    previous_month_revenue,
    CASE
        WHEN previous_month_revenue IS NULL THEN NULL
        ELSE ROUND(
            ((monthly_revenue - previous_month_revenue) / previous_month_revenue) * 100,
            2
        )
    END AS MoM_Growth_Percentage,
    CASE
        WHEN previous_month_revenue IS NULL THEN 'First Month'
        WHEN ((monthly_revenue - previous_month_revenue) / previous_month_revenue) > 0 THEN 'Growth'
        ELSE 'Decline'
    END AS trend
FROM revenue_with_lag
ORDER BY revenue_month;


-- ============================================================================
-- 7. VERIFY TABLE ROW COUNTS
-- ============================================================================

SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders;


-- ============================================================================
-- 8. FIRST 10 ORDERS WITH CUSTOMER NAMES AND ORDER VALUES
-- ============================================================================

SELECT
    o.order_id,
    o.order_date,
    c.customer_id,
    c.customer_name,
    o.product_id,
    o.quantity,
    o.total_amount AS total_order_value
FROM Orders o
INNER JOIN Customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date, o.order_id
LIMIT 10;


-- ============================================================================
-- 9. POWER BI CONSOLIDATED CUSTOMER, ORDER, AND CHURN VIEW
-- ============================================================================

CREATE OR REPLACE VIEW vw_ecommerce_powerbi AS
WITH customer_last_order AS (
    SELECT
        c.customer_id,
        MAX(o.order_date) AS last_order_date
    FROM Customers c
    LEFT JOIN Orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    c.customer_id,
    c.customer_name,
    c.email,
    c.country,
    c.registration_date,
    o.order_id,
    o.order_date,
    o.product_id,
    o.quantity,
    o.total_amount AS order_total_value,
    clo.last_order_date,
    DATEDIFF(CURDATE(), clo.last_order_date) AS days_since_last_order,
    CASE
        WHEN clo.last_order_date IS NULL THEN 'Churned'
        WHEN DATEDIFF(CURDATE(), clo.last_order_date) > 90 THEN 'Churned'
        WHEN DATEDIFF(CURDATE(), clo.last_order_date) > 30 THEN 'At Risk'
        ELSE 'Active'
    END AS churn_status
FROM Customers c
LEFT JOIN Orders o ON o.customer_id = c.customer_id
INNER JOIN customer_last_order clo ON clo.customer_id = c.customer_id;

-- Preview the consolidated Power BI dataset
SELECT *
FROM vw_ecommerce_powerbi;
