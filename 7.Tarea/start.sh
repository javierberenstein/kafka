echo "Levantando entorno"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      echo "Ejecutando en Linux cambio no necesario"
elif [[ "$OSTYPE" == "darwin"* ]]; then
      echo "Ejecutando en MAC cambio no necesario"
elif [[ "$OSTYPE" == "cygwin" ]]; then
      echo "Ejecutando en Cygwin swapeando retornos de carro"
      sed -i 's/\r//' $DIR/mongo/init.sh
elif [[ "$OSTYPE" == "msys" ]]; then
       echo "Ejecutando en Cygwin swapeando retornos de carro"
       sed -i 's/\r//' $DIR/mongo/init.sh
else
       echo "OS desconocido swapeando retornos de carro"
       sed -i 's/\r//' $DIR/mongo/init.sh
fi

docker compose up -d

echo "Esperando 30 sg a que connect levante"

sleep 30

docker compose exec connect confluent-hub install --no-prompt confluentinc/kafka-connect-datagen:0.6.3

docker compose exec connect confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.4

docker compose exec connect confluent-hub install --no-prompt  mongodb/kafka-connect-mongodb:1.11.2

docker cp $DIR/mysql/mysql-connector-java-5.1.45.jar connect:/usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/mysql-connector-java-5.1.45.jar

docker compose restart connect

echo "Esperando 30 sg a que connect reinicie"

sleep 30

$DIR/create-mongo-flights.sh

docker cp $DIR/statements.sql ksqldb-cli:/tmp/statements.sql
echo
echo "Esperando 30 sg a la creación de las queries KSQL"
sleep 30
echo
docker compose exec ksqldb-cli bash -c "ksql -u ksqlDBUser -p ksqlDBUser http://ksqldb-server:8088 <<EOF
RUN SCRIPT '/tmp/statements.sql';
exit ;
EOF"
echo
echo -e "\033[0;33mDeploying MySQL connector...\033[0m"
echo
curl -d @"$DIR/mysql_connector_sink.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors
echo
echo "Prior to tables, creation in advance of table should be done"
echo
$DIR/create_tables.sh
echo
curl -d @"$DIR/mysql_max_sink.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors
echo
echo -e "\033[0;32mMySQL Sink Connector deployment request sent.\033[0m"
echo
echo -e "\033[0;32mTotal count of flights from New Orleans\033[0m" 

docker exec ksqldb-cli ksql http://ksqldb-server:8088 --execute "SELECT * FROM NEW_ORLEANS_FLIGHT_COUNT;"
echo
echo -e "\033[0;33mWaiting for MySQL tables to be populated...\033[0m"
echo
sleep 10

echo -e "\033[0;33mGet city with maximum flights in January 2023:\033[0m" 
echo 
docker exec mysql bash -c "\
mysql --user=root \
--password=password \
--database=db \
-e 'SELECT * FROM db.FLIGHTS_ORIGIN_COUNT ORDER BY FLIGHTS_COUNT DESC LIMIT 1;'"







