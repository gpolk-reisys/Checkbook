package FunctionalPayroll;

import static org.junit.Assert.assertEquals;
import helpers.Helper;

import java.sql.SQLException;

import org.junit.Before;
import org.junit.Test;

import pages.payroll.PayrollPage;
import pages.payroll.PayrollPage.WidgetOption;
import pages.home.HomePage;
import utilities.NYCBaseTest;
import utilities.NYCDatabaseUtil;

public class PayrollWidgetDetailsTest extends NYCBaseTest {

	@Before
	public void GoToPage(){
		PayrollPage.GoTo();

		if(!(Helper.getCurrentSelectedYear()).equalsIgnoreCase(NYCBaseTest.prop.getProperty("CurrentYear")))
			HomePage.SelectYear(NYCBaseTest.prop.getProperty("CurrentYear"));
		HomePage.ShowWidgetDetails();
	}

	/* ***************** Test Widget Transaction Count ****************** */
	@Test
	public void VerifyTop5AgenciesbyPayrollTransactionCount() throws SQLException{
		PayrollPage.GoToTop5DetailsPage(WidgetOption.Top5AgenciesbyPayroll);
		HomePage.ShowWidgetDetails();
		int NumOfPayrollDetailsCount2016 = NYCDatabaseUtil.getPayrollDetailsCount(2016,'B');
		int numOfPayrollDetailsCountapp = PayrollPage.GetTransactionCount();
		assertEquals("Number of Payroll salaried employees did not match", numOfPayrollDetailsCountapp, NumOfPayrollDetailsCount2016); 
	}
	public void VerifyTop5AgenciesbyOvertimeTransactionCount() throws SQLException{
		PayrollPage.GoToTop5DetailsPage(WidgetOption.Top5AgenciesbyOvertime);
		HomePage.ShowWidgetDetails();
		int NumOfPayrollDetailsCount2016 = NYCDatabaseUtil.getPayrollDetailsCount(2016,'B');
		int numOfPayrollDetailsCountapp = PayrollPage.GetTransactionCount();
		assertEquals("Number of Payroll salaried employees did not match", numOfPayrollDetailsCountapp, NumOfPayrollDetailsCount2016); 
	}
	@Test
	public void VerifyNumOfPayrollAnnualSalariesTransactioncount() throws SQLException {
		PayrollPage.GoToTop5DetailsPage(WidgetOption.Top5AnnualSalaries);
		HomePage.ShowWidgetDetails();
		int NumOfPayrollDetailsCount2016 = NYCDatabaseUtil.getPayrollDetailsCount(2016,'B');
		int numOfPayrollDetailsCountapp = PayrollPage.GetTransactionCount();
		assertEquals("Number of Payroll salaried employees did not match", numOfPayrollDetailsCountapp, NumOfPayrollDetailsCount2016); 
	}
	/* issue with widgettitle function for titile widget	
	@Test
		public void VerifyNumOfPayrollTitlesbyNumberofEmployeesTransactioncount() throws SQLException {
			PayrollPage.GoToTop5DetailsPage(WidgetOption.Top5TitlesbyNumberofEmployees);
			HomePage.ShowWidgetDetails();
			 int NumOfPayrollDetailsCount2016 = NYCDatabaseUtil.getPayrollTitleDetailsCount(2016,'B');
			 int numOfPayrollDetailsCountapp = PayrollPage.GetTransactionCount1();
			 assertEquals("Number of Payroll salaried employees did not match", numOfPayrollDetailsCountapp, NumOfPayrollDetailsCount2016); 
		}
	 */
}
