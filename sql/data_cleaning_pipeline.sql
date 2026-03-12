/*
DATA CLEANING PIPELINE – WORLD LAYOFFS DATASET

This pipeline script creates a clean version of the layoffs dataset by:
- Creating a staging table
- Removing duplicate records
- Standarizing text values
- Converting data types
- Handling missing values

The result is a cleaned table called "clean_layoffs" ready for analysis

Author: Biel Caballol Prat
*/ 

DROP TABLE IF EXISTS staging_layoffs;
DROP TABLE IF EXISTS staging2_layoffs;
DROP TABLE IF EXISTS clean_layoffs;
CREATE TABLE staging_layoffs LIKE world_layoffs.layoffs;

INSERT INTO world_layoffs.staging_layoffs
SELECT *
FROM world_layoffs.layoffs;

CREATE TABLE staging2_layoffs (
  company text,
  location text,
  industry text,
  total_laid_off int DEFAULT NULL,
  percentage_laid_off text,
  date text,
  stage text,
  country text,
  funds_raised_millions int DEFAULT NULL,
  row_num INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO world_layoffs.staging2_layoffs
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions
) row_num
FROM world_layoffs.staging_layoffs;

DELETE
FROM world_layoffs.staging2_layoffs
WHERE row_num != 1;

UPDATE world_layoffs.staging2_layoffs
SET company = TRIM(company),
location = TRIM(location),
industry = TRIM(industry),
stage = TRIM(stage),
country = TRIM(country);

UPDATE world_layoffs.staging2_layoffs
SET industry = "Crypto"
WHERE industry LIKE "Crypto%";

UPDATE world_layoffs.staging2_layoffs
SET country = "United States"
WHERE country LIKE "United States%";

UPDATE world_layoffs.staging2_layoffs
SET `date` = STR_TO_DATE(`date`, "%m/%d/%Y");

ALTER TABLE world_layoffs.staging2_layoffs
MODIFY COLUMN `date` DATE;

UPDATE world_layoffs.staging2_layoffs
SET industry = NULL
WHERE industry = "";

UPDATE world_layoffs.staging2_layoffs t1
JOIN world_layoffs.staging2_layoffs t2
ON t1.company = t2.company
AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

UPDATE world_layoffs.staging2_layoffs
SET stage = NULL
WHERE stage LIKE "Unknown%";

DELETE
FROM world_layoffs.staging2_layoffs
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

ALTER TABLE world_layoffs.staging2_layoffs
DROP COLUMN row_num;

DROP TABLE world_layoffs.staging_layoffs;

RENAME TABLE world_layoffs.staging2_layoffs TO clean_layoffs;