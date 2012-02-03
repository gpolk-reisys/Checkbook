CREATE RULE all_agreement_rule AS ON INSERT TO all_agreement
WHERE privacy_flag ='F'
DO ALSO INSERT INTO agreement(agreement_id,master_agreement_id,document_code_id,
				agency_history_id,document_id,document_version,
				tracking_number,record_date_id,budget_fiscal_year,
				document_fiscal_year,document_period,description,
				actual_amount,obligated_amount,maximum_contract_amount,
				amendment_number,replacing_agreement_id,replaced_by_agreement_id,
				award_status_id,procurement_id,procurement_type_id,
				effective_begin_date_id,effective_end_date_id,reason_modification,
				source_created_date_id,source_updated_date_id,document_function_code_id,
				award_method_id,award_level_id,agreement_type_id,
				contract_class_code,award_category_id_1,award_category_id_2,
				award_category_id_3,award_category_id_4,award_category_id_5,
				number_responses,location_service,location_zip,
				borough_code,block_code,lot_code,
				council_district_code,vendor_history_id,vendor_preference_level,
				original_contract_amount,registered_date_id,oca_number,
				number_solicitation,document_name,original_term_begin_date_id,
				original_term_end_date_id,privacy_flag,load_id,created_date)
	 VALUES( new.agreement_id,new.master_agreement_id,new.document_code_id,new.
		agency_history_id,new.document_id,new.document_version,new.
		tracking_number,new.record_date_id,new.budget_fiscal_year,new.
		document_fiscal_year,new.document_period,new.description,new.
		actual_amount,new.obligated_amount,new.maximum_contract_amount,new.
		amendment_number,new.replacing_agreement_id,new.replaced_by_agreement_id,new.
		award_status_id,new.procurement_id,new.procurement_type_id,new.
		effective_begin_date_id,new.effective_end_date_id,new.reason_modification,new.
		source_created_date_id,new.source_updated_date_id,new.document_function_code_id,new.
		award_method_id,new.award_level_id,new.agreement_type_id,new.
		contract_class_code,new.award_category_id_1,new.award_category_id_2,new.
		award_category_id_3,new.award_category_id_4,new.award_category_id_5,new.
		number_responses,new.location_service,new.location_zip,new.
		borough_code,new.block_code,new.lot_code,new.
		council_district_code,new.vendor_history_id,new.vendor_preference_level,new.
		original_contract_amount,new.registered_date_id,new.oca_number,new.
		number_solicitation,new.document_name,new.original_term_begin_date_id,new.
		original_term_end_date_id,new.privacy_flag,new.load_id,new.created_date);
			

CREATE RULE history_all_agreement_rule AS ON INSERT TO history_all_agreement
WHERE privacy_flag ='F'
DO ALSO INSERT INTO history_agreement(agreement_id,master_agreement_id,document_code_id,
				agency_history_id,document_id,document_version,
				tracking_number,record_date_id,budget_fiscal_year,
				document_fiscal_year,document_period,description,
				actual_amount,obligated_amount,maximum_contract_amount,
				amendment_number,replacing_agreement_id,replaced_by_agreement_id,
				award_status_id,procurement_id,procurement_type_id,
				effective_begin_date_id,effective_end_date_id,reason_modification,
				source_created_date_id,source_updated_date_id,document_function_code_id,
				award_method_id,award_level_id,agreement_type_id,
				contract_class_code,award_category_id_1,award_category_id_2,
				award_category_id_3,award_category_id_4,award_category_id_5,
				number_responses,location_service,location_zip,
				borough_code,block_code,lot_code,
				council_district_code,vendor_history_id,vendor_preference_level,
				original_contract_amount,registered_date_id,oca_number,
				number_solicitation,document_name,original_term_begin_date_id,
				original_term_end_date_id,privacy_flag,load_id,created_date)
	 VALUES( new.agreement_id,new.master_agreement_id,new.document_code_id,new.
		agency_history_id,new.document_id,new.document_version,new.
		tracking_number,new.record_date_id,new.budget_fiscal_year,new.
		document_fiscal_year,new.document_period,new.description,new.
		actual_amount,new.obligated_amount,new.maximum_contract_amount,new.
		amendment_number,new.replacing_agreement_id,new.replaced_by_agreement_id,new.
		award_status_id,new.procurement_id,new.procurement_type_id,new.
		effective_begin_date_id,new.effective_end_date_id,new.reason_modification,new.
		source_created_date_id,new.source_updated_date_id,new.document_function_code_id,new.
		award_method_id,new.award_level_id,new.agreement_type_id,new.
		contract_class_code,new.award_category_id_1,new.award_category_id_2,new.
		award_category_id_3,new.award_category_id_4,new.award_category_id_5,new.
		number_responses,new.location_service,new.location_zip,new.
		borough_code,new.block_code,new.lot_code,new.
		council_district_code,new.vendor_history_id,new.vendor_preference_level,new.
		original_contract_amount,new.registered_date_id,new.oca_number,new.
		number_solicitation,new.document_name,new.original_term_begin_date_id,new.
		original_term_end_date_id,new.privacy_flag,new.load_id,new.created_date);


