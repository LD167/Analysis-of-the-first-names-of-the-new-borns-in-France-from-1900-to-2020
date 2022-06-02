-- CONNECT TO PSQL (command-line interface to Postgresql in Linux)

sudo -u postgres psql


-- IMPORT DATA

-- 1) Create the database 'prénoms'

CREATE DATABASE prénoms;

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

-- 1) Check the integrity of the import of each table

------ Make a visual check of all columns and rows of the table 'nat2020'
SELECT * FROM nat2020;
------ => we have the expected 4 columns and 667 364 rows

------ Make a visual check of all columns and rows of the table 'dpt2020'
SELECT * FROM dpt2020;
------ => we have the expected 5 columns and 3 727 554 rows

-- 2) Check the data consistency of each table regarding the range of years

------ List all the years contained in the table 'nat2020'
SELECT annais FROM nat2020 GROUP BY annais;
------ List all the years contained in the table 'dpt2020'
SELECT DISTINCT annais FROM dpt2020 ORDER BY annais;
------ => for both tables, we have 122 rows corresponding to the range of years "1900 to 2020" (121 rows) + one unknown year "XXXX"

-- 3) Check the data consistency of the table 'dpt2020' regarding the range of departments

------ List all the departments contained in the table 'dpt2020'
SELECT DISTINCT dpt FROM dpt2020 ORDER BY dpt;
------ => we have 100 rows corresponding to 99 known departments + one unknown department "XX"

------ List all the known departments contained in the table 'dpt2020'
SELECT DISTINCT CAST(dpt AS INT) WHERE dpt <> 'XX' FROM dpt2020 ORDER BY dpt;
------ => we have the 95 French continental departments ("1" to "95") and the 4 French overseas departments ("971" to "974")

------ Check which years/departments are associated to the unknown department "XX"/year "XXXX"
SELECT dpt, annais FROM dpt2020 WHERE dpt = 'XX' OR annais = 'XXXX' GROUP BY dpt, annais;
------ => the unknown department "XX" is only used for the unknown year "XXXX" (and vice versa)

-- 5) Check the data consistency of the table 'dpt2020' versus the table 'nat2020' regarding the number of births

------ Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020'
SELECT (SELECT SUM(nombre) FROM nat2020) AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020) AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020)-(SELECT SUM(nombre) FROM dpt2020)) AS nb_total_écart;
------ => we have an immaterial difference of only -103 births for a total of 86 605 605 births (according to the table 'nat2020')

