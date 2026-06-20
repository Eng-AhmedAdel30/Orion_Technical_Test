CREATE DATABASE Orion_Solutions;
GO

USE Orion_Solutions;
GO

-- ==================================================
-- stg schema  (raw)

CREATE SCHEMA stg;
GO

CREATE TABLE stg.Products (
    ProductKey      INT             NOT NULL unique,
    ProductName     NVARCHAR(255)   NULL,
    Brand           NVARCHAR(100)   NULL,
    Color           NVARCHAR(100)   NULL,
    Subcategory     NVARCHAR(100)   NULL,
    Category        NVARCHAR(100)   NULL
);

CREATE TABLE stg.Customers (
    CustomerKey     INT             NOT NULL unique,
    CustomerCode    NVARCHAR(50)    NULL,
    Continent       NVARCHAR(50)    NULL,
    City            NVARCHAR(100)   NULL,
    State           NVARCHAR(100)   NULL,
    CountryRegion   NVARCHAR(100)   NULL
);

CREATE TABLE stg.Forecast (
    CountryRegion   NVARCHAR(100)   NULL,
    Brand           NVARCHAR(100)   NULL,
    Forecast        DECIMAL(18,2)   NULL,
    [Year]          INT             NULL
);

CREATE TABLE stg.Sales (
    ProductKey      INT             NOT NULL,
    CustomerKey     INT             NOT NULL,
    OrderDate       DATE            NULL,
    Quantity        INT             NULL,
    NetPrice        DECIMAL(18,4)   NULL,
    TotalAmount     DECIMAL(18,4)   NULL
);
GO

-- ==================================================
-- dw schema — star schema: dimensions & facts

CREATE SCHEMA dw;
GO

CREATE TABLE dw.Dim_Date (
    DateKey         INT             NOT NULL PRIMARY KEY,   -- ex: 20080101
    [Date]          DATE            NOT NULL,
    [Day]           TINYINT         NOT NULL,
    DayName         NVARCHAR(10)    NOT NULL,
    WeekOfYear      TINYINT         NOT NULL,
    [Month]         TINYINT         NOT NULL,
    MonthName       NVARCHAR(10)    NOT NULL,
    MonthYear       NVARCHAR(8)     NOT NULL,
    Quarter         TINYINT         NOT NULL,
    QuarterName     NVARCHAR(2)     NOT NULL,
    [Year]          SMALLINT        NOT NULL,
    IsWeekend       BIT             NOT NULL,
    FirstDayOfMonth DATE            NOT NULL,
    LastDayOfMonth  DATE            NOT NULL
);

CREATE TABLE dw.Dim_Products (
    Prod_SK         INT             IDENTITY(1,1) PRIMARY KEY,
    ProductKey      INT             NOT NULL UNIQUE,
    ProductName     NVARCHAR(255)   NULL,
    Brand           NVARCHAR(100)   NULL,
    Color           NVARCHAR(100)   NULL,
    Subcategory     NVARCHAR(100)   NULL,
    Category        NVARCHAR(100)   NULL
);

CREATE TABLE dw.Dim_Customers (
    Cust_SK         INT             IDENTITY(1,1) PRIMARY KEY,
    CustomerKey     INT             NOT NULL UNIQUE,
    CustomerCode    NVARCHAR(50)    NULL,
    Continent       NVARCHAR(50)    NULL,
    City            NVARCHAR(100)   NULL,
    State           NVARCHAR(100)   NULL,
    CountryRegion   NVARCHAR(100)   NULL
);
GO

-- Fact_Sales:

CREATE TABLE dw.Fact_Sales (
    Sales_SK        INT             IDENTITY(1,1) PRIMARY KEY,
    ProductKey      INT             NOT NULL,
    CustomerKey     INT             NOT NULL,
    DateKey         INT             NOT NULL,
    Quantity        INT             NULL,
    NetPrice        DECIMAL(18,4)   NULL,
    TotalAmount     DECIMAL(18,4)   NULL,
    CONSTRAINT FK_Sales_Date     FOREIGN KEY (DateKey)     REFERENCES dw.Dim_Date(DateKey),
    CONSTRAINT FK_Sales_Product  FOREIGN KEY (ProductKey)  REFERENCES dw.Dim_Products(ProductKey),
    CONSTRAINT FK_Sales_Customer FOREIGN KEY (CustomerKey) REFERENCES dw.Dim_Customers(CustomerKey)
);
GO

-- Fact_Forecast: Grain is ( Country x Brand x Year )

CREATE TABLE dw.Fact_Forecast (
    Forecast_SK     INT             IDENTITY(1,1) PRIMARY KEY,
    CountryRegion   NVARCHAR(100)   NULL,
    Brand           NVARCHAR(100)   NULL,
    Forecast        DECIMAL(18,2)   NULL,
    [Year]          INT             NULL
);
