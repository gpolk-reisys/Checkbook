package FunctionalRevenue;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import helpers.Helper;

import java.sql.SQLException;
import java.util.Arrays;

import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ErrorCollector;

import pages.revenue.RevenuePage;
import pages.revenue.RevenuePage.WidgetOption;
import pages.home.HomePage;

import utilities.NYCBaseTest;
import utilities.NYCDatabaseUtil;

public class RevenueWidgetTitles extends NYCBaseTest {

		@Before
	    public void GoToPage() {
			RevenuePage.GoTo();
		 
			if(!(Helper.getCurrentSelectedYear()).equalsIgnoreCase(NYCBaseTest.prop.getProperty("CurrentYear")))
				HomePage.SelectYear(NYCBaseTest.prop.getProperty("CurrentYear"));
			HomePage.ShowWidgetDetails();
		}
			
				@Test
		    public void VerifyRevnueAmount() throws SQLException {
		        String TotalRevenueAmtFY2016 = NYCDatabaseUtil.getRevenueAmount(2016, 'B');
		        String revenueAmt = RevenuePage.GetRevenueAmount();
		        assertEquals("Revenue Amount did not match", revenueAmt, TotalRevenueAmtFY2016);
		    }
			
			@Test
		    public void VerifyRevenueDomainVisualizationsTitles(){
			    String[] sliderTitles= {"Revenue", 
			    						"Fiscal Year Comparisons", 
			    						"Top Ten Agencies by Revenue", 
			    						"Top Ten Revenue Categories by Revenue"};  
		    	assertTrue(Arrays.equals(sliderTitles, RevenuePage.RevenueVisualizationTitles().toArray()));
		    }
			 
			@Test
		    public void VerifyRevenueWidgetTitles(){
			    String[] widgetTitles = {"Top 5 Agencies",
			    						"Top 5 Revenue Categories",
			    						"Top 5 Revenue by Funding Classes"};  
		    	//HomePage.ShowWidgetDetails();
		    	assertTrue(Arrays.equals(widgetTitles, RevenuePage.WidgetTitles().toArray()));
		    	//assertEquals("Budget Title did not match", widgetTitles,  RevenuePage.WidgetTitles().toArray());
			}	    
			
			
		}

