/* ============================================================
   FoodCorp Marketing Analytics
   End-to-end SQL analysis pipeline

   Purpose:
   - Clean transactional data
   - Create regional mapping
   - Generate core KPIs
   ============================================================ */

/* ============================================================
   DATA CLEANING
   Remove invalid / garbage receipts
   ============================================================ */

DELETE FROM receipt_lines
WHERE receipt_id IN (3708, 75144, 68424);

DELETE FROM receipts
WHERE receipt_id IN (3708, 75144, 68424);


/* ============================================================
   REGION MAPPING
   ============================================================ */

CREATE TABLE IF NOT EXISTS receipts_r AS
SELECT * FROM receipts;

ALTER TABLE receipts_r
ADD COLUMN region STRING;

UPDATE receipts_r
SET region =
    CASE
        WHEN store_code = 0 THEN 'Nottingham'
        WHEN store_code = 1 THEN 'Birmingham'
        WHEN store_code > 1 THEN 'London'
    END;


/* ============================================================
   1.	GENERAL PERFORMANCE STATISTICS
   ============================================================ */

/* KPI: Annual revenue and transactions per store
   KPI formula: sum(sale values) and count( unique receipts), per year, per store  */

SELECT
    store_code,
    EXTRACT(YEAR FROM purchased_at) AS year,
    SUM(value) AS total_sales,
    COUNT(DISTINCT receipt_id) AS total_transactions
FROM receipts
JOIN receipt_lines USING (receipt_id)
GROUP BY 1,2
ORDER BY 1,2;


/* KPI : Top selling departments per store
  KPI formula:
  1.	Total sales per department per store
  2.	Rank the department by sales and store as department_rank
  3.	Limit the display to top 5 departments per store */

SELECT
    store_code,
    department_code,
    department_name,
    total_sales
FROM (
    SELECT
        store_code,
        department_code,
        department_name,
        sum(value)AS total_sales,
        ROW_NUMBER() OVER (PARTITION BY store_code ORDER BY SUM(value) DESC) AS department_rank
    FROM receipts
    JOIN receipt_lines USING (receipt_id)
    JOIN products USING (product_code)
    GROUP BY 1,2,3
  )  
WHERE department_rank <= 5
ORDER BY 1, department_rank;


/* ============================================================
   2. SALES PERFORMANCE METRICS
   ============================================================ */

/* KPI: Regional Sales per customer (quarterly)
   KPI formula: sum(sale value)/count(unique customer) as mean sale, group by quarter and region */

SELECT
    region,
    DATE_FORMAT(DATE_TRUNC('quarter', purchased_at), 'yyyy-MM') AS quarter,
    SUM(value) / COUNT(DISTINCT customer_id) AS sale_per_customer
FROM receipts_r
JOIN receipt_lines USING (receipt_id)
GROUP BY 1,2
ORDER BY 1,2;


/* KPI: Regional Sales per transaction (quarterly)
   KPI formula: sum(sale value)/count(unique receipt_id) as mean sale, group by quarter and region */

SELECT
    region,
    DATE_FORMAT(DATE_TRUNC('quarter', purchased_at), 'yyyy-MM') AS quarter,
    SUM(value) / COUNT(DISTINCT receipt_id) AS sale_per_transaction
FROM receipts_r
JOIN receipt_lines USING (receipt_id)
GROUP BY 1,2
ORDER BY 1,2;


/* KPI: Quarterly sales growth per region
  KPI formula: 
  •	Sum(value) per quarter per region
  •	Lag(sale) partition over region, order by quarter as previous quarter sale
  •	Percentage (Current – previous quarter sale)/previous , per quarter, per region */

WITH sales_data AS (
    SELECT
        region,
        DATE_FORMAT(DATE_TRUNC('quarter', purchased_at), 'yyyy-MM') AS quarter,
        SUM(value) AS total_sales
    FROM receipts_r
    JOIN receipt_lines USING (receipt_id)
    GROUP BY 1,2
)

