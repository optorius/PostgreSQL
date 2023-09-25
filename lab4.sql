/*
1. Написать функцию, возвращающую число доставленных заказов по номеру 
сотрудника за месяц. Все аргументы функции должны принимать определенной значение.
*/

create or replace function
	F1(_emp_id in integer, _date in varchar)
returns integer as $$
declare 
	txt_error text;
	count_orders integer;
	date_validation date;
BEGIN
	if _emp_id is null or _emp_id < 1 or _date is null then
		raise exception 'the argument(s) of function are invalid';
	end if;
	date_validation := to_date(_date, 'YYYY-MM');

	select
	count(*) from pd_orders as orders
	into count_orders
	where _emp_id = orders.emp_id
		 and _date = to_char(exec_date, 'YYYY-MM');
	return  count_orders;
exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;

END;
$$ language plpgsql;

/*
2. Написать функцию, возвращающую число доставленных заказов
под руководством сотрудника по его номеру за месяц. 
Все аргументы функции должны принимать определенной значение.
*/


create or replace function
	F2(_emp_id in integer, date in varchar)
returns integer as $$
declare
	txt_error text;
	count_orders integer;
	date_validation date;
begin
	if _emp_id is null or _emp_id < 1 or date is null then
		raise exception 'the argument(s) of function is(are) invalid';
	end if;
	date_validation := to_date(date, 'YYYY-MM');

	select count(*) from pd_orders as orders
	into count_orders 
	join pd_employees as employees
		on employees.emp_id = orders.emp_id
			and date = to_char(orders.exec_date, 'YYYY-MM')
	where employees.manager_id = _emp_id;
	return count_orders;
exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end;
$$ language plpgsql;


/*
3. Написать функцию, возвращающую общее число заказов за месяц. 
Все аргументы функции должны принимать определенной значение.

*/

create or replace function
	F3(date in varchar)
returns integer as $$
declare
	date_validation date;
	txt_error text; 
	count_orders integer;
begin
	if date is null then
		raise exception 'the argument(s) of function is(are) invalid';
	end if;
	date_validation := to_date(date, 'YYYY-MM');

	select count(*) from pd_orders as orders
	into count_orders
	where date = to_char(orders.exec_date, 'YYYY-MM');
	return count_orders;
exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end;
$$ language plpgsql;

-- 4. Написать функцию, выводящую насколько цена продукта 
--больше чем средняя цена в категории.

create or replace function
	F4(_product_id in integer)
returns numeric as $$
declare 
	txt_error text;
	price_differ numeric;
begin
	if _product_id is null or _product_id < 1 then
		raise exception 'the argument(s) of function is(are) invalid';
	end if;
	select round(abs(products.price - avg(second_products.price)), 2)
	into price_differ
	from pd_products as products
	join pd_products as second_products
		on second_products.category_id = products.category_id
	where products.product_id = _product_id
	group by products.price;
	return price_differ;
exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end;
$$ language plpgsql;	


/*5. Сформировать “открытку” с поздравлением всех изменников заранее заданного месяца:
“В <название месяца> мы поздравляем с днём рождения: <имя+фамили, имя+фамили> и <имя+фамили >”.*/

create or replace procedure P5(b_month date)
language plpgsql as
$$
declare
	emp_crs cursor
	is
	select case when rank = count then ' и '
				when rank > 1 then ', ' 
				else '' end || name
	from 
	(		
		select name || ' ' || last_name,
		rank() over(order by emp_id),
		count(*) over()
		from pd_employees
		where extract(month from birthday) = extract(month from b_month)
	) as temp(name,rank,count)
	order by rank;
	txt varchar(500);
	txt_1 varchar(500);
	date_validation date;
	txt_error text;
