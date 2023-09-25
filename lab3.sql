/*
1. Найти среднюю стоимость пиццы с точность до второго знака
*/
select round(avg(price), 2) as avg_price_pizzas
from pd_products as products
join pd_categories as categories
	on products.category_id = categories.category_id
		and lower(categories.category_name) = 'пицца';

/*
2. Найти среднюю стоимость для каждой категории товара с точность до второго знака. Выборка должна содержать наименование категории и среднюю стоимость.
*/

select categories.category_name, round(avg(products.price), 2) as average_price
from pd_categories as categories
join pd_products as products 
	on products.category_id =  categories.category_id
group by categories.category_name;

/*
3. Для каждой из должностей найдите средний, максимальный и минимальный возраст сотрудников.
Выборка должна название должности и средний, максимальный и минимальный возраст, все столбцы должны быть подписаны
*/

select post,  
extract(year from min(age(current_date, birthday))) as min_year,
extract(year from max(age(current_date, birthday))) as max_year,
extract(year from avg (age(current_date, birthday))) as average_year
from pd_employees as employees
join pd_posts as posts
	on posts.post_id = employees.post_id
group by post;

/*
4.	Для каждого заказа посчитать сумму заказа. Выборка должна содержать номер заказа, сумму.
*/

select order_id, sum(round(price* quantity)) as total_price 
from pd_order_details as order_details
join pd_products as products 
	on order_details.product_id = products.product_id 
group by order_id
order by total_price desc; 

/*
5. Напишите запрос, выводящий следующие данные: номер заказа, 
имя курьера (одной строкой), имя заказчика (одной строкой), 
общая стоимость заказа, строк доставки, отметка о том был ли заказа доставлен вовремя.
*/

select distinct orders.order_id, employees.name || ' ' || employees.last_name || ' ' || employees.patronymic 
		as employee_fullname,
	customers.name || ' ' || customers.last_name || ' ' || customers.patronymic 
		as customer_fullname,
	    age(exec_date, order_date) as delivery_time,
		round(sum (quantity * price) over(partition by orders.order_id)) as full_price,
		(case 
		 	when delivery_date >= exec_date  then 1 else 0
		 end) as is_delivered_on_time
from pd_orders as orders
join pd_employees as employees
	on employees.emp_id = orders.emp_id
join pd_customers as customers
	on customers.cust_id = orders.cust_id
join pd_order_details as order_details 
	on order_details.order_id = orders.order_id
join pd_products as products
	on products.product_id = order_details.product_id
order by orders.order_id

/*
6. Напишите запрос, выводящий следующие данные для каждого месяца: 
общее количество заказов, процент доставленных заказов, 
процент отменённых заказов, общий доход за месяц (заказы в доставке и отменённые не учитываются,
на задержанные заказы предоставляется скидка в размере 15%).
*/

with base as
(
	select distinct orders.order_id,
	(
		case when exec_date is not null then
		sum(round(quantity * price)) *
		(
			case
				when exec_date > delivery_date then 0.85
				else 1
			end
		) else 0 end
	) as price,
	(
		case when lower(order_state) = 'cancel' then 1
		else 0 end
	) as order_canceled,
	exec_date, order_date
	from pd_orders as orders
	join pd_order_details as order_details
		on order_details.order_id = orders.order_id
	join pd_products as products
		on products.product_id = order_details.product_id
	group by orders.order_id
	
)
select  count(*) as count_orders,
round(count(exec_date) * 100 / count(*)) as orders_completed, -- count считает для не null
sum(order_canceled) * 100 / count(*) as orders_canceled,
sum(price) as cost,
to_char(order_date, 'YYYY-MM') as date
from base
group by date
order by date asc;

/*
7. Для каждого заказа посчитать сумму,
количество видов заказанных товаров, общее число позиций.
Вывести только заказы, сделанные в августе или сентябре и на сумму более 5000
*/

select orders.order_id, round(sum(quantity * price)) as total_price,
count (distinct products.category_id) as count_category,
count (*) as number_product
from pd_orders as orders
join pd_order_details as order_details
	on order_details.order_id = orders.order_id
join pd_products as products
	on products.product_id = order_details.product_id
where extract(month from orders.exec_date) in (8, 9)
group by orders.order_id
having (sum(quantity * price)) > 5000
order by orders.order_id

/*
8. Найти всех заказчиков, которые сделали заказ одного товара на сумму не менее 3000. 
Отчёт должен содержать имя заказчика, номер заказа и стоимость.
*/

select distinct on (full_name_customers)
orders.order_id,  round (sum (quantity * price)) as total_price,
customers.name || ' ' || customers.last_name || ' '  || customers.patronymic as full_name_customers
from pd_orders as orders
join pd_order_details as order_details
	on order_details.order_id = orders.order_id
join pd_products as products
	on products.product_id = order_details.product_id
join pd_customers as customers
	on customers.cust_id = orders.cust_id
group by orders.order_id, customers.cust_id	
having max (quantity * price ) >= 3000
order by full_name_customers