SELECT
    region,
    quarter,
    total_sales,
    LAG(total_sales) OVER (PARTITION BY region ORDER BY quarter) AS previous_quarter_sales,
    CASE
        WHEN LAG(total_sales) OVER (PARTITION BY region ORDER BY quarter) IS NOT NULL
        THEN
            ((total_sales -
              LAG(total_sales) OVER (PARTITION BY region ORDER BY quarter))
              /
              LAG(total_sales) OVER (PARTITION BY region ORDER BY quarter)) * 100
    END AS quarterly_growth_pct
FROM sales_data
ORDER BY 1,2;


/* ============================================================
   3. CUSTOMER ENGAGEMENT METRICS
   ============================================================ */

/* KPI: customers per store 
   KPI formula: count(unique customer) per year per store */

SELECT store_code, 
  extract(YEAR from purchased_at) AS year,
  count(distinct customer_id) as customers
FROM receipts
GROUP BY 1,2
ORDER BY 1,2; 


/* KPI: New customers per month
  KPI formula: 
  1.	Calculate new customers per month per store - count(customer with min purchase date), per month per store
  2.	Calculate active customer per month per store
  3.	Percentage ((1)/(2))*100 */

WITH first_purchase AS (
    SELECT
        customer_id,
        store_code,
        DATE_FORMAT(DATE_TRUNC('month', MIN(purchased_at)), 'yyyy-MM') AS month
    FROM receipts
    GROUP BY 1,2
),
active_customers AS (
    SELECT
        store_code,
        DATE_FORMAT(DATE_TRUNC('month', purchased_at), 'yyyy-MM') AS month,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM receipts
    GROUP BY 1,2
)

SELECT
    f.store_code,
    f.month,
    COUNT(f.customer_id) * 100.0 / a.active_customers AS new_customer_pct
FROM first_purchase f
JOIN active_customers a
USING (store_code, month)
GROUP BY 1,2, a.active_customers
ORDER BY 1,2;

/* KPI: Percentage of loyal customers per month per store (A loyal customer is defined as someone who purchases on at least 5 distinct days in a month)
  KPI formula:
  1.	Calculate loyal customers per month per store – count(customer with distinct purchase date >=5), per month per store
  2.	Calculate active customer per month per store
  3.	Percentage ((1)/(2))*100 */

WITH loyal AS(
SELECT store_code, month, COUNT(*) as loyal_customers
FROM (
  SELECT customer_id, date_format(DATE_TRUNC('month',purchased_at), 'yyyy-MM') as month, store_code
  FROM receipts
  GROUP BY 1, 2, 3
  HAVING COUNT( DISTINCT purchased_at ) >= 5 
) x
GROUP BY 1, 2
),
 
active AS(
SELECT store_code, DATE_FORMAT(DATE_TRUNC('month',purchased_at),'yyyy-MM') AS month, COUNT( DISTINCT customer_id ) AS active_customers
FROM receipts
GROUP BY 1,2
)

SELECT store_code,month, loyal_customers*100/active_customers AS loyalty
FROM loyal
JOIN active
USING (store_code,month)

/* KPI: Quarterly Cohort Retention Analysis
  KPI formula:
  1)	Assign customers to cohorts. Cohort consists of group of customers which started making purchases from the same month.
  2)	Count the number of customer's active each in each subsequent period.
  3)	Convert the counts to percents
  4)	Count the number of users per cohort. Add column to table. */

WITH cohort_assignment AS (
    SELECT
        customer_id,
        region,
        DATE_FORMAT(DATE_TRUNC('quarter', MIN(purchased_at)), 'yyyy-MM') AS cohort
    FROM receipts_r
    GROUP BY 1,2
),

cohort_activity AS (
    SELECT
        c.cohort,
        r.region,
        MONTHS_BETWEEN(
            DATE_TRUNC('quarter', r.purchased_at),
            DATE_TRUNC('quarter', c.cohort)
        ) AS period,
        COUNT(DISTINCT r.customer_id) AS active_customers
    FROM receipts_r r
    JOIN cohort_assignment c
      ON r.customer_id = c.customer_id
     AND r.region = c.region
    GROUP BY 1,2,3
)

SELECT *
FROM cohort_activity
ORDER BY region, cohort, period;


/* ============================================================
   END OF ANALYSIS PIPELINE
   ============================================================ */
