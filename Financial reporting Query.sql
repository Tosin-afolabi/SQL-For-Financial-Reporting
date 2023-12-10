USE `financial_reporting_db_prod`;
/* ......................1. REVENUE REPORTING
			....................................................................... */
-- 1a Total Revenue by Year 
SELECT 
    YEAR(OrderDate) AS Year,
    ROUND(SUM(LineTotal),2) As Total_Revenue
FROM sales_orders
GROUP BY 
    YEAR(OrderDate);
    
-- b Revenue by Territory segmentation 
SELECT 
    regions.Territory,
    ROUND(SUM(sales_orders.LineTotal),2) As Total_Revenue
FROM sales_orders
INNER JOIN regions ON sales_orders.DeliveryRegionIndex = regions.RegionIndex
GROUP BY 
    regions.Territory;

-- c Revenues by Month and Channel 
SELECT
	YEAR(OrderDate) AS Year,
	MONTHNAME(OrderDate) AS Month,
    channel,
    ROUND(SUM(LineTotal),2) As Total_Revenue
FROM sales_orders
GROUP BY 
	YEAR(OrderDate),
	MONTHNAME(OrderDate),
    channel;

-- d. Revenue for 2017 vs Prior year 
SELECT 
	 CASE WHEN GROUPING(Channel) = 1 THEN 'Total' ELSE Channel END AS Channel,
	ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2018 THEN LineTotal ELSE 0 END),2) AS Revenue_2018,
	ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END),2) AS Revenue_2017,
    ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2018 THEN LineTotal ELSE 0 END) - SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END),2) AS RevenuePY_vs_LY
FROM sales_orders
GROUP BY channel WITH ROLLUP
ORDER BY GROUPING(channel) ASC, Channel ASC;

-- e. Percentage revenue change from previous year 
SELECT 
--     IFNULL(Channel, 'Total') AS Channel,
	CASE WHEN GROUPING(Channel) = 1 THEN 'Total' ELSE Channel END AS Channel,
    ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2018 THEN LineTotal ELSE 0 END), 2) AS Revenue_2018,
    ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END), 2) AS Revenue_2017,
    ROUND(SUM(CASE WHEN YEAR(OrderDate) = 2018 THEN LineTotal ELSE 0 END) -
          SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END), 2) AS RevenuePY_vs_LY,
    ROUND((CASE WHEN SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END) > 0 
                THEN (SUM(CASE WHEN YEAR(OrderDate) = 2018 THEN LineTotal ELSE 0 END) /
                     SUM(CASE WHEN YEAR(OrderDate) = 2017 THEN LineTotal ELSE 0 END) - 1)
                ELSE 0 END) * 100, 2) AS RevenuePY_vs_LY_Percent
FROM 
    sales_orders
GROUP BY 
    Channel WITH ROLLUP
ORDER BY 
    GROUPING(Channel) ASC, Channel ASC;

/* ----------------------------------2. Profitability
												Profit and Loss
			....................................................................... */
-- a. Total Cost of Sales by Year 
SELECT YEAR(ExpenseDate) AS Year, 
	ExpenseCategory,
    ROUND(SUM(ExpenseAmount),2) AS Total_Expenses
FROM company_expenses
WHERE ExpenseCategory = "COGS"
GROUP BY YEAR(ExpenseDate)  /*ExpenseCategory*/;

-- b. Total Gross Profit and Percentage change 
WITH COG_Sold AS (
    SELECT YEAR(ExpenseDate) AS Year, 
           ExpenseCategory,
           SUM(ExpenseAmount) AS Total_Expenses
    FROM company_expenses
    WHERE ExpenseCategory = 'COGS'
    GROUP BY YEAR(ExpenseDate)
)
SELECT COG_Sold.Year,
       COG_Sold.Total_Expenses,
       SUM(sales_orders.LineTotal) AS Rev,
       ROUND(SUM(sales_orders.LineTotal) - COG_Sold.Total_Expenses,2) AS Total_Gross_profit,
       CONCAT(ROUND(((SUM(sales_orders.LineTotal) - COG_Sold.Total_Expenses) / SUM(sales_orders.LineTotal))*100,2),'%') AS 'Gross_profit%'
       
FROM COG_Sold
INNER JOIN sales_orders
    ON YEAR(sales_orders.OrderDate) = COG_Sold.Year
GROUP BY COG_Sold.Year;

-- c Total Other Expenses 
SELECT ROUND(SUM(ExpenseAmount),2) AS Total_other_expenses,
	YEAR(ExpenseDate) AS Year
