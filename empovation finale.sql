select *
from [dbo].[Categories]
select *
from [dbo].[Customers]
select *
from [dbo].[Exchange_Rates]
select *
from [dbo].[Pproducts]
select *
from [dbo].[Products]
select *
from [dbo].[Sales]
select *
from [dbo].[Stores]

/*Year-over-Year Growth in Sales per Category
Write a query to calculate the total annual sales per product category for the current year and the previous year, and then use window functions to calculate the year-over-year growth percentage.*/
WITH yearly_sales AS (
    SELECT
        category,
        YEAR(s.Delivery_Date) AS sale_year,
        SUM(p.Unit_Price_USD) AS total_sales
    FROM
        Products p
		join Sales s on s.ProductKey = p.ProductKey
    GROUP BY
        category,
       YEAR(s.Delivery_Date)
),
sales_with_growth AS (
    SELECT
        category,
        sale_year,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY category ORDER BY sale_year) AS previous_year_sales
    FROM
        yearly_sales
)
SELECT
    category,
    sale_year,
    total_sales,
    previous_year_sales,
    CASE
        WHEN previous_year_sales IS NULL THEN NULL
        ELSE (total_sales - previous_year_sales) * 100.0 / previous_year_sales
    END AS yoy_growth_percentage
FROM
    sales_with_growth
ORDER BY
    category,
    sale_year;

/*Customer’s Purchase Rank Within Store
Write a SQL query to find each customer’s purchase rank within the store they bought from, based on the total price of the order (quantity * unit price).*/
WITH CustomerTotal AS (
    SELECT
       c.CustomerKey,
	   c.Name
        StoreKey,
        SUM(quantity * Unit_Price_USD) AS total_price
    FROM 
	[dbo].[Customers] c
       
	JOIN 
        [dbo].[Sales] s
		ON c.CustomerKey = s.CustomerKey
		JOIN 
		[dbo].[Products]P
		ON P.ProductKey = s.ProductKey
		
    GROUP BY
       c.CustomerKey,
	   c.Name,
        StoreKey
),
RankedCustomers AS (
    SELECT
        customerKey,
        storeKey,
        total_price,
        RANK() OVER (PARTITION BY storekey ORDER BY total_price DESC) AS purchase_rank
    FROM
        CustomerTotal
)
SELECT
    CustomerKey,
    StoreKey,
    total_price,
    purchase_rank
FROM
    RankedCustomers
ORDER BY
    StoreKey,
    purchase_rank;

/*Customer Retention Analysis
Perform a customer retention analysis to determine the percentage of customers who made repeat purchases within three months of their initial purchase. Calculate the percentage of retained customers by gender, age group, and location.

Hint: The output should include a table with the customer demographics such as gender, age, location and calculated total customer count, retained customer count and the retention rate, in your analysis.

Additionally, identify any trends or patterns in customer retention based on these demographics.*/


	WITH FirstPurchase AS (
    SELECT
        c.CustomerKey,
        MIN(s.order_date) AS first_purchase_date
    FROM
        Customers c
        JOIN Sales s ON c.CustomerKey = s.CustomerKey
    GROUP BY
        c.CustomerKey
),
RepeatPurchases AS (
    SELECT
        s.CustomerKey,
        f.first_purchase_date,
        s.order_date
    FROM
        Sales s
        JOIN FirstPurchase f ON s.CustomerKey = f.CustomerKey
    WHERE
        s.order_date > f.first_purchase_date
        AND s.order_date <= DATEADD(MONTH, 3, f.first_purchase_date)
),
CustomerDemographics AS (
    SELECT
        c.CustomerKey,
        c.gender,
        c.State,
        CASE
            
            WHEN Birthday BETWEEN 26 AND 35 THEN '26-35'
            WHEN Birthday BETWEEN 36 AND 45 THEN '36-45'
            WHEN Birthday BETWEEN 46 AND 55 THEN '46-55'
            ELSE '56+'
        END AS age_group
    FROM
        Customers c
),
RetentionStats AS (
    SELECT
        d.gender,
        d.age_group,
        d.State,
        COUNT(DISTINCT d.CustomerKey) AS total_customers,
        COUNT(DISTINCT r.CustomerKey) AS retained_customers
    FROM
        CustomerDemographics d
        LEFT JOIN RepeatPurchases r ON d.CustomerKey = r.CustomerKey
    GROUP BY
        d.gender,
        d.age_group,
        d.State
)
SELECT
    gender,
    age_group,
    State,
    total_customers,
    retained_customers,
    ROUND((retained_customers * 100.0) / total_customers, 2) AS retention_rate
FROM
    RetentionStats
