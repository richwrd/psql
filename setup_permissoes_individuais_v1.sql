
create sequence schema.permissoes_individuais_id_seq;

create table schema.permissoes_individuais(
	idkey int8 not null default nextval('schema.permissoes_individuais_id_seq'::regclass),
	idkey_usuario int8 null,
	apelido text null,
	schema_nome text null,
	p_select bool NULL,
	p_insert bool NULL,
	p_update bool NULL,
	p_delete bool NULL,
	r_owner text NULL,
	datahora timestamp NULL DEFAULT now(),
	validado bool NULL,
	constraint permissoes_individuais_pk primary key (idkey),
	constraint permissoes_individuais_usuarios_fk foreign key (idkey_usuario) references schema.usuarios(idkey)
);


/*										VERSAO 1.0					  				*/


create or replace function schema.validar_individual_v1(opcao text)
	returns text 
language plpgsql
as $function$
	declare
		info_r record;
		recursiva_tables record;
		recursiva_sequencia record;
	begin
/*===========================================================================
		
					Permissão em schema por usuario
	exemplo:
	
		---------------------<¤¤ GRANT ¤¤>-----------------------
	
			Usuario recebe permissões setadas como >> TRUE <<	
		
	
			->	select schema.validar_individual('grant');
		
		
		---------------------<¤¤ REVOKE ¤¤>----------------------
	

				Usuario perde permissões setadas como >> FALSE <<	
		
		
			->	select schema.validar_individual('revoke');
			
		---------------------------------------------------------
						 	¤ by: richard ¤
			
								(• . •)
		
=============================================================================*/
		
		/* verifica opcao digitada pelo usuario */
	if(opcao ~~ 'grant') then 
		
		for info_r in (select
							t.idkey,
							t.idkey_usuario,
							u.usuario_login,
							t.schema_nome,
							t.p_select,
							t.p_insert,
							t.p_update,
							t.p_delete,
							t.r_owner,
							t.datahora,
							t.validado
						from 
							schema.permissoes_individuais t
						left join 
							schema.usuarios u 
							on t.idkey_usuario = u.idkey
						where 
							t.validado is null
							or t.validado = false)
		loop
			/* permissão de usar o esquema antes das demais */
			execute format('GRANT USAGE ON SCHEMA %I TO %I', info_r.schema_nome, info_r.usuario_login);
			
			
			/* se permissão de SELECT for autorizada */
			if(info_r.p_select) then
				
				/*	select em todas tabelas do schema dado */
				for recursiva_tables in (select
											t.table_name 
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas tabelas encontradas no schema */						
						execute format('GRANT SELECT ON %I.%I TO %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
					end loop;
				
				
				/*	select em todas sequencias do schema dado */
				for recursiva_sequencia in (select
												s.sequence_name
											from
												information_schema."sequences" s
											where 
												s.sequence_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas sequencias encontradas no schema */						
						execute format('GRANT USAGE ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						execute format('GRANT SELECT ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
					
					end loop;
			end if;
		
	
			/*se permissão de INSERT for autorizada*/
			if(info_r.p_insert) then
				
				/*	select em todas tabelas do schema dado */
				for recursiva_tables in (select
											t.table_name 
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas tabelas encontradas no schema */						
						execute format('GRANT INSERT ON %I.%I TO %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
					end loop;
			end if;
		
		
		
			/*se permissão de UPDATE for autorizada*/
			if(info_r.p_update) then
				
				/*	select em todas tabelas do schema dado */
				for recursiva_tables in (select
											t.table_name 
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas tabelas encontradas no schema */						
						execute format('GRANT UPDATE ON %I.%I TO %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
					end loop;
				
				
				/*	select em todas sequencias do schema dado */
				for recursiva_sequencia in (select
												s.sequence_name
											from
												information_schema."sequences" s
											where 
												s.sequence_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas sequencias encontradas no schema */						
						execute format('GRANT USAGE ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						execute format('GRANT UPDATE ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
					
					end loop;
			end if;
		
		
			/*se permissão de DELETE for autorizada*/
			if(info_r.p_delete) then
				
				/*	select em todas tabelas do schema dado */
				for recursiva_tables in (select
											t.table_name 
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas tabelas encontradas no schema */						
						execute format('GRANT DELETE ON %I.%I TO %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
					end loop;
				
				
				/*	select em todas sequencias do schema dado */
				for recursiva_sequencia in (select
												s.sequence_name
											from
												information_schema."sequences" s
											where 
												s.sequence_schema = info_r.schema_nome)
					loop
						/* da permissão pra todas sequencias encontradas no schema */						
						execute format('GRANT USAGE ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						execute format('GRANT DELETE ON %I.%I TO %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
					
					end loop;
			end if;
	
			/* seta o campo validado como TRUE */ 
			update schema.permissoes_individuais set validado = true where idkey = info_r.idkey;
		
		/*fim do loop por schema*/
		end loop;
	
	/*fim do if 'grant'*/
		return 'Validado com SUCESSO!';	
	end if;

		---------------------------------------------------------

		/* verifica opcao digitada pelo usuario */
	if(opcao ~~ 'revoke') then
	
		/* devolve 1 linha (até finalizar todas) com as informações que serão processadas*/
		for info_r in (select 
							r.idkey,
							r.idkey_usuario,
							u.usuario_login,
							r.schema_nome,
							r.p_select,
							r.p_insert,
							r.p_update,
							r.p_delete,
							r.r_owner,
							r.datahora,
							r.validado 
						from 
							schema.permissoes_individuais r 
						left join 
							schema.usuarios u
							on u.idkey = r.idkey_usuario
						where 
							r.validado is null
							or r.validado = false)
		
			loop 
				/* permissão de usar o esquema antes das demais */
				execute format('GRANT USAGE ON SCHEMA %I TO %I', info_r.schema_nome, info_r.usuario_login);

		
				/* se permissão de SELECT for retirada*/
				if(info_r.p_select is false) then
					
					/*	select em todas tabelas do schema dado */
					for recursiva_tables in (select
												t.table_name 
											from
												information_schema."tables" t
											where 
												t.table_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas tabelas encontradas no schema */						
							execute format('REVOKE SELECT ON %I.%I FROM %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
						end loop;
					
					
					/*	select em todas sequencias do schema dado */
					for recursiva_sequencia in (select
													s.sequence_name
												from
													information_schema."sequences" s
												where 
													s.sequence_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas sequencias encontradas no schema */						
							execute format('REVOKE USAGE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
							execute format('REVOKE SELECT ON %I.%I FROM %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						
						end loop;
				end if;
			
		
				/*se permissão de INSERT for retirada*/
				if(info_r.p_insert is false) then
					
					/*	select em todas tabelas do schema dado */
					for recursiva_tables in (select
												t.table_name 
											from
												information_schema."tables" t
											where 
												t.table_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas tabelas encontradas no schema */						
							execute format('REVOKE INSERT ON %I.%I FROM %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
						end loop;
				end if;
			
			
				/*se permissão de UPDATE for retirada*/
				if(info_r.p_update is false) then
					
					/*	select em todas tabelas do schema dado */
					for recursiva_tables in (select
												t.table_name 
											from
												information_schema."tables" t
											where 
												t.table_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas tabelas encontradas no schema */						
							execute format('REVOKE UPDATE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
						end loop;
					
					
					/*	select em todas sequencias do schema dado */
					for recursiva_sequencia in (select
													s.sequence_name
												from
													information_schema."sequences" s
												where 
													s.sequence_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas sequencias encontradas no schema */						
							execute format('REVOKE UPDATE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						
						end loop;
				end if;
			
			
				/*se permissão de DELETE for autorizada*/
				if(info_r.p_delete is false) then
					
					/*	select em todas tabelas do schema dado */
					for recursiva_tables in (select
												t.table_name 
											from
												information_schema."tables" t
											where 
												t.table_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas tabelas encontradas no schema */						
							execute format('REVOKE DELETE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
						
						end loop;
					
					
					/*	select em todas sequencias do schema dado */
					for recursiva_sequencia in (select
													s.sequence_name
												from
													information_schema."sequences" s
												where 
													s.sequence_schema = info_r.schema_nome)
						loop
							/* retira permissão pra todas sequencias encontradas no schema */						
							execute format('REVOKE USAGE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
							execute format('REVOKE DELETE ON %I.%I FROM %I',  info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
						
						end loop;
				end if;
		
			/* seta o campo validado como TRUE */ 
			update schema.permissoes_individuais set validado = true where idkey = info_r.idkey;
		
		/*fim do loop por schema*/
		end loop;
				
		return 'Validado com SUCESSO!';	
	
	elseif opcao != '' then
	
		return 'Opção inválida/incorreta!';	
	end if;
end;
$function$;
