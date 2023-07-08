-- by Richard.
-- data: 30 de jun. de 2023


--/* PARA EXECUTAR -> */  SELECT audit.validate_log();

/*__________________________________________________________________________________________*/

	
--SELECT
--	ps.nspname AS "schema",
--	p.relname AS "table",
--	ld.command_dml AS comando,
--	ld.username AS usuario,
--	ld.datehour AS datahora,
--	ld.data_object AS dados
--FROM
--	audit.logging_dml ld 
--LEFT JOIN
--	pg_class p
--	ON p."oid" = ld.oid_table 
--LEFT JOIN 
--	pg_catalog.pg_namespace ps
--	ON p.relnamespace = ps."oid"
	
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
	
/*  CONTROLE DE ONDE VAI SER REGISTRADO OS DELETES  */
CREATE SEQUENCE IF NOT EXISTS audit.log_control_id_seq;
	

CREATE TABLE IF NOT EXISTS audit.log_control(
	idkey INT8 NOT NULL DEFAULT NEXTVAL('audit.log_control_id_seq'::REGCLASS),
	schema_name TEXT NULL,
	log_insert BOOL NULL,
	log_update BOOL NULL,
	log_delete BOOL NULL,
	r_owner TEXT NOT NULL DEFAULT CURRENT_USER,
	datehour TIMESTAMP NOT NULL DEFAULT NOW(),
	validated BOOL NULL,
	CONSTRAINT log_control_pk PRIMARY KEY (idkey)
);
	
/* função básica para dar update em 3 colunas importantes caso haja alguma modificação */
CREATE OR REPLACE FUNCTION audit.update_validated()
 RETURNS TRIGGER
 LANGUAGE plpgsql
AS $FUNCTION$
BEGIN
		NEW.validated := FALSE;	
		NEW.r_owner  := CURRENT_USER;
		NEW.datehour := NOW();
	
		RETURN NEW;
END;
$FUNCTION$;
	
/* trigger chamando a função acima caso haja alguma modificação na tabela log_control */
CREATE TRIGGER log_control_validated 
BEFORE
	INSERT OR UPDATE OF schema_name, log_insert, log_update, log_delete, r_owner
	ON audit.log_control
FOR EACH ROW
	EXECUTE FUNCTION audit.update_validated();
END;
	
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
	
/*	REGISTRO DE COMANDOS COMPLETO */
CREATE SEQUENCE IF NOT EXISTS audit.logging_dml_id_seq;
	
CREATE TABLE audit.logging_dml (
	idkey int8 NOT NULL DEFAULT nextval('audit.logging_dml_id_seq'::regclass),
	oid_table int8 NOT NULL,
	command_dml TEXT NOT NULL,
	username text NOT NULL DEFAULT CURRENT_USER,
	datehour timestamp NOT NULL DEFAULT NOW(),
	data_object JSONB NULL,
	CONSTRAINT pk_logging_dml PRIMARY KEY (idkey)
);
CREATE INDEX ipk_logging_dml ON audit.logging_dml USING btree (idkey); 
	
CREATE OR REPLACE FUNCTION audit.log_dml()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
	oid_rec int8;
	command TEXT;
	data_log JSONB;
BEGIN
/*===========================================================================

	 ---------------------<|    by: richard    |>-----------------------

=============================================================================*/
	
	oid_rec := TG_RELID;
	
		IF (TG_OP = 'INSERT') THEN
				
			data_log  := row_to_json(NEW.*);
			command := 'INSERT';
		
			INSERT INTO audit.logging_dml (oid_table, command_dml, data_object) VALUES
				(oid_rec, command, data_log);
			
			RETURN NEW;

		ELSEIF (TG_OP = 'UPDATE') THEN
			
			data_log := row_to_json(OLD.*);
			command := 'UPDATE';
		
			INSERT INTO audit.logging_dml (oid_table, command_dml, data_object) VALUES
				(oid_rec, command, data_log);
				
			RETURN NEW;
			
		ELSEIF (TG_OP = 'DELETE') THEN
		
			data_log := row_to_json(OLD.*);
			command := 'DELETE';
		
			INSERT INTO audit.logging_dml (oid_table, command_dml, data_object) VALUES
				(oid_rec, command, data_log);
				
			RETURN NULL;
		
		END IF;
END $function$;
	
	
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
/*__________________________________________________________________________________________*//*__________________________________________________________________________________________*/
	
/*__________________________________________________________________________________________*/
/* função que irá percorrer os schemas (e tabelas contidas) citados criando trigger de acordo com oque foi definido na tabela de controle*/
	
CREATE OR REPLACE FUNCTION audit.validate_log()
	RETURNS TEXT 
LANGUAGE plpgsql
AS $emp_stamp$
DECLARE
		info_r record;
		recursive_tables record;
		table_verify TEXT;
		trigger_exists bool;
	BEGIN
/*===========================================================================
		
		CRIA/DELETA LOG de comandos DML a partir de definições setadas em audit.log_control
			
---------------------<|            TRIGGERS            |>--------------------
---------------------<|    INSERT / UPDATE / DELETE    |>--------------------

			Tabelas RECEBE triggers setados 	APENAS como   >> TRUE  <<	
			Tabelas PERDE  triggers setados 	APENAS como   >> FALSE <<	
		
			->	select audit.validate_log();
		
          ---------------------<|    (O.0)    |>-----------------------
	
                                  by: richard 

=============================================================================*/

		IF EXISTS (SELECT
							lc.idkey,
							lc.validated
						FROM 	
							audit.log_control lc 
						WHERE
							lc.validated = FALSE
							OR lc.validated IS NULL)
		THEN
