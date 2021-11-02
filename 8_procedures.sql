USE matbalance;
DELIMITER //
DROP PROCEDURE IF EXISTS sp_get_path//
CREATE PROCEDURE sp_get_tree(IN id INT, IN yr DATE)
/* возвращает путь перекачки до точки сдачи 
от выбранной ДНС в заданный год; 
первоисточник взят из 
https://coderoad.ru/16513418/%D0%9A%D0%B0%D0%BA-%D1%81%D0%B4%D0%B5%D0%BB%D0%B0%D1%82%D1%8C-%D1%80%D0%B5%D0%BA%D1%83%D1%80%D1%81%D0%B8%D0%B2%D0%BD%D1%8B%D0%B9-%D0%B7%D0%B0%D0%BF%D1%80%D0%BE%D1%81-SELECT-%D0%B2-MySQL*/

BEGIN
	DECLARE nxt_id INT DEFAULT 0;
    DECLARE prev_id INT DEFAULT id;
    SELECT dns_to INTO nxt_id FROM dns_hierarchy WHERE dns_from = id AND `year` = yr;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp AS (SELECT * FROM dns_hierarchy WHERE 1 = 0);
    TRUNCATE TABLE tmp;
    WHILE nxt_id <> 0 DO
		INSERT INTO tmp SELECT * FROM dns_hierarchy WHERE dns_from = prev_id AND `year` = yr;
        SET prev_id = nxt_id;
        SET nxt_id = 0;
        SELECT dns_to INTO nxt_id FROM dns_hierarchy WHERE dns_from = prev_id AND `year` = yr;
	END WHILE;
	-- SELECT * FROM tmp;
    SELECT t.dns_to, d.name, t.`year` 
    FROM tmp AS T
    JOIN dns AS D
    ON t.dns_to = d.id;
END//
DELIMITER ;
-- проверка процедуры sp_get_path
CALL sp_get_path('2018-01-01');

USE matbalance;
DELIMITER //
DROP PROCEDURE IF EXISTS get_depth//
CREATE PROCEDURE get_depth(IN yr DATE)
/*дожимные насосные (ДНС) связаны трубами и образуют иерархическую стркутуру; 
процедура последовательно проходит таблицу взаимосвязей ДНС (dns_hierarchy), 
определяет маршрут от каждой ДНС до точки сдачи
и в итоге выводит таблицу, показывающую для всех ДНС их уровень вложенности, 
а также маршрут перекачки; 
для исправления ошибки использовал https://www.jamescoyle.net/how-to/3076-mysql-mariadb-error-code-1329-no-data-zero-rows-fetched-selected-or-processed*/

BEGIN
    DECLARE cid INT;
    DECLARE cid2 CHAR(20);
    DECLARE pid INT;
    DECLARE lvl TINYINT;
    DECLARE pth vARCHAR(255);
	
    DECLARE no_data TINYINT DEFAULT 0;
    DECLARE crs CURSOR FOR SELECT dns_from, dns_to FROM dns_hierarchy WHERE `year` = yr;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_data = 1;
    
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp1(obj_i INT);
    TRUNCATE tmp1;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp2(obj_c CHAR(20), `level` TINYINT, `path` VARCHAR(255));
    TRUNCATE tmp2;
 
	OPEN crs;
    cycle:LOOP
		SET no_data = 0;
        FETCH crs INTO cid, pid;
		IF no_data = 1 THEN ITERATE cycle; -- error handler
        END IF;
        SET cid2 = (SELECT `name` FROM dns WHERE id = cid);
        INSERT INTO tmp1(obj_i) VALUE (cid);
        WHILE pid<>0 DO
			INSERT INTO tmp1(obj_i) VALUE (pid);
			SET cid = pid;
			SET pid = 0;
            SELECT dns_to INTO pid FROM dns_hierarchy WHERE dns_from = cid AND `year` = yr;
		END WHILE;
        -- lvl - уровень вложенности, глубина данной ДНС в иерархии, кол-во "остановок" до точки сдачи продукции скважин
        -- pth объединяет последовательность "остановок" в одну строку; отражает маршрут транспорта
        SET lvl = (SELECT COUNT(*) FROM tmp1); 
        SET pth = (SELECT GROUP_CONCAT(`name` SEPARATOR '|') 
					FROM dns 
                    WHERE id IN (SELECT obj_i FROM tmp1) GROUP BY NULL);
        INSERT INTO tmp2(obj_c, `level`, `path`) VALUES (cid2, lvl, pth);
        SELECT * from tmp2;
        /* благодаря строке SELECT * from tmp2 я увидел, что процедура способна возврашать правдоподобные результаты,
        но, похоже, зацикливается; не понимаю, в чем тут дело; 
        возможно, курсор возвращает что-то лишнее, но в его определении я указал требуемый год в WHERE*/        
        TRUNCATE tmp1;
		
	END LOOP cycle;
    CLOSE crs;
    SELECT * FROM tmp2;
