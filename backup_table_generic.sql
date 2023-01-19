
CREATE OR REPLACE
	FUNCTION flyway.backup_table()
	RETURNS TRIGGER
LANGUAGE plpgsql
AS $emp_stamp$
DECLARE
	create_sequence_backup TEXT;
	create_table_backup TEXT;
	insert_table_backup TEXT;
	alter_table_backup TEXT;
	pk_sequence TEXT;
	colunas record;
	colunas_insert TEXT;
BEGIN

	/* ------------------------------------------
		cria tabela de backup se ela não existir  */
		IF NOT EXISTS (SELECT * 
						FROM 
							information_schema."tables" t 
						WHERE 
							table_name = 'backup_' || TG_TABLE_NAME) THEN 
		
			pk_sequence := '''' || TG_TABLE_SCHEMA || '.backup_' || TG_TABLE_NAME || '_id_seq''';
							
			create_sequence_backup := 'create sequence if not exists ' || TG_TABLE_SCHEMA || '.backup_' || TG_TABLE_NAME || '_id_seq';
			EXECUTE create_sequence_backup;
		
			create_table_backup := 'create table if not exists ' || TG_TABLE_SCHEMA || '.backup_' || TG_TABLE_NAME || '(idkey_backup int8 NOT NULL DEFAULT nextval(' || pk_sequence || '::regclass) PRIMARY KEY,' || ' like ' || TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || ')';
			EXECUTE create_table_backup;
	
		END IF;
	
	/* ------------------------------------------ 
	 	string para adicionar coluna caso não exista  */
	
		alter_table_backup := 'alter table ' || TG_TABLE_SCHEMA || ' .backup_' || TG_TABLE_NAME || ' add column if not exists ';

	/*	verifica as colunas se houver alguma faltante na table backup, A retorna para o loop */
	FOR colunas IN (
					SELECT
						column_name 
					FROM 
						information_schema."columns"
					WHERE 
						table_name = TG_TABLE_NAME
						AND table_schema = TG_TABLE_SCHEMA
						AND column_name NOT IN (
													SELECT
														column_name
													FROM
														information_schema."columns"
													WHERE
														table_name = 'backup_' || TG_TABLE_NAME
														AND table_schema = TG_TABLE_SCHEMA ))
	
	LOOP
		
		EXECUTE alter_table_backup || colunas.column_name || ' ' || (
																	SELECT
																		data_type 
																	FROM 
																		information_schema."columns" 
																	WHERE
																		table_name = TG_TABLE_NAME
																		AND table_schema = TG_TABLE_SCHEMA
																		AND column_name = colunas.column_name
																	) || ' null';					
																
	END LOOP;
	
	/*	colunas da tabela a serem inseridas */
	FOR colunas IN (SELECT
						column_name 
					FROM 
						information_schema."columns"
					WHERE 
						table_name = TG_TABLE_NAME
						AND table_schema = TG_TABLE_SCHEMA
					ORDER BY ordinal_position desc)
	LOOP 	
		colunas_insert := concat(colunas.column_name, ', ',colunas_insert) ;
		
	END LOOP;

		colunas_insert := substring(colunas_insert,0, length(colunas_insert)-1);


 		insert_table_backup := 'insert into ' || TG_TABLE_SCHEMA || '.backup_' || TG_TABLE_NAME || '(' || colunas_insert || ')' || ' values (($1).*)';
		EXECUTE insert_table_backup USING OLD;

	RETURN OLD;
		
END $emp_stamp$;



CREATE TRIGGER backup_table BEFORE
DELETE
	ON
	geopdm.torressinal
    FOR EACH ROW EXECUTE FUNCTION flyway.backup_table();
