--Zero Copy Clone for instant dev,qa,uat sandboxes and backups
use role sysadmin;
drop database if exists finservam_dev;

create database finservam_dev clone finservam;
grant ownership on database finservam_dev to role finservam_admin;

use role finservam_admin;
use warehouse finservam_devops_wh;

--test against a random trader
set trader = (select top 1 trader from trader sample(1) where trader is not null);


//Clones are zero additional storage cost; storage cost is only on deltas; 
//ie if you have 10 TB in prod but change only 2 TBs in your clone, you only pay for 12 automatically compressed TBs
select *
from finservam.public.trade 
where trader = $trader and symbol = 'COST';

//we can change clones without impacting production
select *
from finservam_dev.public.trade 
where trader = $trader and symbol = 'COST';

update finservam_dev.public.trade
set symbol = 'CMG'
where trader = $trader and symbol = 'COST';


//we use Time Travel for DevOps & Rollbacks [configurable from 0-90 days]
set queryID = last_query_id(); 

//Currently Costco doesn't exist
select *
from finservam_dev.public.trade 
where trader = $trader and symbol = 'COST';

//But we can Time Travel to see before the (DML) delete
select *
from finservam_dev.public.trade 
before (statement => $queryid)
where trader = $trader and symbol = 'COST';

--roll back our our change
insert into finservam_dev.public.trade 
select *
from finservam_dev.public.trade 
before (statement => $queryid)
where trader = $trader and symbol = 'COST';


--Undrop is also up to 90 days of Time Travel; DBAs and Release Managers sleep much better than backup & restore
drop table finservam_dev.public.trade;

--uncomment this and watch it fail
-- select count(*) from finservam_dev.public.trade;

--but we can undrop for the time travel that we have set
undrop table finservam_dev.public.trade;

--we can also undrop databases
drop database if exists finservam_dev;

show databases like 'finserv%';

//notice temporary escalation of privileges in RBAC model
use role accountadmin;
undrop database finservam_dev;

use role finservam_admin;
show databases like 'finserv%';

//let's not wait for auto-suspend
alter warehouse finservam_devops_wh suspend;
use schema finservam.public;