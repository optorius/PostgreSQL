
/* 
1. Написать триггер, активизирующийся при изменении содержимого таблицы «Orders» и проверяющий, 
чтобы срок доставки был больше текущего времени не менее чем на 30 минут.
Если время заказа не указано автоматически должно проставляться текущее время, если срок доставки не указан,
то он автоматически должен ставиться на час позже времени заказа. 
*/

create or replace function TR1_trigger_definiton() 
returns trigger 
as $TR1_trigger_definiton$
begin 
	
	if new.order_date is null then
		new.order_date = current_timestamp;
	end if;
	if new.delivery_date is null then
		new.delivery_date = current_timestamp + interval '1h';
	elsif new.delivery_date < current_timestamp + interval '30m' then
		raise exception 'delivery_date is invalid: less then 30 minutes';
	end if;
	new.order_date = date_trunc('second', new.order_date);
	new.delivery_date = date_trunc('second', new.delivery_date);
	return new;
end; $TR1_trigger_definiton$ language plpgsql;

drop trigger if exists TR1_trigger on pd_orders;
create trigger TR1_trigger
before insert on pd_orders
for each row execute function TR1_trigger_definiton();

--insert order where order_date is null:
insert into pd_orders(order_id, emp_id, cust_id, location_id, card, order_date, delivery_date, exec_date
							 , order_state)
values
	(9, 18, 208, 239, 0, null, current_timestamp + '2h', null, 'NEW' );
	
select * from pd_orders
where order_id = 9;

delete from pd_orders
where order_id = 9;

--insert order where  delivery_date is null
insert into pd_orders(order_id, emp_id, cust_id, location_id, card, order_date, delivery_date, exec_date
							 , order_state)
values
	(10, 18, 208, 239, 0, current_timestamp, null, null, 'NEW' );
	
select * from pd_orders
where order_id = 10;

delete from pd_orders
where order_id = 9;

--insert order where delivery_date is less than 30 minutes:
insert into pd_orders(order_id, emp_id, cust_id, location_id, card, order_date, delivery_date, exec_date
							 , order_state)
values
	(8, 18, 208, 239, 0, current_timestamp, current_timestamp + interval '25m', null, 'NEW' );
	
---------------------------------------------------------------------------

/*
2. Написать триггер, автоматически меняющий статус заказа 
на “ доставлен” (“END”) если выставляется дата исполнения заказа 
(EXEC_DATE) и на “доставляется” (EXEC) если назначается курьер.
*/
language
create or replace function TR2_trigger_definition()
returns trigger
as $TR2_trigger_definition$
begin
  if new.exec_date is not null and old.emp_id is not null then
    new.order_state = 'END';
	return new;
  end if;
  
  if new.emp_id is not null and old.exec_date is null then
    new.order_state = 'EXEC';
  end if;
  return new;
end; $TR2_trigger_definition$ language plpgsql;

drop trigger if exists TR2_trigger on pd_orders;
create trigger TR2_trigger
before update on pd_orders
for each row
execute function TR2_trigger_definition();

--назначим курьера для заказа
--у 134 заказа emp_id null 
select * from pd_orders
where emp_id is null
order by order_id;

update pd_orders 
set emp_id  = 1 
where order_id = 134

select * from pd_orders
where order_id = 134

update pd_orders
set exec_date = date_trunc('second', current_timestamp)
where order_id = 134

select * from pd_orders
where order_id = 134
-----------------------------------------------

/*
3. Написать триггер, сохраняющий статистику изменений таблицы «EMPLOYEES» в таблице (таблицу создать),
 в которой хранятся номер сотрудника дата изменения,
 тип изменения (insert, update, delete). 
 Триггер также выводит на экран сообщение с указанием количества дней прошедших со дня последнего изменения.
*/

