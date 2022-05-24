-- CONNECT TO PSQL (command-line interface to Postgresql in Linux)

sudo -u postgres psql


-- IMPORT DATA

-- Create the database 'prénoms'
CREATE DATABASE prenoms;

-- Switch to the database 'prénoms'
\c prénoms

-- Import the data of the "nat2020.csv" file
------ Create the table 'nat2020'
CREATE TABLE nat2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, nombre INT);
------ Copy data from the "nat2020.csv" file to the table 'nat2020'
COPY nat2020 FROM '/home/oem/Documents/Lies/INSEE/nat2020.csv' DELIMITER ',' CSV HEADER;

-- Import the data of the "dpt2020.csv" file
------ Create the table 'dpt2020'
CREATE TABLE dpt2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, dpt VARCHAR, nombre INT);
------ Copy data from the "dpt2020.csv" file to the table 'dpt2020'
------ => the number of lines being too high, the file has been beforehand cut into 4 sub-files, then the copy done in 4 steps
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_01.csv' DELIMITER ',' CSV HEADER;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_02.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_03.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_04.csv' DELIMITER ',' CSV;


-- CHECK IMPORTED DATA

-- Check the integrity of the data import
------ Make a visual check of all columns and rows of the table 'nat2020'
SELECT * FROM nat2020;
------ => we have the expected 4 columns and 667,364 rows
------ Make a visual check of all columns and rows of the table 'dpt2020'
SELECT * FROM dpt2020;
------ => we have the expected 5 columns and 3,727,554 rows

-- Check the data consistency regarding the range of years
------ List all the years contained in the table 'nat2020'
SELECT annais FROM nat2020 GROUP BY annais;
------ List all the years contained in the table 'dpt2020'
SELECT DISTINCT annais FROM dpt2020 ORDER BY annais;
------ => for both tables, we have 122 rows corresponding to the range of years "1900 to 2020" (121 rows) + one unknown year "XXXX"

-- Check the data consistency regarding the total number of births
------ Calculate the difference in the total number of births (between the table 'nat2020' and the table 'dpt2020')
SELECT (SELECT SUM(nombre) FROM nat2020) AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020) AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020)-(SELECT SUM(nombre) FROM dpt2020)) AS nb_total_écart;
------ => we have an immaterial difference of only -103 births for a total of 86,605,605 births (according to the table 'nat2020')

-- Check the data consistency regarding the total number of births with a split between the known years (all years from 1900 to 2020) and the unknown year ("XXXX")
------ Calculate the difference in the total number of births (between the table 'nat2020' and the table 'dpt2020') for the known years (from 1900 to 2020)
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX')) AS nb_total_écart
------ Concatenete all the previous rows with the rows that will follow
UNION ALL
------ Calculate the difference in the total number of births (between the table 'nat2020' and the table 'dpt2020') for the unknown year ("XXXX")
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX')) AS nb_total_écart;
------ => for the known years, the difference is +7,822,178 births so there are lacking births in the table 'dpt2020'
------ => for the unknown year, the difference is -7,822,281 births so the lacking births in the table 'dpt2020' have been computed in the unknown year

-- Check the data consistency regarding the number of births per year
------ Create the CTE 'a' to calculate the number of births per year according to the table 'nat2020'
WITH a(annais, nb_annuel_nat) AS (SELECT annais, SUM(nombre) AS nb_annuel_nat FROM nat2020 GROUP BY annais),
------ Create the CTE 'b' to calculate the number of births per year according to the table 'dpt2020'
b(annais, nb_annuel_dpt) AS (SELECT annais, SUM(nombre) AS nb_annuel_dpt FROM dpt2020 GROUP BY annais)
------ Use the two CTE to calculate the difference in the number of births per year (between the table 'nat2020' and the table 'dpt2020') and the percentage of difference (based on the table 'nat2020') 
SELECT a.annais, nb_annuel_nat, nb_annuel_dpt, nb_annuel_nat-nb_annuel_dpt AS nb_annuel_écart, to_char(100*(nb_annuel_nat-nb_annuel_dpt)/nb_annuel_nat, '000.99%') AS pourcentage_écart FROM a
------ Join the CTE b to the CTE a
JOIN b ON a.annais = b.annais;
------ => untill 1982, the percentage of difference is below 10%
------ => from 1983 untill 2009, the percentage of difference is between 10% and 19%
------ => from 2010, the percentage of difference is between 20% and 24%

-- Check for each first name the percentage of the "unknown births" (= number of births for year "XXXX) compared to the "maximum births" (= highest annual number of births over the period 1900 to 2020)  
------ Create the CTE 'a' to calculate the "unknown births"
WITH a(preusuel, nombre) AS (SELECT preusuel, SUM(nombre) FROM dpt2020 WHERE annais ='XXXX' GROUP BY preusuel), 
------ Create the CTE 'b' to calculate the "maximum births"
b(preusuel, nombre_max) AS (SELECT preusuel, MAX(nombre) AS nombre_max FROM dpt2020 GROUP BY preusuel)
------ Use the two CTE to calculate the percentage of "unknown births" compared to the "maximum births"
SELECT a.preusuel, a.nombre, nombre_max, to_char(100*CAST(a.nombre AS DECIMAL)/nombre_max, '000.99%') AS pourcentage_du_max FROM a 
------ Join the CTE b to the CTE a
JOIN b ON a.preusuel = b.preusuel ORDER BY pourcentage_du_max DESC, nombre_max DESC;

-- Check the percentage of the "unknown births" (= number of births for year "XXXX) compared to the "minimum births" (= lowest annual number of births over the period 1900 to 2020)  
SELECT MIN(nombre) AS nombre_min FROM dpt2020 GROUP BY annais
------ Use the two CTE to calculate the percentage of "unknown births" compared to the "maximum births"
SELECT a.preusuel, a.nombre, nombre_max, to_char(100*CAST(a.nombre AS DECIMAL)/nombre_max, '000.99%') AS pourcentage_du_max FROM a 
------ Join the CTE b to the CTE a
JOIN b ON a.preusuel = b.preusuel ORDER BY pourcentage_du_max DESC, nombre_max DESC;


-- DATA ANALYSIS

-- Classification of the first names per number of births over the whole period 