ORDER BY
    gender,
    age_group,
    State;


	WITH FirstPurchase AS (
    SELECT
        c.CustomerKey,
        MIN(s.order_date) AS first_purchase_date
    FROM
        Customers c
        JOIN Sales s ON c.CustomerKey = s.CustomerKey
    GROUP BY
        c.CustomerKey
),
RepeatPurchases AS (
    SELECT
        s.CustomerKey,
        f.first_purchase_date,
        s.order_date
    FROM
        Sales s
        JOIN FirstPurchase f ON s.CustomerKey = f.CustomerKey
    WHERE
        s.order_date > f.first_purchase_date
        AND s.order_date <= DATEADD(MONTH, 3, f.first_purchase_date)
),
CustomerDemographics AS (
    SELECT
        c.CustomerKey,
        c.gender,
        c.State,
        CASE
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 36 AND 45 THEN '36-45'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 46 AND 55 THEN '46-55'
            ELSE '56+'
        END AS age_group
    FROM
        Customers c
),
RetentionStats AS (
    SELECT
        d.gender,
        d.age_group,
        d.State,
        COUNT(DISTINCT d.CustomerKey) AS total_customers,
        COUNT(DISTINCT r.CustomerKey) AS retained_customers
    FROM
        CustomerDemographics d
        LEFT JOIN RepeatPurchases r ON d.CustomerKey = r.CustomerKey
    GROUP BY
        d.gender,
        d.age_group,
        d.State
)
SELECT
    gender,
    age_group,
    State,
    total_customers,
    retained_customers,
    ROUND((retained_customers * 100.0) / total_customers, 2) AS retention_rate
FROM
    RetentionStats
ORDER BY
    gender,
    age_group,
    State;
	/*Optimize the product mix for each store location to maximize sales revenue.
Analyze historical sales data to identify the top-selling products in each product category for each store.  Determine the optimal product assortment for each store based on sales performance, product popularity, and profit margins.

Hint: The output should include a table with the store key, category, product assortment (separated by ‘,’) and the quantities sold.*/

WITH SalesData AS (
    SELECT
        s.StoreKey,
        p.Category,
        s.ProductKey,
        p.Product_Name,
        SUM(s.Quantity) AS TotalQuantitySold,
        SUM(s.Line_Item) AS TotalSalesRevenue,
        AVG(p.Unit_Price_USD - p.Unit_Cost_USD) AS AverageProfitMargin
    FROM
        Sales s
        JOIN Products p ON s.ProductKey = p.ProductKey
    GROUP BY
        s.StoreKey,
        p.Category,
        s.ProductKey,
        p.Product_Name
),
TopProducts AS (
    SELECT
        StoreKey,
        Category,
        ProductKey,
        Product_Name,
        TotalQuantitySold,
        TotalSalesRevenue,
        AverageProfitMargin,
        RANK() OVER (PARTITION BY StoreKey, Category ORDER BY TotalQuantitySold DESC) AS ProductRank
    FROM
        SalesData
),
OptimalProductAssortment AS (
    SELECT
        StoreKey,
        Category,
        STRING_AGG(Product_Name, ', ') WITHIN GROUP (ORDER BY ProductRank) AS ProductAssortment,
        SUM(TotalQuantitySold) AS TotalQuantitySold
    FROM
        TopProducts
    WHERE
        ProductRank <= 10 -- Adjust this number based on the desired number of top products
    GROUP BY
        StoreKey,
        Category
)
SELECT
    StoreKey,
    Category,
    ProductAssortment,
    TotalQuantitySold
FROM
    OptimalProductAssortment
ORDER BY
    StoreKey,
    Category;

	WITH FirstPurchase AS (
    SELECT 
        c.CustomerKey, 
        MIN(s.order_date) AS FirstPurchaseDate
    FROM 
        Customers c
        JOIN Sales s ON c.CustomerKey = s.CustomerKey
    GROUP BY 
        c.CustomerKey
),
RepeatPurchases AS (
    SELECT 
        s.CustomerKey, 
        f.FirstPurchaseDate, 
        s.order_date
    FROM 
        Sales s
        JOIN FirstPurchase f ON s.CustomerKey = f.CustomerKey
    WHERE 
        s.order_date > f.FirstPurchaseDate
        AND s.order_date <= DATEADD(MONTH, 3, f.FirstPurchaseDate)
),
CustomerDemographics AS (
    SELECT 
        c.CustomerKey, 
        c.Gender, 
        CASE 
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 36 AND 45 THEN '36-45'
            WHEN DATEDIFF(YEAR, c.Birthday, GETDATE()) BETWEEN 46 AND 55 THEN '46-55'
            ELSE '56+'
        END AS AgeGroup
    FROM 
        Customers c
),
RetentionStats AS (
    SELECT 
        d.Gender, 
        d.AgeGroup, 
        COUNT(DISTINCT d.CustomerKey) AS TotalCustomers, 
        COUNT(DISTINCT r.CustomerKey) AS RetainedCustomers
    FROM 
        CustomerDemographics d
        LEFT JOIN RepeatPurchases r ON d.CustomerKey = r.CustomerKey
    GROUP BY 
        d.Gender, 
        d.AgeGroup
)
SELECT 
    Gender, 
    AgeGroup, 
    TotalCustomers, 
    RetainedCustomers, 
    ROUND((RetainedCustomers * 100.0) / TotalCustomers, 2) AS RetentionRate
FROM 
    RetentionStats
ORDER BY 
    Gender, 
    AgeGroup;