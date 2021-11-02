USE matbalance;
-- запрос выводит доли кустов
SELECT 
	f.id AS field, 
	po.dns_id AS dns, 
	po.kns_fld_id AS kns, 
	po.id AS pad, 
	IF(b1.summO=0,0,po.q_oil/b1.summO) AS part_o,
	IF(b2.summL=0,0, pl.q_liq/b2.summL) AS part_l,
	IF(b3.summFld=0,0,pw.q_fld/b3.summFld) AS part_fld
FROM 
	`fields` AS f, 
    pads AS po 
	INNER JOIN 
		(SELECT pads.field_id, pads.dns_id, SUM(pads.q_oil) AS summO 
		FROM pads GROUP BY pads.field_id, pads.dns_id) AS b1
	ON (po.dns_id = b1.dns_id) AND (po.field_id = b1.field_id),
    pads AS pl 
    INNER JOIN 
		(SELECT pads.field_id, pads.dns_id, SUM(pads.q_liq) AS summL 
        FROM pads GROUP BY pads.field_id, pads.dns_id) AS b2
	ON (pl.dns_id = b2.dns_id) AND (pl.field_id = b2.field_id),
    pads AS pw
    INNER JOIN
		(SELECT pads.field_id, pads.kns_fld_id, SUM(pads.q_fld) AS summFld
        FROM pads GROUP BY pads.field_id, pads.kns_fld_id) AS b3
	ON (pw.kns_fld_id = b3.kns_fld_id) AND (pw.field_id = b3.field_id)
WHERE po.field_id = f.id AND po.field_id = pl.field_id AND po.field_id = pw.field_id AND po.id = pl.id AND po.id=pw.id;

-- вывод м-ий, кустов и их долей
SELECT 
	f.`name`, 
	po.`name`, 
	IF(b1.summO=0,0, po.q_oil/b1.summO) AS part_o,
	IF(b2.summL=0,0, pl.q_liq/b2.summL) AS part_l, 
	IF(b3.summFld=0,0, pw.q_fld/b3.summFld) AS part_fld
FROM 
	fields as f, 
	pads as po
INNER JOIN 
	(SELECT pads.id, pads.dns_id, SUM(pads.q_oil) AS summO
    FROM pads GROUP BY pads.field_id, pads.dns_id) AS b1
ON po.id = b1.id,
pads AS pl
INNER JOIN
	(SELECT pads.id, pads.dns_id, SUM(pads.q_liq) AS summL
    FROM pads GROUP BY pads.field_id, pads.dns_id) AS b2
ON pl.id = b2.id,
pads AS pw
INNER JOIN
	(SELECT pads.id, pads.kns_fld_id, SUM(pads.q_fld) as summFld
    FROM pads GROUP BY pads.field_id, pads.kns_fld_id) AS b3
ON pw.id = b3.id
WHERE f.id = po.field_id AND po.id = pl.id AND pl.id = pw.id;

/* запрос, показывающий взаимосвязи кустов и насосных,
 выводит название куста, название ДНС, куда он сдает продукцию
 и название КНС, с которой выполняется закачка */
SELECT 
	p.`name` AS 'куст',
    d.`name` AS 'ДНС', 
	k.`name` AS 'КНС'
FROM 
	dns AS d
    INNER JOIN
    pads AS p
    ON p.dns_id = d.id
    INNER JOIN
    kns AS k
    ON p.kns_fld_id = k.id; 

-- запрос выводит имена ДНС, количество подключенных к ним кустов и список этих кустов
SELECT 
	d.`name`,
    -- p.dns_id,
	COUNT(*) AS total,
	GROUP_CONCAT(p.id SEPARATOR ',') AS pads_list
FROM 
	dns AS d 
    INNER JOIN
    pads AS p
	ON d.id = p.dns_id
GROUP BY d.name
ORDER BY total DESC;
    
    
-- запрос, который для зазданной КНС выводит названия ДНС, к которым подключены кусты закачиваемые с этой КНС
SET @kns_id = 3;
SELECT 
	d.`name`
FROM 
	dns AS d
WHERE d.id IN 
	(SELECT dns_id FROM pads WHERE kns_fld_id = @kns_id);
    
-- запрос, который выводит маршрут перекачки от заданной днс до точки сдачи в заданный год
-- первоисточники 
-- https://overcoder.net/q/572/%D0%BA%D0%B0%D0%BA-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D1%82%D1%8C-mysql-%D0%B8%D0%B5%D1%80%D0%B0%D1%80%D1%85%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B8%D0%B9-%D1%80%D0%B5%D0%BA%D1%83%D1%80%D1%81%D0%B8%D0%B2%D0%BD%D1%8B%D0%B9-%D0%B7%D0%B0%D0%BF%D1%80%D0%BE%D1%81
-- https://qastack.ru/programming/20215744/how-to-create-a-mysql-hierarchical-recursive-query
-- https://habr.com/ru/post/43955/
-- https://coderoad.ru/20215744/%D0%9A%D0%B0%D0%BA-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D1%82%D1%8C-%D0%B8%D0%B5%D1%80%D0%B0%D1%80%D1%85%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B8%D0%B9-%D1%80%D0%B5%D0%BA%D1%83%D1%80%D1%81%D0%B8%D0%B2%D0%BD%D1%8B%D0%B9-%D0%B7%D0%B0%D0%BF%D1%80%D0%BE%D1%81-MySQL
SET @yr = '2019-01-01';
Set @dns = 5;
WITH RECURSIVE
	Rec(dns_from, dns_to) AS (
    SELECT dns_from, dns_to 
    FROM dns_hierarchy 
    WHERE `year` = @yr
    UNION ALL
    SELECT Rec.dns_from, h.dns_to
    FROM dns_hierarchy AS h 
    INNER JOIN  Rec 
    ON h.dns_from = Rec.dns_to
    WHERE h.`year` = @yr)
-- SELECT * FROM Rec WHERE dns_from = @dns;
SELECT 
	d1.`name` AS `from`,  d2.`name` AS `to` 
    FROM Rec AS r 
    INNER JOIN dns as d1 ON d1.id = r.dns_from 
    INNER JOIN dns AS d2 ON d2.id = r.dns_to
    WHERE r.dns_from = @dns;