FROM company_expenses
WHERE ExpenseCategory <> 'COGS'
GROUP BY YEAR(ExpenseDate);

-- d Net Profit and Net Profit percentage change

-- Total revenue per year from sales table
WITH Yearly_Revenue AS (
    SELECT YEAR(OrderDate) AS Year, 
           SUM(LineTotal) AS Total_Revenue
    FROM sales_orders
    GROUP BY YEAR(OrderDate)
),
-- Total COGS per year from company_expenses
Yearly_COGS AS (
    SELECT YEAR(ExpenseDate) AS Year, 
           SUM(ExpenseAmount) AS Total_COGS
    FROM company_expenses
    WHERE ExpenseCategory = 'COGS'
    GROUP BY YEAR(ExpenseDate)
),
-- Total Other Expenses per year from company_expenses
Yearly_Other_Expenses AS (
    SELECT YEAR(ExpenseDate) AS Year, 
           SUM(ExpenseAmount) AS Total_Other_Expenses
    FROM company_expenses
    WHERE ExpenseCategory != 'COGS'
    GROUP BY YEAR(ExpenseDate)
)
-- Net Profit and Net profit percentage change per year

SELECT 
    YR.Year,
    YR.Total_Revenue,
    COALESCE(YC.Total_COGS, 0) AS Total_COGS,
    COALESCE(YOE.Total_Other_Expenses, 0) AS Total_Other_Expenses,
    (YR.Total_Revenue - COALESCE(YC.Total_COGS, 0)) AS Gross_Profit,
    (YR.Total_Revenue - COALESCE(YC.Total_COGS, 0) - COALESCE(YOE.Total_Other_Expenses, 0)) AS Net_Profit,
    LAG((YR.Total_Revenue - COALESCE(YC.Total_COGS, 0) - COALESCE(YOE.Total_Other_Expenses, 0))) OVER (ORDER BY YR.Year) AS Net_profit_LY, 
		/* Net profit % change */
    ROUND(
        (
            ((YR.Total_Revenue - COALESCE(YC.Total_COGS, 0) - COALESCE(YOE.Total_Other_Expenses, 0))
            - LAG((YR.Total_Revenue - COALESCE(YC.Total_COGS, 0) - COALESCE(YOE.Total_Other_Expenses, 0))) OVER (ORDER BY YR.Year))
            / NULLIF((YR.Total_Revenue - COALESCE(YC.Total_COGS, 0) - COALESCE(YOE.Total_Other_Expenses, 0)), 0)
        ) * 100,
        2
    ) AS Net_profit_Percentage_Change
FROM Yearly_Revenue YR
LEFT JOIN Yearly_COGS YC ON YR.Year = YC.Year
LEFT JOIN Yearly_Other_Expenses YOE ON YR.Year = YOE.Year;

/* ------------------------------------------------------3. Balance Sheet
																	 -----------------------------------------------------------*/
-- a Total current Assets for 2015, 2016, 2017, 2018
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Current_Asset
FROM balance_sheet_data
WHERE Category = 'Current Assets'
GROUP BY(BalancesheetYear);

-- b Total Fixed Asssets for 2015, 2016, 2017, 2018	
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Fixed_Asset
FROM balance_sheet_data
WHERE Category = 'Fixed (Long-Term) Assets'
GROUP BY(BalancesheetYear);	

-- c Other Asssets for 2015, 2016, 2017, 2018	
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Other_Asset
FROM balance_sheet_data
WHERE Category = 'Other Assets'
GROUP BY(BalancesheetYear);

-- d Total Assets for 2015, 2016, 2017, 2018
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Asset
FROM balance_sheet_data
WHERE BalanceSheetType = 'Assets'
GROUP BY(BalancesheetYear);

-- e Liability & Owner's Equity 
		-- Current Liabilities -- 
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Current_Liabilities
FROM balance_sheet_data
WHERE Category = 'Current Liabilities'
GROUP BY(BalancesheetYear);

-------- f Long Term Liabilities ---------
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_LongTerm_Liabilities
FROM balance_sheet_data
WHERE Category = 'Long-Term Liabilities'
GROUP BY(BalancesheetYear);

-------- g Total_Owner's Equity --------- 
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS "Total_Owner's Equity"
FROM balance_sheet_data
WHERE Category = "Owner's Equity"
GROUP BY(BalancesheetYear);

-----    h Total Liabilities and Owner's Equity -----------
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS "Total_Liabilities"
FROM balance_sheet_data
WHERE Category = "Owner's Equity" OR "Balance Sheet Type" = "Assets"
GROUP BY(BalancesheetYear);

