# RESOLUCIÓN
## Introducción

El presente ejercicio trata de un caso de uso ficticio, End-to-End, de análisis de vuelos empleando Kafka. Se utilizará la infraestructura planteada en 6.CasoDeUso, y se partirá de las consultas y objectos creados en él. Para evaluar el flujo, lanzar el comando clean.sh (que dejará el entorno listo) y start.sh, una versión modificada del script de entorno del apartado anterior.

## Resolución ejercicios
### Consideración previa

Para la resolución de los ejercicios se parte del tópico creado en el apartado anterior con una ligera modificación, se adapta la fecha para que sea de tipo DATE, de modo que facilite el análisis y tratamiento posterior.

```sql
CREATE STREAM flights 
WITH (
  KAFKA_TOPIC = 'flights',
  PARTITIONS = 3,
  VALUE_FORMAT = 'AVRO'
)
AS SELECT   
  PARSE_DATE(FLIGHTDATE, 'yyyy-MM-dd') AS FLIGHTDATE,
  AIRLINE_INFO -> FLIGHT_NUMBER_REPORTING_AIRLINE AS FLIGHTNUMBER,
  DEPARTURE_PERFORMANCE -> DEPTIME AS DEPARTURETIME,
  ARRIVAL_PERFORMANCE -> ARRTIME AS ARRIVALTIME,
  AIRTIME,      
  DEPARTURE_PERFORMANCE -> DEPDELAY AS DEPARTUREDELAY,
  ARRIVAL_PERFORMANCE -> ARRDELAY AS ARRIVLDELAY,
  ORIGIN_INFO -> ORIGIN AS ORIGINAIRPORT,
  ORIGIN_INFO -> ORIGINCITYNAME AS ORIGINCITY,
  DESTINATION_INFO -> DEST AS DESTINATIONAIRPORT,
  DESTINATION_INFO -> DESTCITYNAME AS DESTINATIONCITY,
  CANCELLED,
  DIVERTED
FROM FLIGHTS_JSON
EMIT CHANGES;
```

### Ejercicio 1

En el ejercicio 1 se plantea la necesidad de realizar transformaciones para responder a las siguientes preguntas:

- ¿Cuantos vuelos llegaron a New Orleans entre el 1 y el 20 de enero?

Para ello, se construye la siguiente Tabla `new_orleans_flight_count` en Kafka. Dado que esta tabla únicamente aloja la información de new_orleans y esta especificamente destinada para ello, con tal de utilizar el GROUP BY se necesita una key para la agregación, por lo que se genera artificalmente la total_key. Para contabilizar realmente aquellos vuelos que llegaron, se tiene que filtrar adecuadamente la información. ksqlDB permite procesar streams de datos en tiempo real. Al crear una tabla a partir de un stream, efectivamente estás transformando un flujo continuo de eventos (en este caso, información sobre vuelos) en un estado agregado y consultable.Al crear una tabla que acumula el conteo de vuelos hacia New Orleans, ksqlDB mantiene este estado de forma interna. Esto permite realizar consultas sobre el estado acumulado (como obtener el conteo total) de manera eficiente.

```sql
CREATE TABLE new_orleans_flight_count AS 
SELECT 'total' AS total_key, COUNT(*) AS total_count
FROM flights 
WHERE DESTINATIONCITY = 'New Orleans, LA'
  AND FLIGHTDATE BETWEEN '2023-01-01' AND'2023-01-20'
  AND CANCELLED = 0
  AND DIVERTED = 0
GROUP BY 'total'
EMIT CHANGES;
```

- ¿Cual fue la ciudad de la que más vuelos partieron en Enero de 2023?

Para satisfacer esta pregunta, se genera nuevamente otra tabla a partir del tópico `flights`. Esto devuelve la evolución del total en base a la clave de partición ORIGINCITY. No responde directamente la pregunta, pero asienta las bases.  Kafka está diseñado principalmente como un sistema de mensajería y streaming de datos. Su fortaleza radica en la capacidad de manejar grandes volúmenes de datos en tiempo real, permitiendo el procesamiento de estos datos a medida que se generan. Sin embargo, Kafka no está diseñado como un sistema de gestión de bases de datos tradicional, donde se pueden realizar consultas ad-hoc complejas, especialmente aquellas que requieren operaciones de agregación avanzadas sobre el estado histórico completo de los datos.  En particular, calcular el "máximo" de un conjunto de datos (como encontrar la ciudad con más vuelos de salida) en un stream de datos en tiempo real es conceptualmente diferente de hacerlo en una base de datos relacional tradicional. ksqlDB mantiene el estado de las agregaciones en tiempo real, pero las consultas para determinar el "máximo" global pueden requerir el procesamiento de todo el conjunto de datos históricos, lo cual es menos directo en ksqlDB comparado con sistemas de bases de datos analíticas. Se empleará esta tabla en MySQL para un entorno de analitica, donde efectivamente se recuperará cual es la ciudad de orígen con más vuelos.

```sql
CREATE TABLE flights_origin_count AS
SELECT ORIGINCITY, COUNT(*) AS flights_count
FROM flights
WHERE FORMAT_DATE(FLIGHTDATE, 'yyyy-MM-dd') LIKE '2023-01-%'
  AND CANCELLED = 0
  AND DIVERTED = 0
GROUP BY ORIGINCITY
EMIT CHANGES;
```

### Ejercicio 2

Para el último ejercicio se plantea el siguiente stream, que alimentará MySQL, utilizando Kafka Connect. Debido a la naturaleza de los datos, que se introducen de forma secuencial, no se realiza ninguna estrategia de upsert, sino únicamente de insertado.

```sql
CREATE STREAM simplified_stream AS
SELECT 
    FlightDate AS date,
    airline_info->Flight_Number_Reporting_Airline AS flightNumber,
    origin_info->OriginCityName AS originCity,
    destination_info->DestCityName AS destinationCity
FROM flights_json;
```

La configuración del conector es la siguiente:

```json
{
    "name": "mysql-simplified_flights-sink",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "tasks": "[]",
        "topics": "simplified_flights",
        "connection.url": "jdbc:mysql://mysql:3306/db?user=user&password=password&useSSL=false",
        "auto.create": "true",
        "insert.mode": "insert",
        "auto.evolve": "true",
        "delete.enabled": "false",
        "type":"sink"
    }
}
```