/*__________________________________________________________________*/
			/* LOOP P/ SCHEMA */
			FOR info_r IN (SELECT
									lc.idkey,
									lc.schema_name,
									lc.log_insert,
									lc.log_update,
									lc.log_delete,
									lc.r_owner,
									lc.datehour,
									lc.validated
								FROM 	
									audit.log_control lc 
								WHERE
									lc.validated = FALSE
									OR lc.validated IS NULL)
			LOOP
				
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				
				/*->>> LOG	INSERT TRUE*/
				
				IF(info_r.log_insert)THEN
					
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM 
															pg_catalog.pg_tables t
														WHERE 
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
					
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists  /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_insert'
							AND t.tgrelid = table_verify::regclass;

						/*	executa criacao do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists) THEN
							EXIT;
						ELSE 
							/* cria trigger na tabela */
							EXECUTE 'CREATE TRIGGER "log_insert"
								BEFORE  
									INSERT ON ' || 
										table_verify 
								|| ' FOR EACH ROW EXECUTE FUNCTION audit.log_dml();';

						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'INSERT LOG FROM ALL % HAS BEEN >> CREATED <<', info_r.schema_name;
				
				/*->>> LOG	INSERT FALSE*/
				
				ELSEIF (info_r.log_insert = FALSE) THEN
					
				
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM 
															pg_catalog.pg_tables t
														WHERE 
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
					
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_insert'
							AND t.tgrelid = table_verify::regclass;

						/*	executa DELETE do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists IS NOT NULL) THEN
							EXECUTE 'DROP TRIGGER "log_insert" ON ' || table_verify;
						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'INSERT LOG FROM ALL % HAS BEEN >> DELETED <<', info_r.schema_name;
				
				END IF;
			
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				
				/*->>> LOG	UPDATE TRUE*/
				
				IF(info_r.log_update)THEN
					
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM 
															pg_catalog.pg_tables t
														WHERE 
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
					
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists   /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_update'
							AND t.tgrelid = table_verify::regclass;

						/*	executa criacao do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists) THEN
							EXIT;
						ELSE 
		
										/* cria trigger na tabela */
							EXECUTE 'CREATE TRIGGER "log_update"
								AFTER  
									UPDATE ON ' || 
										table_verify 
								|| ' FOR EACH ROW EXECUTE FUNCTION audit.log_dml();';

						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'UPDATE LOG FROM ALL % HAS BEEN >> CREATED <<', info_r.schema_name;
				
				/*->>> LOG	UPDATE FALSE*/
				
				ELSEIF(info_r.log_update = FALSE) THEN
					
				
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM 
															pg_catalog.pg_tables t
														WHERE 
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
					
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists   /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_update'
							AND t.tgrelid = table_verify::regclass;

						/*	executa DELETE do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists) THEN
							EXECUTE 'DROP TRIGGER "log_update" ON ' || table_verify;
						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'UPDATE LOG FROM ALL % HAS BEEN >> DELETED <<', info_r.schema_name;
				
				END IF;
			
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
				
				/*->>> LOG	DELETE TRUE*/
				
				IF(info_r.log_delete)THEN
					
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM 
															pg_catalog.pg_tables t
														WHERE 
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
					
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists   /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_delete'
							AND t.tgrelid = table_verify::regclass;

						/*	executa criacao do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists) THEN
							EXIT;
						ELSE 
						
										/* cria trigger na tabela */
							EXECUTE 'CREATE TRIGGER "log_delete"
								AFTER  
									DELETE ON ' || 
										table_verify 
								|| ' FOR EACH ROW EXECUTE FUNCTION audit.log_dml();';

						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'DELETE LOG FROM ALL % HAS BEEN >> CREATED <<', info_r.schema_name;
				
				/*->>> LOG	DELETE FALSE*/
				
				ELSEIF(info_r.log_delete = FALSE) THEN
						
					/* LOOP em todas TABLES do SCHEMA dado */
					FOR recursive_tables IN (SELECT
														t.tablename
														FROM
															pg_catalog.pg_tables t
														WHERE
															schemaname = info_r.schema_name)
					LOOP 
						
						table_verify := CONCAT(info_r.schema_name , '.' , recursive_tables.tablename);
						trigger_exists := NULL;
						
						/* verifica se o trigger existe na tabela retornada pelo LOOP FOR*/
						SELECT 
							CASE
								WHEN t.tgname IS NOT NULL THEN TRUE
								ELSE FALSE
							END INTO trigger_exists   /* insere nome da trigger na variavel */
						FROM 
							pg_trigger t
						WHERE 
							t.tgconstraint = 0
							AND t.tgname = 'log_delete'
							AND t.tgrelid = table_verify::regclass;

						/*	executa DELETE do trigger na tabela retornada do laço FOR*/
						IF (trigger_exists) THEN
							EXECUTE 'DROP TRIGGER "log_delete" ON ' || table_verify;
						END IF;
						
					END LOOP;
				
					RAISE NOTICE 'DELETE LOG FROM ALL % HAS BEEN >> DELETED <<', info_r.schema_name;
				
				END IF;
				
			/* FIM LOOP P/ SCHEMA */
			END LOOP;
/*__________________________________________________________________*/
		
			/* seta o campo validado como TRUE */ 
			UPDATE 
				audit.log_control
			SET 
				validated = TRUE
			WHERE 
				idkey = info_r.idkey;

			RETURN 'TRIGGERS criado com SUCESSO!';	
	ELSE
		 	RETURN 'Todos SHEMAS estão validados, nao há nada a fazer.';	
	END  IF;
END $emp_stamp$;


/* PARA EXECUTAR -> */  SELECT audit.validate_log();




