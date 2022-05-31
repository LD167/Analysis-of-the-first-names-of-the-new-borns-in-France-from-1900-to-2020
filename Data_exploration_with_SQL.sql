-- CONNECT TO PSQL (command-line interface to Postgresql in Linux)

sudo -u postgres psql


-- IMPORT DATA

-- 1) Create the database 'prénoms'

CREATE DATABASE prenoms;

-- 2) Switch to the database 'prénoms'

\c prénoms

-- 3) Import the data of the file "nat2020.csv"

------ Create the table 'nat2020'
CREATE TABLE nat2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, nombre INT);
------ Copy data from the "nat2020.csv" file to the table 'nat2020'
COPY nat2020 FROM '/home/oem/Documents/Lies/INSEE/nat2020.csv' DELIMITER ',' CSV HEADER;

-- 4) Import the data of the file "dpt2020.csv"

------ Create the table 'dpt2020'
CREATE TABLE dpt2020(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, dpt VARCHAR, nombre INT);
------ Copy data from the "dpt2020.csv" file to the table 'dpt2020'
------ => the number of lines being too high, the file has been beforehand cut into 4 sub-files, then the copy done in 4 steps
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_01.csv' DELIMITER ',' CSV HEADER;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_02.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_03.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_04.csv' DELIMITER ',' CSV;


-- CHECK DATA

-- 1) Check the integrity of the import

------ Make a visual check of all columns and rows of the table 'nat2020'
SELECT * FROM nat2020;
------ => we have the expected 4 columns and 667 364 rows
------ Make a visual check of all columns and rows of the table 'dpt2020'
SELECT * FROM dpt2020;
------ => we have the expected 5 columns and 3 727 554 rows

-- 2) Check the data consistency regarding the range of years and departments

------ List all the years contained in the table 'nat2020'
SELECT annais FROM nat2020 GROUP BY annais;
------ List all the years contained in the table 'dpt2020'
SELECT DISTINCT annais FROM dpt2020 ORDER BY annais;
------ => for both tables, we have 122 rows corresponding to the range of years "1900 to 2020" (121 rows) + one unknown year "XXXX"
------ List all the departments contained in the table 'dpt2020'
SELECT DISTINCT dpt FROM dpt2020 ORDER BY dpt;
------ => we have 100 rows corresponding to 99 known departments + one unknown department "XX"
------ List all the known departments contained in the table 'dpt2020'
SELECT DISTINCT CAST(dpt AS INT) WHERE dpt <> 'XX' FROM dpt2020 ORDER BY dpt;
------ => we have the 95 French continental departments ("1" to "95") and the 4 French overseas departments ("971" to "974")
------ Check which years/departments are associated to the unknown department "XX"/year "XXXX"
SELECT dpt, annais FROM dpt2020 WHERE dpt = 'XX' OR annais = 'XXXX' GROUP BY dpt, annais;
------ => the unknown department "XX" is only used for the unknown year "XXXX" (and vice versa)

-- 3) Check the data consistency regarding the total number of births

------ Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020'
SELECT (SELECT SUM(nombre) FROM nat2020) AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020) AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020)-(SELECT SUM(nombre) FROM dpt2020)) AS nb_total_écart;
------ => we have an immaterial difference of only -103 births for a total of 86 605 605 births (according to the table 'nat2020')

-- 4) Check the data consistency regarding the total number of births with a split between the known years (all years from 1900 to 2020) and the unknown year ("XXXX")

------ Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020' for the known years (from 1900 to 2020)
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX')) AS nb_total_écart
------ Concatenete the previous rows with the rows selected thereafter
UNION ALL
------ Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020' for the unknown year ("XXXX")
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX')) AS nb_total_écart;
------ => for the known years, the difference is +7 822 178 births so there are lacking births in the table 'dpt2020'
------ => for the unknown year, the difference is -7 822 281 births so the lacking births in the table 'dpt2020' have been computed in the unknown year

-- 5) Check the data consistency regarding the number of births per year

