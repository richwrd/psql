select tributech.validar_permissoes();

select tributech.validar_individual();

create sequence if not exists tributech.permissoes_individuais_id_seq;

create table if not exists tributech.permissoes_indi[viduais(
	idkey int8 not null default nextval('tributech.permissoes_individuais_id_seq'::regclass),
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
	constraint permissoes_individuais_usuarios_fk foreign key (idkey_usuario) references tributech.usuarios(idkey)
);


create or replace function tributech.validar_individual()
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
	
		---------------------<¤¤ GRANT / REVOKE ¤¤>-----------------------
	
			Usuario RECEBE permissões setadas APENAS como   >> TRUE  <<	
			Usuario PERDE permissões setadas APENAS como 	>> FALSE <<	
		
	
			->	select tributech.validar_individual();
		
		
		---------------------<¤¤     (• . •)     ¤¤>----------------------
	
						 		¤ by: richard ¤

=============================================================================*/
		
	if exists (select
				*
				from 
					tributech.permissoes_individuais t
				left join 
					tributech.usuarios u 
					on t.idkey_usuario = u.idkey
				where 
					t.validado is null
					or t.validado = false) then
						
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
							tributech.permissoes_individuais t
						left join 
							tributech.usuarios u 
							on t.idkey_usuario = u.idkey
						where 
							t.validado is null
							or t.validado = false)
		loop 
	
/*---------------------<¤¤ SELECT TRUE ¤¤>-----------------------*/
		
			/* se permissão de SELECT for autorizada */
			if(info_r.p_select) then
			
			/* permissão de usar o esquema antes das demais */
			execute format('GRANT USAGE ON SCHEMA %I TO %I', info_r.schema_nome, info_r.usuario_login);
				
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

/*---------------------<¤¤ SELECT FALSE ¤¤>-----------------------*/
				
			elseif(info_r.p_select = false) then 
			
					for recursiva_tables in (select
												t.table_name
											from 
												information_schema."tables" t 
											where 
												t.table_schema = info_r.schema_nome)
					loop 
						execute format('REVOKE ALL ON %I.%I FROM %I', info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
					end loop;

					for recursiva_sequencia in ( select
													s.sequence_name
												from 
													information_schema."sequences" s
												where
													s.sequence_schema = info_r.schema_nome)
					loop 
						execute format('REVOKE ALL ON %I.%I FROM %I', info_r.schema_nome,recursiva_sequencia.sequence_name, info_r.usuario_login);
					end loop;
				
				execute format('REVOKE USAGE ON SCHEMA %I FROM %I', info_r.schema_nome, info_r.usuario_login);
			
			end if;
		
		
/*---------------------<¤¤ INSERT TRUE ¤¤>-----------------------*/
		
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

/*---------------------<¤¤ INSERT FALSE ¤¤>-----------------------*/
				
			elseif(info_r.p_insert = false) then

				for recursiva_tables in (select
											t.table_name
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
				loop
					execute format('REVOKE INSERT ON %I.%I FROM %I', info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
				end loop;
			end if;
		


/*---------------------<¤¤ UPDATE TRUE ¤¤>-----------------------*/
		
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
	
/*---------------------<¤¤ UPDATE FALSE ¤¤>-----------------------*/		
				
			elseif(info_r.p_update = false) then 
				
				for recursiva_tables in (select 
											t.table_name
										from 
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
				loop
					execute format('REVOKE UPDATE ON %I.%I FROM %I', info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
				end loop;

				for recursiva_sequencia in (select 
												s.sequence_name
											from 
												information_schema."sequences" s
											where 
												s.sequence_schema = info_r.schema_nome)
				loop
					execute format('REVOKE USAGE ON %I.%I FROM %I', info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
					execute format('REVOKE UPDATE ON %I.%I FROM %I', info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
				end loop;
			end if;
		
		
/*---------------------<¤¤ DELETE TRUE ¤¤>-----------------------*/
		
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
	
/*---------------------<¤¤ DELETE FALSE ¤¤>-----------------------*/
				
			elseif(info_r.p_delete = false) then

				for recursiva_tables in (select
											t.table_name
										from
											information_schema."tables" t
										where 
											t.table_schema = info_r.schema_nome)
				loop
					execute format('REVOKE DELETE ON %I.%I FROM %I', info_r.schema_nome, recursiva_tables.table_name, info_r.usuario_login);
				end loop;			

				for recursiva_sequencia in (select
												s.sequence_name
											from 
												information_schema."sequences" s
											where 
												s.sequence_schema = info_r.schema_nome)
				loop
					execute format('REVOKE USAGE ON %I.%I FROM %I', info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);					
					execute format('REVOKE DELETE ON %I.%I FROM %I', info_r.schema_nome, recursiva_sequencia.sequence_name, info_r.usuario_login);
				end loop;
			end if;
	
		
			/* seta o campo validado como TRUE */ 
			update 
				tributech.permissoes_individuais 
			set 
				validado = true 
			where 
				idkey = info_r.idkey;
		
		/*fim do loop por schema*/
		end loop;
	
	/*fim do if */
		return 'Validado com SUCESSO!';	
	else
		return 'Todos usuários estão validados, não há nada a fazer.';	
	end if;

end; 
$function$;


/**/

create or replace function tributech.atualizar_validado()
 returns trigger
 language plpgsql
as $function$
begin
		new.validado := false;	
		new.r_owner  := current_user;
		new.datahora := now();
	
		if(new.p_select = false or new.p_select is null) then 
	
			new.p_select := false;
			new.p_insert := false;
			new.p_update := false;
			new.p_delete := false;
	
		end if;
	
		return new;
end;
$function$;


create trigger permissaoindividual_validado 
before
	insert or update of p_select, p_insert, p_update, p_delete
	on tributech.permissoes_individuais
for each row
	execute function tributech.atualizar_validado();
end;
