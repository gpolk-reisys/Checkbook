gpssh  -f  /home/gpadmin/etl/web-batch1 �e "psql" -p 6432 -c "truncate table pgpool_category.query_cache" pgpool