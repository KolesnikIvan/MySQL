USE matbalance;

/* представление показывает суммарные мощности по промысловой подготовке 
продукции скважин по регионам в удобной для пользователя форме 
(с названиями, а не идентификаторами) в 2019 году*/
CREATE OR REPLACE VIEW capacities (region, number_of_sites, total_power)
AS 
SELECT 
	r.`name`, 
    COUNT(*) AS num, 
    SUM(p.liq_pwr) AS pwr
FROM 
	regions AS r
    INNER JOIN 
    dns AS d
    ON d.reg_id = r.id
    INNER JOIN
    pwr_dns AS p
    ON p.dns_id = d.id
WHERE p.`year` = '2019-01-01'
GROUP BY r.`name`;

/*представление предназначено для демонстрации изменений суммарной мощности 
площадок подготовки (насосных) двух выбранных регионов в 2020..2023 годах*/
CREATE OR REPLACE VIEW power20_23 (region, pw_2020, pw_2021, pw2022, pw2023)
AS
SELECT 
	r.`name`, 
    SUM(p20.liq_pwr) AS p2020, SUM(p21.liq_pwr) AS p2021,
    SUM(p22.liq_pwr) AS p2022, SUM(p23.liq_pwr) AS p2023
FROM 
	regions AS r
    INNER JOIN 
    dns AS d
    ON d.reg_id = r.id
    INNER JOIN pwr_dns AS p20 ON d.id = p20.dns_id
    INNER JOIN pwr_dns AS p21 ON p21.dns_id = d.id
    INNER JOIN pwr_dns AS p22 ON p22.dns_id = d.id
    INNER JOIN pwr_dns AS p23 ON d.id = p23.dns_id
WHERE p20.`year` = '2020-01-01' AND p21.`year` = '2021-01-01'
AND p22.`year` ='2022-01-01' AND p23.`year` = '2023-01-01'
AND r.id IN ( 2, 5 )
GROUP BY r.`name`;
	