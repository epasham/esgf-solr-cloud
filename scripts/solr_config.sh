#!/bin/bash
# Script to initialize Solr collections at startup
# The following env variables must be set before invoking this script:
# ZOOKEEPER_HOST, ZOOKEEPER_PORT
# SOLR_HOST, SOLR_PORT
# SOLR_NUM_SHARDS, SOLR_NUM_REPLICAS, SOLR_MAX_SHARDS_PER_NODE

set -e

# wait for Solr to be available
#/opt/docker-solr/scripts/wait-for-solr.sh --solr-url "http://${SOLR_HOST}:${SOLR_PORT}"

# root directory of this source code repository
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname $SOURCE_DIR)"

# upload latest configuration to Zookeeper
/opt/solr/bin/solr zk upconfig -z ${ZOOKEEPER_HOST}:${ZOOKEEPER_PORT} -d ${PARENT_DIR}/solr/solr-home/conf -confname esgf_config

# create collections, if not existing already, using the latest configuration
for collection in "datasets" "files" "aggregations"
do
  # try querying this collection to see if it exists
  if ( curl "http://${SOLR_HOST}:${SOLR_PORT}/solr/admin/collections?action=LIST&wt=json" | grep "${collection}" ); then
  	 echo "Collection ${collection} already exists"
  else
  	echo "Creating collection: $collection"
  	
  	# use default hash algorithm as sharding strategy
    curl "http://${SOLR_HOST}:${SOLR_PORT}/solr/admin/collections?action=CREATE&name=${collection}&numShards=${SOLR_NUM_SHARDS}&replicationFactor=${SOLR_NUM_REPLICAS}&maxShardsPerNode=${SOLR_MAX_SHARDS_PER_NODE}&collection.configName=esgf_config"
	
	# use field 'index_node' as sharding strategy
	# shards="esgf-node.jpl.nasa.gov,esgf-node.llnl.gov,esgf-data.dkrz.de"
    # curl "http://${SOLR_HOST}:${SOLR_PORT}/solr/admin/collections?action=CREATE&name=${collection}&numShards=${SOLR_NUM_SHARDS}&replicationFactor=${SOLR_NUM_REPLICAS}&maxShardsPerNode=${SOLR_MAX_SHARDS_PER_NODE}&collection.configName=esgf_config&router.name=implicit&router.field=index_node&shards=${shards}"
    
    # disable schemaless feature
    curl "http://${SOLR_HOST}:${SOLR_PORT}/solr/${collection}/config" -d '{"set-user-property": {"update.autoCreateFields":"false"}}'
  
  fi
done

# upload updated configuration
# must also reload each collections for changes to go into effect
for collection in "datasets" "files" "aggregations"
do
  #/opt/solr/bin/solr zk upconfig -z ${ZOOKEEPER_HOST}:${ZOOKEEPER_PORT} -n ${collection}  -d /esgf/solr-home/conf
  curl "http://${SOLR_HOST}:${SOLR_PORT}/solr/admin/collections?action=RELOAD&name=${collection}&wt=xml"
done
