set search_path=etl;
/*
Functions defined
	updateForeignKeysForPOInHeader
	updateForeignKeysForPOInAwardDetail
	associateMAGToPO
	updateForeignKeysForPOVendors
	updateForeignKeysForPOInAccLine
	processCONPurchaseOrder

*/
CREATE OR REPLACE FUNCTION updateForeignKeysForPOInHeader(p_load_id_in bigint) RETURNS INT AS $$
DECLARE
BEGIN
	/* UPDATING FOREIGN KEY VALUES	FOR THE HEADER RECORD*/		
	
	CREATE TEMPORARY TABLE tmp_fk_po_values (uniq_id bigint, document_code_id smallint,agency_history_id smallint,
					      document_function_code_id smallint, record_date_id smallint,procurement_type_id smallint,
					      effective_begin_date_id smallint,effective_end_date_id smallint,source_created_date_id smallint,
					      source_updated_date_id smallint)
	DISTRIBUTED BY (uniq_id);
	
	-- FK:Document_Code_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,document_code_id)
	SELECT	a.uniq_id, b.document_code_id
	FROM etl.stg_con_po_header a JOIN ref_document_code b ON a.doc_cd = b.document_code;
	
	-- FK:Agency_history_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) as agency_history_id
	FROM etl.stg_con_po_header a JOIN ref_agency b ON a.doc_dept_cd = b.agency_code
		JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1;

	CREATE TEMPORARY TABLE tmp_fk_po_values_new_agencies(dept_cd varchar,uniq_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_po_values_new_agencies
	SELECT doc_dept_cd,MIN(b.uniq_id) as uniq_id
	FROM etl.stg_con_po_header a join (SELECT uniq_id
						 FROM tmp_fk_po_values
						 GROUP BY 1
						 HAVING max(agency_history_id) is null) b on a.uniq_id=b.uniq_id
	GROUP BY 1;

	RAISE NOTICE '1';
	
	TRUNCATE etl.ref_agency_id_seq;
	
	INSERT INTO etl.ref_agency_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_po_values_new_agencies;
	
	INSERT INTO ref_agency(agency_id,agency_code,agency_name,created_date,created_load_id,original_agency_name)
	SELECT a.agency_id,b.dept_cd,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in,'<Unknown Agency>' as original_agency_name
	FROM   etl.ref_agency_id_seq a JOIN tmp_fk_po_values_new_agencies b ON a.uniq_id = b.uniq_id;

	RAISE NOTICE '1.1';

	-- Generate the agency history id for history records
	
	TRUNCATE etl.ref_agency_history_id_seq;
	
	INSERT INTO etl.ref_agency_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM   tmp_fk_po_values_new_agencies;

	INSERT INTO ref_agency_history(agency_history_id,agency_id,agency_name,created_date,load_id)
	SELECT a.agency_history_id,b.agency_id,'<Unknown Agency>' as agency_name,now()::timestamp,p_load_id_in
	FROM   etl.ref_agency_history_id_seq a JOIN etl.ref_agency_id_seq b ON a.uniq_id = b.uniq_id;

	RAISE NOTICE '1.3';
	INSERT INTO tmp_fk_po_values(uniq_id,agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) 
	FROM etl.stg_con_po_header a JOIN ref_agency b ON a.doc_dept_cd = b.agency_code
		JOIN ref_agency_history c ON b.agency_id = c.agency_id
		JOIN etl.ref_agency_history_id_seq d ON c.agency_history_id = d.agency_history_id
	GROUP BY 1	;	
	
	-- FK:document_function_code_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,document_function_code_id)
	SELECT	a.uniq_id, b.document_function_code_id
	FROM etl.stg_con_po_header a JOIN ref_document_function_code b ON a.doc_func_cd = b.document_function_code_id;
	
	-- FK:record_date_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,record_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_con_po_header a JOIN ref_date b ON a.doc_rec_dt_dc = b.date;
	
	--FK:procurement_type_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,procurement_type_id)
	SELECT	a.uniq_id, b.procurement_type_id
	FROM etl.stg_con_po_header a JOIN ref_procurement_type b ON a.prcu_typ_id = b.procurement_type_id;
	
	--FK:effective_begin_date_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,effective_begin_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_con_po_header a JOIN ref_date b ON a.cntrct_strt_dt = b.date;
	
	--FK:effective_end_date_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,effective_end_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_con_po_header a JOIN ref_date b ON a.cntrct_end_dt = b.date;
	
	--FK:source_created_date_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,source_created_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_con_po_header a JOIN ref_date b ON a.doc_appl_crea_dt = b.date;
	
	--FK:source_updated_date_id
	
	INSERT INTO tmp_fk_po_values(uniq_id,source_updated_date_id)
	SELECT	a.uniq_id, b.date_id
	FROM etl.stg_con_po_header a JOIN ref_date b ON a.doc_appl_last_dt = b.date;
	
	--Updating con_ct_header with all the FK values
	
	UPDATE etl.stg_con_po_header a
	SET	document_code_id = ct_table.document_code_id ,
		agency_history_id = ct_table.agency_history_id,		
		document_function_code_id = ct_table.document_function_code_id, 
		record_date_id = ct_table.record_date_id,
		procurement_type_id = ct_table.procurement_type_id, 
		effective_begin_date_id = ct_table.effective_begin_date_id,
		effective_end_date_id = ct_table.effective_end_date_id,
		source_created_date_id = ct_table.source_created_date_id,
		source_updated_date_id = ct_table.source_updated_date_id
	FROM	(SELECT uniq_id, max(document_code_id) as document_code_id ,
				 max(agency_history_id) as agency_history_id,
				 max(document_function_code_id) as document_function_code_id, max(record_date_id) as record_date_id,
				 max(procurement_type_id) as procurement_type_id, max(effective_begin_date_id) as effective_begin_date_id,
				 max(effective_end_date_id) as effective_end_date_id,max(source_created_date_id) as source_created_date_id,
				 max(source_updated_date_id) as source_updated_date_id
		 FROM	tmp_fk_po_values
		 GROUP BY 1) ct_table
	WHERE	a.uniq_id = ct_table.uniq_id;	
	
	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in updateForeignKeysForPOInHeader';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION updateForeignKeysForPOInAwardDetail() RETURNS INT AS $$
