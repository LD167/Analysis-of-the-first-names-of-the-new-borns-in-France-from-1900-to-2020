-- CONNECT TO PSQL (command-line interface to Postgresql in Linux)

sudo -u postgres psql


-- IMPORT DATA

-- 1) Create the database 'prenoms'

CREATE DATABASE prenoms;

-- 2) Switch to the database 'prenoms'

\c prenoms

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
------ => for these 4 years, we will compare the table 'nat2020' with the official annual number of births provided by the INSEE at the following URL : https://www.insee.fr/fr/statistiques/2381380

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
SELECT a.annais, nb_annuel_nat, nb_annuel_dpt, nb_annuel_nat-nb_annuel_dpt AS nb_annuel_écart, to_char(100*(nb_annuel_nat-nb_annuel_dpt)/nb_annuel_nat, '999%') AS pourcentage_écart FROM a
JOIN b ON a.annais = b.annais;
------ => from 1900 to 1968, the percentage of difference is immaterial (below 5%) so, before 1969, we can ignore the unknown year "XXXX" in the table 'dpt2020'
------ => from 1969, the percentage of difference is material (between 6% and 24%) : we will have to clean the table 'dpt2020' in order to match the number of births per year with the table 'nat2020'
------ => the cleaning and restructuration of the table 'dpt2020' will be done in Python


-- RESTRUCTURE DATA

-- => we will create a new table 'nat2020bis' that will be the copy of the table 'nat2020' but without the unknown year 'XXXX' plus other modifications (columns renamed, values replaced, format type changed)

-- 1) Create new table

-- Create the table 'nat2020bis'
CREATE TABLE nat2020bis(sexe VARCHAR, preusuel VARCHAR, annais VARCHAR, nombre INT);

-- Insert the data from the table 'nat2020' into the table 'nat2020bis'
INSERT INTO nat2020bis SELECT * FROM nat2020;

-- 2) Delete rows

------ Delete the rows associated to the unknown year "XXXX" 
DELETE FROM nat2020bis WHERE annais = 'XXXX';
------ => 36 675 rows have been deleted

-- 3) Rename columns

------ Rename the column 'annais' as 'annee'
ALTER TABLE nat2020bis RENAME annais TO annee;

------ Rename the column 'preusuel' as 'prenom'
ALTER TABLE nat2020bis RENAME preusuel TO prenom;

-- 4) Replace values

------ In the column 'sexe', replace the value "1" by "garçon"
UPDATE nat2020bis SET sexe = REPLACE(sexe, '1', 'garçon')
------ => 630 689 rows have been updated

------ In the column 'sexe', replace the value "2" by "fille"
UPDATE nat2020bis SET sexe = REPLACE(sexe, '2', 'fille');
------ => 630 689 rows have been updated

------ In the column 'prenom', replace the value "_PRENOMS_RARES" by "PRENOMS_RARES"
UPDATE nat2020bis SET prenom = REPLACE(prenom, '_PRENOMS_RARES', 'PRENOMS_RARES');
------ => 630 689 rows have been updated

-- 5) Change format types

------ Change the format type of the column 'annee' (from "VARCHAR" to "INT")
ALTER TABLE nat2020bis ALTER COLUMN annee TYPE INT USING (annee::integer);

-- 6) Create new column

-- => we will create a new column to classify the years per decades

