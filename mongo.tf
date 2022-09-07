resource "aiven_kafka" "demo-kafka" {
  project                 = var.project_name
  cloud_name              = var.cloud_name
  plan                    = "business-4"
  service_name            = join("-", [var.service_name_prefix, "kafka"])
  maintenance_window_dow  = "sunday"
  maintenance_window_time = "10:00:00"
  kafka_user_config {
    kafka_connect = true
    kafka_rest    = true
    kafka_version = "3.2"
    kafka {
      auto_create_topics_enable    = true
    }
  }
}

resource "aiven_kafka_connect" "demo-kafka-connect" {
  project = var.project_name
  cloud_name = var.cloud_name
  plan = "business-4"
  service_name = "demo-kafka-connect"
  maintenance_window_dow = "sunday"
  maintenance_window_time = "10:00:00"
  depends_on = [aiven_kafka.demo-kafka]
  kafka_connect_user_config {
    kafka_connect {
      consumer_isolation_level = "read_committed"
    }

    public_access {
      kafka_connect = true
    }
  }
}

resource "aiven_service_integration" "demo-kafka-connect-integration" {
  project = var.project_name
  integration_type = "kafka_connect"
  source_service_name = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  depends_on = [aiven_kafka_connect.demo-kafka-connect, aiven_kafka.demo-kafka]
}

resource "aiven_kafka_connector" "mongo-source" {
  project = var.project_name
  service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  connector_name = "mongo-source"
  depends_on = [aiven_service_integration.demo-kafka-connect-integration]
  config = {
    "name" : "mongo-source",
    "connector.class" : "com.mongodb.kafka.connect.MongoSourceConnector",
    "connection.uri" :  var.mongo_uri,
    "database" : "sample_mflix",
    "collection" : "movies",
    "copy.existing" : "true",
    "poll.await.time.ms" : "1000",
    "output.format.value": "json",
    "output.format.key": "json",
  }
}

resource "aiven_kafka_connector" "mongo-s3-sink" {
  project        = var.project_name
  service_name   = aiven_kafka_connect.demo-kafka-connect.service_name
  connector_name = "mongo-s3-sink"
  depends_on = [aiven_service_integration.demo-kafka-connect-integration]
  config = {
    "aws.secret.access.key": var.aws_key_secret,
    "aws.access.key.id": var.aws_key_id,
    "topics": "sample_mflix.movies",
    "tasks.max": "3",
    "format.output.envelope":"false",
    "file.max.records":"600",
    "aws.s3.prefix":"mongo-",
    "format.output.type":"json",
    "name": "mongo-s3-sink",
    "aws.s3.region": "ap-southeast-2",
    "aws.s3.bucket.name": "troys-mongodb-sink-demo",
    "connector.class": "io.aiven.kafka.connect.s3.AivenKafkaConnectS3SinkConnector"
  }
}