-- SHOW VARIABLES WHERE Variable_name LIKE "%dir";
DROP DATABASE IF EXISTS matbalance;
CREATE DATABASE matbalance;
USE matbalance;

DROP TABLE IF EXISTS regions;
CREATE TABLE regions(
id SERIAL PRIMARY KEY,
`name` VARCHAR(20))
COMMENT 'Справочник регионов';

DROP TABLE IF EXISTS `fields`;
CREATE TABLE `fields`(
id SERIAL PRIMARY KEY, 
`name` VARCHAR(40), 
reg_id BIGINT UNSIGNED, 
FOREIGN KEY (reg_id) REFERENCES regions(id) ON UPDATE CASCADE ON DELETE SET NULL)
COMMENT 'Справочник месторождений';


/*SET GLOBAL FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE dns;
SET GLOBAL FOREIGN_KEY_CHECKS = 1;*/
DROP TABLE IF EXISTS dns;
CREATE TABLE dns(
id SERIAL PRIMARY KEY,
`name` VARCHAR(30), 
field_id BIGINT UNSIGNED,
reg_id BIGINT UNSIGNED,
FOREIGN KEY (field_id) REFERENCES `fields`(id) ON UPDATE CASCADE ON DELETE SET NULL, 
FOREIGN KEY (reg_id) REFERENCES regions(id) ON UPDATE CASCADE ON DELETE SET NULL)
COMMENT 'Дожимные насосные станции';
-- ALTER TABLE dns MODIFY id BIGINT UNSIGNED AUTO_INCREMENT UNIQUE;


DROP TABLE IF EXISTS kns;
CREATE TABLE kns(
id SERIAL PRIMARY KEY,
`name` VARCHAR(30), 
field_id BIGINT UNSIGNED,
reg_id BIGINT UNSIGNED,
FOREIGN KEY (field_id) REFERENCES `fields`(id) ON UPDATE CASCADE ON DELETE SET NULL, 
FOREIGN KEY (reg_id) REFERENCES regions(id) ON UPDATE CASCADE ON DELETE SET NULL)
COMMENT 'Кустовые насосные станции';
-- ALTER TABLE kns MODIFY id BIGINT UNSIGNED AUTO_INCREMENT;

DROP TABLE IF EXISTS dns_kns_relations;
CREATE TABLE dns_kns_relations(
kns_id BIGINT UNSIGNED, 
dns_id BIGINT UNSIGNED, 
source_priority TINYINT,
consumer_priority TINYINT,
`year` DATE); -- таблица взаимосвязей ДНС и КНС, которые могут меняться со временем
ALTER TABLE dns_kns_relations ADD FOREIGN KEY (kns_id) REFERENCES kns(id) 
ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE dns_kns_relations ADD FOREIGN KEY (dns_id) REFERENCES dns(id)
ON DELETE CASCADE ON UPDATE CASCADE;

DROP TABLE IF EXISTS dns_hierarchy;
CREATE TABLE dns_hierarchy(
dns_from BIGINT UNSIGNED, 
dns_to BIGINT UNSIGNED,
`year` DATE,
FOREIGN KEY (dns_from) REFERENCES dns(id) ON UPDATE CASCADE ON DELETE SET NULL,
FOREIGN KEY (dns_to) REFERENCES dns(id) ON UPDATE CASCADE ON DELETE SET NULL)
COMMENT 'Взаимосвязи дожимных насосных'; 
-- дожимные насосные перекачивают продукцию друг за другом до сдачи в магистральные трубы Транснефти

DROP TABLE IF EXISTS pwr_dns;
CREATE TABLE pwr_dns(
dns_id BIGINT UNSIGNED, 
`year` DATE, 
liq_pwr INT COMMENT 'производительность по входящей жидкости', 
liq_oil INT COMMENT 'мощность по подготвке нефти', 
liq_wat INT COMMENT 'мощность по подготовке отделяемой воды', 
liq_o_pmp INT COMMENT 'подача насосов перекачки нефти', 
liq_w_pmp INT COMMENT 'подача насосов откачки воды', 
wcut FLOAT COMMENT 'обводенность подготовленной нефти', 
FOREIGN KEY (dns_id) REFERENCES dns(id) ON UPDATE CASCADE ON DELETE CASCADE) 
COMMENT 'Мощности насосных';
-- мощность или производительность насосных скадывается из показателей по разным материальным потокам

-- для экспорта из .csv пришлось в первоисточнике заменить запятые на точки и цифры на строки
DROP TABLE IF EXISTS forecast;
CREATE TABLE forecast(
field_id BIGINT UNSIGNED, 
`year` DATE, 
base_liquid FLOAT, 
base_oil FLOAT,
base_gas FLOAT, 
flood FLOAT, 
FOREIGN KEY (field_id) REFERENCES `fields`(id) ON UPDATE CASCADE ON DELETE SET NULL) 
COMMENT 'Прогноз уровней добычи/закачки по месторождениям';
-- прогноз - это входная информация для анализа трубопроводной инфраструктуры; 
-- прогноз делают геологи и передают отделу инфраструктуры

DROP TABLE IF EXISTS pads;
CREATE TABLE pads(
id SERIAL PRIMARY KEY, 
`name` VARCHAR(10), 
field_id BIGINT UNSIGNED NULL, 
reg_id BIGINT UNSIGNED NULL, 
dns_id BIGINT UNSIGNED NULL, 
kns_fld_id BIGINT UNSIGNED COMMENT 'идентификатор закачивающей КНС', 
kns_intk_id BIGINT UNSIGNED COMMENT 'идентификатор снабжаемой КНС означает, что куст водозаборный', 
q_oil FLOAT COMMENT 'дебит нефти', 
q_liq FLOAT COMMENT 'дебит жидкости', 
q_fld FLOAT COMMENT 'приемистость закачки', 
q_int FLOAT COMMENT 'дебит водозаборного куста', 
FOREIGN KEY (field_id) REFERENCES `fields`(id) ON UPDATE CASCADE ON DELETE SET NULL,
FOREIGN KEY (reg_id) REFERENCES regions(id) ON UPDATE CASCADE ON DELETE SET NULL,
FOREIGN KEY (dns_id) REFERENCES dns(id) ON UPDATE CASCADE ON DELETE SET NULL,
FOREIGN KEY (kns_fld_id) REFERENCES kns(id) ON UPDATE CASCADE ON DELETE SET NULL,
FOREIGN KEY (kns_intk_id) REFERENCES kns(id) ON UPDATE CASCADE ON DELETE SET NULL) 
COMMENT 'Кустовые площадки скважин';

DROP TABLE IF EXISTS actions;
CREATE TABLE actions(
id SERIAL PRIMARY KEY,
`table` CHAR(20) COMMENT 'таблица в которой зафиксировано изменение', 
obj_id BIGINT UNSIGNED NULL COMMENT 'объект, параметр которого измененился', 
parameter CHAR(20) COMMENT 'наименование измененного параметра', 
`year` DATE COMMENT 'дата изменения',
`old_val` FLOAT COMMENT 'было',
`new_val` FLOAT COMMENT 'стало', 
`comment` CHAR(255) COMMENT 'комментарий или причина изменения');
/*таблица мероприятий; мероприятие - это изменение параметра или связи