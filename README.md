# Retail-Store-Engagement-Analysis
This project analyses retail transaction data for a UK supermarket chain to compare regional sales performance and customer behaviour. The goal is to identify the store with the strongest growth potential to support a targeted marketing investment.
Caveat: Due to limited historical and marketing data, the analysis relies exclusively on transactional sales data. The goal is not to select the highest-revenue store, but to identify the region with the greatest potential for incremental growth based on customer behaviour and performance trends.

## Project Objectives
- Compare sales and customer performance across regions and stores
- Analyse customer behaviour, loyalty, and retention trends
- Identify regional growth opportunities beyond current store size
- Develop and justify relevant KPIs using SQL
- Provide insights through clear dashboards and analysis

## Dataset Overview
- Transaction-level retail data
- Time period: July 2020 – March 2022
- Birmingham store data available from October 2020
- Tables used:
        receipts
        receipt_lines
        products

## Data Cleaning & Preparation
Issues Identified
- Garbage receipt IDs with invalid transaction values (9999999)
- Missing regional information
- Inconsistent store-level segmentation
Cleaning Actions
- Removed invalid receipt records
- Created regional mapping table
- Standardized time dimensions (month, quarter, year)

## Feature Engineering
- Region classification from store codes
- Quarterly and monthly time buckets
- Customer lifecycle metrics:
      New customers
      Active customers
      Loyal customers
- Cohort assignment based on first purchase quarter

## Key KPIs
- Annual revenue & transactions
- Sales per customer
- Sales per transaction
- Quarterly growth
- New vs loyal customers
- Cohort retention
- Top-performing departments

## Tableau Dashboards

The following dashboards were built:
- Annual Revenue & Transactions
- Top Performing Departments
- Regional Sales Trends
- Customer Acquisition & Loyalty
- Quarterly Retention Heatmap
Each KPI directly feeds into a business insight.

## Key Insights
- London generates the highest revenue and transaction volume
- Customer spend per transaction is highest in London
- New customer acquisition declined across all stores
- Birmingham shows the strongest retention rate
- Nottingham shows weaker long-term customer value

## Recommendation
While London delivers the highest current performance, Birmingham presents the strongest opportunity for marketing investment due to higher retention and greater potential for customer growth.

## Tools Used
- SQL (analytics & transformations)
- Tableau (visualizations)