------ Add the column 'decade'
ALTER TABLE nat2020bis ADD COLUMN decade VARCHAR;
------ Set values in the column 'decade'
UPDATE nat2020bis
SET decade = CASE 
WHEN annee BETWEEN 1900 AND 1909 THEN 'années 1900'
WHEN annee BETWEEN 1910 AND 1919 THEN 'années 1910'
WHEN annee BETWEEN 1920 AND 1929 THEN 'années 1920'
WHEN annee BETWEEN 1930 AND 1939 THEN 'années 1930'
WHEN annee BETWEEN 1940 AND 1949 THEN 'années 1940'
WHEN annee BETWEEN 1950 AND 1959 THEN 'années 1950'
WHEN annee BETWEEN 1960 AND 1969 THEN 'années 1960'
WHEN annee BETWEEN 1970 AND 1979 THEN 'années 1970'
WHEN annee BETWEEN 1980 AND 1989 THEN 'années 1980'
WHEN annee BETWEEN 1990 AND 1999 THEN 'années 1990'
WHEN annee BETWEEN 2000 AND 2009 THEN 'années 2000'
WHEN annee BETWEEN 2010 AND 2019 THEN 'années 2010'
WHEN 2020 = annee THEN 'year 2020'
END;
------ => 630 689 rows have been updated

-- 7) Check the new structure

------ Make a visual check of all columns and rows of the table 'nat2020bis'
SELECT * FROM nat2020bis;
------ => we have the expected renamed/added columns and replaced values

------ Check that the unknown year "XXXX" doesn't exist any more
SELECT annee FROM nat2020bis WHERE annee = 'XXXX';
------ => 0 rows returned


-- EXPLORE DATA

-- => we will explore the table 'nat2020bis'

-- 1) Rankings of the years

------ Based on the number of births for all first names

---------- Boys and girls combined
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, annee, SUM(nombre) AS nombre_de_naissances FROM nat2020bis GROUP BY annee;
---------- Boys and girls separated
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, annee) AS rang, annee, sexe, SUM(nombre) AS nombre_de_naissances FROM nat2020bis GROUP BY annee, sexe;
---------- Only boys
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, annee, sexe, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE sexe = 'garçon' GROUP BY annee, sexe;
---------- Only girls
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, annee, sexe, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE sexe = 'fille' GROUP BY annee, sexe;

------ Based on the number of births for specific first names

---------- Boys and girls combined / Only the first name "MARIE"
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, decade, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom = 'MARIE' GROUP BY decade;
---------- Boys and girls combined / Only the first names "LIÈS", "DJAMEL","MERIEM", "RACHID"
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC) AS rang, decade, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom IN ('LIÈS', 'DJAMEL', 'MERIEM', 'RACHID') GROUP BY decade;

------ Based on the number of distinct first names

---------- Boys and girls combined
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT prenom) DESC) AS rang, annee, COUNT(DISTINCT prenom) AS nombre_de_prenoms FROM nat2020bis GROUP BY annee;
---------- Boys and girls separated
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT prenom) DESC) AS rang, annee, sexe, COUNT(DISTINCT prenom) AS nombre_de_prenoms FROM nat2020bis GROUP BY annee, sexe;
---------- Only boys
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT prenom) DESC) AS rang, annee, sexe, COUNT(DISTINCT prenom) AS nombre_de_prenoms FROM nat2020bis WHERE sexe = 'garçon' GROUP BY annee, sexe;
---------- Only girls
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT prenom) DESC) AS rang, annee, sexe, COUNT(DISTINCT prenom) AS nombre_de_prenoms FROM nat2020bis WHERE sexe = 'fille' GROUP BY annee, sexe;

-- 2) Rankings of the first names

------ Based on the number of births (then on the number of disctinct years) for all first names (except "PRENOMS_RARES") and all years

---------- Boys and girls combined
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' GROUP BY prenom;
---------- Boys and girls separated
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, sexe, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' GROUP BY prenom, sexe;
---------- Only boys
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, sexe, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' AND sexe = 'garçon' GROUP BY prenom, sexe;
---------- Only girls
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, sexe, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' AND sexe = 'fille' GROUP BY prenom, sexe;

------ Based on the number of births (then on the number of disctinct years) for specific first names and specific years

