/*
DATA CLEANING PROJECT – WORLD LAYOFFS DATASET

This script documents the step-by-step cleaning process I applied to the World Layoffs dataset
The dataset is from kaggle: https://www.kaggle.com/datasets/swaptr/layoffs-2022
The final cleaned table is generated as "clean_layoffs"

Author: Biel Caballol Prat
*/ 

-- As a first step, I create a staging table where I am going to be manipulating the data to avoid any error risk
DROP TABLE IF EXISTS staging_layoffs;
CREATE TABLE staging_layoffs LIKE world_layoffs.layoffs;
INSERT INTO world_layoffs.staging_layoffs 
SELECT * 
FROM world_layoffs.layoffs;

-- With the following CTE, I am able to identify duplicates, which I am going to delete on the next step
WITH duplicates AS
(
    SELECT *, ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) row_num
	FROM world_layoffs.staging_layoffs
)
SELECT *
FROM duplicates
WHERE row_num != 1;

-- After identifying duplicates I like to double check, not necessary, just making sure
SELECT * FROM world_layoffs.staging_layoffs WHERE company = "Cazoo";

-- I am currently using MySQL Workbench and cannot use DELETE from a CTE, so I chose to create a second staging table with a `row_num` column so i can delete the duplicates
CREATE TABLE `staging2_layoffs` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO world_layoffs.staging2_layoffs
SELECT *, ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) row_num
FROM world_layoffs.staging_layoffs;

-- After the new staging table is created and populated, I can safely delete all the duplicates, making sure first what we are going to delete
SELECT *
FROM world_layoffs.staging2_layoffs;

DELETE
FROM world_layoffs.staging2_layoffs
WHERE row_num != 1;

-- My next step is going to standarize the data, I will first use TRIM() to cut any blank spaces at the start or end of any column
UPDATE world_layoffs.staging2_layoffs
SET company = TRIM(company), location = TRIM(location), industry = TRIM(industry), stage = TRIM(stage), country = TRIM(country);

-- After, I checked all rows looking for misspelled values or duplicate values with different spelling, and found out that in the "industry" row, "Crypto" is also written as "CryptoCurrency" and "Crypto Currency", so I just changed it all to "Crypto"
SELECT DISTINCT industry
FROM world_layoffs.staging2_layoffs
ORDER BY 1;

UPDATE world_layoffs.staging2_layoffs
SET industry = "Crypto"
WHERE industry LIKE "Crypto%";

-- I also found that on the "country" row, there were two United States, one ending with a "." so I just changed it
SELECT DISTINCT country
FROM world_layoffs.staging2_layoffs
ORDER BY 1;

UPDATE world_layoffs.staging2_layoffs
SET country = "United States"
WHERE country LIKE "United States%";

-- When I imported the dataset into MySQL, the date column was imported as text, I changed it so the data type is DATE instead of TEXT and the date format is correct
-- First of all I change the format of the date so I can alter the data type safely after
SELECT `date`, str_to_date(`date`, "%m/%d/%Y")
FROM world_layoffs.staging2_layoffs;

UPDATE world_layoffs.staging2_layoffs
SET `date` = STR_TO_DATE(`date`, "%m/%d/%Y");

ALTER TABLE world_layoffs.staging2_layoffs
MODIFY COLUMN `date` DATE;

-- My next step is to eliminate or populate null/blank values
-- I found null/blank values in the following columns: industry, total_laid_off, percentage_laid_off, date, stage and funds_raised_millions

-- I tackle the industry column first, changing all blank values to NULL so I can better work with them
UPDATE world_layoffs.staging2_layoffs
SET industry = NULL
WHERE industry = "";

-- After, I check for any blank values that have another row with the same company and location where the industry is populated and populate the null industry based on the complete row
SELECT *
FROM world_layoffs.staging2_layoffs t1
JOIN world_layoffs.staging2_layoffs t2
ON t1.company = t2.company AND t1.location = t2.location
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;

UPDATE world_layoffs.staging2_layoffs t1
JOIN world_layoffs.staging2_layoffs t2
ON t1.company = t2.company AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;
-- The previous update was successful, although there are still some null values that didn't have any reference, so it has to stay NULL

-- I noticed in the stage column that there are some "Unknown" and NULL values, since they both mean the same, I converted all the "Unknown" into NULL to standarize
SELECT *
FROM world_layoffs.staging2_layoffs
WHERE stage IS NULL OR stage LIKE "Unknown%";

UPDATE world_layoffs.staging2_layoffs
SET stage = NULL
WHERE stage LIKE "Unknown%";

-- For the total_laid_off and percentage_laid_off columns, I could populate some of them if I had the number of total employees but, since I don't I cannot populate them
-- For the date column, there is a null value that I cannot populate since I don't know the details of the layoff
-- Same goes for the funds_raised_millions column

-- Now that I have populated as much data as possible, I noticed that many companies have no information at all on total or percentage laid off
-- At first, I considered leaving these rows as they are, but since I plan to perform an exploratory analysis on this cleaned dataset, I will delete them because they wont add any value
SELECT *
FROM world_layoffs.staging2_layoffs
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

DELETE
FROM world_layoffs.staging2_layoffs
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

-- The data is cleaned up, and I don't need the row_num column anymore, so I just dropped it
ALTER TABLE world_layoffs.staging2_layoffs
DROP COLUMN row_num;

-- I also dropped the first staging table and change the name to the second one to give it a professional look
DROP TABLE world_layoffs.staging_layoffs;

RENAME TABLE world_layoffs.staging2_layoffs TO clean_layoffs;


