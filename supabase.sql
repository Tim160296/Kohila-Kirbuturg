-- Käivita Supabase -> SQL Editor (uus, tühi projekt).
-- Kui vana supabase.sql on juba käivitatud, kustuta enne vanad tabelid (KUSTUTAB ka olemasolevad broneeringud!):
-- drop function if exists book_box(text,text,text,text,date,text); drop function if exists expire_bookings();
-- drop table if exists bookings; drop table if exists boxes; drop table if exists box_types;

create extension if not exists btree_gist;

create table box_types(
 code text primary key,
 name text not null,
 price_eur numeric(6,2) not null  -- hind kuus
);
insert into box_types(code,name,price_eur) values
 ('tava',   'TavaBOX',          30),
 ('xl',     'XL BOX',           40),
 ('riiul',  'Riiul',            20),
 ('riiul3', '3 riiuliga boks',  30);

create table boxes(
 id serial primary key,
 number int unique not null,
 type text not null references box_types(code)
);
-- NÄIDE: kui palju igat tüüpi on. MUUDA numbrid tegelikuks enne käivitamist.
insert into boxes(number,type) select n,'tava'   from generate_series(1,50)   n;
insert into boxes(number,type) select n,'xl'     from generate_series(51,70)  n;
insert into boxes(number,type) select n,'riiul'  from generate_series(71,90)  n;
insert into boxes(number,type) select n,'riiul3' from generate_series(91,100) n;

create table bookings(
 id uuid primary key default gen_random_uuid(),
 box_id int not null references boxes(id),
 name text not null, phone text not null, email text not null, note text,
 start_date date not null, end_date date not null,
 price_eur numeric(6,2) not null,   -- broneerimise hetke hind (hilisem hinnamuutus seda ei muuda)
 status text not null default 'ootel' check (status in ('ootel','makstud','aegunud','tuhistatud')),
 pay_method text check (pay_method in ('sularaha','arve')),
 hold_until timestamptz not null, paid_at timestamptz, created_at timestamptz default now(),
 -- sama boks ei saa kattuvatel kuupäevadel olla korraga ootel/makstud (kaitseb topeltbroneeringu eest)
 exclude using gist (box_id with =, daterange(start_date,end_date) with &&) where (status in ('ootel','makstud'))
);

-- Ligipääs ainult serverifunktsioonidest (poliitikaid pole meelega)
alter table box_types enable row level security;
alter table boxes enable row level security;
alter table bookings enable row level security;

create function expire_bookings() returns void language sql as $$
 update bookings set status='aegunud' where status='ootel' and hold_until < now(); $$;

create function book_box(p_name text,p_phone text,p_email text,p_type text,p_start date,p_note text)
returns table(booking_id uuid, box_number int, end_date date, hold_until timestamptz, price_eur numeric)
language plpgsql as $$
declare v_box int; v_price numeric; v_id uuid; v_end date := (p_start + interval '1 month')::date;
 v_hold timestamptz := greatest(((p_start + time '18:00') at time zone 'Europe/Tallinn'), now() + interval '2 hours');
begin
 perform expire_bookings();
 select t.price_eur into v_price from box_types t where t.code = p_type;
 if v_price is null then raise exception 'bad_type'; end if;
 if p_start < (now() at time zone 'Europe/Tallinn')::date then raise exception 'past_date'; end if;
 select b.id into v_box from boxes b where b.type=p_type and not exists (
   select 1 from bookings k where k.box_id=b.id and k.status in ('ootel','makstud')
   and daterange(k.start_date,k.end_date) && daterange(p_start,v_end)) order by b.number limit 1;
 if v_box is null then raise exception 'full'; end if;
 insert into bookings(box_id,name,phone,email,note,start_date,end_date,price_eur,hold_until)
  values(v_box,p_name,p_phone,p_email,p_note,p_start,v_end,v_price,v_hold) returning id into v_id;
 return query select v_id,(select number from boxes where id=v_box),v_end,v_hold,v_price;
end $$;
