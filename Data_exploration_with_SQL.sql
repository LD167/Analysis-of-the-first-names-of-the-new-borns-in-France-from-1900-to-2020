-- CONNECTION TO PSQL (Postgresql interactive Terminal in Linux)
sudo -u postgres psql


-- IMPORT OF THE DATA

----- Create the database 'first_names'
CREATE DATABASE first_names;

----- Create the table 'dpt2020'
CREATE TABLE dpt2020(sexe VARCHAR, preusuel VARCHAR, annais INT, dpt INT, nombre INT);

----- Copy data from the INSEE file "dpt2020.csv" to the table 'dpt2020'
----- {the number of lines being too high, the file has been cut beforehand in 4 sub-files, so the copy done in 4 steps}
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_01.csv' DELIMITER ',' CSV HEADER;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_02.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_03.csv' DELIMITER ',' CSV;
COPY dpt2020 FROM '/home/oem/Documents/Lies/INSEE/dpt2020_04.csv' DELIMITER ',' CSV;

-- SANITY CHECK OF THE DATA

----- Make a quick visual check
SELECT * FROM dpt2020;

----- Check the total number of lines
SELECT COUNT(*) FROM dpt2020;

----- Check the total number of years
SELECT DISTINCT COUNT(*) FROM dpt2020;


-- EXPLORATION OF THE DATA

----- OF LINES

