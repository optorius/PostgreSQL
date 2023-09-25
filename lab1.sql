-- 1.Выбрать список всех продуктов из первой категории (пиццы) по номеру категории .

select * from pd_products
where category_id = 1;


--2. Выбрать все продукты, в описании которых упоминается “Моцарелла”. Выборка должна содержать только наименование и описание.

select product_name, description from pd_products
where lower(description) like '%моцарелла%'


--3. Список домов по улицам Красноармейская и Кирова. Выборка должна представлять список адресов в 
--формате <название улицы>, дом <номер дома> кв. <номер квартиры>.

select distinct street || ', д.' || house_number || ', кв.' || apartment as Street from pd_locations
where lower(street) like '%красноармейская%'  or lower(street) like '%кирова%';


--4. Список всех острых или вегетарианских пицц с базиликом. Выборка должна содержать только
--наименование, описание, номер категории.

select product_name, description, products.category_id from pd_products as products
join pd_categories as categories
	on categories.category_id = products.category_id
where lower(category_name) = 'пицца' and (hot = '1' or vegan = '1') and lower(description) like '%базилик%';


/*
5. Список курьеров в именах, которых (неважно в какой части) есть одна или две “а”, и фамилия оканчивается “ва”. 
Для старших группы (ответственных) вывести  отметку с текстом “начальник”. 
Выборка должна содержать только один столбец: полное имя (фамилия, имя, отчество) и отметку. 
Все столбец должн быть поименован
*/

select distinct name || ' ' || last_name || ' ' || patronymic ||
(
	case
		when manager_id is null then ' - Начальник'
		else ''
	end
) as courier_name
from pd_employees
where 
lower(post) = 'курьер' and last_name like '%ва'
and 
lower(name || last_name || patronymic) not like '%а%а%а%';


/*
6. Список всех острых пицц стоимостью от 460 до 510, если пицц  при этом ещё и вегетарианская,
то стоимость может доходить до 560. Выборка должна содержать только наименование, 
цену и отметки об остроте и доступности для вегетарианцев. 
*/

select product_name, price, hot, vegan from pd_products
where hot = '1' and (price >= 460 and ((vegan = '1' and price <= 560) or price <= 510));


/*
7. Для каждого продукта рассчитать, на сколько процентов можно поднять цену,  
так что бы первая цифра цены не поменялась.
Выборка должна содержать только наименование, цену, процент повышения цены до 3-х 
знаков после запятой, размер возможного повышения с учётом копеек
и размер возможного повышения в рублях. 
*/

select product_name, price,
round ( (power (10,  trunc (log (price) ) ) - 0.001  
	  - 	( mod (price, power (10, trunc(log(price) ) ) ) )) / price * 100, 3) as procent,
trunc(((power(10, trunc(log(price)))) - 0.001 - mod(price, power(10, trunc(log(price)) ))) * 100) as kopecks,
trunc((power(10, trunc(log(price)))) - 0.001 - mod(price, power(10, (trunc(log(price)))))) as rubles
from pd_products;

/*
8. Дополнительная наценка (процент наценки уже заложен в цену) для острых продуктов составляет 1,5%,
для вегетарианских - 1%, для острых и вегетарианских - 2%.
Выбрать продукты, для которых цена без наценки не превышает 500 для пицц,
180 для сэндвич-роллов 60 для остальных.
Выборка должна содержать только наименование, описание, 
цену, цену без наценки (до 2-х знаков после запятой) 
и отметки об остроте и доступности для вегетарианцев. 
*/

select product_name, description, price, round(price * 
		(case
			when products.hot = '1' and products.vegan = '1'
		 							then 0.98
			when products.hot = '1' then 0.985
			when products.vegan = '1' then 0.99
			else 1
		end), 2)
		as real_price, hot, vegan
from pd_products as products
join pd_categories as categories on categories.category_id = products.category_id
where ((price * 
		case
		when products.hot = '1' and products.vegan = '1'
			then 0.98
		when products.hot = '1' then 0.985
		when products.vegan = '1' then 0.99
		else 1
		end)  <= (case when lower(categories.category_name) = 'пицца' then 500
		   			when lower(categories.category_name) = 'сэндвич-ролл' then 180
		   			else 60
		  			end))


--9.Список всех продуктов с их типами и описанием.
--Выборка должна содержать только тип (наименование 
									 --типа), название продукта и его описание. 
	   
select category_name, product_name, description from pd_categories
join pd_products on pd_categories.category_id = pd_products.category_id;


--10.Список всех продуктов, которых в одном заказе хотя бы раз было более 9 штук. Выборка должна 
--cодержать только наименование и цену. 

select distinct product_name, price from pd_order_details as order_details
join pd_products as products 
	on products.product_id = order_details.product_id
where quantity > 9


--11. Список всех заказчиков, заказывавших пиццу в октябрьском районе в сентябре или октябре. Выборка 
--должна содержать только полные имена одной стройкой.   

select  distinct name || ' ' ||  last_name || ' ' || patronymic as names_of_customers
from pd_orders as orders --берем заказы
join  pd_customers as customers 
	on orders.cust_id = customers.cust_id 
	  AND EXTRACT(MONTH FROM orders.order_date) between 9 and 10
join pd_locations as location 
	on location.location_id = orders.location_id 
		and lower(location.area) like 'октябрьский' 	
join pd_order_details as orderDetails 
	on orders.order_id = orderDetails.order_id
join pd_products as products 
	on orderDetails.product_id = products.product_id
join pd_categories as categories 
	on products.category_id = categories.category_id 
	and lower(categories.category_name) like 'пицца' 

--12. Список имён все страдников и с указанием имени начальника. Для начальников в соотв. cтолбце
--выводить – ‘шеф’. 

SELECT 
  DISTINCT one.name || ' ' || one.last_name || ' ' || one.patronymic
  as full_name_employee,
  case 
    when one.manager_id is NULL THEN 'Chief' 
    else 
      two.name || ' ' || two.last_name || ' ' || two.patronymic
  end as chief
    
from pd_employees as one
left join pd_employees as two on one.manager_id = two.emp_id;


--13. Список всех заказов, которые были доставлены под руководствам Барановой (или ей самой). В списке 
--также должны отображаться: номер заказа, имя курьера и район (‘нет’ – если район не известен).

select order_id, emp.name || ' ' || emp.last_name,
	case 
		when area is null then 'НЕТ'
		else area 
	end as area,
pd_locations.location_id
from pd_orders
join pd_locations on pd_locations.location_id = pd_orders.location_id
join pd_employees as emp on pd_orders.emp_id = emp.emp_id
left join pd_employees as newEmp on emp.manager_id = newEmp.emp_id 
where lower(emp.last_name) = 'баранова' OR lower(newEmp.last_name) = 'баранова';


--14. Список продуктов с типом, которые заказывали вмести с острыми
--или вегетарианскими пиццами в этом месяце.

select distinct second_categories.category_name, second_products.product_name, 
EXTRACT(MONTH FROM orders.order_date) 
as month from pd_orders as orders
join pd_order_details as orders_details
	on  orders_details.order_id = orders.order_id
		and extract(month from orders.order_date) = extract(month from current_date) 
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
