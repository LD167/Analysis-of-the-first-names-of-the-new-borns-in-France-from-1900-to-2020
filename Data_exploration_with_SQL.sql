-- CONNECTION TO PSQL (command-line interface to Postgresql in Linux)

sudo -u postgres psql


-- IMPORT OF THE DATA

-- Create the database 'prénoms'
CREATE DATABASE prenoms;

-- Switch to the database 'prénoms'
\c prénoms

-- Import the INSEE file "nat2020.csv"
------ Create the table 'nat2020'
CREATE TABLE nat2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, nombre INT);
------ Copy data from the INSEE file "nat2020.csv" to the table 'dpt2020'
COPY nat2020 FROM '/home/oem/Documents/Lies/INSEE/nat2020.csv' DELIMITER ',' CSV HEADER;

-- Import the INSEE file "dpt2020.csv"
------ Create the table 'dpt2020'
CREATE TABLE dpt2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, dpt VARCHAR, nombre INT);
------ Copy data from the INSEE file "dpt2020.csv" to the table 'dpt2020'
------ => the number of lines being too high, the file has been cut beforehand in 4 sub-files, so the copy done in 4 steps
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_01.csv' DELIMITER ',' CSV HEADER;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_02.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_03.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_04.csv' DELIMITER ',' CSV;


-- SANITY CHECK OF THE DATA

-- Make a quick visual check of all columns and rows of the table 'nat2020'
SELECT * FROM nat2020;
-- => we have the expected 4 columns and 667,364 rows

-- Make a quick visual check of all columns and rows of the table 'dpt2020'
SELECT * FROM dpt2020;
-- => we have the expected 5 columns and 3,727,554 rows

-- Check the range of years
------ Method 1
SELECT annais FROM dpt2020 GROUP BY annais;
------ Method 2
SELECT DISTINCT annais FROM dpt2020 ORDER BY annais;
------ => we have 122 rows corresponding to the range of years "1900 to 2020" (121 rows) + one unknown year "XXXX"

-- Check for each first name the percentage of the "unknown births" (= number of births for year "XXXX) compared to the "maximum births" (= highest annual number of births over the period 1900 to 2020)  
----- Create the CTE 'a' to calculate the "unknown births"
WITH a(preusuel, nombre) AS (SELECT preusuel, SUM(nombre) FROM dpt2020 WHERE annais ='XXXX' GROUP BY preusuel), 
----- Create the CTE 'b' to calculate the "maximum births"
b(preusuel, nombre_max) AS (SELECT preusuel, MAX(nombre) AS nombre_max FROM dpt2020 GROUP BY preusuel)
----- Use the two CTE to calculate the percentage of "unknown births" compared to the "maximum births"
SELECT a.preusuel, a.nombre, nombre_max, to_char(100*CAST(a.nombre AS DECIMAL)/nombre_max, '000.99%') AS pourcentage_du_max FROM a 
----- Join the CTE b to the CTE a
JOIN b ON a.preusuel = b.preusuel ORDER BY pourcentage_du_max DESC, nombre_max DESC;

-- Check the percentage of the "unknown births" (= number of births for year "XXXX) compared to the "minimum births" (= lowest annual number of births over the period 1900 to 2020)  
SELECT MIN(nombre) AS nombre_min FROM dpt2020 GROUP BY annais
----- Use the two CTE to calculate the percentage of "unknown births" compared to the "maximum births"
SELECT a.preusuel, a.nombre, nombre_max, to_char(100*CAST(a.nombre AS DECIMAL)/nombre_max, '000.99%') AS pourcentage_du_max FROM a 
----- Join the CTE b to the CTE a
JOIN b ON a.preusuel = b.preusuel ORDER BY pourcentage_du_max DESC, nombre_max DESC;


-- EXPLORATION OF THE DATA

-- Classification of the first names per number of births over the whole period 

