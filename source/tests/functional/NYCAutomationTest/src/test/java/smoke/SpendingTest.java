package smoke;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import helpers.Helper;

import java.sql.SQLException;
import java.util.Arrays;

import org.junit.Before;
import org.junit.Test;

import pages.home.HomePage;
import pages.spending.SpendingPage;
import utilities.NYCBaseTest;
import utilities.NYCDatabaseUtil;
import utilities.TestStatusReport;

//public class SpendingTest extends TestStatusReport{
public class SpendingTest extends NYCBaseTest{
	
	@Before
    public void GoToPage(){
	   if (!SpendingPage.isAt())
		   SpendingPage.GoTo();
	   if(!(Helper.getCurrentSelectedYear()).equalsIgnoreCase(NYCBaseTest.prop.getProperty("CurrentYear")))
		   HomePage.SelectYear(NYCBaseTest.prop.getProperty("CurrentYear"));
    }

	@Test
    public void VerifySpendingAmount() throws SQLException {
        String TotalSpendingAmtFY2016 = NYCDatabaseUtil.getSpendingAmount(2016, 'B');
        String spendingAmt = SpendingPage.GetSpendingAmount();
        assertEquals("Spending Amount did not match", spendingAmt, TotalSpendingAmtFY2016);
    }
	
	@Test
    public void VerifySpendingDomainVisualizationsTitles(){
	    String[] sliderTitles= {"Total Spending", 
	    						"Top Ten Agencies by Disbursement Amount", 
	    						"Top Ten Contracts by Disbursement Amount", 
	    						"Top Ten Prime Vendors by Disbursement Amount"};  
    	assertTrue(Arrays.equals(sliderTitles, SpendingPage.VisualizationTitles().toArray()));
    	System.out.println( SpendingPage.VisualizationTitles()); 
    }
	 
	@Test
    public void VerifySpendingWidgetTitles(){
	   String[] widgetTitles = {"Top 5 Checks",
	    						"Top 5 Agencies",
	    						"Top 5 Expense Categories",
	    						"Top 5 Prime Vendors",
	    						"Top 5 Contracts",
	    						"Top 5 Agencies"}; 
	    							    						 
		//System.out.println( SpendingPage.GetAllWidgetText()); 
	//	 String widgetTitle = "Top 5 Checks";
//	assertEquals("Top 5 Checks", SpendingPage.GetWidgetText());
	//System.out.println( SpendingPage.GetAllWidgetText()); 
	//assertEquals("Top 5 Agencies", SpendingPage.GetWidgetText());
		//assertEquals(widgetTitles,SpendingPage.GetWidgetText());
		
		
    	//HomePage.ShowWidgetDetails();
    	assertTrue(Arrays.equals(widgetTitles, SpendingPage.WidgetTitles().toArray()));
    	
    	/*try {
    		//assertTrue(Arrays.equals(widgetTitles, SpendingPage.GetAllWidgetText().toArray()));
    	 	//assertTrue(Arrays.equals(widgetTitles, SpendingPage.WidgetTitles().toArray()));
    		
 	
    		//System.out.println( SpendingPage.GetAllWidgetText()); 
    		System.out.println( SpendingPage.WidgetTitles()); 
    		 
    	    System.out.println("no errors in widget titles");
    	}  catch (Throwable e) {
            System.out.println("errors in widget titles");
            } */
    	
    }
	
}