DECLARE
BEGIN
	-- UPDATING FK VALUES IN AWARD DETAIL
	
	CREATE TEMPORARY TABLE tmp_fk_values_po_award_detail(uniq_id bigint,award_method_id smallint,award_level_id smallint,agreement_type_id smallint,
						      		award_category_id_1 smallint)
	DISTRIBUTED BY (uniq_id);
	
	-- FK:award_method_id
	
	INSERT INTO tmp_fk_values_po_award_detail(uniq_id,award_method_id)
	SELECT a.uniq_id , b.award_method_id
	FROM	etl.stg_con_po_award_detail a JOIN ref_award_method b ON a.awd_meth_cd = b.award_method_code;

	--FK:award_level_id
	
	INSERT INTO tmp_fk_values_po_award_detail(uniq_id,award_level_id)
	SELECT a.uniq_id , b.award_level_id
	FROM	etl.stg_con_po_award_detail a JOIN ref_award_level b ON a.awd_lvl_cd = b.award_level_code;
	
	--FK:agreement_type_id
	
	INSERT INTO tmp_fk_values_po_award_detail(uniq_id,agreement_type_id)
	SELECT a.uniq_id , b.agreement_type_id
	FROM	etl.stg_con_po_award_detail a JOIN ref_agreement_type b ON a.cttyp_cd = b.agreement_type_code;

	--FK:award_category_id_1
	
	INSERT INTO tmp_fk_values_po_award_detail(uniq_id,award_category_id_1)
	SELECT a.uniq_id , b.award_category_id
	FROM	etl.stg_con_po_award_detail a JOIN ref_award_category b ON a.ctcat_cd_1 = b.award_category_code;

	UPDATE etl.stg_con_po_award_detail a
	SET	award_method_id = ct_table.award_method_id ,
		award_level_id = ct_table.award_level_id ,
		agreement_type_id = ct_table.agreement_type_id ,
		award_category_id_1 = ct_table.award_category_id_1 		
	FROM	
		(SELECT uniq_id,
			max(award_method_id) as award_method_id ,
			max(award_level_id) as award_level_id 	 ,
			max(agreement_type_id) as agreement_type_id   ,
			max(award_category_id_1) as award_category_id_1	 
		FROM 	tmp_fk_values_po_award_detail
		GROUP BY 1 )ct_table
	WHERE	a.uniq_id = ct_table.uniq_id;	
	

	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in updateForeignKeysForPOInAwardDetail';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;

-------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION associateMAGToPO() RETURNS INT AS $$
DECLARE
	l_worksite_col_array VARCHAR ARRAY[10];
	l_array_ctr smallint;
	l_fk_update int;
BEGIN
						  
	-- Fetch all the contracts associated with MAG
	
	CREATE TEMPORARY TABLE tmp_po_mag(uniq_id bigint, master_agreement_id bigint,mag_document_id varchar, 
				mag_agency_history_id smallint, mag_document_code_id smallint, mag_document_code varchar, mag_agency_code varchar )	
	DISTRIBUTED BY(uniq_id);
	
	INSERT INTO tmp_po_mag
	SELECT uniq_id, 0 as master_agreement_id,
	       max(agree_doc_id),
	       max(d.agency_history_id) as mag_agency_history_id,
	       max(c.document_code_id),
	       max(c.document_code),
	       max(b.agency_code)
	FROM	etl.stg_con_po_header a JOIN ref_agency b ON a.agree_doc_dept_cd = b.agency_code
		JOIN ref_document_code c ON a.agree_doc_cd = c.document_code
		JOIN ref_agency_history d ON b.agency_id = d.agency_id
	GROUP BY 1,2;		
		
	
	-- Identify the MAG Id
	
	CREATE TEMPORARY TABLE tmp_old_po_mag_con(uniq_id bigint,master_agreement_id bigint, action_flag char(1), latest_flag char(1))
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_old_po_mag_con
	SELECT uniq_id,
	       master_agreement_id	
	FROM	
		(SELECT  uniq_id,		
			 b.document_version as mag_document_version,
			 b.master_agreement_id,
			 rank()over(partition by uniq_id order by b.document_version desc) as rank_value
		FROM tmp_po_mag a JOIN history_all_master_agreement b ON a.mag_document_id = b.document_id 
			JOIN ref_document_code f ON a.mag_document_code = f.document_code AND b.document_code_id = f.document_code_id
			JOIN ref_agency e ON a.mag_agency_code = e.agency_code 
			JOIN ref_agency_history c ON b.agency_history_id = c.agency_history_id AND e.agency_id = c.agency_id			
		) inner_tbl
	WHERE	rank_value = 1;	
	
	UPDATE tmp_po_mag a
	SET	master_agreement_id = b.master_agreement_id
	FROM	tmp_old_po_mag_con b
	WHERE	a.uniq_id = b.uniq_id;
	
	-- Identify the MAG ones which have to be created
	
	CREATE TEMPORARY TABLE tmp_new_po_mag_con(mag_document_code varchar,mag_agency_code varchar, mag_document_id varchar,
					   mag_agency_history_id smallint,mag_document_code_id smallint,uniq_id bigint);
	
	INSERT INTO tmp_new_po_mag_con
	SELECT 	mag_document_code,mag_agency_code, mag_document_id,mag_agency_history_id,mag_document_code_id,min(uniq_id)
	FROM	tmp_po_mag
	WHERE	master_agreement_id =0
	GROUP BY 1,2,3,4,5;
	
	TRUNCATE etl.agreement_id_seq;
	
	INSERT INTO etl.agreement_id_seq(uniq_id)
	SELECT uniq_id
	FROM  tmp_new_po_mag_con;
	
	INSERT INTO all_master_agreement(master_agreement_id,document_code_id,agency_history_id,document_id,document_version,privacy_flag)
	SELECT  b.agreement_id, a.mag_document_code_id,a.mag_agency_history_id,a.mag_document_id,0 as document_version,'F' as privacy_flag
	FROM	tmp_new_po_mag_con a JOIN etl.agreement_id_seq b ON a.uniq_id = b.uniq_id;
	
	INSERT INTO history_all_master_agreement(master_agreement_id,document_code_id,agency_history_id,document_id,document_version,privacy_flag)
	SELECT  b.agreement_id, a.mag_document_code_id,a.mag_agency_history_id,a.mag_document_id,0 as document_version,'F' as privacy_flag
	FROM	tmp_new_po_mag_con a JOIN etl.agreement_id_seq b ON a.uniq_id = b.uniq_id;	
	
	/* Rule covers this
	INSERT INTO master_agreement(master_agreement_id,document_code_id,agency_history_id,document_id,document_version)
	SELECT  b.agreement_id, a.mag_document_code_id,a.mag_agency_history_id,a.mag_document_id,0 as document_version
	FROM	tmp_new_po_mag_con a JOIN etl.agreement_id_seq b ON a.uniq_id = b.uniq_id;
	
	INSERT INTO history_master_agreement(master_agreement_id,document_code_id,agency_history_id,document_id,document_version)
	SELECT  b.agreement_id, a.mag_document_code_id,a.mag_agency_history_id,a.mag_document_id,0 as document_version
	FROM	tmp_new_po_mag_con a JOIN etl.agreement_id_seq b ON a.uniq_id = b.uniq_id;
	*/
	
	-- Updating the newly created MAG identifier.
	
	CREATE TEMPORARY TABLE tmp_new_po_mag_con_2(uniq_id bigint,master_agreement_id bigint)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_new_po_mag_con_2
	SELECT c.uniq_id,d.agreement_id
	FROM   tmp_po_mag a JOIN tmp_new_po_mag_con b ON a.uniq_id = b.uniq_id
		JOIN tmp_po_mag c ON c.mag_document_code = a.mag_document_code
				     AND c.mag_agency_code = a.mag_agency_code
				     AND c.mag_document_id = a.mag_document_id
		JOIN etl.agreement_id_seq d ON b.uniq_id = d.uniq_id;
		
	UPDATE tmp_po_mag a
	SET	master_agreement_id = b.master_agreement_id
	FROM	tmp_new_po_mag_con_2 b
	WHERE	a.uniq_id = b.uniq_id
		AND a.master_agreement_id =0;
	 	
	 UPDATE etl.stg_con_po_header a
	 SET	master_agreement_id = b.master_agreement_id
	 FROM	tmp_po_mag b
	 WHERE	a.uniq_id = b.uniq_id;
	 
	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in associateMAGToPO';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;