/*
9. Список продуктов с типом, которые заказывали вмести с 
острыми или вегетарианскими пиццами летом.
*/

select distinct second_categories.category_name, second_products.product_name
from pd_orders as orders
join pd_order_details as orders_details
	on  orders_details.order_id = orders.order_id
		and extract(month from orders.order_date) between 6 and 8 
join pd_order_details  as other_orders_details
	on other_orders_details.order_id = orders_details.order_id 
		and  other_orders_details.product_id <> orders_details.product_id
join pd_products as first_products
	on first_products.product_id = orders_details.product_id
join pd_products as second_products
	on second_products.product_id = other_orders_details.product_id
join pd_categories as first_categories
	on first_categories.category_id = first_products.category_id
join pd_categories as second_categories
	on second_categories.category_id = second_products.category_id
where lower(first_categories.category_name) = 'пицца' and (first_products.hot = '1' or first_products.vegan = '1')

/*
  10. Для каждого заказа, в котором есть хотя бы 1 острая пицца посчитать стоимость напитков. 
*/

select order_details.order_id, round(sum(second_products.price * other_order_details.quantity)) as total_price_drinks
    from pd_order_details as order_details
	join pd_products as products 
		on products.product_id = order_details.product_id
			and products.hot = '1'
	join pd_categories as categories
		on categories.category_id = products.category_id
			and lower(categories.category_name) = 'пицца'
	
	join pd_order_details as other_order_details
		on other_order_details.order_id = order_details.order_id
	join pd_products as second_products
		on second_products.product_id <> products.product_id
			and  other_order_details.product_id = second_products.product_id
	join pd_categories as second_categories
		on second_categories.category_id = second_products.category_id
			and lower(second_categories.category_name) = 'напитки'
group by order_details.order_id
order by order_details.order_id

/*
11. Найти курьера выполнившего вовремя наибольшее число заказов.
*/

with base as (
  select distinct employees.name || ' ' ||
	' ' || employees.last_name || ' '  || employees.patronymic as full_name_employee,
  count(*) as delivered_in_time_count
  from pd_orders as orders
  join pd_employees as employees
    on employees.emp_id = orders.emp_id
  where exec_date <= delivery_date
  group by(full_name_employee)
  order by delivered_in_time_count desc
)
select full_name_employee, delivered_in_time_count from  base
where base.delivered_in_time_count = (select max(base.delivered_in_time_count) from base);

/*
12. Для каждого месяца найти стоимость самого дорогого заказа.
*/

with base as
( 
	select (case when exec_date is null then 0 else round (sum(price * quantity)) end) as total_price, 
	order_date, exec_date
	from pd_orders as orders
	join pd_order_details as order_details 
		on order_details.order_id = orders.order_id
	join pd_products as products
		on products.product_id = order_details.product_id
	group by orders.order_id
)
select max(total_price) as max_cost,
to_char(order_date, 'YYYY-MM') as date
from base
group by date
order by date;

/*
13. Оформить запросы 6-8, как представления.
*/

create view view_sixth as
with base as
(
	select distinct orders.order_id,
	(
		case when exec_date is not null then
		sum(round(quantity * price)) *
		(
			case
				when exec_date > delivery_date then 0.85
				else 1
			end
		) else 0 end
	) as price,
	(
		case when lower(order_state) = 'cancel' then 1
		else 0 end
	) as order_canceled,
	exec_date, order_date
	from pd_orders as orders
	join pd_order_details as order_details
		on order_details.order_id = orders.order_id
	join pd_products as products
		on products.product_id = order_details.product_id
	group by orders.order_id
)
select  count(*) as count_orders,
round(count(exec_date) * 100 / count(*)) as orders_completed, -- count считает для не null
sum(order_canceled) * 100 / count(*) as orders_canceled,
sum(price) as cost,
to_char(order_date, 'YYYY-MM') as date
from base
group by date
order by date asc;

create view view_seventh as
select orders.order_id, round(sum(quantity * price)) as total_price,
count (distinct products.category_id) as count_category,
count (*) as number_product
from pd_orders as orders
join pd_order_details as order_details
	on order_details.order_id = orders.order_id
join pd_products as products
	on products.product_id = order_details.product_id
where extract(month from orders.exec_date) in (8, 9)
group by orders.order_id
having (sum(quantity * price)) > 5000
order by orders.order_id

create view view_eighth as
select distinct on (full_name_customers)
orders.order_id,  round (sum (quantity * price)) as total_price,
customers.name || ' ' || customers.last_name || ' '  || customers.patronymic as full_name_customers
from pd_orders as orders
join pd_order_details as order_details
	on order_details.order_id = orders.order_id
join pd_products as products
	on products.product_id = order_details.product_id
join pd_customers as customers
	on customers.cust_id = orders.cust_id
group by orders.order_id, customers.cust_id	
having max (quantity * price ) >= 3000
order by full_name_customers


drop view view_sixth;
drop view view_seventh;
drop view view_eighth;
