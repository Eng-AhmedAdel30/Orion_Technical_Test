-- ========================================================
-- Insert  Data into  stg_Schema:
-- ========================================================

BULK INSERT stg.Products
FROM 'E:\.Eng_Ahmed\Data Engineer\Orion\Outputs\Products.csv'
WITH (
    FIRSTROW = 2,             
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
    );

BULK INSERT stg.Customers
FROM 'E:\.Eng_Ahmed\Data Engineer\Orion\Outputs\Customers.csv'
WITH (
    FIRSTROW = 2,             
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
    );

BULK INSERT stg.Sales
FROM 'E:\.Eng_Ahmed\Data Engineer\Orion\Outputs\Sales.csv'
WITH (
    FIRSTROW = 2,             
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
    );

BULK INSERT stg.Forecast
FROM 'E:\.Eng_Ahmed\Data Engineer\Orion\Outputs\Forecast.csv'
WITH (
    FIRSTROW = 2,             
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
    );


-- ========================================================
-- Loading stg → dw:
-- ========================================================

-- 1. Dim_Date — populate independently (not derived from stg

DECLARE @MinDate DATE, @MaxDate DATE;
DECLARE @StartDate DATE, @EndDate DATE;

-- Pull the actual range straight from staged Sales data
SELECT
    @MinDate = MIN(OrderDate),
    @MaxDate = MAX(OrderDate)
FROM stg.Sales
WHERE OrderDate IS NOT NULL;

SET @StartDate = DATEFROMPARTS(YEAR(@MinDate) , 1, 1);
SET @EndDate   = DATEFROMPARTS(YEAR(@MaxDate) , 12, 31);

WITH My_calendar AS (
    SELECT @StartDate AS [Date]
    UNION ALL
    SELECT DATEADD(DAY, 1, [Date])
    FROM My_calendar
    WHERE [Date] < @EndDate
)
INSERT INTO dw.Dim_Date (
    DateKey, [Date], [Day], DayName, WeekOfYear, [Month], MonthName,
    MonthYear, Quarter, QuarterName, [Year], IsWeekend, FirstDayOfMonth, LastDayOfMonth
)
SELECT
    CONVERT(INT, FORMAT([Date], 'yyyyMMdd'))                       AS DateKey,
    [Date],
    DAY([Date])                                                    AS [Day],
    DATENAME(WEEKDAY, [Date])                                       AS DayName,
    DATEPART(WEEK, [Date])                                          AS WeekOfYear,
    MONTH([Date])                                                   AS [Month],
    DATENAME(MONTH, [Date])                                         AS MonthName,
    FORMAT([Date], 'MMM yyyy')                                      AS MonthYear,
    DATEPART(QUARTER, [Date])                                       AS Quarter,
    'Q' + CAST(DATEPART(QUARTER, [Date]) AS NVARCHAR(1))            AS QuarterName,
    YEAR([Date])                                                    AS [Year],
    CASE WHEN DATEPART(WEEKDAY, [Date]) IN (1,7) THEN 1 ELSE 0 END  AS IsWeekend,
    DATEFROMPARTS(YEAR([Date]), MONTH([Date]), 1)                   AS FirstDayOfMonth,
    EOMONTH([Date])                                                 AS LastDayOfMonth
FROM My_calendar

-- 2. Dim_Products — from stg.Products

INSERT INTO dw.Dim_Products (ProductKey, ProductName, Brand, Color, Subcategory, Category)
SELECT ProductKey, ProductName, Brand, Color, Subcategory, Category
FROM stg.Products;

-- 3. Dim_Customers — from stg.Customers

INSERT INTO dw.Dim_Customers (CustomerKey, CustomerCode, Continent, City, State, CountryRegion)
SELECT CustomerKey, CustomerCode, Continent, City, State, CountryRegion
FROM stg.Customers;

-- 4. Fact_Forecast — from stg.Forecast (no FK dependency, can run anytime after stg load)

INSERT INTO dw.Fact_Forecast (CountryRegion, Brand, Forecast, [Year])
SELECT CountryRegion, Brand, Forecast, [Year]
FROM stg.Forecast;

-- 5. Fact_Sales — from stg.Sales, computing DateKey from OrderDate

INSERT INTO dw.Fact_Sales (ProductKey, CustomerKey, DateKey, Quantity, NetPrice, TotalAmount)
SELECT
    ProductKey,
    CustomerKey,
    CONVERT(INT, FORMAT(OrderDate, 'yyyyMMdd')) AS DateKey,
    Quantity,
    NetPrice,
    TotalAmount
FROM stg.Sales;
GO
