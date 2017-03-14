<?php

abstract class VendorService {

    /**
     * Returns the Latest Minority Type for the given Vendor and the current selected year
     * @param $vendor_id
     * @param null $agency_id
     * @param string $vendor_type
     * @param string $domain
     * @return mixed
     */
    static protected function getLatestMinorityType($vendor_id, $agency_id = null, $vendor_type, $domain = null) {

        $latest_minority_types = null;
        $type_of_year = 'B';
        $year_id = _getRequestParamValue('year') ?:  _getCurrentYearID();
        $agency_id = $agency_id ?: _getRequestParamValue('agency');
        $domain = $domain ?: CheckbookDomain::getCurrent();

        $latest_minority_types = MinorityTypeService::getAllVendorMinorityTypes($type_of_year, $year_id, $domain);
        $latest_minority_type_id = isset($agency_id)
            ? $latest_minority_types[$vendor_id][(int)$agency_id][$vendor_type]['minority_type_id']
            : $latest_minority_types[$vendor_id][$vendor_type]['minority_type_id'];

        return $latest_minority_type_id;
    }

    /**
     *  Returns the Latest Minority Type for the given Vendor and the current provided transaction year
     * @param $vendor_id
     * @param $year_id
     * @param $type_of_year
     * @param string $vendor_type
     * @param string $domain
     * @return bool
     */
    static protected function getLatestMinorityTypeByYear($vendor_id, $year_id, $type_of_year, $vendor_type, $domain = null) {

        $data_set = $domain == Domain::$SPENDING ? "spending_vendor_latest_mwbe_category" : "contract_vendor_latest_mwbe_category";
        $query = "SELECT minority_type_id
                  FROM ".$data_set."
                  WHERE minority_type_id IN (2,3,4,5,9)
                  AND vendor_id = ".$vendor_id."
                  AND year_id = ".$year_id."
                  AND type_of_year = '".$type_of_year."'
                  AND is_prime_or_sub = '".$vendor_type."' LIMIT 1";

        $results = _checkbook_project_execute_sql_by_data_source($query,'checkbook');
        $minority_type_id = $results[0]['minority_type_id'];
        return $minority_type_id != '' ? $minority_type_id : false;
    }
}