-- This script performs various checks to ensure consistency and completeness of metadata collected in previous steps.
-- It compares counts and existence of tables, columns, and sequences across different metadata tables and logs any discrepancies 
-- in the cross_checking table for both Source and Target databases.

-- Check that the number of tables is consistent across rules 01, 02 in Source.
-- This query checks if the count of tables in metadata_02 matches with metadata_01
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-01' as issue_code,  'Error' as issue_type, 
       'Different table counts between rules 02 and 01.' title,
       'Find table counts: for rule 02 - ' || cnt_1 || ', for rule 01 - ' || cnt_2 || '.' as message,
       'Source' as direction
from
(
select count(*) as cnt_1, 
       (select object_count from src.metadata_01
         where object_type = 'TABLES') as cnt_2 
from src.metadata_02
) r where cnt_1 <> cnt_2;

-- Check that the number of tables is consistent across rules 01, 02 in Target.
-- This query checks if the count of tables in metadata_02 matches with metadata_01
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-01' as issue_code, 'Error' as issue_type, 
       'Different table counts between rules 02 and 01.' title,
       'Find table counts: for rule 02 - ' || cnt_1 || ', for rule 01 - ' || cnt_2 || '.' as message,
       'Target' as direction
from
(
select count(*) as cnt_1, 
       (select object_count from trg.metadata_01
         where object_type = 'TABLES') as cnt_2 
from trg.metadata_02
) r where cnt_1 <> cnt_2;

-- Check that the number of tables is consistent across rules 03, 01 in Source.
-- This query checks if the count of distinct tables in metadata_03 matches with metadata_01
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-02' as issue_code, 'Error' as issue_type, 
       'Different table counts between rules 03 and 01.' title,
       'Find table counts: for rule 03 - ' || cnt_1 || ', for rule 01 - ' || cnt_2 || '.' as message,
       'Source' as direction
from
(
select count(distinct schema_name || '|' || table_name) as cnt_1,
       (select object_count from src.metadata_01
         where object_type = 'TABLES') as cnt_2 
from src.metadata_03
) r where cnt_1 <> cnt_2;

-- Check that the number of tables is consistent across rules 03, 01 in Target.
-- This query checks if the count of distinct tables in metadata_03 matches with metadata_01
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-02' as issue_code, 'Error' as issue_type, 
       'Different table counts between rules 03 and 01.' title,
       'Find table counts: for rule 03 - ' || cnt_1 || ', for rule 01 - ' || cnt_2 || '.' as message,
       'Target' as direction
from
(
select count(distinct schema_name || '|' || table_name) as cnt_1,
       (select object_count from trg.metadata_01
         where object_type = 'TABLES') as cnt_2 
from trg.metadata_03
) r where cnt_1 <> cnt_2;

-- Check that all tables in rule 04 exist in rule 02 in Source
-- This query checks if all tables in metadata_04 exist in metadata_02.
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-03' as issue_code, 'Error' as issue_type, 
       'Table mismatch detected between rules 04 and 02' as title,
       'Table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Source' as direction
from
(
    select e.* from src.metadata_04 e
    where not exists
    (
        select 1 from src.metadata_02 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
    )
) r; 

-- Check that all tables in rule 04 exist in rule 02 in Target
-- This query checks if all tables in metadata_04 exist in metadata_02.
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-03' as issue_code, 'Error' as issue_type, 
       'Table mismatch detected between rules 04 and 02' as title,
       'Table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Target' as direction
from
(
    select e.* from trg.metadata_04 e
    where not exists 
    (
        select 1 from trg.metadata_02 i
		 where i.schema_name = e.schema_name
		   and i.table_name = e.table_name
    )
) r; 

-- Check that all columns in rule 04 exist in rule 03 in Source
-- This query checks if all columns in metadata_04 exist in metadata_03.
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-04' as issue_code, 'Error' as issue_type, 
       'Column mismatch detected between rules 04 and 03' as title,
       'Column ' || column_name || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Source' as direction
from
(
    select e.* from src.metadata_04 e
    where not exists (
        select 1 from src.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = e.column_name
    )
) r;

-- Check that all columns in rule 04 exist in rule 03 in Target
-- This query checks if all columns in metadata_04 exist in metadata_03.
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-04' as issue_code, 'Error' as issue_type, 
       'Column mismatch detected between rules 04 and 03' as title,
       'Column ' || column_name || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Target' as direction
from
(
    select e.* from trg.metadata_04 e
    where not exists (
        select 1 from trg.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = e.column_name
    )
) r;

-- Check that all sequences in rule 04 exist in rule 05 in Source
-- This query checks if all sequences in metadata_04 exist in metadata_05.
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-05' as issue_code, 'Error' as issue_type, 
       'Sequence mismatch detected between rules 04 and 05' as title,
       'Sequence ' || schema_name || '.' || sequence_name || ' is not specified.' as message,
       'Source' as direction
from
(
	select e.* from src.metadata_04 e
	where not exists
	(
	    select 1 from src.metadata_05 i
		 where i.sequence_name = e.sequence_name
	)
) r;

-- Check that all sequences in rule 04 exist in rule 05 in Target
-- This query checks if all sequences in metadata_04 exist in metadata_05.
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-05' as issue_code, 'Error' as issue_type,
       'Sequence mismatch detected between rules 04 and 05' as title,
       'Sequence ' || schema_name || '.' || sequence_name || ' is not specified.' as message,
       'Target' as direction
from
(
	select e.* from trg.metadata_04 e
	where not exists
	(
	    select 1 from trg.metadata_05 i
		 where i.sequence_name = e.sequence_name
	)
) r;