---------- Boys and girls combined / Only the first names beginning by "CHA" / Since year 2000
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom LIKE 'CHA%' AND annee >= 2000 GROUP BY prenom;
---------- Boys and girls combined / Only the first names composed of 3 characters and finishing by "VA" / Only years between 2005 and 2015 
SELECT DENSE_RANK() OVER (ORDER BY SUM(nombre) DESC, COUNT(DISTINCT annee) DESC) AS rang, prenom, SUM(nombre) AS nombre_de_naissances, COUNT(DISTINCT annee) AS nombre_d_annees FROM nat2020bis WHERE prenom LIKE '_VA' AND annee BETWEEN 2005 AND 2015 GROUP BY prenom;

------ Based on the number of distinct years (then on the number of births)

---------- Boys and girls combined
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT annee) DESC, SUM(nombre) DESC) AS rang, prenom, COUNT(DISTINCT annee) AS nombre_d_annees, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' GROUP BY prenom;
---------- Boys and girls separated
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT annee) DESC, SUM(nombre) DESC) AS rang, prenom, sexe, COUNT(DISTINCT annee) AS nombre_d_annees, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' GROUP BY prenom, sexe;
---------- Only boys
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT annee) DESC, SUM(nombre) DESC) AS rang, prenom, sexe, COUNT(DISTINCT annee) AS nombre_d_annees, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' AND sexe = 'garçon' GROUP BY prenom, sexe;
---------- Only girls
SELECT DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT annee) DESC, SUM(nombre) DESC) AS rang, prenom, sexe, COUNT(DISTINCT annee) AS nombre_d_annees, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE prenom <> 'PRENOMS_RARES' AND sexe = 'fille' GROUP BY prenom, sexe;

-- 3) Main annual statistics (average, maximum, minimum, standard deviation) per decade

------ Based on the number of births
WITH a AS (SELECT decade, annee, SUM(nombre) AS nombre_de_naissances FROM nat2020bis GROUP BY decade, annee)
SELECT DISTINCT decade, ROUND(AVG(nombre_de_naissances) OVER (PARTITION BY decade)) AS nombre_annuel_moyen_de_naissances, MAX(nombre_de_naissances) OVER (PARTITION BY decade) AS nombre_annuel_maximum_de_naissances, MIN(nombre_de_naissances) OVER (PARTITION BY decade) AS nombre_annuel_minimum_de_naissances, ROUND(STDDEV(nombre_de_naissances) OVER (PARTITION BY decade)) AS ecart_type FROM a ORDER BY decade;

------ Based on the number of distinct first names
WITH a AS (SELECT decade, annee, COUNT(DISTINCT prenom) AS nombre_de_prenoms FROM nat2020bis GROUP BY decade, annee)
SELECT DISTINCT decade, ROUND(AVG(nombre_de_prenoms) OVER (PARTITION BY decade)) AS nombre_annuel_moyen_de_prenoms, MAX(nombre_de_prenoms) OVER (PARTITION BY decade) AS nombre_annuel_maximum_de_prenoms, MIN(nombre_de_prenoms) OVER(PARTITION BY decade) AS nombre_annuel_minimum_de_prenoms, ROUND(STDDEV(nombre_de_prenoms) OVER (PARTITION BY decade)) AS ecart_type FROM a ORDER BY decade;

------ Based on the number of births per first name
WITH a AS (SELECT decade, annee, prenom, SUM(nombre) AS nombre_de_naissances FROM nat2020bis GROUP BY decade, annee, prenom)
SELECT DISTINCT decade, ROUND(AVG(nombre_de_naissances) OVER (PARTITION BY decade)) AS nombre_annuel_moyen_de_naissances_par_prenom, MAX(nombre_de_naissances) OVER (PARTITION BY decade) AS nombre_annuel_maximum_de_naissances_par_prenom, MIN(nombre_de_naissances) OVER (PARTITION BY decade) AS nombre_annuel_minimum_de_naissances_par_prenom, ROUND(STDDEV(nombre_de_naissances) OVER (PARTITION BY decade)) AS ecart_type FROM a ORDER BY decade;

