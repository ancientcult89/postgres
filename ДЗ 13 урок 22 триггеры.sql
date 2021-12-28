--задаЄм схему по-умолчанию в рамках ƒ«
SET search_path = pract_functions, publ

CREATE OR REPLACE FUNCTION tf_good_sum_mart()
RETURNS trigger
AS
$triggerfnhotbody$
DECLARE
	_good_price float = 0.00; --цена за единицу, узнаЄм дл€ текущих обновлений good_sum_mart
	_goodName text = ''; -- наименование товара

	_data_row record; -- вот тут требуетс€ небольша€ подсказка, всегда ли требуетс€ в триггерной функции реализаци€ RETURN
	_summ float = 0.00; -- количество проданных единиц
BEGIN
    IF TG_LEVEL = 'ROW' then    	
        CASE TG_OP
            WHEN 'DELETE' THEN 
            	_data_row = OLD;
				--подт€нем в переменные _goodName, _good_price наименование и стоимость товара за единицу дл€ дальнейших расчетов
            	select g.good_name, g.good_price into _goodName, _good_price from goods g
            	where old.good_id = g.goods_id;
            	--RAISE notice '%, %', _goodName, _good_price; --отладочное
				--обновл€ем сумму с учЄтом "отмен€емой" продажи. если же записи в таблице по такому параметру нет - ошибки не будет, проблемы не вижу
				update good_sum_mart set sum_sale = sum_sale - (old.sales_qty * _good_price)
				where good_sum_mart.good_name = _goodName;
            WHEN 'UPDATE' THEN 
            	_data_row = NEW;
				--подт€нем в переменные _goodName, _good_price наименование и стоимость товара за единицу дл€ дальнейших расчетов
           		select g.good_name, g.good_price into _goodName, _good_price from goods g
            	where NEW.good_id = g.goods_id;
            	--RAISE notice '%, %', _goodName, _good_price; --отладочное
				--нужно проверить, есть ли уже в таблице-ветрине данные по текущей позиции
            	if (select 1 from good_sum_mart where good_sum_mart.good_name = _goodName) then
				--если данные нашли, то обновл€ем, минусу€ старое значение позиции и добавл€€ новое
					update good_sum_mart set sum_sale = sum_sale - (OLD.sales_qty * _good_price) + (NEW.sales_qty * _good_price)
					where good_sum_mart.good_name = _goodName;
				else
				--если данные не нашли, то т.к. триггер € вешаю на стейт AFTER, то запись уже подразумеваетс€ внесЄнна€, соотвентсвенно просто 
				-- получаем количество продаж по позиции и перемножаем на цену. результат уже вносим в таблицу-ветрину
					--RAISE notice 'damn';
					insert into good_sum_mart (good_name, sum_sale) values (
						_goodName
						,(select SUM(sales_qty) from sales s where good_id  = new.good_id)* _good_price);
				end if;
            WHEN 'INSERT' then
            	_data_row = NEW;
           		select g.good_name, g.good_price into _goodName, _good_price from goods g
            	where NEW.good_id = g.goods_id;            
				--RAISE notice '%, %', _goodName, _good_price;
				--raise notice '%', _data_row::text;
				
				--инсЄрт по своей сути похож логически на апдейт, за тем лишь исключением, что у нас нет старого значени€
				--и мы только добавл€ем
            	if (select 1 from good_sum_mart where good_sum_mart.good_name = _goodName) then
            		--RAISE notice 'bingo';
	            	update good_sum_mart set sum_sale = sum_sale + (NEW.sales_qty * _good_price)
					where good_sum_mart.good_name = _goodName;
				else
					--RAISE notice 'damn';
					insert into good_sum_mart (good_name, sum_sale) values (
						_goodName
						,(select SUM(sales_qty) from sales s where good_id  = new.good_id)* _good_price);
				end if;
        END CASE;
    END IF;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
    RETURN _data_row;
END;
$triggerfnhotbody$ LANGUAGE plpgsql;

drop trigger if exists tr_good_sum_mart on sales

CREATE TRIGGER tr_good_sum_mart
AFTER INSERT OR UPDATE OR delete     -- можно и BEFORE
ON sales
FOR EACH ROW
EXECUTE PROCEDURE tf_good_sum_mart();


--дл€ проверки работы триггера. в верхней части - таблица-витрина, в нижней - результат выполнени€ запроса. должно быть 100% совпадение при отработке триггера в рамках конкретной записи
select * from good_sum_mart gsm 
union all
select 'table^|query v', null
union all
SELECT G.good_name, sum(G.good_price * coalesce (S.sales_qty, 0))
FROM goods G
left JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

--скрипты дл€ тестировани€ работы тригера, после каждого выполнени€ проверить скриптом выше
--delete from sales where sales_id = 2 
--INSERT INTO sales (good_id, sales_qty) VALUES (1, 10); 
--update SALES set sales_qty = 3 where sales_id = 4