CREATE RULE all_agreement_acc_line_del_rule AS ON DELETE TO all_agreement_accounting_line
DO ALSO DELETE FROM agreement_accounting_line WHERE agreement_id = old.agreement_id;

CREATE RULE hist_all_agreement_acc_line_del_rule AS ON DELETE TO history_all_agreement_accounting_line
DO ALSO DELETE FROM history_agreement_accounting_line WHERE agreement_id = old.agreement_id;
			

CREATE RULE all_agreement_worksite_del_rule AS ON DELETE TO all_agreement_worksite
DO ALSO DELETE FROM agreement_worksite WHERE agreement_id = old.agreement_id;

CREATE RULE hist_all_agreement_worksite_del_rule AS ON DELETE TO history_all_agreement_worksite
DO ALSO DELETE FROM history_agreement_worksite WHERE agreement_id = old.agreement_id;

CREATE RULE all_agreement_commodity_del_rule AS ON DELETE TO all_agreement_commodity
DO ALSO DELETE FROM agreement_commodity WHERE agreement_id = old.agreement_id;

CREATE RULE hist_all_agreement_commodity_del_rule AS ON DELETE TO history_all_agreement_commodity
DO ALSO DELETE FROM history_agreement_commodity WHERE agreement_id = old.agreement_id;

CREATE RULE hist_all_agreement_upd_rule_1 AS ON UPDATE TO history_all_agreement
DO ALSO UPDATE history_agreement SET 
				master_agreement_id = new.master_agreement_id,
				document_code_id = new.document_code_id,
				agency_history_id  = new.agency_history_id,
				document_id  = new.document_id,
				document_version = new.document_version,
				tracking_number = new.tracking_number,
				record_date_id = new.record_date_id,
				budget_fiscal_year = new.budget_fiscal_year,
				document_fiscal_year = new.document_fiscal_year,
				document_period = new.document_period,
				description = new.description,
				actual_amount = new.actual_amount,
				obligated_amount = new.obligated_amount,
				maximum_contract_amount = new.maximum_contract_amount,
				amendment_number = new.amendment_number,
				replacing_agreement_id = new.replacing_agreement_id,
				replaced_by_agreement_id = new.replaced_by_agreement_id,
				award_status_id = new.award_status_id,
				procurement_id = new.procurement_id,
				procurement_type_id = new.procurement_type_id,
				effective_begin_date_id = new.effective_begin_date_id,
				effective_end_date_id = new.effective_end_date_id,
				reason_modification = new.reason_modification,
				source_created_date_id = new.source_created_date_id,
				source_updated_date_id = new.source_updated_date_id,
				document_function_code_id = new.document_function_code_id,
				award_method_id = new.award_method_id,
				award_level_id = new.award_level_id,
				agreement_type_id = new.agreement_type_id,
				contract_class_code = new.contract_class_code,
				award_category_id_1 = new.award_category_id_1,
				award_category_id_2 = new.award_category_id_2,
				award_category_id_3 = new.award_category_id_3,
				award_category_id_4 = new.award_category_id_4,
				award_category_id_5 = new.award_category_id_5,
				number_responses = new.number_responses,
				location_service = new.location_service,
				location_zip = new.location_zip,
				borough_code = new.borough_code,
				block_code = new.block_code,
				lot_code = new.lot_code,
				council_district_code = new.council_district_code,
				vendor_history_id = new.vendor_history_id,
				vendor_preference_level = new.vendor_preference_level,
				original_contract_amount = new.original_contract_amount,
				registered_date_id = new.registered_date_id,
				oca_number = new.oca_number,
				number_solicitation = new.number_solicitation,
				document_name = new.document_name,
				original_term_begin_date_id = new.original_term_begin_date_id,
				original_term_end_date_id = new.original_term_end_date_id,
				privacy_flag = new.privacy_flag,
				load_id = new.load_id,
				updated_date = new.updated_date
			WHERE agreement_id =new.agreement_id;	
			
