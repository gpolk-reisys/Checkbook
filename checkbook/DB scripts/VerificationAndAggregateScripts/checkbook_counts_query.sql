COPY (select 'history_agreement' as table_name , count(*) as num_records, 'contracts' as domain  from history_agreement UNION 
select 'history_agreement_accounting_line' as table_name , count(*) as num_records, 'contracts' as domain  from history_agreement_accounting_line UNION 
select 'history_master_agreement' as table_name , count(*) as num_records, 'contracts' as domain  from history_master_agreement UNION 
select 'agreement_snapshot' as table_name , count(*) as num_records, 'contracts' as domain  from agreement_snapshot UNION 
select 'agreement_snapshot_cy' as table_name , count(*) as num_records, 'contracts' as domain  from agreement_snapshot_cy UNION 
select 'aggregateon_contracts_cumulative_spending' as table_name , count(*) as num_records, 'contracts' as domain  from aggregateon_contracts_cumulative_spending UNION 
select 'aggregateon_contracts_department' as table_name , count(*) as num_records, 'contracts' as domain  from aggregateon_contracts_department UNION 
select 'aggregateon_contracts_expense' as table_name , count(*) as num_records, 'contracts' as domain  from aggregateon_contracts_expense UNION 
select 'aggregateon_contracts_spending_by_month' as table_name , count(*) as num_records, 'contracts' as domain  from aggregateon_contracts_spending_by_month UNION 
select 'aggregateon_total_contracts' as table_name , count(*) as num_records, 'contracts' as domain  from aggregateon_total_contracts UNION 
select 'contracts_spending_transactions' as table_name , count(*) as num_records, 'contracts' as domain  from contracts_spending_transactions UNION 
select 'pending_contracts' as table_name , count(*) as num_records, 'contracts' as domain  from pending_contracts UNION
select 'employee' as table_name , count(*) as num_records, 'payroll' as domain  from employee UNION 
select 'payroll' as table_name , count(*) as num_records, 'payroll' as domain  from payroll UNION 
select 'payroll_summary' as table_name , count(*) as num_records, 'payroll' as domain  from payroll_summary UNION 
select 'aggregateon_payroll_agency' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_agency UNION 
select 'aggregateon_payroll_agency_month' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_agency_month UNION 
select 'aggregateon_payroll_coa_month' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_coa_month UNION 
select 'aggregateon_payroll_employee_agency' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_employee_agency UNION 
select 'aggregateon_payroll_employee_agency_month' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_employee_agency_month UNION 
select 'aggregateon_payroll_year' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_year UNION 
select 'aggregateon_payroll_year_and_month' as table_name , count(*) as num_records, 'payroll' as domain  from aggregateon_payroll_year_and_month UNION
select 'revenue' as table_name , count(*) as num_records, 'revenue_budget' as domain  from revenue UNION 
select 'revenue_budget' as table_name , count(*) as num_records, 'revenue_budget' as domain  from revenue_budget UNION 
select 'revenue_details' as table_name , count(*) as num_records, 'revenue_budget' as domain  from revenue_details UNION 
select 'budget' as table_name , count(*) as num_records, 'revenue_budget' as domain  from budget UNION 
select 'aggregateon_revenue_category_funding_class' as table_name , count(*) as num_records, 'revenue_budget' as domain  from aggregateon_revenue_category_funding_class UNION
select 'disbursement' as table_name , count(*) as num_records, 'spending' as domain  from disbursement UNION 
select 'disbursement_line_item' as table_name , count(*) as num_records, 'spending' as domain  from disbursement_line_item UNION 
select 'disbursement_line_item_details' as table_name , count(*) as num_records, 'spending' as domain  from disbursement_line_item_details UNION 
select 'aggregateon_spending_coa_entities' as table_name , count(*) as num_records, 'spending' as domain  from aggregateon_spending_coa_entities UNION 
select 'aggregateon_spending_contract' as table_name , count(*) as num_records, 'spending' as domain  from aggregateon_spending_contract UNION 
select 'aggregateon_spending_vendor' as table_name , count(*) as num_records, 'spending' as domain  from aggregateon_spending_vendor UNION 
select 'aggregateon_spending_vendor_exp_object' as table_name , count(*) as num_records, 'spending' as domain  from aggregateon_spending_vendor_exp_object UNION
select 'vendor' as table_name , count(*) as num_records, 'vendor' as domain  from vendor UNION 
select 'ref_agency' as table_name , count(*) as num_records, 'refrence_data' as domain  from ref_agency UNION 
select 'ref_department' as table_name , count(*) as num_records, 'refrence_data' as domain  from ref_department UNION 
select 'ref_expenditure_object' as table_name , count(*) as num_records, 'refrence_data' as domain  from ref_expenditure_object UNION 
select 'ref_minority_type' as table_name , count(*) as num_records, 'refrence_data' as domain  from ref_minority_type UNION 
select 'ref_object_class' as table_name , count(*) as num_records, 'refrence_data' as domain  from ref_object_class order by domain, table_name) TO '/vol2share/NYC/FEEDS/count_verification.csv' CSV HEADER QUOTE as '"';


select * from ref_agency where agency_name ilike '%unknown%'   ;
select * from ref_agency where agency_name ilike '%non-appli%'  ;

select * from ref_department where department_name ilike '%unknown%' ;
select * from ref_department where department_name ilike '%non-appli%' ;

select * from ref_location  where location_name ilike '%unknown%' ;
select * from ref_location  where location_name ilike '%non-appli%' ;

select * from ref_expenditure_object   where expenditure_object_name  ilike '%unknown%' ;
select * from ref_expenditure_object   where expenditure_object_name  ilike  '%non-appli%' ;

select count(*) from history_agreement; -- 19504

select count(*) from history_master_agreement;  -- 196

select count(*) from history_agreement_accounting_line ;-- 46983

select count(*) from disbursement; -- 69972


select count(*) from disbursement_line_item ; -- 133499

select count(*) from payroll_summary; -- 1558

select count(*) from disbursement_line_item_details; -- 135057

select 133499 + 1558 ; -- 135057

select count(*) from pending_contracts ;  -- 16

select count(*) from payroll ; -- 744026


select count(*) from employee ; -- 58796

select count(*) from vendor -- 6932

select count(*) from agreement_snapshot; -- 15389
select count(*) from agreement_snapshot_cy;  -- 15865

select count(*) from aggregateon_contracts_cumulative_spending ; -- 20737

select count(*) from aggregateon_contracts_department ; --19343

select count(*) from aggregateon_spending_coa_entities; -- 99058

select count(*) from aggregateon_spending_contract; --20164