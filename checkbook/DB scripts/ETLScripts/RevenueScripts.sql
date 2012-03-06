/*
Functions defined
	updateForeignKeysForRevenue
	processrevenue

*/

-- Function: etl.updateforeignkeysforrevenue(bigint)

-- DROP FUNCTION etl.updateforeignkeysforrevenue(bigint);

CREATE OR REPLACE FUNCTION etl.updateforeignkeysforrevenue(p_load_id_in bigint)   RETURNS integer AS $$
DECLARE
BEGIN
	/* UPDATING FOREIGN KEY VALUES	FOR THE HEADER RECORD*/		
	
	CREATE TEMPORARY TABLE tmp_fk_revenue_values (uniq_id bigint, agency_history_id smallint, document_agency_history_id smallint, ref_document_agency_history_id smallint, budget_code_id integer, record_date_id smallint,service_start_date_id smallint,
						service_end_date_id smallint, department_history_id integer, document_code_id smallint, ref_document_code_id smallint,  expenditure_object_history_id integer,
						fund_class_id smallint, funding_source_id smallint, object_class_history_id integer, revenue_category_id smallint, revenue_class_id smallint, revenue_source_id smallint, vendor_history_id integer)
	DISTRIBUTED BY (uniq_id);
	
	-- FK:Document_Code_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,document_code_id)
	SELECT	a.uniq_id, b.document_code_id
	FROM etl.stg_revenue a JOIN ref_document_code b ON a.doc_cd = b.document_code;

	-- FK:ref_Document_Code_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,ref_document_code_id)
	SELECT	a.uniq_id, b.document_code_id
	FROM etl.stg_revenue a JOIN ref_document_code b ON a.rfed_doc_cd = b.document_code;


	-- FK:record_date_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,record_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_revenue a JOIN ref_date b ON a.doc_rec_dt = b.date;

	-- FK:service_start_date_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,service_start_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_revenue a JOIN ref_date b ON a.svc_frm_dt = b.date;

	-- FK:service_end_date_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,service_end_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_revenue a JOIN ref_date b ON a.svc_to_dt = b.date;

	-- FK:funding_source_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,funding_source_id)
	SELECT	a.uniq_id, b.funding_source_id
	FROM etl.stg_revenue a JOIN ref_funding_source b ON a.atyp_cd = b.funding_source_code;
	
	-- FK:fund_class_id
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,fund_class_id)
	SELECT	a.uniq_id, b.fund_class_id
	FROM etl.stg_revenue a JOIN ref_fund_class b ON a.fcls_cd = b.fund_class_code;
	
	-- FK:Agency_history_id

	RAISE NOTICE 'populating agency_history_id 1';
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;

	
	
	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_agencies(dept_cd varchar,uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_agencies
	SELECT dept_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(agency_history_id) is null) b on a.uniq_id=b.uniq_id
	GROUP BY 1;

	
	
	TRUNCATE etl.ref_agency_id_seq;
	
	INSERT INTO etl.ref_agency_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;
	
	INSERT INTO ref_agency(agency_id,agency_code,agency_name,created_date,created_load_id,original_agency_name)
	SELECT a.agency_id,b.dept_cd,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in,'<Unknown Agency>' as original_agency_name
	FROM   etl.ref_agency_id_seq a JOIN tmp_fk_revenue_values_new_agencies b ON a.uniq_id = b.uniq_id;

	RAISE NOTICE 'populating agency_history_id 1.1';

	-- Generate the agency history id for history records
	
	TRUNCATE etl.ref_agency_history_id_seq;
	
	INSERT INTO etl.ref_agency_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;

	INSERT INTO ref_agency_history(agency_history_id,agency_id,agency_name,created_date,load_id)
	SELECT a.agency_history_id,b.agency_id,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_agency_history_id_seq a JOIN etl.ref_agency_id_seq b ON a.uniq_id = b.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;
	

	-- FK:document_agency_history_id

	RAISE NOTICE 'populating document_agency_history_id 1';
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,document_agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.doc_dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;


	TRUNCATE tmp_fk_revenue_values_new_agencies;
	
	INSERT INTO tmp_fk_revenue_values_new_agencies
	SELECT doc_dept_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(document_agency_history_id) is null) b on a.uniq_id=b.uniq_id
	GROUP BY 1;

	
	
	TRUNCATE etl.ref_agency_id_seq;
	
	INSERT INTO etl.ref_agency_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;
	
	INSERT INTO ref_agency(agency_id,agency_code,agency_name,created_date,created_load_id,original_agency_name)
	SELECT a.agency_id,b.dept_cd,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in,'<Unknown Agency>' as original_agency_name
	FROM   etl.ref_agency_id_seq a JOIN tmp_fk_revenue_values_new_agencies b ON a.uniq_id = b.uniq_id;

	RAISE NOTICE 'populating document_agency_history_id 1.1';

	-- Generate the agency history id for history records
	
	TRUNCATE etl.ref_agency_history_id_seq;
	
	INSERT INTO etl.ref_agency_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;

	INSERT INTO ref_agency_history(agency_history_id,agency_id,agency_name,created_date,load_id)
	SELECT a.agency_history_id,b.agency_id,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_agency_history_id_seq a JOIN etl.ref_agency_id_seq b ON a.uniq_id = b.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,document_agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.doc_dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;
	

	-- FK:ref_document_agency_history_id

	RAISE NOTICE 'populating ref_document_agency_history_id 1';
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,ref_document_agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.rfed_doc_dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;

	TRUNCATE tmp_fk_revenue_values_new_agencies;
	
	INSERT INTO tmp_fk_revenue_values_new_agencies
	SELECT rfed_doc_dept_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(ref_document_agency_history_id) is null) b on a.uniq_id=b.uniq_id
	GROUP BY 1;

	
	
	TRUNCATE etl.ref_agency_id_seq;
	
	INSERT INTO etl.ref_agency_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;
	
	INSERT INTO ref_agency(agency_id,agency_code,agency_name,created_date,created_load_id,original_agency_name)
	SELECT a.agency_id,b.dept_cd,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in,'<Unknown Agency>' as original_agency_name
	FROM   etl.ref_agency_id_seq a JOIN tmp_fk_revenue_values_new_agencies b ON a.uniq_id = b.uniq_id;

	
	RAISE NOTICE 'populating ref_document_agency_history_id 1.1';

	-- Generate the agency history id for history records
	
	TRUNCATE etl.ref_agency_history_id_seq;
	
	INSERT INTO etl.ref_agency_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_agencies;

	INSERT INTO ref_agency_history(agency_history_id,agency_id,agency_name,created_date,load_id)
	SELECT a.agency_history_id,b.agency_id,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_agency_history_id_seq a JOIN etl.ref_agency_id_seq b ON a.uniq_id = b.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,ref_document_agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_revenue a JOIN ref_agency b ON a.rfed_doc_dept_cd = b.agency_code
		 JOIN ref_agency_history c ON b.agency_id = c.agency_id ;



	-- FK:department_history_id

	INSERT INTO tmp_fk_revenue_values(uniq_id,department_history_id)
	SELECT	a.uniq_id, max(c.department_history_id) 
	FROM etl.stg_revenue a JOIN ref_department b ON a.appr_cd = b.department_code AND a.fy_dc = b.fiscal_year
		JOIN ref_department_history c ON b.department_id = c.department_id
		JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
		JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id
	GROUP BY 1;
	
	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_dept(agency_history_id integer,agency_id integer,appr_cd varchar,
						fund_class_id smallint,fiscal_year smallint, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_dept
	SELECT d.agency_history_id,c.agency_id,appr_cd,e.fund_class_id,fy_dc,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(department_history_id) IS NULL) b on a.uniq_id=b.uniq_id
		JOIN ref_agency c ON a.dept_cd = c.agency_code
		JOIN ref_agency_history d ON c.agency_id = d.agency_id
		JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code
	GROUP BY 1,2,3,4,5;

	RAISE NOTICE '1.4';
						
	-- Generate the department id for new records
		
	TRUNCATE etl.ref_department_id_seq;
	
	INSERT INTO etl.ref_department_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_dept;

	INSERT INTO ref_department(department_id,department_code,
				   department_name,
				   agency_id,fund_class_id,
				   fiscal_year,created_date,created_load_id,original_department_name)
	SELECT a.department_id,COALESCE(b.appr_cd,'---------') as department_code,
		(CASE WHEN COALESCE(b.appr_cd,'') <> '' THEN '<Unknown Department>'
			ELSE 'Non-Applicable Department' END) as department_name,
		b.agency_id,b.fund_class_id,b.fiscal_year,
		now()::timestamp,p_load_id_in,
		(CASE WHEN COALESCE(b.appr_cd,'') <> '' THEN '<Unknown Department>'
			ELSE 'Non-Applicable Department' END) as original_department_name
	FROM   etl.ref_department_id_seq a JOIN tmp_fk_revenue_values_new_dept b ON a.uniq_id = b.uniq_id;

	RAISE NOTICE '1.5';
	-- Generate the department history id for history records
	
	TRUNCATE etl.ref_department_history_id_seq;
	
	INSERT INTO etl.ref_department_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_dept;

	INSERT INTO ref_department_history(department_history_id,department_id,
					   department_name,agency_id,fund_class_id,
					   fiscal_year,created_date,load_id)
	SELECT a.department_history_id,c.department_id,	
		(CASE WHEN COALESCE(b.appr_cd,'') <> '' THEN '<Unknown Department>'
		      ELSE 'Non-Applicable Department' END) as department_name,
		b.agency_id,b.fund_class_id,b.fiscal_year,now()::timestamp,p_load_id_in
	FROM   etl.ref_department_history_id_seq a JOIN tmp_fk_revenue_values_new_dept b ON a.uniq_id = b.uniq_id
		JOIN etl.ref_department_id_seq  c ON a.uniq_id = c.uniq_id ;


	RAISE NOTICE '1.6';
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,department_history_id)
	SELECT	a.uniq_id, max(c.department_history_id) 
	FROM etl.stg_revenue a JOIN ref_department b ON a.appr_cd = b.department_code AND a.fy_dc = b.fiscal_year
		JOIN ref_department_history c ON b.department_id = c.department_id
		JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
		JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id
		JOIN etl.ref_department_history_id_seq f ON c.department_history_id = f.department_history_id
	GROUP BY 1;

	
	RAISE NOTICE '1.7';
	
	-- FK:expenditure_object_history_id

	INSERT INTO tmp_fk_revenue_values(uniq_id,expenditure_object_history_id)
	SELECT	a.uniq_id, max(c.expenditure_object_history_id) 
	FROM etl.stg_revenue a JOIN ref_expenditure_object b ON a.obj_cd = b.expenditure_object_code AND a.fy_dc = b.fiscal_year
		JOIN ref_expenditure_object_history c ON b.expenditure_object_id = c.expenditure_object_id
	GROUP BY 1	;


	RAISE NOTICE '1.8';
	
	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_exp_object(obj_cd varchar,fiscal_year smallint,uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_exp_object
	SELECT (CASE WHEN COALESCE(obj_cd,'')='' THEN '----' ELSE obj_cd END) as obj_cd,fy_dc,MIN(a.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM stg_revenue
						 GROUP BY 1
						 HAVING max(expenditure_object_history_id) is null) b on a.uniq_id=b.uniq_id
	GROUP BY 1,2;

	-- Generate the expenditure_object id for new records
		
	TRUNCATE etl.ref_expenditure_object_id_seq;
	
	INSERT INTO etl.ref_expenditure_object_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_exp_object;

	RAISE NOTICE '1.9';
	
	INSERT INTO ref_expenditure_object(expenditure_object_id,expenditure_object_code,
		expenditure_object_name,fiscal_year,created_date,created_load_id,original_expenditure_object_name)
	SELECT a.expenditure_object_id,b.obj_cd,
		(CASE WHEN b.obj_cd <> '----' THEN '<Unknown Expenditure Object>'
			ELSE '<Non-Applicable Expenditure Object>' END) as expenditure_object_name,
		b.fiscal_year,now()::timestamp,p_load_id_in,
		(CASE WHEN b.obj_cd <> '----' THEN '<Unknown Expenditure Object>'
			ELSE '<Non-Applicable Expenditure Object>' END) as original_expenditure_object_name
	FROM   etl.ref_expenditure_object_id_seq a JOIN tmp_fk_revenue_values_new_exp_object b ON a.uniq_id = b.uniq_id;

	-- Generate the expenditure_object history id for history records
	
	TRUNCATE etl.ref_expenditure_object_history_id_seq;
	
	INSERT INTO etl.ref_expenditure_object_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_exp_object;

	RAISE NOTICE '1.10';
	
	INSERT INTO ref_expenditure_object_history(expenditure_object_history_id,expenditure_object_id,fiscal_year,expenditure_object_name,created_date,load_id)
	SELECT a.expenditure_object_history_id,c.expenditure_object_id,b.fiscal_year,
		(CASE WHEN b.obj_cd <> '----' THEN '<Unknown Expenditure Object>'
			ELSE '<Non-Applicable Expenditure Object>' END) as expenditure_object_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_expenditure_object_history_id_seq a JOIN tmp_fk_revenue_values_new_exp_object b ON a.uniq_id = b.uniq_id
		JOIN etl.ref_expenditure_object_id_seq c ON a.uniq_id = c.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,expenditure_object_history_id)
	SELECT	a.uniq_id, max(c.expenditure_object_history_id) 
	FROM etl.stg_revenue a JOIN ref_expenditure_object b ON (COALESCE(a.obj_cd,'----') = b.expenditure_object_code 
										OR (a.obj_cd='' AND b.expenditure_object_code='----')
									     ) 
									     AND a.fy_dc = b.fiscal_year
		JOIN ref_expenditure_object_history c ON b.expenditure_object_id = c.expenditure_object_id
		JOIN etl.ref_expenditure_object_history_id_seq d ON c.expenditure_object_history_id = d.expenditure_object_history_id
	GROUP BY 1	;

	
	-- FK:budget_code_id

	RAISE NOTICE 'populating budget_code_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,budget_code_id)
	SELECT	a.uniq_id, b.budget_code_id 
	FROM etl.stg_revenue a JOIN ref_budget_code b ON a.func_cd = b.budget_code AND a.fy_dc = b.fiscal_year
			       JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
				JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id ;
	

	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_budget_codes(agency_id integer,func_cd varchar,
						fund_class_id smallint,fiscal_year smallint, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_budget_codes
	SELECT c.agency_id,func_cd,e.fund_class_id,fy_dc,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(budget_code_id) IS NULL) b on a.uniq_id=b.uniq_id
		JOIN ref_agency c ON a.dept_cd = c.agency_code
		JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code
	GROUP BY 1,2,3,4;


	TRUNCATE etl.ref_budget_code_id_seq;
	
	INSERT INTO etl.ref_budget_code_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_budget_codes;
	
	INSERT INTO ref_budget_code(budget_code_id,fiscal_year,budget_code,agency_id, fund_class_id, budget_code_name,created_date,load_id)
	SELECT a.budget_code_id,fiscal_year,func_cd,'<Unknown Budget Code>' as budget_code_name,agency_id,fund_class_id,now()::timestamp,p_load_id_in
	FROM   etl.ref_budget_code_id_seq a JOIN tmp_fk_revenue_values_new_budget_codes b ON a.uniq_id = b.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,budget_code_id)
	SELECT	a.uniq_id, b.budget_code_id 
	FROM etl.stg_revenue a JOIN ref_budget_code b ON a.func_cd = b.budget_code AND a.fy_dc = b.fiscal_year
			       JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
				JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id ;
		
	raise notice 'populating budget_code_id 1.1';



	-- FK:object_class_history_id

	RAISE NOTICE 'populating object_class_history_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,object_class_history_id)
	SELECT	a.uniq_id, b.object_class_history_id 
	FROM etl.stg_revenue a JOIN ref_object_class b ON a.ocls_cd = b.object_class_code
			       JOIN ref_object_class_history d ON b.object_class_id = d.object_class_id  ;
	

	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_obj_class(ocls_cd varchar, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_obj_class
	SELECT ocls_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(object_class_history_id) IS NULL) b on a.uniq_id=b.uniq_id		
	GROUP BY 1;


	TRUNCATE etl.ref_object_class_id_seq;
	
	INSERT INTO etl.ref_object_class_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_obj_class;
	
	INSERT INTO ref_object_class(object_class_id,object_class_code, object_class_name,created_date,created_load_id)
	SELECT a.object_class_id,ocls_cd,'<Unknown Object Class>' as object_class_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_object_class_id_seq a JOIN tmp_fk_revenue_values_new_obj_class b ON a.uniq_id = b.uniq_id;
		
	raise notice 'populating object_class_history_id 1.1';

	TRUNCATE etl.ref_object_class_history_id_seq;
	
	INSERT INTO etl.ref_object_class_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_obj_class;

	INSERT INTO ref_object_class_history(object_class_history_id,object_class_id,object_class_name, created_date,load_id)
	SELECT a.object_class_history_id,b.object_class_id,'<Unknown Object Class>' as object_class_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_object_class_history_id_seq a JOIN etl.ref_object_class_id_seq b ON a.uniq_id = b.uniq_id;

	INSERT INTO tmp_fk_revenue_values(uniq_id,object_class_history_id)
	SELECT	a.uniq_id, b.object_class_history_id 
	FROM etl.stg_revenue a JOIN ref_object_class b ON a.ocls_cd = b.object_class_code
			       JOIN ref_object_class_history d ON b.object_class_id = d.object_class_id  ;
			       




	-- FK:revenue_category_id

	RAISE NOTICE 'populating revenue_category_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_category_id)
	SELECT	a.uniq_id, b.revenue_category_id 
	FROM etl.stg_revenue a JOIN ref_revenue_category b ON a.rscat_cd = b.revenue_category_code  ;
			

	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_rev_category(rscat_cd varchar, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_rev_category
	SELECT rscat_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(budget_code_id) IS NULL) b on a.uniq_id=b.uniq_id
	GROUP BY 1;


	TRUNCATE etl.ref_revenue_category_id_seq;
	
	INSERT INTO etl.ref_revenue_category_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_rev_category;
	
	INSERT INTO ref_revenue_category(revenue_category_id,revenue_category_code, revenue_category_name,created_date,updated_load_id)
	SELECT a.revenue_category_id,rscat_cd,'<Unknown Revenue Category>' as revenue_category_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_revenue_category_id_seq a JOIN tmp_fk_revenue_values_new_rev_category b ON a.uniq_id = b.uniq_id;

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_category_id)
	SELECT	a.uniq_id, b.revenue_category_id 
	FROM etl.stg_revenue a JOIN ref_revenue_category b ON a.rscat_cd = b.revenue_category_code ;
		
	raise notice 'populating revenue_category_id 1.1';


	-- FK:revenue_class_id

	RAISE NOTICE 'populating revenue_class_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_class_id)
	SELECT	a.uniq_id, b.revenue_class_id 
	FROM etl.stg_revenue a JOIN ref_revenue_class b ON a.rscls_cd = b.revenue_class_code ;
	

	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_budget_codes(agency_id integer,func_cd varchar,
						fund_class_id smallint,fiscal_year smallint, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_budget_codes
	SELECT c.agency_id,func_cd,e.fund_class_id,fy_dc,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(budget_code_id) IS NULL) b on a.uniq_id=b.uniq_id
		JOIN ref_agency c ON a.dept_cd = c.agency_code
		JOIN ref_fund_class e ON a.fcls_cd = e.fund_class_code
	GROUP BY 1,2,3,4;

	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_rev_category(rscls_cd varchar, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_rev_class
	SELECT rscls_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(budget_code_id) IS NULL) b on a.uniq_id=b.uniq_id
	GROUP BY 1;


	TRUNCATE etl.ref_revenue_class_id_seq;
	
	INSERT INTO etl.ref_revenue_class_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_rev_class;
	
	INSERT INTO ref_revenue_class(revenue_class_id,revenue_class_code, revenue_class_name,created_date,updated_load_id)
	SELECT a.revenue_class_id,rscls_cd,'<Unknown Revenue Class>' as revenue_class_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_revenue_class_id_seq a JOIN tmp_fk_revenue_values_new_rev_class b ON a.uniq_id = b.uniq_id;

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_class_id)
	SELECT	a.uniq_id, b.revenue_class_id 
	FROM etl.stg_revenue a JOIN ref_revenue_class b ON a.rscat_cd = b.revenue_class_code ;
		
	raise notice 'populating revenue_class_id 1.1';




	-- FK:revenue_source_id

	RAISE NOTICE 'populating revenue_source_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_source_id)
	SELECT	a.uniq_id, b.revenue_source_id 
	FROM etl.stg_revenue a JOIN ref_revenue_source b ON a.rsrc_cd = b.revenue_source_code AND  a.fy_dc = b.fiscal_year
			       JOIN ref_revenue_category c ON b.revenue_category_id = c.revenue_category_id AND a.rscat_cd = c.revenue_category_code
			       JOIN ref_revenue_class d ON b.revenue_class_id = d.revenue_class_id AND a.rscls_cd = d.revenue_class_code;
	


	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_rev_source(rsrc_cd varchar,  revenue_class_id smallint, revenue_category_id smallint, fiscal_year smallint, uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_rev_source
	SELECT rsrc_cd, revenue_class_id, revenue_category_id, fy_dc, MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(revenue_source_id) IS NULL) b on a.uniq_id=b.uniq_id
			JOIN ref_revenue_category c ON a.rscat_cd = c.revenue_category_code
			JOIN ref_revenue_class d ON a.rscls_cd = d.revenue_class_code
	GROUP BY 1,2,3,4;


	TRUNCATE etl.ref_revenue_source_id_seq;
	
	INSERT INTO etl.ref_revenue_source_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_revenue_values_new_rev_source;
	
	INSERT INTO ref_revenue_class(revenue_source_id,revenue_source_code, fiscal_year, revenue_source_name, revenue_class_id, revenue_category_id, created_date,updated_load_id)
	SELECT a.revenue_source_id,rsrc_cd,fiscal_year, '<Unknown Revenue Source>' as revenue_class_name, revenue_class_id, revenue_category_id, now()::timestamp,p_load_id_in
	FROM   etl.ref_revenue_source_id_seq a JOIN tmp_fk_revenue_values_new_rev_source b ON a.uniq_id = b.uniq_id;

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,revenue_class_id)
	SELECT	a.uniq_id, b.revenue_class_id 
	FROM etl.stg_revenue a JOIN ref_revenue_source_id_seq b ON a.uniq_id = b.uniq_id 
			       JOIN ref_revenue_category c ON a.rscat_cd = c.revenue_category_code
			       JOIN ref_revenue_class d ON  a.rscls_cd = d.revenue_class_code;
		
	RAISE notice 'populating revenue_source_id 1.1';
	

	
	-- FK:vendor_history_id

	RAISE NOTICE 'populating vendor_history_id 1';

	
	INSERT INTO tmp_fk_revenue_values(uniq_id,vendor_history_id)
	SELECT	a.uniq_id, b.vendor_history_id 
	FROM etl.stg_revenue a JOIN vendor b ON a.vend_cust_cd = b.vendor_customer_code 
			       JOIN vendor_history c ON b.vendor_id = c.vendor_id ;
	


	CREATE TEMPORARY TABLE tmp_fk_revenue_values_new_vendors(vend_cust_cd varchar,  uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_revenue_values_new_rev_source
	SELECT vend_cust_cd, MIN(b.uniq_id) as uniq_id
	FROM etl.stg_revenue a join (SELECT uniq_id
						 FROM tmp_fk_revenue_values
						 GROUP BY 1
						 HAVING max(vendor_history_id) IS NULL) b on a.uniq_id=b.uniq_id
	GROUP BY 1;

	
	INSERT INTO vendor(vendor_customer_code, legal_name, created_date,created_load_id)
	SELECT a.vend_cust_cd, '<Unknown Vendor>' as legal_name,  now()::timestamp,p_load_id_in
	FROM   etl.stg_revenue a JOIN tmp_fk_revenue_values_new_vendors b ON a.uniq_id = b.uniq_id;

	INSERT INTO vendor_history(vendor_id,  legal_name, created_date,load_id)
	SELECT c.vendor_id,  '<Unknown Vendor>' as legal_name,  now()::timestamp,p_load_id_in
	FROM   etl.stg_revenue a JOIN tmp_fk_revenue_values_new_vendors b ON a.uniq_id = b.uniq_id JOIN vendor c ON a.vend_cust_cd = c.vendor_customer_code;

	
	
	INSERT INTO tmp_fk_revenue_values(uniq_id,vendor_history_id)
	SELECT	a.uniq_id, b.vendor_history_id 
	FROM etl.stg_revenue a JOIN vendor b ON a.vend_cust_cd = b.vendor_customer_code 
			       JOIN vendor_history c ON b.vendor_id = c.vendor_id ;
		
	RAISE notice 'populating revenue_source_id 1.1';
	
	
	CREATE TEMPORARY TABLE tmp_fk_revenue_values1 (uniq_id bigint, agency_history_id smallint, document_agency_history_id smallint, ref_document_agency_history_id smallint, budget_code_id integer, record_date_id smallint,service_start_date_id smallint,
						service_end_date_id smallint, department_history_id integer, document_code_id smallint, ref_document_code_id smallint,  expenditure_object_history_id integer,
						fund_class_id smallint, funding_source_id smallint, object_class_history_id integer, revenue_category_id smallint, revenue_class_id smallint, revenue_source_id smallint, vendor_history_id integer)
	DISTRIBUTED BY (uniq_id);

	
		
	INSERT INTO tmp_fk_revenue_values1 (uniq_id, agency_history_id, document_agency_history_id, ref_document_agency_history_id, budget_code_id, record_date_id,service_start_date_id,
						service_end_date_id, department_history_id, document_code_id, ref_document_code_id,  expenditure_object_history_id,
						fund_class_id, funding_source_id, object_class_history_id, revenue_category_id, revenue_class_id, revenue_source_id, vendor_history_id)
						(SELECT uniq_id, max(agency_history_id) as agency_history_id, max(document_agency_history_id) as document_agency_history_id, max(ref_document_agency_history_id) as ref_document_agency_history_id, 
						max(budget_code_id) as budget_code_id, max(record_date_id) as record_date_id, max(service_start_date_id) as service_start_date_id,
						max(service_end_date_id) as service_end_date_id, max(department_history_id) as department_history_id, max(document_code_id) as document_code_id, max(ref_document_code_id) as ref_document_code_id,  
						max(expenditure_object_history_id) as expenditure_object_history_id, max(fund_class_id) as fund_class_id, max(funding_source_id) as funding_source_id, 
						max(object_class_history_id) as object_class_history_id, max(revenue_category_id) as revenue_category_id, max(revenue_class_id) as revenue_class_id, max(revenue_source_id) as revenue_source_id, max(vendor_history_id) as vendor_history_id
		 FROM	tmp_fk_revenue_values
		 GROUP BY 1) ;	
	
	
	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in updateForeignKeysForRevenue';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;

$$ language plpgsql;
--------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION etl.processrevenue(p_load_file_id_in integer, p_load_id_in bigint)   RETURNS integer AS $$
DECLARE


	l_fk_update int;

BEGIN
		
	l_fk_update := etl.updateForeignKeysForRevenue(p_load_id_in);

	RAISE NOTICE 'REVENUE 1';
	
	IF l_fk_update != 1 THEN 
	RETURN -1;
	END IF;

	INSERT INTO revenue(record_date_id, fiscal_period, fiscal_year,  budget_fiscal_year, fiscal_quarter,  event_category,  event_type,  bank_account_code,  posting_pair_type,  posting_code,  debit_credit_indicator,  line_function, posting_amount,  increment_decrement_indicator,  time_of_occurence,  balance_sheet_account_code,  balance_sheet_account_type,  expenditure_object_history_id,  government_branch_code,  cabinet_code,  agency_history_id, department_history_id,  reporting_activity_code,  budget_code_id,  fund_category,  fund_type,  fund_group,  balance_sheet_account_class_code,  balance_sheet_account_category_code,  balance_sheet_account_group_code, balance_sheet_account_override_flag,  object_class_history_id,  object_category_code,  object_type_code,  object_group_code,  document_category,  document_type,  document_code_id,  document_agency_history_id,  document_id, document_version_number,  document_function_code_id,  document_unit,  commodity_line,  accounting_line,  document_posting_line,  ref_document_code_id,  ref_document_agency_history_id,  ref_document_id,  ref_commodity_line, ref_accounting_line,  ref_posting_line,  reference_type,  line_description,  service_start_date_id,  service_end_date_id,  reason_code,  reclassification_flag,  closing_classification_code,  closing_classification_name, revenue_category_id,  revenue_class_id,  revenue_source_id,  funding_source_id,  fund_class_id,  reporting_code,  major_cafr_revenue_type,  minor_cafr_revenue_type,  vendor_history_id,  load_id,  created_date)
	SELECT b.record_date_id, a.per_dc, a.fy_dc, a.bfy, a.fqtr, a.evnt_cat_id, a.evnt_typ_id, a.bank_acct_cd, a.pstng_pr_typ, a.pstng_cd_id, a.drcr_ind, a.ln_func_cd, a.pstng_am, a.incr_dcrs_ind, a.run_tmdt, a.bsa_cd, a.bsa_typ_ind, b.expenditure_object_history_id, a.govt_brn_cd, a.cab_cd, b.agency_history_id, b.department_history_id, a.actv_cd, b.budget_code_id, a.fcat_cd, a.ftyp_cd, a.fgrp_cd, a.bscl_cd, a.bsct_cd, a.bsg_cd, a.bsa_ov_fl, b.object_class_history_id, a.ocat_cd, a.otyp_cd, a.ogrp_cd, a.doc_cat, a.doc_typ, b.document_code_id, b.document_agency_history_id, a.doc_id, a.doc_vers_no, b.document_function_code_id, a.doc_unit_cd, a.doc_comm_ln_no, a.doc_actg_ln_no, a.doc_pstng_ln_no, b.ref_document_code_id, b.ref_document_agency_history_id, a.rfed_doc_id, a.rfed_comm_ln_no, a.rfed_actg_ln_no, a.rfed_pstng_ln_no, a.rf_typ, a.actg_ln_dscr, b.service_start_date_id, b.service_end_date_id, a.reas_cd, a.reclass_ind_fl, a.pscd_clos_cl_cd, a.pscd_clos_cl_nm, b.revenue_category_id, b.revenue_class_id, b.revenue_source_id, b.funding_source_id, b.fund_class_id, a.actv_cd, a.mjr_crtyp_cd, a.mnr_crtyp_cd, b.vendor_history_id, p_load_id_in, now()::timestamp
	FROM etl.stg_revenue a JOIN tmp_fk_revenue_values1 b ON a.uniq_id = b.uniq_id;
	
	RETURN 1;
	
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in processrevenue';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;

$$ language plpgsql;