drop table if exists pd_employees_statistics;
create table pd_employees_statistics
(
  stat_id serial not null,
  emp_id integer not null,
  change_date date not null,
  change_type varchar (10) not null,
  constraint pk_employees_statistics primary key (stat_id)
);

create or replace function TR3_definition()
returns trigger as $TR3_definition$
declare
  change_type varchar(10);
  last_change_date date;
begin
  if tg_op = 'INSERT' then
  	change_type := 'INSERT';
  end if;
  if tg_op = 'DELETE' then
  	change_type := 'DELETE';
  end if;
  if tg_op = 'UPDATE' then
  	change_type := 'UPDATE';
  end if;
  select max(change_date) from pd_employees_statistics 
  into last_change_date;
  if last_change_date is not null then
  	raise notice 'Количество дней с момента последнего изменения: %', (current_date - last_change_date);
  end if;
  insert into pd_employees_statistics 
  values (default, coalesce(new.emp_id, old.emp_id), current_date, change_type);
  return new;
end; $TR3_definition$ language plpgsql;

drop trigger if exists F3_trigger  on pd_employees;
create trigger F3_trigger
after delete or update or insert on pd_employees
for each row
execute function TR3_definition();

--------------------------------------------------------

/*

4. Добавить к таблице “ Orders ” не обязательное поле “ cipher”, 
которое должно заполняться автоматически согласно шаблону: <YYYYMMDD>- <номер район> - < номер заказа в рамках месяца>. 
Номера не обязательно должны соответствовать дате заказа, если район не известен, 
то “ номер района” равен 0.
Номера районов брать из созданного во второй лабораторной справочника.

*/

alter table pd_orders
add column  cipher varchar(150);

drop view  if exists view_orders;
create view view_orders as
select * from pd_orders;


create or replace function TR4_trigger_definition()
returns trigger as $TR4_trigger_definition$ 
declare 
  _area_id integer;
  _cipher varchar(150);
  _num_order integer;
begin
  select area_id
  into _area_id
  from pd_locations as locations
  where locations.location_id = new.location_id;

  select max(substring(pd_orders.cipher, '\d+$'))
  into _num_order
  from pd_orders
  where extract(month from pd_orders.order_date) = extract(month from new.order_date);
  _cipher = to_char(new.order_date, 'YYYYMMDD') || '-' ||  coalesce(_area_id, 0) || '-' || coalesce(_num_order + 1, 1);
  
  insert into pd_orders (order_id, emp_id, cust_id, location_id, 
        card, order_comment, order_date, delivery_date, exec_date,  order_state, cipher)
  values (new.order_id, new.emp_id, new.cust_id, new.location_id, 
        new.card, new.order_comment, new.order_date, new.delivery_date, new.exec_date, new.order_state, _cipher);
  
  new.order_date = date_trunc('second', new.order_date);
  new.delivery_date = date_trunc('second', new.delivery_date);
  return new;

end; $TR4_trigger_definition$ language plpgsql;

drop trigger if exists TR4_trigger on view_orders; 
create trigger TR4_trigger instead of insert on view_orders
for each row
execute function TR4_trigger_definition(); 

insert into view_orders (order_id, emp_id, cust_id, location_id, card, order_comment, order_date, delivery_date, exec_date, order_state)
values (9999, 1, 1, 10, 1, null, current_timestamp, null, null, 'EXEC');

select * from pd_orders
where order_id = 9999;

insert into view_orders (order_id, emp_id, cust_id, location_id, card, order_comment, order_date, delivery_date, exec_date, order_state)
values (10000, 1, 1, 10, 1, null, current_timestamp, null, null, 'EXEC');

select * from pd_orders
where order_id = 10000;

--area_id - null:
insert into view_orders (order_id, emp_id, cust_id, location_id, card, order_comment, order_date, delivery_date, exec_date, order_state)
values (10001, 1, 1, 26, 1, null, current_timestamp, null, null, 'EXEC');

select * from pd_orders
where order_id = 10001;