------ Calculate the number of births per year according to the table 'nat2020'
WITH a(annais, nb_annuel_nat) AS (SELECT annais, SUM(nombre) AS nb_annuel_nat FROM nat2020 GROUP BY annais),
------ Calculate the number of births per year according to the table 'dpt2020'
b(annais, nb_annuel_dpt) AS (SELECT annais, SUM(nombre) AS nb_annuel_dpt FROM dpt2020 GROUP BY annais)
------ Calculate the difference in the number of births per year between the table 'nat2020' and the table 'dpt2020'
------ and the percentage of difference based on the table 'nat2020' 
SELECT a.annais, nb_annuel_nat, nb_annuel_dpt, nb_annuel_nat-nb_annuel_dpt AS nb_annuel_écart, to_char(100*(nb_annuel_nat-nb_annuel_dpt)/nb_annuel_nat, '000.99%') AS pourcentage_écart FROM a
JOIN b ON a.annais = b.annais;
------ => From 1900 to 1968, the percentage of difference is below 5% : we can ignore the lacking births in the table 'dpt2020'
------ => from 1969, the percentage of difference is between 10% and 24% : we'll have to clean the table 'dpt2020' in order to match the number of births per year with the table 'nat2020'(this will be done with Python)


-- EXPLORE DATA

-- 1) About the number of births :

------ What is the average number of births per first name ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
SELECT ROUND(AVG(nombre)) FROM nat2020 WHERE annais <> 'XXXX';
---------- => 136 births
---------- during the last decade (from 2011 to 2020) at the national scope ?
SELECT ROUND(AVG(nombre)) FROM nat2020 WHERE annais BETWEEN '2011' AND '2020';
---------- => 56 births
---------- during the year 1968 in the Paris region (departments : 75, 77, 78, 91, 92, 93, 94, 95) ?
SELECT ROUND(AVG(nombre)) FROM dpt2020 WHERE annais = '1968' AND dpt IN ('75','77','78','91','92','93','94','95');
---------- => 35 births

------ What is the average number of births per year ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
WITH a(annais, nombre_annuel) AS (SELECT annais, SUM(nombre) AS nombre_annuel FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais)
SELECT ROUND(AVG(nombre_annuel)) FROM a;
---------- => 708 766 births
---------- during the fifties (from 1950 to 1959) in the Paris region (departments : 75, 77, 78, 91, 92, 93, 94, 95) ?
WITH a(annais, nombre_annuel) AS (SELECT annais, SUM(nombre) AS nombre_annuel FROM dpt2020 WHERE annais BETWEEN '1950' AND '1959' AND dpt IN ('75','77','78','91','92','93','94','95') GROUP BY annais)
SELECT ROUND(AVG(nombre_annuel)) FROM a;
---------- => 123 356 births

------ What is the average number of births per year and per sex ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
WITH a(annais, sexe, nombre_annuel_par_sexe) AS (SELECT annais, sexe, SUM(nombre) AS nombre_annuel_par_sexe FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais, sexe)
SELECT sexe, ROUND(AVG(nombre_annuel_par_sexe)) FROM a GROUP BY sexe;
---------- => 357 423 births of boys and 351 343 births of girls (so a total of 708 766 births in line with the expectation)

------ Which are the top 3 years for the number of births ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
SELECT annais, SUM(nombre) AS nombre_annuel FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais 
ORDER BY nombre_annuel DESC, annais LIMIT 3;
---------- => "1964" (908 817 births), "1971" (908 325 births), "1972" (903 263 births)

------ Which are the last 2 departments for the average annual number of births ?
---------- during the fifties (from 1950 to 1959) among the continental departments (from 1 to 95) ?
WITH a(dpt, annais, nombre_annuel_par_departement) AS (SELECT dpt, annais, SUM(nombre) AS nombre_annuel_par_departement FROM dpt2020 WHERE dpt BETWEEN '1' AND '95' AND annais BETWEEN '1950' AND '1959'GROUP BY dpt, annais) 
SELECT dpt, ROUND(AVG(nombre_annuel_par_departement)) AS moyenne_annuelle_par_departement FROM a GROUP BY dpt 
ORDER BY moyenne_annuelle_par_departement, dpt LIMIT 2;
---------- => "4" (1 034 births), "48" (1 134 births)

