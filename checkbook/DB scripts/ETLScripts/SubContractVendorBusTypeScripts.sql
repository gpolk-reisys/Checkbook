/*
Functions defined
	processFMSVVendorBusType
*/
CREATE OR REPLACE FUNCTION etl.processSubConVendorBusType(p_load_file_id_in int,p_load_id_in bigint) RETURNS INT AS $$
DECLARE
	rec_count int;
BEGIN	
	
	--  processing data to insert/update in subcontract_vendor_business_type table
	
	CREATE TEMPORARY TABLE tmp_scntrc_ven_bus_type(uniq_id bigint, scntrc_vend_cd varchar, bus_typ varchar, bus_typ_sta integer, min_typ integer,  action_flag char(1))
	DISTRIBUTED BY (uniq_id);
	
	INSERT INTO tmp_scntrc_ven_bus_type(uniq_id, scntrc_vend_cd, bus_typ,	bus_typ_sta, min_typ,  action_flag)
	SELECT MAX(uniq_id) as uniq_id, scntrc_vend_cd, bus_type, bus_typ_sta, min_type,  'I' as action_flag
	FROM etl.stg_scntrc_bus_type 
	GROUP BY 2,3,4,5,6;
	
	UPDATE tmp_scntrc_ven_bus_type a
	SET action_flag = 'U'
	FROM subvendor_business_type b LEFT JOIN ref_business_type c ON b.business_type_id = c.business_type_id
	WHERE a.scntrc_vend_cd = b.vendor_customer_code AND a.bus_type = c.business_type_code 
	AND a.bus_typ_sta = b.status AND a.min_typ = b.minority_type_id ;
	
		
	INSERT INTO subcontract_vendor_business_type(vendor_customer_code,business_type_id,status,
    				       minority_type_id,certification_start_date,certification_end_date, initiation_date, certification_no, disp_certification_start_date)
    	SELECT  a.vend_cust_cd,c.business_type_id,a.bus_typ_sta,
    		a.min_typ,a.cert_strt_dt,a.cert_end_dt,a.init_dt, a.cert_no, a.disp_cert_strt_dt
    	FROM	etl.stg_scntrc_bus_type a JOIN tmp_scntrc_ven_bus_type b ON a.uniq_id = b.uniq_id LEFT JOIN ref_business_type c ON b.bus_typ = c.business_type_code
    	WHERE b.action_flag = 'I';
    
    
    	GET DIAGNOSTICS rec_count = ROW_COUNT;	
	
	INSERT INTO etl.etl_data_load_verification(load_file_id,data_source_code,num_transactions,description)
	VALUES(p_load_file_id_in,'SV',rec_count, '# of records inserted into subcontract_vendor_business_type');
	
	
    UPDATE 	subcontract_vendor_business_type a
    SET certification_start_date = b.cert_strt_dt,
    certification_end_date = b.cert_end_dt,
    initiation_date = b.init_dt,
    certification_no = b.cert_no,
    disp_certification_start_date = b.disp_cert_strt_dt
    FROM tmp_scntrc_ven_bus_type d JOIN etl.stg_scntrc_bus_type b ON d.uniq_id = b.uniq_id LEFT JOIN ref_business_type c ON a.bus_type = c.business_type_code
    WHERE a.vendor_customer_code = b.vend_cust_cd AND a.business_type_id = c.business_type_id 
    AND a.status = b.bus_typ_sta AND a.minority_type_id = b.min_typ
    AND d.action_flag = 'U';
		
	GET DIAGNOSTICS rec_count = ROW_COUNT;	
	
	INSERT INTO etl.etl_data_load_verification(load_file_id,data_source_code,num_transactions,description)
	VALUES(p_load_file_id_in,'SV',rec_count, '# of records updated into subcontract_vendor_business_type');
	
	
	
	--  processing data to insert/update in subcontract_business_type table
	
	CREATE TEMPORARY TABLE tmp_scntrc_bus_type(uniq_id bigint, doc_cd varchar, doc_dept_cd varchar, doc_id varchar, scntrc_id varchar, 
	scntrc_vend_cd varchar, bus_type varchar, bus_typ_sta integer, min_typ integer,  action_flag char(1))
	DISTRIBUTED BY (uniq_id);
	
	
	INSERT INTO tmp_scntrc_bus_type(uniq_id, doc_cd, doc_dept_cd, doc_id, scntrc_id, scntrc_vend_cd, bus_typ,	bus_typ_sta, min_typ,  action_flag)
	SELECT MAX(uniq_id) as uniq_id, doc_cd, doc_dept_cd, doc_id, scntrc_id, scntrc_vend_cd, bus_type, bus_typ_sta, min_type,  'I' as action_flag
	FROM etl.stg_scntrc_bus_type 
	GROUP BY 2,3,4,5,6,7,8,9;
	
	UPDATE tmp_scntrc_bus_type a
	SET action_flag = 'U'
	FROM subcontract_business_type b LEFT JOIN ref_business_type c ON b.business_type_id = c.business_type_id
	WHERE  a.doc_cd || a.doc_dept_cd || a.doc_id  = b.contract_number 
	AND a.scntrc_id = b.subcontract_id AND a.scntrc_vend_cd = b.vendor_customer_code AND a.bus_type = c.business_type_code 
	AND a.bus_typ_sta = b.status AND a.min_typ = b.minority_type_id ;
	
		
	INSERT INTO subcontract_business_type(vendor_customer_code,contract_number, subcontract_id, business_type_id,status,
    				       minority_type_id, load_id, created_date)
    	SELECT  a.vend_cust_cd,a.doc_cd || a.doc_dept_cd || a.doc_id, a.scntrc_id, c.business_type_id,a.bus_typ_sta,
    		a.min_typ, p_load_id_in as created_load_id, now()::timestamp
    	FROM	etl.stg_scntrc_bus_type a JOIN tmp_scntrc_bus_type b ON a.uniq_id = b.uniq_id LEFT JOIN ref_business_type c ON b.bus_typ = c.business_type_code
    	WHERE b.action_flag = 'I';
    
    
    	GET DIAGNOSTICS rec_count = ROW_COUNT;	
	
	INSERT INTO etl.etl_data_load_verification(load_file_id,data_source_code,num_transactions,description)
	VALUES(p_load_file_id_in,'SV',rec_count, '# of records inserted into subcontract_business_type');
	
	
	
	RETURN 1;

EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Exception Occurred in processSubConVendorBusType';
	RAISE NOTICE 'SQL ERRROR % and Desc is %' ,SQLSTATE,SQLERRM;	

	RETURN 0;
		
END;
$$ language plpgsql;