-----------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION updateForeignKeysForPOVendors(p_load_id_in bigint) RETURNS INT AS $$
DECLARE

BEGIN

	-- UPDATING FK VALUES IN VENDOR

	CREATE TEMPORARY TABLE tmp_fk_values_po_vendor(uniq_id bigint,vendor_customer_code varchar, vendor_history_id integer,miscellaneous_vendor_flag bit,
							lgl_nm varchar,alias_nm varchar)	
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_fk_values_po_vendor
	SELECT uniq_id,a.vend_cust_cd,MAX(c.vendor_history_id) as vendor_history_id,COALESCE(b.miscellaneous_vendor_flag,0::bit),
		MIN(a.lgl_nm),MIN(a.vend_cust_alias_nm)
	FROM	etl.stg_con_po_vendor a LEFT JOIN vendor b ON a.vend_cust_cd = b.vendor_customer_code
		LEFT JOIN vendor_history c ON b.vendor_id = c.vendor_id
	WHERE b.miscellaneous_vendor_flag = 0::bit OR b.miscellaneous_vendor_flag IS NULL		
	GROUP BY 1,2,4;
	
	INSERT INTO tmp_fk_values_po_vendor
	SELECT DISTINCT uniq_id,a.vend_cust_cd,0 as vendor_history_id,1::bit,
		a.lgl_nm,a.vend_cust_alias_nm
	FROM	etl.stg_con_po_vendor a LEFT JOIN vendor b ON a.vend_cust_cd = b.vendor_customer_code
	WHERE  b.miscellaneous_vendor_flag = 1::bit;
	
	-- Identify the new vendors
	
	CREATE TEMPORARY TABLE tmp_vendor_po_new(uniq_id bigint, vendor_customer_code varchar)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_vendor_po_new
	SELECT min(uniq_id) as uniq_id, vendor_customer_code
	FROM	tmp_fk_values_po_vendor
	WHERE   vendor_history_id IS NULL AND miscellaneous_vendor_flag = 0::bit
	GROUP BY 2
	HAVING COUNT(*) = 1; -- Miscellaneous one will be considered twice
	

	INSERT INTO tmp_vendor_po_new
	SELECT  uniq_id as uniq_id, vendor_customer_code
	FROM	tmp_fk_values_po_vendor
	WHERE   vendor_history_id =0 AND miscellaneous_vendor_flag = 1::bit;
	
	TRUNCATE etl.vendor_id_seq;
	
	INSERT INTO etl.vendor_id_seq(uniq_id)
	SELECT uniq_id
	FROM tmp_vendor_po_new;
	
	INSERT INTO vendor(vendor_id,vendor_customer_code,legal_name,alias_name,miscellaneous_vendor_flag,created_load_id,created_date)
	SELECT  a.vendor_id,b.vendor_customer_code,b.lgl_nm,b.alias_nm,b.miscellaneous_vendor_flag,  p_load_id_in,now()::timestamp
	FROM	etl.vendor_id_seq a JOIN tmp_fk_values_po_vendor b ON a.uniq_id = b.uniq_id;	

	TRUNCATE etl.vendor_history_id_seq;
	
	INSERT INTO etl.vendor_history_id_seq(uniq_id)
	SELECT uniq_id
	FROM tmp_vendor_po_new;


	INSERT INTO vendor_history(vendor_history_id,vendor_id,legal_name,alias_name,miscellaneous_vendor_flag,load_id,created_date)
	SELECT  a.vendor_history_id,c.vendor_id,b.lgl_nm,b.alias_nm,b.miscellaneous_vendor_flag, p_load_id_in,now()::timestamp
	FROM	etl.vendor_history_id_seq a JOIN tmp_fk_values_po_vendor b ON a.uniq_id = b.uniq_id
		JOIN etl.vendor_id_seq c ON a.uniq_id = c.uniq_id;
		
		
	CREATE TEMPORARY TABLE tmp_po_vendor(uniq_id bigint,vendor_history_id int)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_po_vendor
	SELECT c.uniq_id, d.vendor_history_id
	FROM tmp_fk_values_po_vendor a JOIN tmp_vendor_po_new b ON a.uniq_id = b.uniq_id  AND a.miscellaneous_vendor_flag=0::bit		
		JOIN tmp_fk_values_po_vendor c ON a.vendor_customer_code = c.vendor_customer_code
		JOIN etl.vendor_history_id_seq d ON b.uniq_id = d.uniq_id;
	

	INSERT INTO tmp_po_vendor
	SELECT a.uniq_id, d.vendor_history_id
	FROM tmp_fk_values_po_vendor a JOIN tmp_vendor_po_new b ON a.uniq_id = b.uniq_id AND a.miscellaneous_vendor_flag=1::bit		
		JOIN etl.vendor_history_id_seq d ON b.uniq_id = d.uniq_id;
		
	UPDATE tmp_fk_values_po_vendor a
	SET	vendor_history_id = b.vendor_history_id
	FROM	tmp_po_vendor b 
	WHERE	a.uniq_id = b.uniq_id;
					
	
	UPDATE etl.stg_con_po_vendor a
	SET	vendor_history_id = b.vendor_history_id
	FROM	tmp_fk_values_po_vendor b 
	WHERE	a.uniq_id = b.uniq_id;
	
	RETURN 1;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in updateForeignKeysForPOVendors';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;