-- ----------- 
							-- ALL BALANCE SHEET ITEMS -----------

WITH Current_Assets AS (
	SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Current_Asset
FROM balance_sheet_data
WHERE Category = 'Current Assets'
GROUP BY(BalancesheetYear)
),

Total_Assets AS (
	SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Asset
FROM balance_sheet_data
WHERE BalanceSheetType = 'Assets'
GROUP BY(BalancesheetYear)
),

Total_Current_Liabilities AS (
SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_Current_Liabilities
FROM balance_sheet_data
WHERE Category = 'Current Liabilities'
GROUP BY(BalancesheetYear)
),
Total_LongTerm_Liabilities AS (

SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS Total_LongTerm_Liabilities
FROM balance_sheet_data
WHERE Category = 'Long-Term Liabilities'
GROUP BY(BalancesheetYear)
), 

Total_Owners_Equity AS (

SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS "Total_Owner's Equity"
FROM balance_sheet_data
WHERE Category = "Owner's Equity"
GROUP BY(BalancesheetYear)
),
Total_Liabilities AS (

SELECT 
	BalanceSheetYear AS Year,
    ROUND(SUM(BalanceSheetAmount),0) AS "Total_Liabilities"
FROM balance_sheet_data
WHERE Category = "Owner's Equity" OR "Balance Sheet Type" = "Assets"
GROUP BY(BalancesheetYear)
)
SELECT *
FROM Current_Assets 
LEFT JOIN Total_Assets ON Total_Assets.Year = Current_Assets.Year
LEFT JOIN Total_Current_Liabilities ON Current_Assets.Year = Total_Current_Liabilities.Year
LEFT JOIN Total_LongTerm_Liabilities ON Total_LongTerm_Liabilities.Year = Current_Assets.Year
LEFT JOIN Total_Owners_Equity ON Total_Owners_Equity.Year = Current_Assets.Year
LEFT JOIN Total_Liabilities ON Total_Liabilities.Year = Current_Assets.Year;


/* --------------------------- CASH FLOW ANALYSIS 
															------------------ */
-- a. Cash Flows for Operating Activities
-- Cashflow for Operations
SELECT CashFlowYear,
       -- Cash receipts from customers
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from' AND CashFlowSubCategory = 'Cash receipts from customers' THEN CashFlowValue ELSE 0 END) AS CashReceiptsFromCustomers,
       -- Cash paid for Operating activities
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for' THEN CashFlowValue ELSE 0 END) AS CashPaidForOperatingActivities,
       -- Net Cash flow from operations
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from' AND CashFlowSubCategory = 'Cash receipts from customers' THEN CashFlowValue ELSE 0 END) -
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for' AND CashFlowSubCategory = 'Operating activities' THEN CashFlowValue ELSE 0 END) AS NetCashFlowFromOperations
FROM cash_flow_data
WHERE CashFlowType = 'Operations'
GROUP BY CashFlowYear;

-- Cashflow for Investing Activities
SELECT CashFlowYear,
       -- Cash receipts from Investing Activities
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from' THEN CashFlowValue ELSE 0 END) AS CashReceiptsFromInvestingActivities,
       -- Cash paid for Investing activities
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for' THEN CashFlowValue ELSE 0 END) AS CashPaidForInvestingActivities,
       -- Net Cash flow from Investing activities
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from' THEN CashFlowValue ELSE 0 END) +
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for' THEN CashFlowValue ELSE 0 END) AS NetCashFlowFromInvestingActivities
FROM cash_flow_data
WHERE CashFlowType = 'Investing Activities'
GROUP BY CashFlowYear;

-- Cashflow for Financing Activities
SELECT CashFlowYear,
       -- Cash receipts from Financing Activities
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from' THEN CashFlowValue ELSE 0 END) AS CashReceiptsFromFinancingActivities,
       -- Cash paid for Financing activities
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for'  THEN CashFlowValue ELSE 0 END) AS CashPaidForFinancingActivities,
       -- Net Cash flow from Financing activities
       SUM(CASE WHEN CashFlowCategory = 'Cash receipts from'  THEN CashFlowValue ELSE 0 END) +
       SUM(CASE WHEN CashFlowCategory = 'Cash paid for' THEN CashFlowValue ELSE 0 END) AS NetCashFlowFromFinancingActivities
FROM cash_flow_data
WHERE CashFlowType = 'Financing Activities'
GROUP BY CashFlowYear;
