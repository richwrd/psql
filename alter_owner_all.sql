/*----------------------------------< FUNÇÃO ALTERAR USUARIO SUPERUSER -> SISTEMA >------------------------------------------*/

DROP FUNCTION tributech.alter_owner();

ALTER FUNCTION tributech.alter_owner OWNER TO MASTER;

SELECT tributech.alter_owner();

CREATE SCHEMA tributech;

CREATE OR REPLACE FUNCTION tributech.alter_owner()
 RETURNS TEXT  
LANGUAGE plpgsql
AS $emp_stamp$
DECLARE
DECLARE
	schemas_r record;
	tables_r record;
	sequences_r record;
	views_r record;
	funcoes_r record;
BEGIN
/*===========================================================================
		
		---------------------<{ OWNER to MASTER }>-----------------------
	
			Entidades em seu nome passam a ser MASTER
		
			->	SELECT tributech.alter_owner();
			
			
		---------------------<{ Validacao do SCHEMA }>-----------------------
			
			Schema alterado recebe FALSE em tributech.permissoes_schema.validado
			
			-> SELECT tributech.validar_permissoes();
			
			Permite todos grupos cadastrados terem acesso a tabela.
		
		
		
		---------------------<{     (O . O)     }>----------------------
	
						 		* by: richard *

=============================================================================*/
	
	/* alterar owner to MASTER schemas */

	FOR schemas_r IN (
					SELECT 
						s.schema_name
					FROM 
						information_schema.schemata s
					WHERE 
						s.schema_name NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
						AND s.schema_owner ~~ current_user)
	LOOP
		
		RAISE NOTICE '|--<{SCHEMA}>---<[ % ]>--|', schemas_r.schema_name;
		
		EXECUTE format('alter schema %s owner to MASTER', schemas_r.schema_name);
		EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', schemas_r.schema_name);
	
	END LOOP;
	
/* alterar owner to MASTER tabelas */


	FOR tables_r IN (
					SELECT
				    	pt.schemaname,
				    	pt.tablename
					FROM 
				    	pg_catalog.pg_tables pt
					WHERE
						pt.schemaname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
						AND pt.tableowner ~~ current_user)
	LOOP 
				
				RAISE NOTICE '|--<{TABELA}>---<[ %.% ]>--|', tables_r.schemaname, tables_r.tablename;
				
				EXECUTE format('alter table %s.%s owner to MASTER', tables_r.schemaname, tables_r.tablename);
				EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', tables_r.schemaname);
		
	END LOOP;

/* alterar owner to MASTER sequences */

	FOR sequences_r IN (
						SELECT 
							ps.schemaname,
							ps.sequencename
						FROM 
							pg_catalog.pg_sequences ps
						WHERE
							ps.schemaname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
							AND ps.sequenceowner ~~ current_user)
	LOOP
		
			RAISE NOTICE '|--<{SEQUENCE}>---<[ %.% ]>--|', sequences_r.schemaname, sequences_r.sequencename;
		
			EXECUTE format('alter sequence %s.%s owner to MASTER', sequences_r.schemaname, sequences_r.sequencename);
			EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', sequences_r.schemaname);
	
	END LOOP;
 

/* alterar owner to MASTER views */

	FOR views_r IN (
						SELECT 
							pv.schemaname,
							pv.viewname 
						FROM
							pg_catalog.pg_views pv
						WHERE 
							pv.schemaname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast', 'meta')
							AND pv.viewowner ~~ current_user)
	LOOP
	
			RAISE NOTICE '|--<{VIEW}>---<[ %.% ]>--|', views_r.schemaname, views_r.viewname;
		
			EXECUTE format('alter view %s.%s owner to MASTER', views_r.schemaname, views_r.viewname);
			EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', views_r.schemaname);
			EXECUTE format('update tributech.permissoes_view set validado = false where schema_name ~~ ''%s'' and p_select = TRUE', views_r.schemaname);
	
	END LOOP;