-- 4) Diverse queries

------ Which first names have ranked each year in the top 10 for the annual number of births during the last 3 years (from 2018 to 2020) ?
WITH aa18 AS (SELECT prenom FROM (SELECT annee, prenom, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annee ORDER BY SUM(nombre) DESC) AS rang FROM nat2020bis GROUP BY annee, prenom HAVING annee = 2018) a18 WHERE rang <=10 AND prenom <> 'PRENOMS_RARES'), 
aa19 AS (SELECT prenom FROM (SELECT annee, prenom, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annee ORDER BY SUM(nombre) DESC) AS rang FROM nat2020bis GROUP BY annee, prenom HAVING annee = 2019) a19 WHERE rang <=10 AND prenom <> 'PRENOMS_RARES'), 
aa20 AS (SELECT prenom FROM (SELECT annee, prenom, SUM(nombre), DENSE_RANK() OVER (PARTITION BY annee ORDER BY SUM(nombre) DESC) AS rang FROM nat2020bis GROUP BY annee, prenom HAVING annee = 2020) a20 WHERE rang <=10 AND prenom <> 'PRENOMS_RARES') 
SELECT prenom FROM aa18
INNER JOIN aa19 USING(prenom)
INNER JOIN aa20 USING(prenom);

------ Which first names have been given for the first time in 2020 (since 1900) among the first names composed of 3 characters ?
WITH a(avant_2020) AS (SELECT DISTINCT prenom AS avant_2020 FROM nat2020bis WHERE annee < 2020), b(en_2020) AS (SELECT DISTINCT prenom AS en_2020 FROM nat2020bis WHERE annee = 2020) 
SELECT en_2020 FROM a
RIGHT JOIN b ON en_2020 = avant_2020 WHERE avant_2020 IS NULL AND LENGTH(en_2020) = 3 ORDER BY en_2020;

------ Which first names have been given for the first time in 1950 (since 1900) among the last 200 first names for the number of births ?
WITH a(avant_1950) AS (SELECT DISTINCT prenom AS avant_1950 FROM nat2020bis WHERE annee < 1950), b(en_1950) AS (SELECT prenom AS en_1950, SUM(nombre) AS nombre_de_naissances FROM nat2020bis WHERE annee = 2020 GROUP BY prenom ORDER BY nombre_de_naissances LIMIT 200) 
SELECT en_1950, nombre_de_naissances FROM a
RIGHT JOIN b ON en_1950 = avant_1950 WHERE avant_1950 IS NULL ORDER BY nombre_de_naissances, en_1950;

------ Which first names have not been given any more since 1990 ?
WITH a(before_1990) AS (SELECT DISTINCT prenom AS before_1990 FROM nat2020bis WHERE annee < 1990), b(since_1990) AS (SELECT DISTINCT prenom AS since_1990 FROM nat2020bis WHERE annee >= 1990) 
SELECT before_1990 FROM a
LEFT JOIN b ON since_1990 = before_1990 WHERE since_1990 IS NULL ORDER BY before_1990;

----- Which years the first names "ZYGMUND" and "HECTOR" have been given in ?
WITH a AS (SELECT DISTINCT annee, prenom FROM nat2020bis WHERE prenom = 'ZYGMUND'),
b AS (SELECT DISTINCT annee, prenom FROM nat2020bis WHERE prenom = 'HECTOR')
SELECT annee FROM a
JOIN b USING(annee);

----- Which years the first name "HECTOR" have been given in but not the first name "ZYGMUND" ?
WITH a AS (SELECT DISTINCT annee, prenom FROM nat2020bis WHERE prenom = 'ZYGMUND'),
b AS (SELECT DISTINCT annee, prenom FROM nat2020bis WHERE prenom = 'HECTOR')
SELECT annee FROM a
RIGHT JOIN b USING(annee) WHERE a.prenom IS NULL;