------ Calculate the same with a split between the known years (all years from 1900 to 2020) and the unknown year ("XXXX")
---------- Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020' for the known years (from 1900 to 2020)
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais <> 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais <> 'XXXX')) AS nb_total_écart
---------- Concatenete the previous rows with the rows selected thereafter
UNION ALL
---------- Calculate the difference in the total number of births between the table 'nat2020' and the table 'dpt2020' for the unknown year ("XXXX")
SELECT (SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX') AS nb_total_nat, 
(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX') AS nb_total_dpt, 
((SELECT SUM(nombre) FROM nat2020 WHERE annais = 'XXXX')-(SELECT SUM(nombre) FROM dpt2020 WHERE annais = 'XXXX')) AS nb_total_écart;
------ => for the known years, the difference is +7 822 178 births so there are lacking births in the table 'dpt2020'
------ => for the unknown year, the difference is -7 822 281 births so the lacking births in the table 'dpt2020' have been computed in the unknown year

-- 6) Check the materiality of the unknown year "XXXX" in the table 'nat2020'

------ Calculate the annual average, the annual maximum and the annual minimum number of births according to the table 'nat2020' (excluding the unknown year "XXXX")
WITH a AS (SELECT annais, SUM(nombre) AS nb_annuel_nat FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais)
SELECT ROUND(AVG(nb_annuel_nat)) AS moy_nb_annuel_nat, MAX(nb_annuel_nat) AS max_nb_annuel_nat, MIN(nb_annuel_nat) AS min_nb_annuel_nat FROM a; 
------ => annual average = 708 766 births, annual maximum = 908 817 births, annual minimum = 282 497 births

------ Calculate the total unknown number of births (= associated to the unknown year "XXXX") in the table 'nat2020'
SELECT SUM(nombre) AS nb_annuel_nat FROM nat2020 WHERE annais = 'XXXX';
------ => total unknown = 844 964 births
------ => this total number being material (compared to the annual average), we will now check if it remains material after distributing these unknown births over the years
------ => we will make this check by focusing on a sample of 4 years ("1985", "1995", "2005" and "2015")
------ => for these 4 years, we will compare the table 'nat2020' with the official annual number of births provided by the INSEE at the following web link "https://www.insee.fr/fr/statistiques/2381380"

------ Calculate the difference and the percentage of difference between the annual number of births according to the table 'nat2020' and the official data for the 4 chosen years
WITH a AS (SELECT annais, SUM(nombre) AS nb_annuel_nat FROM nat2020 WHERE annais IN ('1985', '1995', '2005', '2015') GROUP BY annais),
b(annais, nb_annuel_off) AS (SELECT '1985', 796138 UNION ALL SELECT '1995', 759058 UNION ALL SELECT '2005', 806822 UNION ALL SELECT '2015', 798948)
SELECT annais, nb_annuel_nat-nb_annuel_off AS ecart, to_char(100*(nb_annuel_nat - nb_annuel_off)/nb_annuel_off, '999%') AS pourcentage_ecart FROM a
JOIN b USING(annais);
------ => "1985" (-10 118 births, -1%), "1995" (-12 120 births, -1%), "2005" (-12 469 births, -1%), "2015" (-22 894 births, -2%)
------ => the difference is immaterial for the whole sample with an average difference around -14 000 births per year and an average percentage of difference around -1.25% per year
------ => furthermore, if we multiply the average difference (-14 000) by the total number of years (121) we have a total of 1 694 000 births which is far higher than the total unknown number of births (844 964)   
------ => so we can assume that the difference is immaterial for the whole period (from 1900 to 2020)
------ => so we can ignore the unknown year "XXXX" in the table 'nat2020'

-- 7) Check the materiality of the unknown year "XXXX" in the table 'dpt2020'

------ Calculate the number of births per year according to the table 'nat2020'
WITH a(annais, nb_annuel_nat) AS (SELECT annais, SUM(nombre) AS nb_annuel_nat FROM nat2020 GROUP BY annais),
------ Calculate the number of births per year according to the table 'dpt2020'
b(annais, nb_annuel_dpt) AS (SELECT annais, SUM(nombre) AS nb_annuel_dpt FROM dpt2020 GROUP BY annais)
------ Calculate the difference in the number of births per year between the table 'nat2020' and the table 'dpt2020'
------ and the percentage of difference based on the table 'nat2020' 
SELECT a.annais, nb_annuel_nat, nb_annuel_dpt, nb_annuel_nat-nb_annuel_dpt AS nb_annuel_écart, to_char(100*(nb_annuel_nat-nb_annuel_dpt)/nb_annuel_nat, '000.99%') AS pourcentage_écart FROM a
JOIN b ON a.annais = b.annais;
------ => from 1900 to 1968, the percentage of difference is below 5% : we can ignore the lacking births in the table 'dpt2020'
------ => from 1969, the percentage of difference is between 10% and 24% : we will have to clean the table 'dpt2020' in order to match the number of births per year with the table 'nat2020' (this will be done with Python)

-- RESTRUCTURE DATA

-- => we will create a new table 'nat2020bis' that will be the copy of the table 'nat2020' but without the unknown year 'XXXX' and with new names for certain columns and values

-- Create the table 'nat2020bis'
CREATE TABLE nat2020bis(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, nombre INT);
-- Insert the data from the table 'nat2020' into the table 'nat2020bis'
INSERT INTO nat2020bis SELECT * FROM nat2020;
-- Drop the unknown year records 

-- EXPLORE DATA

-- Palmarès of the years based on the number of births + general statistics (average, max, min)
WITH a AS (SELECT annais, SUM(nombre) AS nombre_de_naissance FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais) SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, annais, SUM(nombre) AS nombre_de_naissance, (SELECT ROUND(AVG(nombre_de_naissance)) FROM a) AS moyenne_nombre_de_naissance, to_char(100*SUM(nombre)/(SELECT ROUND(AVG(nombre_de_naissance)) FROM a), '000%') AS pourcentage_moyenne_nombre_de_naissance FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais;