/* alterar owner to MASTER views */

	FOR funcoes_r IN (
					SELECT 
						pf.proname AS namefunction,
						ps.nspname AS schemaname
					FROM
						pg_catalog.pg_proc pf
					LEFT JOIN
						pg_catalog.pg_roles pr
						ON pr."oid" = pf.proowner
					LEFT JOIN 
						pg_catalog.pg_namespace ps
						ON ps."oid" = pf.pronamespace 
					WHERE 
						pr.rolname ~~ current_user
						AND pf.proname != 'alter_owner'
						AND ps.nspname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast'))
	LOOP
		
			RAISE NOTICE '|--<{FUNCTION}>---<{ %.% }>--|', funcoes_r.schemaname, funcoes_r.namefunction;
		
			EXECUTE format('alter function %s.%s owner to MASTER', funcoes_r.schemaname, funcoes_r.namefunction);
		
	END LOOP;

	RETURN 'Finalizado! :)';

END $emp_stamp$;



SELECT tributech.alter_owner();

SELECT tributech.validar_permissoes();


/*----------------------------------<  TESTING >------------------------------------------*/

DO $$
DECLARE 
	tables_r record;
	x int;
BEGIN 
	x := 1;
	
	FOR tables_r IN (
					SELECT
				    	pt.schemaname,
				    	pt.tablename
					FROM 
				    	pg_catalog.pg_tables pt
					WHERE
						pt.tableowner ~~ 'MASTER')
	LOOP 
		RAISE NOTICE 'Tabela % -> %s', x, tables_r.tablename;
		
		x := x+1;
	END LOOP;

END $$;



/*----------------------------------< TRIGGER (A HOMOLOGAR) >------------------------------------------*/
--FAZER 


DROP FUNCTION tributech.alter_owner();

create or replace function tributech.alter_owner_t()
 RETURNS TRIGGER  
language plpgsql
as $emp_stamp$



DECLARE
	schemas_r record;
	tables_r record;
	sequences_r record;
BEGIN
	
	/* alterar owner to MASTER schemas */

	FOR schemas_r IN (
					SELECT 
						s.schema_name
					FROM 
						information_schema.schemata s
					WHERE 
						s.schema_name NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
						AND s.schema_owner ~~ current_user)
	LOOP
		RAISE NOTICE 'Schema ( % )', schemas_r.schema_name;
		
		EXECUTE format('alter schema %s owner to MASTER', schemas_r.schema_name);
	END LOOP;
	
/* alterar owner to MASTER tabelas */

	FOR tables_r IN (
					SELECT
				    	pt.schemaname,
				    	pt.tablename
					FROM 
				    	pg_catalog.pg_tables pt
					WHERE
						pt.schemaname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
						AND pt.tableowner ~~ current_user)
	LOOP 
		RAISE NOTICE 'Tabela ( %.% )', tables_r.schemaname, tables_r.tablename;
		
		EXECUTE format('alter table %s.%s owner to MASTER', tables_r.schemaname, tables_r.tablename);
		EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', tables_r.schemaname);
	END LOOP;

/* alterar owner to MASTER sequences */

	FOR sequences_r IN (
						SELECT 
							ps.schemaname,
							ps.sequencename
						FROM 
							pg_catalog.pg_sequences ps
						WHERE
							ps.schemaname NOT IN ('public', 'tiger', 'tiger_data', 'information_schema', 'topology', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'pg_toast')
							AND ps.sequenceowner ~~ current_user)
	LOOP
		RAISE NOTICE 'Sequencia ( %.% )', sequences_r.schemaname, sequences_r.sequencename;
		
		EXECUTE format('alter sequence %s.%s owner to MASTER', sequences_r.schemaname, sequences_r.sequencename);
		EXECUTE format('update tributech.permissoes_schema set validado = false where schema_name ~~ ''%s'' and (recursivo_select = TRUE OR recursivo_update = TRUE OR recursivo_delete = TRUE) ', sequences_r.schemaname);
	
	END LOOP;

END $emp_stamp$;

