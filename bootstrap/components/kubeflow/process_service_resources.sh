MAX_RETRIES=${MAX_RETRIES:-1}
RETRY_TIMEOUT=${RETRY_TIMEOUT:-8}

process_service_resources()
{
    local options=""
    local command=$KUBE_CMD
    local namespace=""
    local rest_args=
    local max_retries=$MAX_RETRIES
    local timeout=$RETRY_TIMEOUT

    #parse options
    while [ $# -gt 0 ]; do
        case $1 in
            (-n|--namespace) namespace="$2" ; shift ;;
            (-c|--command)   command="$2" ; shift ;;
            (-r|--retries)   max_retries="$2" ; shift ;;
            (-t|--timeout)   timeout="$2" ; shift ;;
            (-*|--*)         echo "Unknown option $1" ;;
            (*)              rest_args="$rest_args $1" ;;
        esac
        shift
    done

    if [ "$command" = "delete" ]; then
        options="delete --ignore-not-found=true"
    else
        options="$command"
    fi

    if [ -n "$namespace" ]; then
        options="$options -n $namespace"
    fi

    for man in $rest_args; do
        local retries=1
        while [ $retries -le $max_retries ] ; do
            echo
            echo "***Try $retries/$max_retries to $command ${man}..."
            echo
            if $KUSTOMIZE build ${MANIFESTS_DIR}/${man} | kubectl ${options} -f - ; then
                break 1
            fi
            retries=$(( retries + 1 ))
            sleep $timeout
        done;
        if [ $retries -gt $max_retries ]; then
            echo "*** ${man} $command failed ***"
            if [ "$command" != "delete" ]; then
                set_config_value "error" "true"
                exit 1
            fi
        else
            echo "*** $command $man finished done; ***"
        fi
    done
}

namespace_exists()
{
    local namespace=$1
    kubectl get ns ${namespace} >/dev/null 2>&1
    return $?
}
