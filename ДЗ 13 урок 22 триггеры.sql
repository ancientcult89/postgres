--����� ����� ��-��������� � ������ ��
SET search_path = pract_functions, publ

CREATE OR REPLACE FUNCTION tf_good_sum_mart()
RETURNS trigger
AS
$triggerfnhotbody$
DECLARE
	_good_price float = 0.00; --���� �� �������, ����� ��� ������� ���������� good_sum_mart
	_goodName text = ''; -- ������������ ������

	_data_row record; -- ��� ��� ��������� ��������� ���������, ������ �� ��������� � ���������� ������� ���������� RETURN
	_summ float = 0.00; -- ���������� ��������� ������
BEGIN
    IF TG_LEVEL = 'ROW' then    	
        CASE TG_OP
            WHEN 'DELETE' THEN 
            	_data_row = OLD;
				--�������� � ���������� _goodName, _good_price ������������ � ��������� ������ �� ������� ��� ���������� ��������
            	select g.good_name, g.good_price into _goodName, _good_price from goods g
            	where old.good_id = g.goods_id;
            	--RAISE notice '%, %', _goodName, _good_price; --����������
				--��������� ����� � ������ "����������" �������. ���� �� ������ � ������� �� ������ ��������� ��� - ������ �� �����, �������� �� ����
				update good_sum_mart set sum_sale = sum_sale - (old.sales_qty * _good_price)
				where good_sum_mart.good_name = _goodName;
            WHEN 'UPDATE' THEN 
            	_data_row = NEW;
				--�������� � ���������� _goodName, _good_price ������������ � ��������� ������ �� ������� ��� ���������� ��������
           		select g.good_name, g.good_price into _goodName, _good_price from goods g
            	where NEW.good_id = g.goods_id;
            	--RAISE notice '%, %', _goodName, _good_price; --����������
				--����� ���������, ���� �� ��� � �������-������� ������ �� ������� �������
            	if (select 1 from good_sum_mart where good_sum_mart.good_name = _goodName) then
				--���� ������ �����, �� ���������, ������� ������ �������� ������� � �������� �����
					update good_sum_mart set sum_sale = sum_sale - (OLD.sales_qty * _good_price) + (NEW.sales_qty * _good_price)
					where good_sum_mart.good_name = _goodName;
				else
				--���� ������ �� �����, �� �.�. ������� � ����� �� ����� AFTER, �� ������ ��� ��������������� ��������, �������������� ������ 
				-- �������� ���������� ������ �� ������� � ����������� �� ����. ��������� ��� ������ � �������-�������
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
				
				--����� �� ����� ���� ����� ��������� �� ������, �� ��� ���� �����������, ��� � ��� ��� ������� ��������
				--� �� ������ ���������
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
AFTER INSERT OR UPDATE OR delete     -- ����� � BEFORE
ON sales
FOR EACH ROW
EXECUTE PROCEDURE tf_good_sum_mart();


--��� �������� ������ ��������. � ������� ����� - �������-�������, � ������ - ��������� ���������� �������. ������ ���� 100% ���������� ��� ��������� �������� � ������ ���������� ������
select * from good_sum_mart gsm 
union all
select 'table^|query v', null
union all
SELECT G.good_name, sum(G.good_price * coalesce (S.sales_qty, 0))
FROM goods G
left JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

--������� ��� ������������ ������ �������, ����� ������� ���������� ��������� �������� ����
--delete from sales where sales_id = 2 
--INSERT INTO sales (good_id, sales_qty) VALUES (1, 10); 
--update SALES set sales_qty = 3 where sales_id = 4