CREATE RULE hist_all_agreement_upd_rule_2 AS ON UPDATE TO history_all_agreement
DO ALSO UPDATE all_agreement SET 
				master_agreement_id = new.master_agreement_id,
				document_code_id = new.document_code_id,
				agency_history_id  = new.agency_history_id,
				document_id  = new.document_id,
				document_version = new.document_version,
				tracking_number = new.tracking_number,
				record_date_id = new.record_date_id,
				budget_fiscal_year = new.budget_fiscal_year,
				document_fiscal_year = new.document_fiscal_year,
				document_period = new.document_period,
				description = new.description,
				actual_amount = new.actual_amount,
				obligated_amount = new.obligated_amount,
				maximum_contract_amount = new.maximum_contract_amount,
				amendment_number = new.amendment_number,
				replacing_agreement_id = new.replacing_agreement_id,
				replaced_by_agreement_id = new.replaced_by_agreement_id,
				award_status_id = new.award_status_id,
				procurement_id = new.procurement_id,
				procurement_type_id = new.procurement_type_id,
				effective_begin_date_id = new.effective_begin_date_id,
				effective_end_date_id = new.effective_end_date_id,
				reason_modification = new.reason_modification,
				source_created_date_id = new.source_created_date_id,
				source_updated_date_id = new.source_updated_date_id,
				document_function_code_id = new.document_function_code_id,
				award_method_id = new.award_method_id,
				award_level_id = new.award_level_id,
				agreement_type_id = new.agreement_type_id,
				contract_class_code = new.contract_class_code,
				award_category_id_1 = new.award_category_id_1,
				award_category_id_2 = new.award_category_id_2,
				award_category_id_3 = new.award_category_id_3,
				award_category_id_4 = new.award_category_id_4,
				award_category_id_5 = new.award_category_id_5,
				number_responses = new.number_responses,
				location_service = new.location_service,
				location_zip = new.location_zip,
				borough_code = new.borough_code,
				block_code = new.block_code,
				lot_code = new.lot_code,
				council_district_code = new.council_district_code,
				vendor_history_id = new.vendor_history_id,
				vendor_preference_level = new.vendor_preference_level,
				original_contract_amount = new.original_contract_amount,
				registered_date_id = new.registered_date_id,
				oca_number = new.oca_number,
				number_solicitation = new.number_solicitation,
				document_name = new.document_name,
				original_term_begin_date_id = new.original_term_begin_date_id,
				original_term_end_date_id = new.original_term_end_date_id,
				privacy_flag = new.privacy_flag,
				load_id = new.load_id,
				updated_date = new.updated_date
			WHERE agreement_id =new.agreement_id;		
			
CREATE RULE hist_all_agreement_upd_rule_3 AS ON UPDATE TO history_all_agreement
DO ALSO UPDATE agreement SET 
				master_agreement_id = new.master_agreement_id,
				document_code_id = new.document_code_id,
				agency_history_id  = new.agency_history_id,
				document_id  = new.document_id,
				document_version = new.document_version,
				tracking_number = new.tracking_number,
				record_date_id = new.record_date_id,
				budget_fiscal_year = new.budget_fiscal_year,
				document_fiscal_year = new.document_fiscal_year,
				document_period = new.document_period,
				description = new.description,
				actual_amount = new.actual_amount,
				obligated_amount = new.obligated_amount,
				maximum_contract_amount = new.maximum_contract_amount,
				amendment_number = new.amendment_number,
				replacing_agreement_id = new.replacing_agreement_id,
				replaced_by_agreement_id = new.replaced_by_agreement_id,
				award_status_id = new.award_status_id,
				procurement_id = new.procurement_id,
				procurement_type_id = new.procurement_type_id,
				effective_begin_date_id = new.effective_begin_date_id,
				effective_end_date_id = new.effective_end_date_id,
				reason_modification = new.reason_modification,
				source_created_date_id = new.source_created_date_id,
				source_updated_date_id = new.source_updated_date_id,
				document_function_code_id = new.document_function_code_id,
				award_method_id = new.award_method_id,
				award_level_id = new.award_level_id,
				agreement_type_id = new.agreement_type_id,
				contract_class_code = new.contract_class_code,
				award_category_id_1 = new.award_category_id_1,
				award_category_id_2 = new.award_category_id_2,
				award_category_id_3 = new.award_category_id_3,
				award_category_id_4 = new.award_category_id_4,
				award_category_id_5 = new.award_category_id_5,
				number_responses = new.number_responses,
				location_service = new.location_service,
				location_zip = new.location_zip,
				borough_code = new.borough_code,
				block_code = new.block_code,
				lot_code = new.lot_code,
				council_district_code = new.council_district_code,
				vendor_history_id = new.vendor_history_id,
				vendor_preference_level = new.vendor_preference_level,
				original_contract_amount = new.original_contract_amount,
				registered_date_id = new.registered_date_id,
				oca_number = new.oca_number,
				number_solicitation = new.number_solicitation,
				document_name = new.document_name,
				original_term_begin_date_id = new.original_term_begin_date_id,
				original_term_end_date_id = new.original_term_end_date_id,
				privacy_flag = new.privacy_flag,
				load_id = new.load_id,
				updated_date = new.updated_date
			WHERE agreement_id =new.agreement_id;				