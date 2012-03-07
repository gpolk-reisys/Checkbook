/* Functions defined
	stageandarchivedata
	validatedata	
	processdata
	isEligibleForConsumption
	errorhandler
	refreshaggregates
*/

CREATE FUNCTION concat(text, text) RETURNS text
    AS $$
  DECLARE
    t text;
  BEGIN
    IF  character_length($1) > 0 THEN
      t = $1 ||', '|| $2;
    ELSE
      t = $2;
    END IF;
    RETURN t;
  END;
  $$ language plpgsql;

CREATE AGGREGATE group_concat(text) (
    SFUNC = concat,
    STYPE = text,
    INITCOND = ''
);
-------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION etl.stageandarchivedata(p_load_file_id_in int) RETURNS INT AS $$
DECLARE
	l_data_source_code ref_data_source.data_source_code%TYPE;
	l_staging_table_array varchar ARRAY[15];
	l_array_ctr smallint;
	l_target_columns varchar;
	l_source_columns varchar;
	l_data_feed_table varchar;
	l_record_identifiers varchar ARRAY[15];
	l_insert_sql varchar;
	l_document_type_array varchar ARRAY[15];
	l_load_id bigint;
	l_archive_table_array varchar ARRAY[15];
	l_processed_flag etl.etl_data_load_file.processed_flag%TYPE;
	l_job_id etl.etl_data_load.job_id%TYPE;
	l_exception int;
	l_start_time  timestamp;
	l_end_time  timestamp;
	l_ins_staging_cnt int:=0;
	l_count int:=0;