END//
DELIMITER ;

-- проверка процедуры
CALL get_depth('2018-01-01');


USE matabalance;
DELIMITER //
DROP PROCEDURE IF EXISTS sp_act_logger//
CREATE PROCEDURE sp_act_logger()
/*процедура предназначена для просмотра отсортированных таблиц dns_hierarchy и pwr_dns 
с целью получения их них мероприятий; 
под мероприятиями понимаются моменты изменения 
- взаимосвязей (хранящихся в таблице dns_hierarchy)б 
- мощностей объектов по подготвке жидкости или нефти*/
BEGIN
	DECLARE pid TINYINT;	 -- previous id
    DECLARE cid TINYINT;	 -- current id
    DECLARE dt DATE;
    DECLARE old_p1 TINYINT DEFAULT 
    (SELECT dns_from FROM dns_hierarchy 
    ORDER BY dns_from, dns_to, `year` LIMIT 1);	 -- old parameter1 value
    DECLARE new_p1 TINYINT DEFAULT 0;	 -- new parameter1 value
    DECLARE old_p2 FLOAT DEFAULT 0;	 -- old parameter2 value
    DECLARE new_p2 FLOAT DEFAULT 0;	 -- new parameter2 value
    DECLARE old_p3 FLOAT DEFAULT 0;	 -- old parameter2 value
    DECLARE new_p3 FLOAT DEFAULT 0;	 -- new parameter2 value    
    
    DECLARE no_data TINYINT DEFAULT 0;
    DECLARE crs_h CURSOR FOR SELECT dns_from, dns_to, `year` FROM dns_hierarchy ORDER BY dns_from, dns_to, `year`;
	DECLARE crs_p CURSOR FOR SELECT dns_id, liq_pwr, liq_oil, `year` FROM pwr_dns ORDER BY dns_id, `year`;
    DECLARE CONTINUE HANDLER FOR NOT  FOUND SET no_data = 1;    
    
    TRUNCATE actions;
    
    OPEN crs_h;
    cycle_h: LOOP
		SET no_data = 0;
        FETCH crs_h INTO cid, new_p1, dt;
        IF no_data THEN ITERATE cycle_h;
        END IF;
        IF pid <> cid THEN
			SET pid = cid;
            SET old_p1 = new_p1;
		ELSE
			IF new_p1 = old_p1 THEN
				ITERATE cycle_h;
			ELSE 
				INSERT INTO actions (`table`, obj_id, parameter, `year`, old_val, new_val) VALUE ('dns_hierarchy', cid, 'relation', dt, old_p1, new_p1);
                SET old_p1 = new_p1;
                SET pid = cid;
			END IF; -- change detected
		END IF; -- id change detected
        SELECT * FROM actions;
	END LOOP cycle_h;
    CLOSE crs_h;
    
    SET pid = 0;
    SET old_p2 = 0;
    
    OPEN crs_p;
    cycle_p: LOOP
		SET no_data = 0;
		FETCH crs_p INTO cid, new_p2, new_p3, dt;
        IF no_data THEN ITERATE cycle_p;
        END IF;
        IF pid <> cid THEN
			SET pid = cid; 
			SET old_p2 = new_p2;
            SET old_p3 = new_p3;
            ITERATE cycle_p;
		ELSE
			IF new_p2 <> old_p2 THEN
				INSERT INTO actions (`table`, obj_id, parameter, `year`, old_val, new_val) VALUE ('pwr_dns', cid, 'liquid_power', dt, old_p2, new_p2);
                SET old_p2 = new_p2;
			END IF;
			IF new_p3 <> old_p3 THEN
				INSERT INTO actions (`table`, obj_id, parameter, `year`, old_val, new_val) VALUE ('pwr_dns', cid, 'oil_power', dt, old_p3, new_p3);
                SET old_p3 = new_p3;
			END IF;
		END IF; -- parameter's change found
        SELECT * FROM actions;
	END LOOP cycle_p;
    CLOSE crs_p;
END//
DELIMITER ;

CALL sp_act_logger;
SELECT * FROM dns;