---------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION etl.updateForeignKeysForPOInAccLine() RETURNS INT AS $$
DECLARE
BEGIN
	-- UPDATING FK VALUES IN ETL.stg_con_po_accounting_line
	
	CREATE TEMPORARY TABLE tmp_fk_values_po_acc_line(uniq_id bigint,event_type_id smallint, fund_class_id smallint,agency_history_id smallint,
							department_history_id int, expenditure_object_history_id integer,budget_code_id integer)
	DISTRIBUTED BY (uniq_id);
	
	-- FK:event_type_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,event_type_id)
	SELECT	a.uniq_id, b.event_type_id
	FROM etl.stg_con_po_accounting_line a JOIN ref_event_type b ON a.evnt_typ_id = b.event_type_code;	
	
	-- FK:fund_class_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,fund_class_id)
	SELECT	a.uniq_id, b.fund_class_id
	FROM etl.stg_con_po_accounting_line a JOIN ref_fund_class b ON a.fund_cd = b.fund_class_code;	

	-- FK:agency_history_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,agency_history_id)
	SELECT	a.uniq_id, max(c.agency_history_id) 
	FROM etl.stg_con_po_accounting_line a JOIN ref_agency b ON a.dept_cd = b.agency_code
		JOIN ref_agency_history c ON b.agency_id = c.agency_id
	GROUP BY 1	;	

	-- FK:department_history_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,department_history_id)
	SELECT	a.uniq_id, max(c.department_history_id) 
	FROM etl.stg_con_po_accounting_line a JOIN ref_department b ON a.appr_cd = b.department_code AND a.bfy = b.fiscal_year
		JOIN ref_department_history c ON b.department_id = c.department_id
		JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
		JOIN ref_fund_class e ON a.fund_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id
	GROUP BY 1	;		


	-- FK:expenditure_object_history_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,expenditure_object_history_id)
	SELECT	a.uniq_id, max(c.expenditure_object_history_id) 
	FROM etl.stg_con_po_accounting_line a JOIN ref_expenditure_object b ON a.obj_cd = b.expenditure_object_code AND a.bfy = b.fiscal_year
		JOIN ref_expenditure_object_history c ON b.expenditure_object_id = c.expenditure_object_id
	GROUP BY 1	;


	-- FK:budget_code_id

	INSERT INTO tmp_fk_values_po_acc_line(uniq_id,budget_code_id)
	SELECT	a.uniq_id, b.budget_code_id
	FROM etl.stg_con_po_accounting_line a JOIN ref_budget_code b ON a.func_cd = b.budget_code AND a.bfy=b.fiscal_year
		JOIN ref_agency d ON a.dept_cd = d.agency_code AND b.agency_id = d.agency_id
		JOIN ref_fund_class e ON a.fund_cd = e.fund_class_code AND e.fund_class_id = b.fund_class_id;	
		
	
	UPDATE etl.stg_con_po_accounting_line a
	SET	event_type_id =ct_table.event_type_id ,
		fund_class_id =ct_table.fund_class_id ,
		agency_history_id =ct_table.agency_history_id ,
		department_history_id =ct_table.department_history_id ,
		expenditure_object_history_id =ct_table.expenditure_object_history_id ,
		budget_code_id=ct_table.budget_code_id 
	FROM	
		(SELECT uniq_id,
			max(event_type_id )as event_type_id ,
			max(fund_class_id )as fund_class_id ,
			max(agency_history_id )as agency_history_id ,
			max(department_history_id )as department_history_id ,
			max(expenditure_object_history_id )as expenditure_object_history_id ,
			max(budget_code_id) as budget_code_id 
		FROM	tmp_fk_values_po_acc_line
		GROUP	BY 1) ct_table
	WHERE	a.uniq_id = ct_table.uniq_id;	

	RETURN 1;
	
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in updateForeignKeysForPOInAccLine';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION etl.processCONPurchaseOrder(p_load_file_id_in int,p_load_id_in bigint) RETURNS INT AS $$
DECLARE
	l_worksite_col_array VARCHAR ARRAY[10];
	l_array_ctr smallint;
	l_fk_update int;
	l_worksite_per_array VARCHAR ARRAY[10];
	l_insert_sql VARCHAR;