------ Which are the top 2 first names for the number of births ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
SELECT preusuel, SUM(nombre) AS nombre_par_prenom FROM nat2020 GROUP BY preusuel 
ORDER BY nombre_par_prenom DESC LIMIT 2;
---------- => "MARIE" (2 259 135 births), "JEAN" (1 914 606 births)
---------- starting by "N" and ending by "E" during the year 2020 at the national scope ?
SELECT preusuel, SUM(nombre) AS nombre_par_prenom FROM nat2020 WHERE preusuel LIKE 'N%E' AND annais = '2020' GROUP BY preusuel 
ORDER BY nombre_par_prenom DESC LIMIT 2;
---------- => "NOÉMIE" (621 births), "NAËLLE" (366 births)

-- 2) About the first names :

------ How many distinct first names have been given ?
---------- during the last decade (from 2011 to 2020) at the national scope ?
SELECT COUNT(DISTINCT preusuel) FROM nat2020 WHERE annais BETWEEN '2011' AND '2020';
---------- => 22 103 distinct first names
---------- in average per year during the last decade (from 2011 to 2020) at the national scope ?
WITH a(annais, nombre_annuel_de_prenom) AS (SELECT annais, COUNT(DISTINCT preusuel) AS nombre_annuel_de_prenom FROM nat2020 WHERE annais BETWEEN '2011' AND '2020' GROUP BY annais)
SELECT ROUND(AVG(nombre_annuel_de_prenom)) FROM a;
---------- => 13 204 distinct first names

------ Which are the top 4th and 5th years for the number of distinct first names ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
SELECT annais, COUNT(DISTINCT preusuel) AS nombre_prenom_par_an FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais 
ORDER BY nombre_prenom_par_an DESC LIMIT 2 OFFSET 3;
---------- => "2011" (13 309 distinct first names), "2015" (13 287 distinct first names)

------ Which first names have been given for the first time in 2020 since 1900 ?
---------- among the first names composed of 3 characters ?
WITH a(avant_2020) AS (SELECT DISTINCT preusuel AS avant_2020 FROM nat2020 WHERE annais < '2020'), b(en_2020) AS (SELECT DISTINCT preusuel AS en_2020 FROM nat2020 WHERE annais = '2020') 
SELECT en_2020 FROM a
RIGHT JOIN b ON en_2020 = avant_2020 WHERE avant_2020 IS NULL AND LENGTH(en_2020) = 3 ORDER BY en_2020;
---------- => "KYA", "OVA", "SAI"
---------- among the last 200 first names for the number of births ?
WITH a(avant_2020) AS (SELECT DISTINCT preusuel AS avant_2020 FROM nat2020 WHERE annais < '2020'), b(en_2020) AS (SELECT preusuel AS en_2020, SUM(nombre) AS nombre_par_prenom FROM nat2020 WHERE annais = '2020' GROUP BY preusuel ORDER BY nombre_par_prenom LIMIT 200) 
SELECT en_2020, nombre_par_prenom FROM a
RIGHT JOIN b ON en_2020 = avant_2020 WHERE avant_2020 IS NULL ORDER BY nombre_par_prenom, en_2020;
---------- => "CONSTANZA", "MELSA", "MYRYAM", "NIRA"

------ Which first names have not been given any more since 1990 ?
WITH a(before_1990) AS (SELECT DISTINCT preusuel AS before_1990 FROM nat2020 WHERE annais < '1990'), b(since_1990) AS (SELECT DISTINCT preusuel AS since_1990 FROM nat2020 WHERE annais >= '1990') 
SELECT before_1990 FROM a
LEFT JOIN b ON since_1990 = before_1990 WHERE since_1990 IS NULL ORDER BY before_1990;
------ => "UTE"

------ Which first names have been each year among the top 10 first names for the number of births ?
---------- during the last decade (from 2011 to 2020) ?
DECLARE @annee INT
SET @annee = 2011
SELECT @annee;
WHILE @annais < 2020
BEGIN
WITH a AS (SELECT preusuel, SUM(nombre) AS nombre_annuel FROM nat2020 WHERE annais = CAST(@annais AS VARCHAR) GROUP BY preusuel ORDER BY nombre_annuel DESC, preusuel LIMIT 10),
b AS (SELECT preusuel, SUM(nombre) AS nombre_annuel FROM nat2020 WHERE annais = CAST(@annais + 1 AS VARCHAR) GROUP BY preusuel ORDER BY nombre_annuel DESC, preusuel LIMIT 10) 
SELECT a.preusuel FROM a
INNER JOIN b ON a.preusuel = b.preusuel ORDER BY a.preusuel;