-- Detailed statistics per first names for a given year
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, preusuel, SUM(nombre) AS nombre_de_naissance FROM nat2020 WHERE preusuel <> '_PRENOMS_RARES' AND annais = '2020' GROUP BY preusuel

SELECT rang, preusuel, nombre_de_naissance, nombre_moyen_de_naissance FROM a
LEFT JOIN b USING(annais);


CREATE PROCEDURE palmares_prenoms_par_nb_annuel_naissance(@annais VARCHAR)
AS BEGIN
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, preusuel, SUM(nombre) AS nombre_de_naissance FROM nat2020 WHERE preusuel <> '_PRENOMS_RARES' AND annais = @annais GROUP BY preusuel
END

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

------ Which first names have ranked 3rd in the annual number of births ?
---------- during the last 3 years (from 2018 to 2020) ?
WITH a AS (SELECT annais, preusuel, SUM(nombre) AS nombre_par_an, DENSE_RANK() OVER (PARTITION BY annais ORDER BY SUM(nombre) DESC) AS rang FROM nat2020 GROUP BY annais, preusuel HAVING annais BETWEEN '2018' AND '2020')
SELECT annais, preusuel, nombre_par_an FROM a WHERE rang = 3;
---------- => "RAPHAËL" in "2018" (4 594 births), "LÉO" in "2019" (4 662 births), "GABRIEL" in "2020" (4 415 births)

------ Which first names have ranked each year in the top 10 for the annual number of births ?
---------- during the last 3 years (from 2018 to 2020) ?
WITH aa18 AS (SELECT preusuel FROM (SELECT annais, preusuel, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annais ORDER BY SUM(nombre) DESC) AS rang FROM nat2020 GROUP BY annais, preusuel HAVING annais = '2018') a18 WHERE rang <=10), 
aa19 AS (SELECT preusuel FROM (SELECT annais, preusuel, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annais ORDER BY SUM(nombre) DESC) AS rang FROM nat2020 GROUP BY annais, preusuel HAVING annais = '2019') a19 WHERE rang <=10), 
aa20 AS (SELECT preusuel FROM (SELECT annais, preusuel, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annais ORDER BY SUM(nombre) DESC) AS rang FROM nat2020 GROUP BY annais, preusuel HAVING annais = '2020') a20 WHERE rang <=10) 
SELECT preusuel FROM aa18 
INNER JOIN aa19 USING(preusuel)
INNER JOIN aa20 USING(preusuel);
---------- => "ARTHUR", "EMMA", "GABRIEL", "JADE", "LÉO", "LOUIS", "LOUISE", "RAPHAËL"

-- 2) About the number of first names :

------ How many distinct first names have been given ?
---------- during the last decade (from 2011 to 2020) at the national scope ?
SELECT COUNT(DISTINCT preusuel) FROM nat2020 WHERE annais BETWEEN '2011' AND '2020';
---------- => 22 103 distinct first names
---------- in average per year during the last decade (from 2011 to 2020) at the national scope ?
WITH a(annais, nombre_annuel_de_prenom) AS (SELECT annais, COUNT(DISTINCT preusuel) AS nombre_annuel_de_prenom FROM nat2020 WHERE annais BETWEEN '2011' AND '2020' GROUP BY annais)
SELECT ROUND(AVG(nombre_annuel_de_prenom)) FROM a;
---------- => 13 204 distinct first names

------ Which year ranks 4th in the annual number of distinct first names ?
---------- over the whole period (from 1900 to 2020) at the national scope ?
WITH a AS (SELECT annais, COUNT(DISTINCT preusuel) AS nombre_prenom_par_an, DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT preusuel) DESC) AS rang FROM nat2020 WHERE annais <> 'XXXX' GROUP BY annais)
SELECT annais, nombre_prenom_par_an FROM a WHERE rang = 4;
---------- => "2011" (13 309 distinct first names)

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



