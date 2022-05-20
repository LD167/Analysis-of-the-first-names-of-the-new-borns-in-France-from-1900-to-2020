-- CONNECTION TO PSQL (Postgresql interactive Terminal in Linux)

sudo -u postgres psql


-- IMPORT OF THE DATA

-- Create the database 'prenoms'
CREATE DATABASE prenoms;

-- Create the table 'dpt2020'
CREATE TABLE dpt2020(sexe VARCHAR, preusuel VARCHAR, annais INT, dpt INT, nombre INT);

-- Copy data from the INSEE file "dpt2020.csv" to the table 'dpt2020'
-- => the number of lines being too high, the file has been cut beforehand in 4 sub-files, so the copy done in 4 steps
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_01.csv' DELIMITER ',' CSV HEADER;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_02.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_03.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_04.csv' DELIMITER ',' CSV;

-- SANITY CHECK OF THE DATA

-- Check the total number of rows
SELECT COUNT(*) FROM dpt2020;

-- Make a quick visual check of all columns and rows
SELECT * FROM dpt2020; 

-- Check the range of years
----- Method 1
SELECT annais FROM dpt2020 GROUP BY annais;
----- Method 2
SELECT DISTINCT annais FROM dpt2020 ORDER BY annais;
-- => we have 122 rows corresponding to the range of years "1900 to 2020" (121 rows) + one unknown year "XXXX"

-- Check for each first name the percentage of births associated to the unknown year "XXXX" 
----- Create two CTE (a and b)
WITH b(preusuel, nombre_total) AS (SELECT preusuel, SUM(nombre) AS nombre_total FROM dpt2020 GROUP BY preusuel), a(preusuel, nombre) AS (SELECT preusuel, SUM(nombre) FROM dpt2020 WHERE annais ='XXXX' GROUP BY preusuel)
----- Join the CTE b to the CTE a
SELECT a.preusuel, a.nombre, nombre_total, to_char(100*CAST(a.nombre AS DECIMAL)/nombre_total, '000.99%') AS pourcentage_du_total FROM a JOIN b ON a.preusuel = b.preusuel ORDER BY pourcentage_du_total DESC, nombre_total DESC;

-- EXPLORATION OF THE DATA

-- Classification of the first names per number of births over the whole period 

