#!/bin/bash

# Define your MySQL database credentials and table schema
MYSQL_DATABASE="db"
MYSQL_USER="user"
MYSQL_PASSWORD="password"
TABLE_SCHEMA="CREATE TABLE IF NOT EXISTS FLIGHTS_ORIGIN_COUNT (
    ORIGINCITY VARCHAR(255) NOT NULL,
    FLIGHTS_COUNT BIGINT,
    PRIMARY KEY (ORIGINCITY)
);"

# Execute the SQL command inside the MySQL container
docker exec -i mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" <<< "$TABLE_SCHEMA"

echo "Table FLIGHTS_ORIGIN_COUNT created or already exists."
