/*1. Увеличить стоимость всех десертов на 5%, новая цена не должна содержать копеек (копейки отбросить, а не округлить)*/
update pd_products
set price = trunc(price * 1.05)
where category_id = 
(
	select category_id from pd_categories
	where lower(category_name) = 'десерты'
);

/*2. Для всех заказов, для которых указано время исполнения заказа (EXEC_DATE) выставить статус “ доставлен” (“END”)*/
update pd_orders
set order_state = 'END'
where exec_date is not null;

/*3. Модифицировать схему базы данных так, что бы для каждого сотрудника можно было хранить несколько телефонных номеров и комментарий для каждого номера. Заполните новую таблицу/таблицы и удалите лишние столбцы.*/
create table pd_phones
(
	emp_id integer not null references pd_employees(emp_id),
	phone varchar(100) not null,
	description varchar(500) default null,
	
	constraint phones_phone_key unique(phone),
	constraint pk_phohes primary key(emp_id)
)

insert into pd_phones(emp_id, phone)
(	
	select emp_id, phone from pd_employees 
	where phone is not null
);

alter table pd_employees
drop phone

/*4. Модифицировать схему базы данных так, что бы должности сотрудников хранились в отдельной таблице, и не осталось избыточных данных.*/
create table pd_posts
(
	post_id integer not null,
	post varchar(100) not null,
	constraint  pk_posts primary key(post_id)
);

insert into pd_posts(post_id, post)
(
	select row_number()	over(order by post), post 
	from (select distinct post from pd_employees) base
);

alter table pd_employees
add post_id integer,
add	 constraint
	fk_employees_posts foreign key (post_id) references pd_posts(post_id);

update pd_employees as employees
set post_id =
(
	select post_id from pd_posts as posts
	where posts.post = employees.post
);

alter table pd_employees
drop  post;

/*5. Модифицировать схему базы данных так, что бы наименования районов хранились в отдельной таблице, и не осталось избыточных данных.*/
create table pd_areas
(
	area_id integer not null,
	area varchar(100) not null,
	constraint pk_areas primary key(area_id)
);

insert into pd_areas(area_id, area)
(
	select row_number()	over(order by area), area 
	from (select distinct area from pd_locations where area is not null) base
);

alter table  pd_locations
add area_id integer,
add constraint 
	fk_locations_areas foreign key (area_id) references pd_areas(area_id);

update pd_locations as locations
set area_id =  
(
	select area_id from pd_areas as areas
	where locations.area =  areas.area
);

alter table pd_locations
drop area;

/*6. Модифицировать схему базы данных таким образом, чтобы при удалении заказа удалялись все его позиции. Удалите все записи об отменённых заказах. */
alter table pd_order_details
add constraint fk_order_details_orders
foreign key (order_id) references pd_orders(order_id) on delete cascade;

delete from pd_orders
where lower(order_state) = 'cancel';

/*7. Добавьте ограничение целостности, гарантирующие исполнение условия: все продукты в заказе должны содержаться в базе. */
alter table pd_order_details
add constraint fk_pd_order_details_products
	foreign key (product_id) references pd_products(product_id);

/*8. Добавьте ограничение целостности, гарантирующие исполнение условия: начальником может быть только реально существующий сотрудник.*/
alter table pd_employees
add constraint fk_employees_manager
	foreign key (manager_id) references pd_employees(emp_id)

/*9. Добавьте ограничения целостности, гарантирующие следующих исполнение условия: наименования категории, наименования продуктов, имена сотрудников, имена заказчиков, названия районов, названия улиц, номера домов не могут быть пустыми.*/
alter table pd_categories
add constraint check_categories_name
check (category_name != ''); --ограничение только на пустую строку, т.к. для c_name по умолчанию not null

alter table pd_products			
add constraint check_products_name 
check (product_name != '')

alter table pd_employees
add constraint check_employees_fullname
check(name != '' and last_name != '' and patronymic != '');

alter table pd_customers
add constraint check_customers_fullname
check(name != '' and last_name != '' and patronymic != '');

alter table pd_areas
add constraint check_areas_area
check(area != '');

alter table pd_locations
add constraint check_locations_street
check(street != ''),
add constraint check_locations_house_number
check(house_number != '');

/*10. Добавьте ограничения целостности, гарантирующие следующих исполнение условия: поля “острая” и “вегетарианская” могут принимать только значения 1 или 0; 
количество любого продукта в заказе не может быть отрицательным или превышать 100; cрок, к которому надо доставить заказ, не может превышать дату и время заказа, заказ не может быть доставлен до того как его сделали; цена товара не может быть отрицательной или нулевой.*/
alter table pd_products
add constraint check_products_kind
check (vegan in ('1', '0') and hot in ('1', '0')),
add constraint check_products_price
check (price > 0);

alter table pd_order_details
add constraint check_order_details_quanity
check (quantity between 0 and 100);

alter table pd_orders
add constraint check_products_delivery_date
check (order_date <= coalesce(nullif(delivery_date, null), order_date) 
	   and order_date <= coalesce(nullif(exec_date, null), order_date)); --т.к. delivery_date 
	   --и exec_date могут быть null;