BEGIN

	-- Initialize all the variables

	l_start_time := timeofday()::timestamp;
	
	l_data_source_code :='';
	l_target_columns :='';
	l_source_columns :='';
	l_data_feed_table :='';
	l_insert_sql :='';
	
	-- Determine the type of data load - F/V/A etc and assign it to l_data_source_code
	
	SELECT b.data_source_code , a.load_id,a.processed_flag,b.job_id
	FROM   etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id	       
	WHERE  a.load_file_id = p_load_file_id_in     
	INTO   l_data_source_code, l_load_id,l_processed_flag, l_job_id;	

	IF l_processed_flag ='N' THEN 
		SELECT staging_table_name
		FROM etl.ref_data_source
		WHERE data_source_code=l_data_source_code
		      AND table_order =1
		INTO l_data_feed_table;

		-- raise notice 'staging table %',l_data_feed_table;

		SELECT ARRAY(SELECT staging_table_name
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_staging_table_array;

		SELECT ARRAY(SELECT archive_table_name
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_archive_table_array;

		SELECT ARRAY(SELECT record_identifier
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_record_identifiers;	

		SELECT ARRAY(SELECT document_type
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_document_type_array;

		FOR l_array_ctr IN 1..array_upper(l_staging_table_array,1) LOOP
			RAISE NOTICE '%', l_staging_table_array[l_array_ctr];


			SELECT array_to_string(ARRAY(SELECT staging_column_name 
						     FROM etl.ref_column_mapping 
						     WHERE staging_table_name=l_staging_table_array[l_array_ctr]						   
						     ORDER BY column_order),',')
			INTO l_target_columns;

			-- raise notice 'target columns %', l_target_columns;

			SELECT array_to_string(ARRAY(SELECT (CASE WHEN staging_data_type in ('varchar','bpchar') THEN
								'TRIM(' || data_feed_column_name||')  AS ' || staging_column_name 
								WHEN staging_data_type = 'int' or staging_data_type = 'smallint' OR staging_data_type like 'numeric%' THEN
									CASE
										WHEN data_feed_data_type = staging_data_type THEN
											data_feed_column_name || ' AS ' || staging_column_name 
										ELSE	
											'(CASE WHEN ' || data_feed_column_name || ' ='''' THEN NULL ELSE  ' || data_feed_column_name || '::' || staging_data_type || ' END ) AS ' ||  staging_column_name 
									END
								WHEN staging_data_type = 'date' THEN
									'(case when ' || data_feed_column_name || ' ='''' THEN NULL ELSE '|| data_feed_column_name || '::date END ) AS ' || staging_column_name 
								WHEN staging_data_type = 'timestamp' THEN
									'(case when ' || data_feed_column_name || ' ='''' THEN NULL ELSE '|| data_feed_column_name || '::timestamp END ) AS ' || staging_column_name 
								WHEN staging_data_type = 'bit' THEN	
									'(CASE WHEN ' || data_feed_column_name || ' =''1'' THEN 1::bit ELSE 0::bit END)'
								ELSE
									data_feed_column_name || ' AS ' || staging_column_name
							END)	
							FROM etl.ref_column_mapping 
							WHERE staging_table_name=l_staging_table_array[l_array_ctr]
							ORDER BY column_order),',')	
			INTO l_source_columns;					

			-- raise notice 'source columns %', l_source_columns;

			l_insert_sql := 'INSERT INTO ' || l_staging_table_array[l_array_ctr] || '(' || l_target_columns || ')' ||
					'SELECT ' || l_source_columns ||
					' FROM ' || l_data_feed_table;				

			IF COALESCE(l_record_identifiers[l_array_ctr],'') <> '' THEN
				l_insert_sql := l_insert_sql || ' WHERE record_type = ''' || l_record_identifiers[l_array_ctr] || ''' ';
			END IF;

			IF COALESCE(l_document_type_array[l_array_ctr] ,'') <> '' THEN
				l_insert_sql := l_insert_sql || ' AND doc_cd IN (''' || replace (l_document_type_array[l_array_ctr],',',''',''') || ''') ';
			END IF;

			 raise notice 'l_insert_sql %',l_insert_sql;

			EXECUTE 'TRUNCATE ' || l_staging_table_array[l_array_ctr];

			EXECUTE l_insert_sql;				

		GET DIAGNOSTICS l_count = ROW_COUNT;

		l_ins_staging_cnt := l_count;

		INSERT INTO etl.etl_data_load_verification(load_file_id,data_source_code,record_identifier,document_type,num_transactions,description)
		VALUES(p_load_file_id_in,l_data_source_code,l_record_identifiers[l_array_ctr],l_document_type_array[l_array_ctr],l_ins_staging_cnt, 'staging');
		
			-- Archiving the records

			IF COALESCE(l_archive_table_array[l_array_ctr],'') <> ''  THEN

				RAISE NOTICE 'INSIDE';


				l_insert_sql :=  'INSERT INTO ' || l_archive_table_array[l_array_ctr] ||
						 ' SELECT *,' || p_load_file_id_in ||
						 ' FROM ' ||l_staging_table_array[l_array_ctr] ;

				-- RAISE NOTICE 'insert %',l_insert_sql;

				EXECUTE l_insert_sql;															

			END IF;
		END LOOP; 

	-- Updating the processed flag to S to indicate that the data is staged.	
	
	UPDATE  etl.etl_data_load_file
	SET	processed_flag ='S' 
	WHERE	load_file_id = p_load_file_id_in;
			
	END IF;

	l_end_time := timeofday()::timestamp;

	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time)
	VALUES(p_load_file_id_in,'etl.stageandarchivedata',1,l_start_time,l_end_time);
		
	RETURN 1;
	
EXCEPTION
	WHEN OTHERS THEN
	
	RAISE NOTICE 'Exception Occurred in stageandarchivedata';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	


	-- l_exception :=  etl.errorhandler(l_job_id,l_data_source_code,l_load_id,p_load_file_id_in);
	
	l_end_time := timeofday()::timestamp;
	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time,errno,errmsg)
	VALUES(p_load_file_id_in,'etl.stageandarchivedata',0,l_start_time,l_end_time,SQLSTATE,SQLERRM);
	
	RETURN 0;
	
END;
$$ language plpgsql;
--------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION etl.validatedata(p_load_file_id_in int) RETURNS INT AS $$
DECLARE
	l_data_source_code etl.ref_data_source.data_source_code%TYPE;
	l_rule	RECORD;
	l_update_str VARCHAR;
	l_insert_str VARCHAR;
	l_select_str VARCHAR;
	l_delete_str VARCHAR;
	l_all_uniq_id VARCHAR;
	l_min_uniq_id VARCHAR;
	l_where_clause VARCHAR;
	l_load_id bigint;
	l_staging_table_array varchar ARRAY[15];
	l_invalid_table_array varchar ARRAY[15];
	l_array_ctr smallint;	
	l_processed_flag etl.etl_data_load_file.processed_flag%TYPE;
	l_job_id etl.etl_data_load.job_id%TYPE;	
	l_exception int;
	l_start_time  timestamp;
	l_end_time  timestamp;
	l_record_identifiers varchar ARRAY[15];
	l_document_type_array varchar ARRAY[15];
	l_ins_invalid_cnt int:=0;
	l_count int:=0;
BEGIN

	-- Initialize the variables

	l_start_time := timeofday()::timestamp;
	
	l_update_str :='';
	l_insert_str :='';
	l_delete_str :='';
	l_select_str :='';
	l_all_uniq_id :='';
	l_min_uniq_id :='';
	l_where_clause :='';
	
	-- Determine the type of data load - F/V/A etc and assign it to l_data_source_code
	
	SELECT b.data_source_code , a.load_id,a.processed_flag,b.job_id
	FROM   etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id	       
	WHERE  a.load_file_id = p_load_file_id_in     
	INTO   l_data_source_code, l_load_id,l_processed_flag, l_job_id;	

	IF l_processed_flag = 'S' THEN
	
		CREATE TEMPORARY TABLE tmp_invalid_uniq_id(uniq_id bigint)
		DISTRIBUTED BY (uniq_id);

		For l_rule IN SELECT a.record_identifier,a.document_type,a.staging_table_name, b.rule_name,b.parent_table_name,
				     b.component_table_name,b.staging_column_name,b.transaction_table_name,b.ref_table_name,b.ref_column_name,
				     b.invalid_condition
			      FROM   etl.ref_data_source a, etl.ref_validation_rule b
			      WHERE  a.data_source_code = b.data_source_code
				     AND COALESCE(a.record_identifier,'')=COALESCE(b.record_identifier,'')
				     AND COALESCE(a.document_type,'')=COALESCE(b.document_type,'')
				     AND a.data_source_code=l_data_source_code
				     AND a.table_order>1
			      ORDER BY b.rule_order

		LOOP
			RAISE NOTICE 'rule name: %', l_rule.rule_name;
			RAISE NOTICE 'staging table name: %', l_rule.staging_table_name;
			-- Missing key elements		
			IF l_rule.rule_name = 'Missing key elements' THEN

				l_select_str :=  ' select array_to_string( ' || 
						 '	 array( ' || 
						 '		select (case when staging_data_type =''varchar'' then '' coalesce(''||staging_column_name||'','''''''')='''''''' '' ' || 
						 '			    when staging_data_type =''int'' or staging_data_type =''smallint'' or staging_data_type like ''numeric%'' then '' coalesce(''||staging_column_name||'',0)=0 '' ' || 
						 '			    when staging_data_type =''date'' then '' coalesce(''||staging_column_name||'',''''2000-01-01'''')=''''2000-01-01'''' '' ' || 
						 '		       end) as sql_condition ' || 
						 '		from etl.ref_column_mapping ' || 
						 '		where staging_table_name = ''' || l_rule.staging_table_name||''' ' || 
						 '			AND staging_column_name IN (''' || replace(l_rule.staging_column_name,',',''',''') ||''' )' ||
						 '		order by column_order )  ,''OR'') ';

				-- RAISE notice 'l_select_str %',l_select_str;
				EXECUTE l_select_str INTO l_where_clause;
				-- RAISE notice 'where %',l_where_clause;

				IF COALESCE(l_rule.invalid_condition,'') <> '' THEN
					l_where_clause := l_where_clause || 'OR (' || l_rule.invalid_condition || ')';
				END IF;

				l_update_str := 'UPDATE ' || l_rule.staging_table_name ||
						' SET invalid_flag = ''Y'', ' ||
						'	invalid_reason =''' || l_rule.rule_name || ''' ' ||
						'WHERE COALESCE(invalid_flag,'''')=''''  AND ' || l_where_clause ;		

				RAISE NOTICE 'l_update_str %',l_update_str;

				EXECUTE l_update_str;		
			END IF;

			-- Duplicate records

			IF l_rule.rule_name  IN ('Duplicate', 'Multiple') THEN
				--RAISE NOTICE 'select %', l_rule.staging_column_name;

				l_select_str := ' SELECT group_concat(all_uniq_id) as all_uniq_id, group_concat(min_uniq_id) as min_uniq_id ' ||
						' FROM ' || 
						' (SELECT ' || l_rule.staging_column_name || ',count(uniq_id) as num_records , min(uniq_id) as min_uniq_id, group_concat(uniq_id) as all_uniq_id' ||
						' FROM ' || l_rule.staging_table_name ||
						' GROUP BY ' || l_rule.staging_column_name ||
						' HAVING count(uniq_id) > 1 ) as a';

				--RAISE NOTICE 'select %', l_select_str;

				EXECUTE	l_select_str INTO l_all_uniq_id, l_min_uniq_id;

				IF COALESCE(l_all_uniq_id,'') <> '' THEN
					l_update_str := 'UPDATE '|| l_rule.staging_table_name ||
							' SET invalid_flag = ''Y'', ' ||
							'	invalid_reason =''' || l_rule.rule_name || ''' ' ||
							' WHERE uniq_id IN (' || l_all_uniq_id || ')' ;						

					-- Retain the least record for duplicates
					IF l_rule.rule_name ='Duplicate' THEN
						l_update_str := l_update_str || 
								' AND uniq_id NOT IN (' || l_min_uniq_id || ')';
					END IF;
					RAISE NOTICE 'l_update_str %',l_update_str;

					EXECUTE l_update_str;		
				END IF; 	
			END IF;



			IF l_rule.rule_name like 'Invalid%' THEN 


				EXECUTE 'TRUNCATE tmp_invalid_uniq_id ';

				-- Invalid Parent/Component		
				IF (COALESCE(l_rule.parent_table_name,'') <> '' OR COALESCE(l_rule.component_table_name,'') <> '' ) THEN


					RAISE NOTICE 'Inside invalid check 1.1';

					l_select_str :=  ' select array_to_string( ' || 
							 '	 array( ' || 
							 '		select (case when staging_data_type =''varchar'' then '' coalesce(a.''||staging_column_name||'','''''''') = coalesce(b.''||staging_column_name||'','''''''') '' ' || 
							 '			    when staging_data_type =''int'' or staging_data_type like ''numeric%'' then '' coalesce(a.''||staging_column_name||'',0) = coalesce(b.''||staging_column_name||'',0) '' ' || 
							 '			    when staging_data_type =''date'' then '' coalesce(a.''||staging_column_name||'',''''2000-01-01'''') = coalesce(b.''||staging_column_name||'',''''2000-01-01'''') '' ' || 
							 '		       end) as sql_condition ' || 
							 '		from etl.ref_column_mapping ' || 
							 '		where staging_table_name = ''' || l_rule.staging_table_name||''' ' ||
							 '			AND staging_column_name IN (''' || replace(l_rule.staging_column_name,',',''',''') ||''' )' ||
							 '		order by column_order )  ,''AND'') ';

					-- RAISE notice 'l_select_str %',l_select_str;
					EXECUTE l_select_str INTO l_where_clause;
					-- RAISE notice 'where %',l_where_clause;		

					l_insert_str := 'INSERT INTO tmp_invalid_uniq_id(uniq_id) '||
							' SELECT a.uniq_id ' ||
							' FROM ' || l_rule.staging_table_name ||' a JOIN ' || COALESCE(l_rule.parent_table_name,l_rule.component_table_name ) || ' b ' ||
							' ON ' || l_where_clause || 
							' WHERE b.invalid_flag =''Y''  '||
							'	AND b.invalid_reason <> ''Duplicate'' '||
							'	AND COALESCE(a.invalid_flag,'''')='''' ' ;
							
					IF l_insert_str <> COALESCE(l_rule.parent_table_name,l_rule.component_table_name )  THEN
						l_insert_str := l_insert_str || '	AND b.invalid_reason not like ''Invalid component -%'' ';
					END IF;


				ELSIF COALESCE(l_rule.ref_table_name,'') <> '' THEN
					RAISE NOTICE 'Inside invalid check 1.2';
					-- Invalid values (Not in the reference table )

					l_select_str :=  ' SELECT (CASE WHEN staging_data_type = ''varchar'' THEN ''COALESCE(''||staging_column_name||'','''''''') <> '''''''' '' '||
							 '	WHEN staging_data_type = ''int'' THEN ''COALESCE('' || staging_column_name || '',0) <> 0 ''   END) '||
							 '	FROM etl.ref_column_mapping '||
							 '	WHERE staging_table_name=''' || l_rule.staging_table_name || ''' '||
							 '	AND staging_column_name=''' || l_rule.staging_column_name || ''' '; 

					EXECUTE l_select_str INTO l_where_clause;

					l_where_clause := l_where_clause || ' AND ' || l_rule.staging_column_name || ' NOT IN (SELECT ' || l_rule.ref_column_name || 
											'	  FROM ' || l_rule.ref_table_name || ' ) ';

					l_insert_str := 'INSERT INTO tmp_invalid_uniq_id(uniq_id) '||
							' SELECT uniq_id ' ||
							' FROM ' || l_rule.staging_table_name ||
							' WHERE COALESCE(invalid_flag,'''')='''' AND ' || l_where_clause ;		

				ELSE
					-- Inconsistent values. Invalid condition must definitely have a value
					RAISE NOTICE 'Inside inconsistent';
					l_where_clause := l_rule.invalid_condition;										


					l_insert_str := 'INSERT INTO tmp_invalid_uniq_id(uniq_id) '||
							' SELECT uniq_id ' ||
							' FROM ' || l_rule.staging_table_name ||
							' WHERE COALESCE(invalid_flag,'''')='''' AND ' || l_where_clause ;		

				END IF;	


				RAISE notice 'l_insert_str %',l_insert_str;		
				EXECUTE l_insert_str;

				l_update_str := 'UPDATE ' || l_rule.staging_table_name || ' a' ||
						' SET invalid_flag = ''Y'', ' ||
						'	invalid_reason =''' || l_rule.rule_name || ''' ' ||
						' FROM tmp_invalid_uniq_id b ' || 
						'WHERE a.uniq_id = b.uniq_id ' ;		

				EXECUTE l_update_str;				
			END IF;

			IF (l_rule.rule_name like 'Missing%' AND l_rule.rule_name <> 'Missing key elements') THEN

				EXECUTE 'TRUNCATE tmp_invalid_uniq_id ';


				l_select_str :=  ' select array_to_string( ' || 
						 '	 array( ' || 
						 '		select (case when staging_data_type =''varchar'' then '' coalesce(a.''||staging_column_name||'','''''''') =coalesce(b.''||staging_column_name||'','''''''') '' ' || 
						 '			    when staging_data_type =''int'' or staging_data_type like ''numeric%'' then '' coalesce(a.''||staging_column_name||'',0) = coalesce(b.''||staging_column_name||'',0) '' ' || 
						 '			    when staging_data_type =''date'' then '' coalesce(a.''||staging_column_name||'',''''2000-01-01'''') = coalesce(b.''||staging_column_name||'',''''2000-01-01'''') '' ' || 
						 '		       end) as sql_condition ' || 
						 '		from etl.ref_column_mapping ' || 
						 '		where staging_table_name = ''' || l_rule.staging_table_name||''' ' ||
						 '			AND staging_column_name IN (''' || replace(l_rule.staging_column_name,',',''',''') ||''' )' ||
						 '		order by column_order )  ,''AND'') ';


				--RAISE notice 'l_select_str %',l_select_str;
				EXECUTE l_select_str INTO l_where_clause;
				 --RAISE notice 'where %',l_where_clause;


				l_insert_str := 'INSERT INTO tmp_invalid_uniq_id(uniq_id) '||
						' SELECT a.uniq_id ' ||
						' FROM ' || l_rule.staging_table_name ||' a LEFT JOIN ' || COALESCE(l_rule.parent_table_name,l_rule.component_table_name ) || ' b ' ||
						' ON ' || l_where_clause || 
						' WHERE b.uniq_id IS NULL ';


				RAISE notice 'l_insert_str %',l_insert_str;		
				EXECUTE l_insert_str;

				l_update_str := 'UPDATE ' || l_rule.staging_table_name || ' a' ||
						' SET invalid_flag = ''Y'', ' ||
						'	invalid_reason =''' || l_rule.rule_name || ''' ' ||
						' FROM tmp_invalid_uniq_id b ' || 
						'WHERE a.uniq_id = b.uniq_id ' ;		

				EXECUTE l_update_str;	

			END IF;


			IF l_rule.rule_name = 'Inter-load duplicate' THEN

				EXECUTE 'TRUNCATE tmp_invalid_uniq_id ';

				l_insert_str := ' INSERT INTO tmp_invalid_uniq_id ' || 
						' SELECT uniq_id ' || 
						' FROM ' || l_rule.staging_table_name || ',' || l_rule.ref_table_name || ',' || l_rule.transaction_table_name || 
						' WHERE ' || l_rule.invalid_condition ;


				RAISE NOTICE 'l_insert_str %', l_insert_str;
				
				EXECUTE l_insert_str;

				l_update_str := 'UPDATE ' || l_rule.staging_table_name || ' a' ||
						' SET invalid_flag = ''Y'', ' ||
						'	invalid_reason =''' || l_rule.rule_name || ''' ' ||
						' FROM tmp_invalid_uniq_id b ' || 
						'WHERE a.uniq_id = b.uniq_id ' ;		

				EXECUTE l_update_str;	

			END IF;

		END LOOP;

		-- Copying the invalid records to invalid table and deleting the same from the staging table

		SELECT ARRAY(SELECT staging_table_name
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_staging_table_array;

		SELECT ARRAY(SELECT invalid_table_name
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_invalid_table_array;

		SELECT ARRAY(SELECT record_identifier
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_record_identifiers;	

		SELECT ARRAY(SELECT document_type
			     FROM etl.ref_data_source
			     WHERE data_source_code=l_data_source_code
				   AND table_order > 1
			     ORDER BY table_order) INTO l_document_type_array;
			     

		FOR l_array_ctr IN 1..array_upper(l_staging_table_array,1) LOOP

			IF COALESCE(l_invalid_table_array[l_array_ctr],'') <> ''  THEN

				RAISE NOTICE 'INSIDE';


				l_insert_str :=  'INSERT INTO ' || l_invalid_table_array[l_array_ctr] ||
						 ' SELECT *,' || p_load_file_id_in ||
						 ' FROM ' ||l_staging_table_array[l_array_ctr] ||
						 ' WHERE invalid_flag = ''Y'' ';

				RAISE NOTICE 'insert %',l_insert_str;

				EXECUTE l_insert_str;															


			GET DIAGNOSTICS l_count = ROW_COUNT;

			l_ins_invalid_cnt := l_count;

			INSERT INTO etl.etl_data_load_verification(load_file_id,data_source_code,record_identifier,document_type,num_transactions,description)
			VALUES(p_load_file_id_in,l_data_source_code,l_record_identifiers[l_array_ctr],l_document_type_array[l_array_ctr],l_ins_invalid_cnt, 'invalid');

		
			END IF;	

			l_delete_str := ' DELETE FROM ' || l_staging_table_array[l_array_ctr] ||
					' WHERE invalid_flag = ''Y'' ';

			EXECUTE l_delete_str;			
		END LOOP;

	-- Updating the processed flag to V to indicate that the data is validated.
	
	UPDATE  etl.etl_data_load_file
	SET	processed_flag ='V' 
	WHERE	load_file_id = p_load_file_id_in;
			
	END IF;

	l_end_time := timeofday()::timestamp;

	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time)
	VALUES(p_load_file_id_in,'etl.validatedata',1,l_start_time,l_end_time);
		     	
	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in validatedatanew';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	
	
	-- l_exception := etl.errorhandler(l_job_id,l_data_source_code,l_load_id,p_load_file_id_in);
	l_end_time := timeofday()::timestamp;
	
	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time,errno,errmsg)
	VALUES(p_load_file_id_in,'etl.validatedata',0,l_start_time,l_end_time,SQLSTATE,SQLERRM);
	
	RETURN 0;
END;
$$ language plpgsql;


-----------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION etl.processdata(p_load_file_id_in int) RETURNS INT AS $$
DECLARE
	l_data_source_code etl.ref_data_source.data_source_code%TYPE;
	l_load_id bigint;
	l_processed int;	
	l_processed_flag etl.etl_data_load_file.processed_flag%TYPE;
	l_job_id etl.etl_data_load.job_id%TYPE;
	l_exception int;
	l_start_time  timestamp;
	l_end_time  timestamp;
	
BEGIN

	l_start_time := timeofday()::timestamp;
	
	-- Determine the type of data load - F/V/A etc and assign it to l_data_source_code
	
	SELECT b.data_source_code , a.load_id,a.processed_flag,b.job_id
	FROM   etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id	       
	WHERE  a.load_file_id = p_load_file_id_in     
	INTO   l_data_source_code, l_load_id,l_processed_flag, l_job_id;
	
	IF l_processed_flag ='V' THEN
	
		IF l_data_source_code ='A' THEN
			l_processed := etl.processCOAAgency(p_load_file_id_in,l_load_id);

		ELSIF 	l_data_source_code ='D' THEN
			l_processed := etl.processCOADepartment(p_load_file_id_in,l_load_id);

		ELSIF 	l_data_source_code ='E' THEN
			l_processed := etl.processCOAExpenditureObject(p_load_file_id_in,l_load_id);

		ELSIF 	l_data_source_code ='L' THEN
			l_processed := etl.processCOALocation(p_load_file_id_in,l_load_id);

		ELSIF 	l_data_source_code ='O' THEN
			l_processed := etl.processCOAObjectClass(p_load_file_id_in,l_load_id);	

		ELSIF 	l_data_source_code ='V' THEN
			l_processed := etl.processFMSVVendor(p_load_file_id_in,l_load_id);	

		ELSIF 	l_data_source_code ='M' THEN
			l_processed := etl.processMAG(p_load_file_id_in,l_load_id);
			
		ELSIF 	l_data_source_code ='C' THEN
			l_processed := etl.processCon(p_load_file_id_in,l_load_id);
			
		ELSIF 	l_data_source_code ='RC' THEN
			l_processed := etl.processrevenueclass(p_load_file_id_in,l_load_id);	

		ELSIF 	l_data_source_code ='B' THEN
			l_processed := etl.processbudget(p_load_file_id_in,l_load_id);

		ELSIF 	l_data_source_code ='RY' THEN
			l_processed := etl.processrevenuecategory(p_load_file_id_in,l_load_id);	
			
		ELSIF 	l_data_source_code ='RS' THEN
			l_processed := etl.processrevenuesource(p_load_file_id_in,l_load_id);	
			
		ELSIF 	l_data_source_code ='R' THEN
			l_processed := etl.processrevenue(p_load_file_id_in,l_load_id);	
			
		END IF;

	-- Updating the processed flag to Y to indicate that the data is posted to the transaction table.
		IF l_processed = 1 THEN
			UPDATE  etl.etl_data_load_file
			SET	processed_flag ='Y' 
			WHERE	load_file_id = p_load_file_id_in;
		ELSE
			UPDATE  etl.etl_data_load_file
			SET	processed_flag ='E' 
			WHERE	load_file_id = p_load_file_id_in;

			RETURN -1;	
		END IF;		
	END IF;

	l_end_time := timeofday()::timestamp;

	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time)
	VALUES(p_load_file_id_in,'etl.processdata',1,l_start_time,l_end_time);
		
	RETURN 1;

EXCEPTION

	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in processdata';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	-- l_exception := etl.errorhandler(l_job_id,l_data_source_code,l_load_id,p_load_file_id_in);
	l_end_time := timeofday()::timestamp;
	
	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time,errno,errmsg)
	VALUES(p_load_file_id_in,'etl.processdata',0,l_start_time,l_end_time,SQLSTATE,SQLERRM);
	
	RETURN 0;
END;
$$ language plpgsql;

-------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION etl.iseligibleforconsumption(p_job_id_in integer) RETURNS integer AS $$
DECLARE
	l_monthly_timestamp VARCHAR;
	l_weekly_timestamp VARCHAR;
	l_timestamp VARCHAR;
BEGIN
	CREATE TEMPORARY TABLE tmp_files_consumption(load_id bigint,load_file_id bigint )
	DISTRIBUTED BY (load_id);
	
	-- Get the file with the latest timestamp for COA feed
	
	INSERT INTO tmp_files_consumption
	SELECT c.load_id, max(load_file_id) as load_file_id
	FROM etl.etl_data_load_file c JOIN
		(SELECT a.load_id,max(file_timestamp) as file_timestamp
		FROM	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
		WHERE 	b.job_id = p_job_id_in
			AND b.data_source_code IN ('A','D','E','L','O','RC','RY','RS','BC')
			AND a.pattern_matched_flag ='Y'
		GROUP BY 1 ) tbl_timestamp ON c.load_id = tbl_timestamp.load_id AND c.file_timestamp = tbl_timestamp.file_timestamp
	WHERE 	c.pattern_matched_flag ='Y'
	GROUP BY 1;		
	
	-- FMSV - Identify the last monthly feed
	
	INSERT INTO tmp_files_consumption
	SELECT c.load_id, max(load_file_id) as load_file_id
	FROM etl.etl_data_load_file c JOIN
		(SELECT a.load_id,max(file_timestamp) as file_timestamp
		FROM	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
		WHERE 	b.job_id = p_job_id_in
			AND b.data_source_code ='V'
			AND a.type_of_feed ='M'
			AND a.pattern_matched_flag ='Y'
		GROUP BY 1 ) tbl_timestamp ON c.load_id = tbl_timestamp.load_id AND c.file_timestamp = tbl_timestamp.file_timestamp
	WHERE 	c.pattern_matched_flag ='Y'
	GROUP BY 1;	
	
	-- Update consume_flag to N for the COA/FMSV files which are not with the latest timestamp
	
	UPDATE etl.etl_data_load_file a
	SET    consume_flag ='N'
	FROM	tmp_files_consumption b
	WHERE	a.load_id = b.load_id
		AND a.load_file_id <> b.load_file_id;
	
	DELETE FROM tmp_files_consumption;
	
	-- Select timestamp associated with the last monthly FMSV data feed.
	
	SELECT 	file_timestamp
	FROM   	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
	WHERE 	data_source_code ='V'
		AND type_of_feed ='M'
		AND pattern_matched_flag ='Y'
	INTO	l_monthly_timestamp;	

	-- Identifying weekly FMSV files uploaded.
	
	INSERT INTO tmp_files_consumption
	SELECT c.load_id, max(load_file_id) as load_file_id
	FROM etl.etl_data_load_file c JOIN
	(SELECT a.load_id,max(file_timestamp) as file_timestamp
		FROM	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
		WHERE 	b.job_id = p_job_id_in
			AND b.data_source_code ='V'
			AND a.type_of_feed ='W'
			AND a.pattern_matched_flag ='Y'
			AND ((a.file_timestamp::timestamp >= l_monthly_timestamp::timestamp) OR 
			      l_monthly_timestamp IS NULL)
		GROUP BY 1) tbl_timestamp ON c.load_id = tbl_timestamp.load_id AND c.file_timestamp = tbl_timestamp.file_timestamp
	WHERE 	c.pattern_matched_flag ='Y'
	GROUP BY 1;	
		
	SELECT 	max(file_timestamp)
	FROM   	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
	WHERE 	data_source_code ='V'
		AND type_of_feed ='W'
		AND pattern_matched_flag ='Y'
	INTO	l_weekly_timestamp;	
	
	SELECT greatest(l_monthly_timestamp::timestamp,l_weekly_timestamp::timestamp) INTO l_timestamp ;
	
	-- Identifying daily FMSV files uploaded.
	
	INSERT INTO tmp_files_consumption
	SELECT c.load_id, max(load_file_id) as load_file_id
	FROM etl.etl_data_load_file c JOIN
	(SELECT a.load_id,max(file_timestamp) as file_timestamp
		FROM	etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id
		WHERE 	b.job_id = p_job_id_in
			AND b.data_source_code ='V'
			AND a.type_of_feed ='D'
			AND a.pattern_matched_flag ='Y'
			AND ((a.file_timestamp::timestamp >= l_timestamp::timestamp) OR 
			      l_timestamp IS NULL)
			      GROUP BY 1) tbl_timestamp ON c.load_id = tbl_timestamp.load_id AND c.file_timestamp = tbl_timestamp.file_timestamp
	WHERE 	c.pattern_matched_flag ='Y'
	GROUP BY 1;	
			      
	-- Update consume_flag to N for the FMSV files which are not with the latest timestamp
	
	UPDATE etl.etl_data_load_file a
	SET    consume_flag ='Y'
	FROM	tmp_files_consumption b
	WHERE	a.load_id = b.load_id
		AND a.load_file_id = b.load_file_id;

	RETURN 1;	
END;
$$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION etl.errorhandler(p_load_file_id_in int) RETURNS INT AS $$
DECLARE
	l_data_source_code etl.ref_data_source.data_source_code%TYPE;
	l_load_id bigint;
	l_job_id etl.etl_data_load.job_id%TYPE;

BEGIN

	
	RAISE NOTICE 'inside error handler % '  , p_load_file_id_in;

	SELECT b.data_source_code , a.load_id,b.job_id
	FROM   etl.etl_data_load_file a JOIN etl.etl_data_load b ON a.load_id = b.load_id	       
	WHERE  a.load_file_id = p_load_file_id_in     
	INTO   l_data_source_code, l_load_id,l_job_id;

	
	-- Updating the processed flag to E for the data file which resulted in an error
	UPDATE etl.etl_data_load_file
	SET    processed_flag ='E' 
	WHERE  load_file_id = p_load_file_id_in;

	RAISE NOTICE 'inside error handler 1';
	
	IF l_data_source_code IN ('A','D','E','L','O') THEN
		-- Updating the processed flag to C for all non processed data files for the job

		UPDATE  etl.etl_data_load_file a
		SET	processed_flag ='C' 
		FROM	etl.etl_data_load b
		WHERE	a.processed_flag = 'N'
			AND a.load_id = b.load_id
			AND b.job_id = l_job_id;		
		
		
		RAISE NOTICE 'inside error handler 1.2';	
	ELSE
		-- For any feed other than COA set only the non processed files of the specific feed to cancelled.
		
		UPDATE  etl.etl_data_load_file a
		SET	processed_flag ='C' 
		FROM	etl.etl_data_load b
		WHERE	a.processed_flag = 'N'
			AND a.load_id = b.load_id
			AND b.load_id = l_load_id;		

		RAISE NOTICE 'inside error handler 1.3';

		
		
	END IF;

	RETURN 1;
	
	
EXCEPTION
	WHEN OTHERS THEN
	
	RAISE NOTICE 'Exception Occurred in errorhandler';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;		
	
	RETURN 0;
END;
$$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT b.load_id,a.data_source_code,c.file_name,(CASE WHEN type_of_feed = 'M' THEN 1 
						      WHEN type_of_feed = 'W' THEN 2
						      WHEN type_of_feed = 'D' THEN 3 END ) file_order, file_timestamp
FROM etl.ref_data_source a JOIN etl.etl_data_load b ON a.data_source_code = b.data_source_code
	JOIN  etl.etl_data_load_file c ON b.load_id = c.load_id
WHERE b.job_id = 1 
	AND  table_order=1
	AND consume_flag='Y'
ORDER BY a.data_source_order, 4,file_timestamp;

--------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION etl.refreshaggregates(p_load_file_id_in integer)   RETURNS integer AS $$
DECLARE
	l_aggregate_table_array varchar ARRAY[15];
	l_array_ctr smallint;	
	l_query etl.aggregate_tables.query%TYPE;
	l_insert_sql varchar;
	l_truncate_sql varchar;	
	l_start_time  timestamp;
	l_end_time  timestamp;
	
BEGIN

	-- Initialize all the variables

	l_start_time := timeofday()::timestamp;
	
	l_query :='';

	SELECT ARRAY(SELECT aggregate_table_name
		FROM etl.aggregate_tables) INTO l_aggregate_table_array;


		FOR l_array_ctr IN 1..array_upper(l_aggregate_table_array,1) LOOP
			RAISE NOTICE '%', l_aggregate_table_array[l_array_ctr];

			l_insert_sql := '';
			l_truncate_sql := '';

			l_truncate_sql := 'TRUNCATE TABLE ' || l_aggregate_table_array[l_array_ctr] ;

			EXECUTE l_truncate_sql ;

			SELECT query
			FROM   etl.aggregate_tables	       
			WHERE  aggregate_table_name = l_aggregate_table_array[l_array_ctr]     
			INTO   l_query;
			
			l_insert_sql := 'INSERT INTO ' || l_aggregate_table_array[l_array_ctr] || '  ' || l_query;

			EXECUTE l_insert_sql;				

		
		END LOOP; 

	

	l_end_time := timeofday()::timestamp;

	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time)
	VALUES(p_load_file_id_in,'etl.refreshaggregates',1,l_start_time,l_end_time);
		
	RETURN 1;
	
EXCEPTION
	WHEN OTHERS THEN
	
	RAISE NOTICE 'Exception Occurred in refreshaggregates';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	


	-- l_exception :=  etl.errorhandler(l_job_id,l_data_source_code,l_load_id,p_load_file_id_in);
	
	l_end_time := timeofday()::timestamp;
	INSERT INTO etl.etl_script_execution_status(load_file_id,script_name,completed_flag,start_time,end_time,errno,errmsg)
	VALUES(p_load_file_id_in,'etl.refreshaggregates',0,l_start_time,l_end_time,SQLSTATE,SQLERRM);
	
	RETURN 0;
	
END;

$$ language plpgsql;