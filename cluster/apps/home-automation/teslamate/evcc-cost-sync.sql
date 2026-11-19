-- Overwrites TeslaMate home-charge costs with evcc's per-session prices.
--
-- psql -v evcc_file=<evcc /api/sessions JSON> -v apply=true|false -f this.sql
-- Without apply=true it reports and rolls back. Safe to re-run.
--
-- evcc sessions don't map 1:1 onto charging_processes: TeslaMate splits one
-- charge into several rows, and the ChargeHQ history imported into evcc is
-- in whole-hour windows. So each session's price is split across the rows
-- it overlaps, weighted by each row's energy that falls inside the window.
-- Rows no session overlaps keep TeslaMate's flat-rate cost.
\set ON_ERROR_STOP on
\set evcc_json `cat :evcc_file`
begin;

create temp table evcc_raw on commit drop as select :'evcc_json'::jsonb as j;

-- Original costs, captured once per row and never overwritten.
create table if not exists evcc_cost_backup (
  charging_process_id integer primary key,
  cost numeric(14,2),
  backed_up_at timestamptz not null default now()
);

create temp table ev on commit drop as
select row_number() over () as sid,
       (s->>'created')::timestamptz as a,
       (s->>'finished')::timestamptz as b,
       (s->>'price')::numeric as price,
       case when s->>'identifier' like 'chargehq-import:%' then 'chargehq' else 'evcc' end as src
  from evcc_raw, jsonb_array_elements(j) s
 where s->>'price' is not null
   and s->>'finished' not like '0001-%'
   and (s->>'finished')::timestamptz > (s->>'created')::timestamptz;

-- TeslaMate stores naive UTC.
create temp table tm on commit drop as
select cp.id, cp.cost,
       cp.start_date at time zone 'UTC' as a,
       cp.end_date at time zone 'UTC' as b,
       coalesce(cp.charge_energy_added, 0) as e
  from charging_processes cp
  join geofences g on g.id = cp.geofence_id and g.name = 'Home'
 where cp.end_date is not null and cp.end_date > cp.start_date;

create temp table w on commit drop as
select ev.sid, ev.price, ev.src, tm.id,
       tm.e * extract(epoch from least(tm.b, ev.b) - greatest(tm.a, ev.a))
            / extract(epoch from tm.b - tm.a) as wt
  from ev join tm on tm.a < ev.b and tm.b > ev.a;

create temp table alloc on commit drop as
select id, min(src) as src,
       round(sum(case when tot > 0 then price * wt / tot else 0 end), 2) as cost
  from (select *, sum(wt) over (partition by sid) as tot from w) x
 group by id;

insert into evcc_cost_backup (charging_process_id, cost)
select tm.id, tm.cost from tm join alloc using (id)
on conflict (charging_process_id) do nothing;

\echo '### home charges by era: old cost vs evcc cost'
select coalesce(a.src, 'unmatched') as era, count(*) as charges,
       sum(tm.e) as kwh, sum(tm.cost) as old_cost, sum(a.cost) as new_cost
  from tm left join alloc a using (id)
 group by 1 order by 1;

\echo '### evcc sessions with no TeslaMate charge to land on (price not carried over)'
select src, count(*) as sessions, round(sum(price), 2) as price
  from ev
 where sid not in (select sid from w group by sid having sum(wt) > 0)
 group by 1;

\echo '### by year'
select extract(year from tm.a)::int as year, sum(tm.cost) as old_cost,
       sum(coalesce(a.cost, tm.cost)) as new_cost
  from tm left join alloc a using (id)
 group by 1 order by 1;

update charging_processes cp
   set cost = a.cost
  from alloc a
 where cp.id = a.id and cp.cost is distinct from a.cost;

\if :apply
commit;
\else
\echo '### dry run, rolling back'
rollback;
\endif