-- Check that all primary key columns in rule 06 exist in rule 03 in Source
-- This query checks if all primary key columns in metadata_06 exist in metadata_03.
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-06' as issue_code, 'Error' as issue_type, 
       'Column mismatch detected between rules 06 and 03' as title,
       'Primary key column ' || pkey || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Source' as direction
from
(
    select e.schema_name, e.table_name, pkey
    from src.metadata_06 e,
    lateral unnest(string_to_array(e.pk_column, ',')) AS pkey
    where not exists (
        select 1 from src.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = pkey
    )
) r;

-- Check that all primary key columns in rule 06 exist in rule 03 in Target
-- This query checks if all primary key columns in metadata_06 exist in metadata_03.
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-06' as issue_code, 'Error' as issue_type,
       'Column mismatch detected between rules 06 and 03' as title,
       'Primary key column ' || pkey || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Target' as direction
from
(
    select e.schema_name, e.table_name, pkey
    from trg.metadata_06 e,
    lateral unnest(string_to_array(e.pk_column, ',')) AS pkey
    where not exists (
        select 1 from trg.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = pkey
    )
) r;

-- Check that all foreign key child columns in rule 08 exist in rule 03 in Source
-- This query checks if all foreign key child columns in metadata_08 exist in metadata_03
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-07' as issue_code, 'Error' as issue_type,
       'Column mismatch detected between rules 08 and 03' as title,
       'Child column ' || child_column || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Source' as direction
from
(
    select
        e.schema_name,
        e.table_name,
        child_column
    from src.metadata_08 e,
    lateral unnest(string_to_array(e.child_columns, ',')) AS child_column
    where not exists (
        select 1 from src.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = child_column
    )
) r;


-- Check that all foreign key child columns in rule 08 exist in rule 03 in Target
-- This query checks if all foreign key child columns in metadata_08 exist in metadata_03.
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-07' as issue_code, 'Error' as issue_type,
       'Column mismatch detected between rules 08 and 03' as title,
       'Child column ' || child_column || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Target' as direction
from
(
    select
        e.schema_name,
        e.table_name,
        child_column
    from trg.metadata_08 e,
    lateral unnest(string_to_array(e.child_columns, ',')) AS child_column
    where not exists (
        select 1 from trg.metadata_03 i
         where i.schema_name = e.schema_name
           and i.table_name = e.table_name
           and i.column_name = child_column
    )
) r;

-- Check that all foreign key parent columns in rule 08 exist in rule 03 in Source
-- This query checks if all foreign key parent columns in metadata_08 exist in metadata_03
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-08' as issue_code, 'Error' as issue_type,
       'Column mismatch detected between rules 08 and 03' as title,
       'Parent column ' || pk_column || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Source' as direction
from
(
    select
        e.parent_schema as schema_name,
        e.parent_table as table_name,
        pk_column
    from src.metadata_08 e,
    lateral unnest(string_to_array(e.parent_columns, ',')) AS pk_column
    where not exists (
        select 1 from src.metadata_03 i
         where i.schema_name = e.parent_schema
           and i.table_name = e.parent_table
           and i.column_name = pk_column
    )
) r;

-- Check that all foreign key parent columns in rule 08 exist in rule 03 in Target
-- This query checks if all foreign key parent columns in metadata_08 exist in metadata_03
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-08' as issue_code, 'Error' as issue_type,
       'Column mismatch detected between rules 08 and 03' as title,
       'Parent column ' || pk_column || ' for table ' || schema_name || '.' || table_name || ' is not specified.' as message,
       'Target' as direction
from
(
    select
        e.parent_schema as schema_name,
        e.parent_table as table_name,
        pk_column
    from trg.metadata_08 e,
    lateral unnest(string_to_array(e.parent_columns, ',')) AS pk_column
    where not exists (
        select 1 from trg.metadata_03 i
         where i.schema_name = e.parent_schema
           and i.table_name = e.parent_table
           and i.column_name = pk_column
    )
) r;

-- Check that row counts from rule 10 match hashed row counts from rule 11 in Source
-- This query compares row counts from metadata_10 with counts of hashed rows from metadata_11
insert into src.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-09' as issue_code, 'Error' as issue_type,
       'Row count mismatch detected between rules 10 and 11' as title,
       'For table ' || rc.schema_name || '.' || rc.table_name || ' found total rows: ' || 
        rc.row_count || ', hashed rows: ' || coalesce(rh.row_count, 0) || '.' as message,
       'Source' as direction
from src.metadata_10 rc
left join (
	select schema_name, table_name, count(*) as row_count
	from src.metadata_11
	group by schema_name, table_name
) rh
on rh.schema_name = rc.schema_name
and rh.table_name = rc.table_name
where rc.row_count != coalesce(rh.row_count, 0);


-- Check that row counts from rule 10 match hashed row counts from rule 11 in Target
-- This query compares row counts from metadata_10 with counts of hashed rows from metadata_11
insert into trg.cross_checking(issue_code, issue_type, title, message, direction)
select 'ERR-09' as issue_code, 'Error' as issue_type,
       'Row count mismatch detected between rules 10 and 11' as title,
       'For table ' || rc.schema_name || '.' || rc.table_name || ' found total rows: ' || 
        rc.row_count || ', hashed rows: ' || coalesce(rh.row_count, 0) || '.' as message,
       'Target' as direction
from trg.metadata_10 rc
left join (
	select schema_name, table_name, count(*) as row_count
	from trg.metadata_11
	group by schema_name, table_name
) rh
on rh.schema_name = rc.schema_name
and rh.table_name = rc.table_name
where rc.row_count != coalesce(rh.row_count, 0);