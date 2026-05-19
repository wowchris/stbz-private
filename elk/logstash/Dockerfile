ARG ELASTIC_VERSION

# https://www.docker.elastic.co/
FROM docker.elastic.co/logstash/logstash:${ELASTIC_VERSION:-7.7.0}

# Add your logstash plugins setup here
# Example: RUN logstash-plugin install logstash-filter-json


ADD mysql-connector-java-5.1.47.jar  /usr/share/logstash/mysql-connector-java-5.1.47.jar

