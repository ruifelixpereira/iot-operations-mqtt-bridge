#!/bin/bash

set -e


required_vars=(
    "resource_group"
    "subscription_id"
    "k8s_context"
    "k8s_cluster_name"
    "k8s_extension_name"
    "event_grid_namespace"
    "event_grid_topic_space"
    "event_grid_topic_template"
)

parse_config_file() {
    local config_file="$1"
    # Parse the configuration file
    while read -r line; do
        key=$(echo "$line" | sed -e 's/[{}"]//g' | awk -F: '{print $1}')
        value=$(echo "$line" | sed -e 's/[{}"]//g' | awk -F: '{print $2}'| xargs)
        case "$key" in
            resource_group) resource_group="$value" ;;
            subscription_id) subscription_id="$value" ;;
            k8s_context) k8s_context="$value" ;;
            k8s_cluster_name) k8s_cluster_name="$value" ;;
            k8s_extension_name) k8s_extension_name="$value" ;;
            event_grid_namespace) event_grid_namespace="$value" ;;
            event_grid_topic_space) event_grid_topic_space="$value" ;;
            event_grid_topic_template) event_grid_topic_template="$value" ;;
        esac
    done < <(cat "$config_file" | grep -Eo '"[^"]*"\s*:\s*"[^"]*"')

    # Check if all required variables have been set
    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done

    # If we have missing key-value pairs, then print all the pairs that are missing from the config file.
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "Error: Missing required values in config file:"
        for var in "${missing_vars[@]}"; do
            echo "  $var"
        done
        exit 1
    fi
}

# Set the current directory to where the script lives.
cd "$(dirname "$0")"

# Function to display usage information
usage() {
    echo "Usage: $0 [-c|--config-file] <MQTT_BRIDGE_SETUP_CONFIG_FILE_PATH>"
    echo ""
    echo "Example:"
    echo "  $0 -c mqtt_bridge_setup.json"
}

check_argument_value() {
    if [[ -z "$2" ]]; then
        echo "Error: Missing value for option $1"
        usage
        exit 1
    fi
}

# Function to check if all required arguments have been set
check_required_arguments() {
    # Array to store the names of the missing arguments
    local missing_arguments=()

    # Loop through the array of required argument names
    for arg_name in "${required_vars[@]}"; do
        # Check if the argument value is empty
        if [[ -z "${!arg_name}" ]]; then
            # Add the name of the missing argument to the array
            missing_arguments+=("${arg_name}")
        fi
    done

    # Check if any required argument is missing
    if [[ ${#missing_arguments[@]} -gt 0 ]]; then
        echo -e "\nError: Missing required arguments:"
        printf '  %s\n' "${missing_arguments[@]}"
        [ ! \( \( $# == 1 \) -a \( "$1" == "-c" \) \) ] && echo "  Either provide a config file path or all the arguments, but not both at the same time."
        [ ! \( $# == 22 \) ] && echo "  All arguments must be provided."
        echo ""
        usage
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--config-file)
    config_file="$2"
    parse_config_file "$config_file"
    shift # past argument
    shift # past value
    break # break out of case statement if config file is provided
    ;;
    -h|--help)
    usage
    exit 0
    ;;
    *)
    echo "Unknown argument: $key"
    usage
    exit 1
esac
done

# Check if all required arguments have been set
check_required_arguments

az account set --subscription "$subscription_id"
azure_providers_id_path="/subscriptions/$subscription_id/resourceGroups/$resource_group/providers"
location=$(az group show --name $resource_group --query location -o tsv)


# Event Grid Namespace with MQTT broker enabled
event_grid_namespace_query=$(az resource list --resource-group "$resource_group" \
    --resource-type "Microsoft.EventGrid/namespaces" \
    --query "[?name=='$event_grid_namespace']")

if [ "$event_grid_namespace_query" == "[]" ]; then
    echo -e "\nCreating an Event Grid Namespace"
    az eventgrid namespace create -n $event_grid_namespace \
        -g $resource_group --location $location \
        --topic-spaces-configuration "{state:Enabled,maximumClientSessionsPerAuthenticationName:3}"
else
    echo "Event Grid Namespace $event_grid_namespace already exists."
fi

# Event Grid Topic space with a topic template
# By using the # wildcard in the topic template, you can publish to any topic under the telemetry topic space.
# For example, telemetry/temperature or telemetry/humidity
event_grid_topic_space_query=$(az eventgrid namespace topic-space list --resource-group "$resource_group" --namespace-name $event_grid_namespace --query "[?name=='$event_grid_topic_space']")

if [ "$event_grid_topic_space_query" == "[]" ]; then
    echo -e "\nCreating the event grid topic space '$event_grid_topic_space'"
    az eventgrid namespace topic-space create -g "$resource_group" --namespace-name $event_grid_namespace --name $event_grid_topic_space --topic-templates "$event_grid_topic_template/#"
else
    echo "Event Grid topic space $event_grid_topic_space already exists."
fi

# Find principal ID for the E4K Arc extension
e4k_managed_id=$(az k8s-extension show --name $k8s_extension_name --cluster-name $k8s_cluster_name --resource-group $resource_group --cluster-type connectedClusters --query identity.principalId --output tsv)

# Give E4K access to the Event Grid topic space
az role assignment create --assignee $e4k_managed_id --role "EventGrid TopicSpaces Subscriber" --scope $azure_providers_id_path/Microsoft.EventGrid/namespaces/$event_grid_namespace/topicSpaces/$event_grid_topic_space
az role assignment create --assignee $e4k_managed_id --role "EventGrid TopicSpaces Publisher" --scope $azure_providers_id_path/Microsoft.EventGrid/namespaces/$event_grid_namespace/topicSpaces/$event_grid_topic_space

# Collect the Event Grid MQTT broker hostname
mqtt_broker_hostname=$(az eventgrid namespace show -g "$resource_group" -n $event_grid_namespace --query topicSpacesConfiguration.hostname -o tsv)
echo "Configure Event Grid MQTT broker hostname $mqtt_broker_hostname in your topic map."

# Ensure proper kubectl context
kubectl config use-context $k8s_context

# Create MQTT Bridge Connector
kubectl apply -f mqtt-bridge.yaml

# Create MQTT Bridge Connector Topic Map
kubectl apply -f topic-map.yaml

exit 0