BEGIN
	l_worksite_col_array := ARRAY['wk_site_cd_01',
				      'wk_site_cd_02',
				      'wk_site_cd_03',
				      'wk_site_cd_04',
				      'wk_site_cd_05',
				      'wk_site_cd_06',
				      'wk_site_cd_07',
				      'wk_site_cd_08',
				      'wk_site_cd_09',
				      'wk_site_cd_10'];
				      
	l_worksite_per_array := ARRAY['percent_01',
				      'percent_02',
				      'percent_03',
				      'percent_04',
				      'percent_05',
				      'percent_06',
				      'percent_07',
				      'percent_08',
				      'percent_09',
				      'percent_10'];
				      

	l_fk_update := etl.updateForeignKeysForPOInHeader(p_load_id_in);

	RAISE NOTICE 'CON 1';
	
	IF l_fk_update = 1 THEN
		l_fk_update := etl.updateForeignKeysForPOInAwardDetail();
	ELSE
		RETURN -1;
	END IF;

	RAISE NOTICE 'CON 2';
	
	IF l_fk_update = 1 THEN
		l_fk_update := etl.associateMAGToPO();
	ELSE
		RETURN -1;
	END IF;

	RAISE NOTICE 'CON 3';
	
	IF l_fk_update = 1 THEN
		l_fk_update := etl.updateForeignKeysForPOVendors(p_load_id_in);
	ELSE
		RETURN -1;
	END IF;

	RAISE NOTICE 'CON 4';
	
	IF l_fk_update = 1 THEN	 
		l_fk_update := etl.updateForeignKeysForPOInAccLine();	
	ELSE
		RETURN -1;
	END IF;


	IF l_fk_update <> 1 THEN
		RETURN -1;
	END IF;
	
	RAISE NOTICE 'CON 5';
	-- UPDATING FK VALUES IN ETL.STG_CON_PO_COMMODITY
	
	CREATE TEMPORARY TABLE tmp_fk_values_po_commodity(uniq_id bigint,commodity_type_id int)
	DISTRIBUTED BY (uniq_id);	
	
	-- FK:commodity_type_id

	INSERT INTO tmp_fk_values_po_commodity(uniq_id,commodity_type_id)
	SELECT	a.uniq_id, b.commodity_type_id
	FROM etl.stg_con_po_commodity a JOIN ref_commodity_type b ON a.ln_typ = b.commodity_type_id;
	
	UPDATE etl.stg_con_po_commodity a
	SET	commodity_type_id = b.commodity_type_id
	FROM	tmp_fk_values_po_commodity b
	WHERE 	a.uniq_id = b.uniq_id;
	
	/*
	1.Pull the key information such as document code, document id, document version etc for all agreements
	2. For the existing contracts gather details on max version in the transaction, staging tables..Determine if the staged agreement is latest version...
	3. Identify the new agreements. Determine the latest version for each of it.
	*/
	
	RAISE NOTICE 'CON 6';
	CREATE TEMPORARY TABLE tmp_po_con(uniq_id bigint, agency_history_id smallint,doc_id varchar,agreement_id bigint, action_flag char(1), 
					  latest_flag char(1),doc_vers_no smallint,privacy_flag char(1),old_agreement_ids varchar)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_po_con(uniq_id,agency_history_id,doc_id,doc_vers_no,privacy_flag)
	SELECT uniq_id,agency_history_id,doc_id,doc_vers_no,'F' as privacy_flag
	FROM etl.stg_con_po_header;
	
	-- For the existing contracts gather details on max version in the transaction, staging tables..Determine if the staged agreement is latest version...
	
	CREATE TEMPORARY TABLE tmp_old_po_con(uniq_id bigint,agreement_id bigint, action_flag char(1), latest_flag char(1),privacy_flag char(1),old_agreement_ids varchar)
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_old_po_con
	SELECT d.uniq_id,
		inner_tbl.agreement_id,
		(CASE WHEN match_count = 1 THEN 'U' ELSE 'I' END) as action_flag,
		(CASE WHEN d.doc_vers_no >= staging_max_doc_vers_no AND d.doc_vers_no >= max_document_version THEN 'Y' ELSE 'N' END) as latest_flag,
		privacy_flag,
		old_agreement_ids
	FROM	
		(SELECT  uniq_id,		
			MAX(c.agency_history_id) as stagig_agency_history_id,	
			MIN(a.doc_id) as staging_document_id,
			MAX(a.doc_vers_no) as staging_max_doc_vers_no,
			MAX(b.document_version) as max_document_version, 
			SUM(CASE WHEN a.doc_vers_no = b.document_version THEN 1 ELSE 0 END) as match_count,			
			MAX(CASE WHEN a.doc_vers_no = b.document_version THEN b.agreement_id ELSE 0 END) as agreement_id,
			MAX(b.privacy_flag) as privacy_flag,
			GROUP_CONCAT(b.agreement_id) as old_agreement_ids
		FROM etl.stg_con_po_header a JOIN history_all_agreement b ON a.doc_id = b.document_id AND a.document_code_id = b.document_code_id
			JOIN ref_agency_history c ON a.agency_history_id = c.agency_history_id
			JOIN ref_agency_history d ON b.agency_history_id = d.agency_history_id
			JOIN ref_agency e ON c.agency_id = d.agency_id AND a.doc_dept_cd = e.agency_code
		GROUP BY 1) inner_tbl JOIN etl.stg_con_po_header d ON inner_tbl.uniq_id = d.uniq_id;
			
	
	UPDATE tmp_po_con a
	SET	agreement_id = b.agreement_id,
		action_flag = b.action_flag,
		latest_flag = b.latest_flag,
		privacy_flag=b.privacy_flag,
		old_agreement_ids = b.old_agreement_ids
	FROM	tmp_old_po_con b
	WHERE	a.uniq_id = b.uniq_id;
	
	RAISE NOTICE 'CON 7';
	-- Identify the new agreements. Determine the latest version for each of it.
	
	CREATE TEMPORARY TABLE tmp_new_po_con(uniq_id bigint,agreement_id bigint, action_flag char(1), latest_flag char(1))
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_new_po_con
	SELECT inner_tbl.uniq_id,
		0 as agreement_id,
		'I' as action_flag,
		(CASE WHEN COALESCE(latest_flag,'Y') ='Y' AND c.doc_vers_no = inner_tbl.staging_max_doc_vers_no THEN 'Y' ELSE 'N' END) as latest_flag
	FROM	
	(SELECT  a.uniq_id,
		max(b.doc_vers_no) as staging_max_doc_vers_no
	FROM	tmp_po_con a JOIN etl.stg_con_po_header b ON a.doc_id = b.doc_id AND a.agency_history_id = b.agency_history_id
	WHERE	COALESCE(a.agreement_id,0) =0 AND a.action_flag IS NULL
	GROUP BY 1) inner_tbl JOIN tmp_po_con c ON inner_tbl.uniq_id = c.uniq_id;
	

	TRUNCATE etl.agreement_id_seq;
	
	
	INSERT INTO etl.agreement_id_seq(uniq_id)
	SELECT uniq_id
	FROM	tmp_new_po_con;
	
	UPDATE tmp_new_po_con a
	SET	agreement_id = b.agreement_id
	FROM	etl.agreement_id_seq b
	WHERE	a.uniq_id = b.uniq_id;
	
	UPDATE tmp_po_con a
	SET	agreement_id = b.agreement_id,
		action_flag = b.action_flag,
		latest_flag = b.latest_flag,
		privacy_flag='F'
	FROM	tmp_new_po_con b
	WHERE	a.uniq_id = b.uniq_id;
	
	RAISE NOTICE 'CON 8';
	-- Handling new ones
		-- match_count is 0 & staging_doc_vers_no > max_document_version then delete the existing one from agreement and insert new records in both agreement,history_agreement
		-- match_count is 0 & staging_doc_vers_no < max_document_version then insert into history_agreement
	-- Handling existing ones
		-- match_count is 0 & staging_doc_vers_no = max_document_version then update agreement,history_agreement. Delete the corresponding child records and insert new sets
		-- match_count is 0 & staging_doc_vers_no < max_document_version then update history_agreement. Delete the corresponding child records and insert new sets
		
	/* Identify the agreements which have to be deleted since the latest version has been recieved in the data feed.*/
	
	CREATE TEMPORARY TABLE tmp_po_deletion(agreement_id bigint, new_agreement_id bigint, uniq_id bigint)
	DISTRIBUTED BY (agreement_id);
	
	INSERT INTO tmp_po_deletion
	SELECT  unnest(string_to_array(old_agreement_ids,','))::int as agreement_id, agreement_id as new_agreement_id, uniq_id
	FROM	tmp_po_con
	WHERE	action_flag = 'I'
		AND latest_flag ='Y';	
		
	DELETE FROM all_agreement_accounting_line WHERE agreement_id IN (select agreement_id from tmp_po_deletion);
	
	DELETE FROM all_agreement_commodity WHERE agreement_id IN (select agreement_id from tmp_po_deletion);
	
	DELETE FROM all_agreement_worksite WHERE agreement_id IN (select agreement_id from tmp_po_deletion) AND master_agreement_yn='N';	
	
	DELETE FROM agreement WHERE agreement_id IN (select agreement_id from tmp_po_deletion);
	DELETE FROM all_agreement WHERE agreement_id IN (select agreement_id from tmp_po_deletion);	

	RAISE NOTICE 'CON 9';
	INSERT INTO all_agreement(agreement_id,master_agreement_id,document_code_id,
				agency_history_id,document_id,document_version,
				tracking_number,record_date_id,budget_fiscal_year,
				document_fiscal_year,document_period,description,
				actual_amount,maximum_contract_amount,
				amendment_number,replacing_agreement_id,replaced_by_agreement_id,
				procurement_id,procurement_type_id,
				effective_begin_date_id,effective_end_date_id,reason_modification,
				source_created_date_id,source_updated_date_id,document_function_code_id,
				award_method_id,award_level_id,agreement_type_id,
				contract_class_code,award_category_id_1,				
				number_responses,
				vendor_history_id,vendor_preference_level,				
				number_solicitation,document_name,
				privacy_flag,created_load_id,created_date)
	SELECT	d.agreement_id,a.master_agreement_id,a.document_code_id,
		a.agency_history_id,a.doc_id,a.doc_vers_no,
		a.trkg_no,a.record_date_id,a.doc_bfy,
		a.doc_fy_dc,a.doc_per_dc,a.doc_dscr,
		a.doc_actu_am,a.max_cntrc_am,
		a.amend_no,0 as replacing_agreement_id,0 as replaced_by_agreement_id,
		a.prcu_id,a.procurement_type_id,
		a.effective_begin_date_id,a.effective_end_date_id,a.reas_mod_dc,
		a.source_created_date_id,a.source_updated_date_id,a.document_function_code_id,
		c.award_method_id,c.award_level_id,c.agreement_type_id,
		c.ctcls_cd,c.award_category_id_1,		
		c.resp_ct,
		b.vendor_history_id,b.vend_pref_lvl,
		c.out_of_no_so,a.doc_nm,
		d.privacy_flag,p_load_id_in,now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_vendor b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
					     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
					JOIN etl.stg_con_po_award_detail c ON a.doc_cd = c.doc_cd AND a.doc_dept_cd = c.doc_dept_cd 
					     AND a.doc_id = c.doc_id AND a.doc_vers_no = c.doc_vers_no
					 JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   action_flag='I' and latest_flag='Y';				 


	/* Insert new contracts into history_all_agreement
	identified by action flag as I 
	It will be inserted into hist_agreement based on the rule
	*/
	
	INSERT INTO history_all_agreement(agreement_id,master_agreement_id,document_code_id,
				agency_history_id,document_id,document_version,
				tracking_number,record_date_id,budget_fiscal_year,
				document_fiscal_year,document_period,description,
				actual_amount,maximum_contract_amount,
				amendment_number,replacing_agreement_id,replaced_by_agreement_id,
				procurement_id,procurement_type_id,
				effective_begin_date_id,effective_end_date_id,reason_modification,
				source_created_date_id,source_updated_date_id,document_function_code_id,
				award_method_id,award_level_id,agreement_type_id,
				contract_class_code,award_category_id_1,				
				number_responses,
				vendor_history_id,vendor_preference_level,				
				number_solicitation,document_name,
				privacy_flag,created_load_id,created_date)
	SELECT	d.agreement_id,a.master_agreement_id,a.document_code_id,
		a.agency_history_id,a.doc_id,a.doc_vers_no,
		a.trkg_no,a.record_date_id,a.doc_bfy,
		a.doc_fy_dc,a.doc_per_dc,a.doc_dscr,
		a.doc_actu_am,a.max_cntrc_am,
		a.amend_no,0 as replacing_agreement_id,0 as replaced_by_agreement_id,
		a.prcu_id,a.procurement_type_id,
		a.effective_begin_date_id,a.effective_end_date_id,a.reas_mod_dc,
		a.source_created_date_id,a.source_updated_date_id,a.document_function_code_id,
		c.award_method_id,c.award_level_id,c.agreement_type_id,
		c.ctcls_cd,c.award_category_id_1,
		c.resp_ct,
		b.vendor_history_id,b.vend_pref_lvl,
		c.out_of_no_so,a.doc_nm,
		d.privacy_flag,p_load_id_in,now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_vendor b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
					     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
					JOIN etl.stg_con_po_award_detail c ON a.doc_cd = c.doc_cd AND a.doc_dept_cd = c.doc_dept_cd 
					     AND a.doc_id = c.doc_id AND a.doc_vers_no = c.doc_vers_no
					 JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   action_flag='I';				 
	
	/* Updates */
	CREATE TEMPORARY TABLE tmp_con_po_update AS
	SELECT d.agreement_id,a.master_agreement_id,a.document_code_id,
			a.agency_history_id,a.doc_id,a.doc_vers_no,
			a.trkg_no,a.record_date_id,a.doc_bfy,
			a.doc_fy_dc,a.doc_per_dc,a.doc_dscr,
			a.doc_actu_am,a.max_cntrc_am,
			a.amend_no,0 as replacing_agreement_id,0 as replaced_by_agreement_id,
			a.prcu_id,a.procurement_type_id,
			a.effective_begin_date_id,a.effective_end_date_id,a.reas_mod_dc,
			a.source_created_date_id,a.source_updated_date_id,a.document_function_code_id,
			c.award_method_id,c.award_level_id,c.agreement_type_id,
			c.ctcls_cd,c.award_category_id_1,
			c.resp_ct,
			b.vendor_history_id,b.vend_pref_lvl,
			c.out_of_no_so,a.doc_nm,
			d.privacy_flag,p_load_id_in as load_id,now()::timestamp as updated_date
		FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_vendor b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
						     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
						JOIN etl.stg_con_po_award_detail c ON a.doc_cd = c.doc_cd AND a.doc_dept_cd = c.doc_dept_cd 
						     AND a.doc_id = c.doc_id AND a.doc_vers_no = c.doc_vers_no
						 JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   action_flag='U'
	DISTRIBUTED BY (agreement_id);				 

	UPDATE history_all_agreement a
	SET	master_agreement_id = b.master_agreement_id,
		document_code_id = b.document_code_id,
		agency_history_id  = b.agency_history_id,
		document_id  = b.doc_id,
		document_version = b.doc_vers_no,
		tracking_number = b.trkg_no,
		record_date_id = b.record_date_id,
		budget_fiscal_year = b.doc_bfy,
		document_fiscal_year = b.doc_fy_dc,
		document_period = b.doc_per_dc,
		description = b.doc_dscr,
		actual_amount = b.doc_actu_am,
		maximum_contract_amount = b.max_cntrc_am,
		amendment_number = b.amend_no,
		replacing_agreement_id = b.replacing_agreement_id,
		replaced_by_agreement_id = b.replaced_by_agreement_id,
		procurement_id = b.prcu_id,
		procurement_type_id = b.procurement_type_id,
		effective_begin_date_id = b.effective_begin_date_id,
		effective_end_date_id = b.effective_end_date_id,
		reason_modification = b.reas_mod_dc,
		source_created_date_id = b.source_created_date_id,
		source_updated_date_id = b.source_updated_date_id,
		document_function_code_id = b.document_function_code_id,
		award_method_id = b.award_method_id,
		award_level_id = b.award_level_id,
		agreement_type_id = b.agreement_type_id,
		contract_class_code = b.ctcls_cd,
		award_category_id_1 = b.award_category_id_1,
		number_responses = b.resp_ct,
		vendor_history_id = b.vendor_history_id,
		vendor_preference_level = b.vend_pref_lvl,
		number_solicitation = b.out_of_no_so,
		document_name = b.doc_nm,
		privacy_flag = b.privacy_flag,
		updated_load_id = b.load_id,		
		updated_date = b.updated_date
	FROM	tmp_con_po_update b
	WHERE	a.agreement_id = b.agreement_id;
	
	/* Delete the existing agreement line items
	Rule is set up on all_agreement_accounting_line to delete from agreement_accounting_line
	Rule is set up on history_all_agreement_accounting_line to delete from history_agreement_accounting_line
	*/

	RAISE NOTICE 'CON 10';
	TRUNCATE tmp_po_deletion;
	
	INSERT INTO tmp_po_deletion
	SELECT  agreement_id
	FROM	tmp_po_con
	WHERE	action_flag = 'U';
	
	DELETE FROM all_agreement_accounting_line WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
		
	DELETE FROM history_all_agreement_accounting_line WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
	
	-- Associate Disbursement line item to the latest version of the agreement
	
	CREATE TEMPORARY TABLE tmp_po_fms_line_item(disbursement_line_item_id bigint, agreement_id bigint,maximum_contract_amount numeric(16,2))
	DISTRIBUTED BY (disbursement_line_item_id);
	
	INSERT INTO tmp_po_fms_line_item
	SELECT disbursement_line_item_id, b.new_agreement_id,c.max_cntrc_am
	FROM disbursement_line_item a JOIN tmp_po_deletion b ON a.agreement_id = b.agreement_id
		JOIN etl.stg_con_po_header c ON b.uniq_id = c.uniq_id;
	
	UPDATE disbursement_line_item a
	SET	agreement_id = b.agreement_id,
		updated_load_id = p_load_id_in,
		updated_date = now()::timestamp
	FROM	tmp_po_fms_line_item b
	WHERE	a.disbursement_line_item_id = b.disbursement_line_item_id;
	
	UPDATE fact_disbursement_line_item a
	SET	agreement_id = b.agreement_id,
		maximum_contract_amount = b.maximum_contract_amount
	FROM	tmp_po_fms_line_item b
	WHERE	a.disbursement_line_item_id = b.disbursement_line_item_id;
	
	-- End of associating Disbursement line item to the latest version of an agreement

	
	/* Insert the agreement accounting lines.
	Accounting lines of the Latest version will be inserted into all_agreement_accounting_line.
	Accounting lines of the Latest version corresponding to public agreements will be inserted into all_agreement_accounting_line.
	Accounting lines of all the versions will be inserted into history_all_agreement_accounting_line.
	Accounting lines of all the versions of public agreements will be inserted into history_agreement_accounting_line.
	*/
	INSERT INTO all_agreement_accounting_line(agreement_id,line_number,
			event_type_id,description,line_amount,
			budget_fiscal_year,fiscal_year,fiscal_period,
			fund_class_id,agency_history_id,department_history_id,
			expenditure_object_history_id,revenue_source_id,location_code,
			budget_code_id,reporting_code,load_id,
			created_date)	
	SELECT  d.agreement_id,b.doc_actg_ln_no,
		b.event_type_id,b.actg_ln_dscr,b.ln_am,
		b.bfy,b.fy_dc,b.per_dc,
		b.fund_class_id,b.agency_history_id,b.department_history_id,
		b.expenditure_object_history_id,null as revenue_source_id,b.loc_cd,
		b.budget_code_id,b.rpt_cd,p_load_id_in,
		now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_accounting_line b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
					     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
					     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   latest_flag='Y';		
					     
	INSERT INTO agreement_accounting_line
	SELECT a.*
	FROM   all_agreement_accounting_line a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';
	

	INSERT INTO history_all_agreement_accounting_line
	SELECT a.*
	FROM   all_agreement_accounting_line a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';
	
	INSERT INTO history_all_agreement_accounting_line(agreement_id,line_number,
			event_type_id,description,line_amount,
			budget_fiscal_year,fiscal_year,fiscal_period,
			fund_class_id,agency_history_id,department_history_id,
			expenditure_object_history_id,revenue_source_id,location_code,
			budget_code_id,reporting_code,load_id,
			created_date)	
	SELECT  d.agreement_id,b.doc_actg_ln_no,
		b.event_type_id,b.actg_ln_dscr,b.ln_am,
		b.bfy,b.fy_dc,b.per_dc,
		b.fund_class_id,b.agency_history_id,b.department_history_id,
		b.expenditure_object_history_id,null as revenue_source_id,b.loc_cd,
		b.budget_code_id,b.rpt_cd,p_load_id_in,
		now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_accounting_line b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
					     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
					     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   latest_flag='N';
	
	INSERT INTO history_agreement_accounting_line
	SELECT a.*
	FROM   history_all_agreement_accounting_line a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';
	

	RAISE NOTICE 'CON 11';
	-- Capturing worksite information
	
	DELETE FROM all_agreement_worksite WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
		
	DELETE FROM history_all_agreement_worksite WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);

	
	FOR l_array_ctr IN 1..array_upper(l_worksite_col_array,1) LOOP
	
		l_insert_sql := ' INSERT INTO all_agreement_worksite(agreement_id,worksite_id,percentage,amount,master_agreement_yn,load_id,created_date) '||
				' SELECT d.agreement_id,c.worksite_id,b.'|| l_worksite_per_array[l_array_ctr] || ',(a.max_cntrc_am *b.'||l_worksite_per_array[l_array_ctr] || ')/100 as amount ,''N'',' ||p_load_id_in || ', now()::timestamp '||
				' FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_award_detail b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd '||
				'			     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no '||
				'			     JOIN ref_worksite c ON b.' || l_worksite_col_array[l_array_ctr] || ' = c.worksite_code ' ||
				'			     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id '||
				' WHERE latest_flag=''Y'' ';			     

		EXECUTE l_insert_sql;		
		
		l_insert_sql := ' INSERT INTO history_all_agreement_worksite(agreement_id,worksite_id,percentage,amount,master_agreement_yn,load_id,created_date) '||
				' SELECT d.agreement_id,c.worksite_id,b.'|| l_worksite_per_array[l_array_ctr] || ',(a.max_cntrc_am *b.'|| l_worksite_per_array[l_array_ctr] || ')/100 as amount ,''N'',' ||p_load_id_in || ', now()::timestamp '||
				' FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_award_detail b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd '||
				'			     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no '||
				'			     JOIN ref_worksite c ON b.' || l_worksite_col_array[l_array_ctr] || ' = c.worksite_code ' ||
				'			     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id '||
				' WHERE latest_flag=''N'' ';	

		EXECUTE l_insert_sql;			
	END LOOP; 
	
	INSERT INTO agreement_worksite
	SELECT a.* 
	FROM 	all_agreement_worksite a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	b.privacy_flag ='F';
	
	INSERT INTO history_all_agreement_worksite
	SELECT a.* 
	FROM 	all_agreement_worksite a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id;


	INSERT INTO history_agreement_worksite
	SELECT a.* 
	FROM 	history_all_agreement_worksite a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	b.privacy_flag ='F';

	RAISE NOTICE 'CON 12';
	-- Capturing commodity

	DELETE FROM all_agreement_commodity WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
		
	DELETE FROM history_all_agreement_commodity WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
	
	INSERT INTO all_agreement_commodity(agreement_id,line_number,master_agreement_yn,
					    description,commodity_code,commodity_type_id,
					    quantity,unit_of_measurement,unit_price,
					    contract_amount,commodity_specification,load_id,
					    created_date)
	SELECT	d.agreement_id,b.doc_comm_ln_no,'N' as master_agreement_yn,
		b.cl_dscr,b.comm_cd,b.commodity_type_id,
		b.qty,b.unit_meas_cd,b.unit_price,
		b.cntrc_am,b.comm_cd_spfn,p_load_id_in,
		now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_commodity b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
						     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
						     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   latest_flag='Y';	
	
	

	INSERT INTO agreement_commodity
	SELECT a.*
	FROM   all_agreement_commodity a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';
	

	INSERT INTO history_all_agreement_commodity
	SELECT a.*
	FROM   all_agreement_commodity a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';
	
	INSERT INTO history_all_agreement_commodity(agreement_id,line_number,master_agreement_yn,
					    description,commodity_code,commodity_type_id,
					    quantity,unit_of_measurement,unit_price,
					    contract_amount,commodity_specification,load_id,
					    created_date)
	SELECT	d.agreement_id,b.doc_comm_ln_no,'N' as master_agreement_yn,
		b.cl_dscr,b.comm_cd,b.commodity_type_id,
		b.qty,b.unit_meas_cd,b.unit_price,
		b.cntrc_am,b.comm_cd_spfn,p_load_id_in,
		now()::timestamp
	FROM	etl.stg_con_po_header a JOIN etl.stg_con_po_commodity b ON a.doc_cd = b.doc_cd AND a.doc_dept_cd = b.doc_dept_cd 
						     AND a.doc_id = b.doc_id AND a.doc_vers_no = b.doc_vers_no
						     JOIN tmp_po_con d ON a.uniq_id = d.uniq_id
	WHERE   latest_flag='N';	
	
	INSERT INTO history_agreement_commodity
	SELECT a.*
	FROM   history_all_agreement_commodity a JOIN tmp_po_con b ON a.agreement_id = b.agreement_id
	WHERE	privacy_flag = 'F';	

	RAISE NOTICE 'CON 13';
	
	------------ Insering into the fact table----------------------------------------------------------------------------------------------------

	DELETE FROM fact_agreement WHERE agreement_id IN (SELECT agreement_id FROM tmp_po_deletion);
	
	INSERT INTO fact_agreement(agreement_id,master_agreement_id,document_code_id,agency_id,
				document_id,document_version,effective_begin_date_id,effective_end_date_id,
				registered_date_id,maximum_contract_amount,award_method_id,
				vendor_id,original_contract_amount,master_agreement_yn,description)
	SELECT a.agreement_id,a.master_agreement_id,a.document_code_id,b.agency_id,
		a.document_id,a.document_version,a.effective_begin_date_id,a.effective_end_date_id,
		a.registered_date_id,a.maximum_contract_amount,a.award_method_id,
		c.vendor_id,a.original_contract_amount,'N' as master_agreement_yn,a.description
	FROM   agreement a JOIN ref_agency_history b ON a.agency_history_id = b.agency_history_id
		JOIN vendor_history c ON a.vendor_history_id = c.vendor_history_id
		JOIN tmp_po_con d ON a.agreement_id = d.agreement_id;	
		
	RETURN 1;
	
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in processCONPurchaseOrder';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
END;
$$ language plpgsql;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