begin
	if b_month is null then
		raise exception 'the data is null';
	end if;
	date_validation := to_date(b_month, 'YYYY-MM');

	open emp_crs;
	txt:= 'В этом месяце ' || to_char(b_month, 'month')  || ', хотим поздравить следующих именинников:  ';
	loop
		fetch emp_crs into txt_1;	
		exit when not found;
		txt = txt || txt_1;
	end loop;
	txt:= txt || '.';
	raise notice '%', txt;
	exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end;
$$;



/*
6. Написать функцию, возвращающую максимальную общую стоимость заказа (не учитывать другие товары в заказе)
для заданного товара за указанный месяц года.
Если месяц не указан, выводить стоимость максимальную стоимость за всё время.
Параметры функции: месяц года (даты с точностью до месяца) и номер товара.
Для проверки напишите запрос: Список товаров с наименованиями и стоимостями за всё время и за сентябрь 2020 года.
*/


create or replace function
	F6( _product_id in integer, date in varchar)
returns integer as $$
declare 
	txt_error text;
	max_cost integer;
	date_format text;
	date_validation date;
begin 
	if _product_id is null or _product_id < 1 or date is null then
		raise exception 'the argument(s) of function is(are) invalid';
	end if;
	date_validation := to_date(date, 'YYYY-MM');
	
	date_format := 'YYYY-MM';
	if length(date) = 4 then 
		date_format := 'YYYY';
	end if;
	select max(order_details.quantity) * price into max_cost
	from pd_orders as orders
	join pd_order_details as order_details
		on order_details.order_id = orders.order_id
	join pd_products as products
		on products.product_id = order_details.product_id
	where date = to_char(orders.order_date, date_format) and _product_id = products.product_id
    group by price;
	return max_cost;
exception 
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end; 
$$ language plpgsql;


select product_id, F6(product_id, '2021') AS in_total_time, 
F6(product_id, '2021-03') AS in_march
from pd_products

/*
7. Написать функцию, возвращающую общую стоимость заказов сделанных заданным заказчиком за выбранный период.
Если заказчик не указан или не заданы границы периода, выводить сообщение об ошибке. 
Параметры функции: промежуток времени (две даты с точностью до месяца) и номер заказчика.
Для проверки написать соответствующие запросы. 
*/

create or replace function
	F7 (_cust_id in integer, from_date_1 in varchar, to_date_2 in varchar)
returns integer as $$
declare 
	total_cost integer;
	date_validation date;
	txt_error text;
begin
	if _cust_id is null or _cust_id < 1 or 
	from_date_1 is null or to_date_2 is null  then
		raise exception 'the argument(s) of function is(are) invalid';
	end if;
	if to_date(from_date_1, 'YYYY-MM') > to_date(to_date_2, 'YYYY-MM') then
		raise exception 'beginning date is greather than end of date';
	end if;
	date_validation := to_date(from_date_1, 'YYYY-MM');
	date_validation := to_date(to_date_2, 'YYYY-MM');
	select sum(price * quantity)
	into total_cost
	from pd_orders as orders
	join pd_order_details as order_details
		on order_details.order_id = orders.order_id
	join pd_products as products
		on products.product_id = order_details.product_id
	where _cust_id = orders.cust_id and orders.order_date between to_date(from_date_1, 'YYYY-MM') 
		and to_date(to_date_2, 'YYYY-MM');
	return total_cost;
exception 
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end; $$ language plpgsql;

select * from F7(1, '2021-01', '2021-03');
select * from F7(1, '2022-01', '2021-03');
select * from F7(1, '2021-30', '2021-03');
select * from F7(1, '2021-01', 'world');

/*
8. Написать процедуру формирующую список скидок по итогам заданного месяца 
(месяц считает от введенной даты). Условия: скидка 10% на самую часто заказываемую пиццу,
 скидка 5% на пиццу, которую заказали на самые большую сумму. 
 Формат вывода: наименование – новая цена, процент скидки.
*/

