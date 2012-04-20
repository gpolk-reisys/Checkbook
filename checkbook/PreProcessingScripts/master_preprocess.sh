#!/bin/sh
echo $1

rm -f goodfile.txt
rm -f badfile.txt
dirName="/home/gpadmin/athiagarajan/NYC/datafiles/"
fileName=$dirName$2
if [ $1 == "COAAgency" ] ; then	
	./removeMalformedAgencyRecords.sh 
	
elif [ $1 == "COABudgetCode" ] ; then
	./removeMalformedBudgetCodeRecords.sh $fileName
	
elif [ $1 == "COADepartment" ] ; then
	./removeMalformedDepartmentRecords.sh $fileName
	
elif [ $1 == "COAExpenditureObject" ] ; then
	./removeMalformedExpenditureObjectRecords.sh $fileName
	 
elif [ $1 == "COALocation" ] ; then
	./removeMalformedLocationRecords.sh $fileName
	 
elif [ $1 == "COAObjectClass" ] ; then
	./removeMalformedObjectClassRecords.sh $fileName
	 
elif [ $1 == "COARevenueCategory" ] ; then
	./removeMalformedRevenueCategoryRecords.sh $fileName
	 
elif [ $1 == "COARevenueClass" ] ; then
	./removeMalformedRevenueClassRecords.sh $fileName
	 
elif [ $1 == "COARevenueSource" ] ; then
	./removeMalformedRevenueSourceRecords.sh $fileName
	 
elif [ $1 == "CON" ] ; then
	./removeMalformedCONRecords.sh $fileName
	 
elif [ $1 == "FMS" ] ; then
	./removeMalformedFMSRecords.sh $fileName
	 
elif [ $1 == "MAG" ] ; then
	./removeMalformedMAGRecords.sh $fileName
	 
elif [ $1 == "Revenue" ] ; then
	./removeMalformedRevenueRecords.sh $fileName
	 
elif [ $1 == "Budget" ] ; then
	./removeMalformedBudgetRecords.sh $fileName
	
fi

if ! [ -f "goodfile.txt" ]; then
        touch "goodfile.txt"
fi

mv goodfile.txt $fileName
if ! [ -f "badfile.txt" ]; then
        touch "badfile.txt"
fi


