--  For Graph

--from aggregate tables

-- from source tables

select sum(base_pay+other_payments) from payroll 
join ref_date on payroll.pay_date_id = ref_date.date_id
join ref_month on ref_date.calendar_month_id=ref_month.month_id 
join ref_year on ref_date.nyc_year_id = ref_year.year_id
where ref_month.month_value = 5 and fiscal_year=2011


-- TOP 5 employee by annual salary

-- From Aggregate tables

select b.first_name, b.last_name, c.agency_name, annual_salary, gross_pay, base_pay, other_payments, overtime_pay
 from  aggregateon_payroll_employee_agency a JOIN employee b ON a.employee_id = b.employee_id JOIN ref_agency c ON a.agency_id = c.agency_id
 WHERE fiscal_year_id = 113 and type_of_year = 'B' and type_of_employment = 'Salaried' order by annual_salary desc limit 20


--  From source tables

select employee.first_name, employee.last_name, ref_agency.agency_name, max(annual_salary), sum(gross_pay), sum(base_pay),sum(other_payments),sum(overtime_pay) 
from payroll
join employee_history on employee_history.employee_history_id=payroll.employee_history_id
join employee on employee_history.employee_id = employee.employee_id
join ref_agency on ref_agency.agency_id = payroll.agency_id
where fiscal_year=2012
group by payroll.employee_id,employee.first_name, employee.last_name, ref_agency.agency_name
order by 4 desc limit 10