create or replace procedure P8(date_valid in date)
language plpgsql as 
$$
declare
	txt_error text;
	discount numeric(4,2);
	str varchar;
	product_crs cursor 
	is
	select products.product_name
		, products.price
		, rank() over (order by count(*) desc) as max_count
		, rank() over (order by max(products.price * order_details.quantity) desc) as max_cost
	from pd_orders as orders
	join pd_order_details as order_details 
		on order_details.order_id = orders.order_id
	join pd_products as products 
		on products.product_id = order_details.product_id
	inner join pd_categories as categories
		on categories.category_id = products.category_id
	where lower(categories.category_name) = 'пицца'
		and date_trunc('month', orders.order_date) = date_valid
	group by products.product_id, products.product_name, products.price;
begin
	if date_valid is null then
		raise exception 'date is null';
	end if;
	for i in product_crs loop
		discount := 0;
		if i.max_count = 1 then
			discount := discount + 0.1;
		end if;
		if i.max_cost = 1 then
			discount := discount + 0.05;
		end if;
		str:= i.product_name || ': ' || i.price * (1 - discount) || ' (' || discount * 100 || '%)';
		raise notice 'скидка: %',str;
	end loop;
exception
	when others then
		get stacked diagnostics txt_error = message_text;
       	raise notice '%', txt_error;
end 
$$
;

/*
9. Написать процедуру, создающую новый заказа как копию существующего заказа, 
чей номер – аргумент функции. Новый заказ должен иметь соответствующий статус.
*/

create or replace procedure P9(_order_id integer)
language plpgsql as
$$
declare
	order_id_valid integer;
	order_id_new integer;
begin
	
	if _order_id is null then
		raise exception 'the argument is invalid';
	end if;
	select count(*)
	into order_id_valid
	from pd_orders as orders
	where orders.order_id = _order_id;
	
	if order_id_valid = 0 then
		raise exception 'order_id in invalid';
	end if;

	select max(order_id) + 1
	into order_id_new
	from pd_orders;

	insert into pd_orders(order_id, emp_id, cust_id, location_id, card, order_comment, order_date, delivery_date, exec_date, order_state)
	select order_id_new, orders.emp_id, orders.cust_id, orders.location_id, orders.card, orders.order_comment, current_date, orders.delivery_date - orders.order_date + current_date, null, 'NEW'
	from pd_orders as orders
	where orders.order_id = _order_id;

	insert into pd_order_details(order_id, product_id, quantity)
	select order_id_new, order_details.product_id, order_details.quantity
	from pd_order_details as order_details
	where order_details.order_id = _order_id;
end;
$$;



--10. Написать один или несколько сценариев (анонимных блока) демонстрирующий работу процедур и функций из пп. 1-9.

do $$
begin
select * from F1(1, '2021-06'); --успешный  вывод
select * from F1(1, '2021-13'); --ошибка

select * from F2(1, '2021-03'); --успешный вывод 
select * from F2(-4, '2021-03');  --ошибка

select * from F3('2021-09'); -- успешный вывод
select * from F3(null); --ошибка

select * from F4(2);
select * from F4(-34); --ошибка

call P5(to_date('2021-09', 'YYYY-MM')); --успешный вывод
call P5(to_date(null, 'YYYY-MM')); -- ошибка
call P5(to_date('2021-09', 'YYYY')); --notice об ошибке

select product_name, F6(product_id, '2021-04') from pd_products; -- успешный вывод
select product_name, F6(null, '2021-04') from pd_products; -- ошибка
select product_name, F6(product_id, null) from pd_products; --ошибка

select * from F7(1, '2021-07', '2021-08');  --успешный вывод
select * from F7(1, '2021-08', '2021-05');--ошибка

call P8(to_date('2021-09', 'YYYY-MM')); --успешный вывод
call P8(to_date(null, 'YYYY-MM')); --notice об null
call P8(to_date('2k21', 'YYYY-MM')); --ошибка

call P9(100); --успешный вывод
call P9(null); --ошибка
end;
$$
