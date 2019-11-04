#!/usr/bin/env bash

_kube_fzf_usage() {
  local func=$1
  echo -e "\nUSAGE:\n"
  case $func in
    findpod)
      cat << EOF
findpod [-a | -n <namespace-query>] [pod-query]

-a                    -  Search in all namespaces
-h                    -  Show help
-n <namespace-query>  -  Find namespaces matching <namespace-query> and do fzf.
                         If there is only one match then it is selected automatically.
-C <context>          -  Use the given context name.
EOF
      ;;
    tailpod)
      cat << EOF
tailpod [-a | -n <namespace-query>] [pod-query]

-a                    -  Search in all namespaces
-h                    -  Show help
-n <namespace-query>  -  Find namespaces matching <namespace-query> and do fzf.
                         If there is only one match then it is selected automatically.
-C <context>          -  Use the given context name.
EOF
      ;;
    execpod)
      cat << EOF
execpod [-a | -n <namespace-query>] [pod-query] <command>

-a                    -  Search in all namespaces
-h                    -  Show help
-n <namespace-query>  -  Find namespaces matching <namespace-query> and do fzf.
                         If there is only one match then it is selected automatically.
-C <context>          -  Use the given context name.
EOF
      ;;
    pfpod)
      cat << EOF
pfpod [ -c | -o | -a | -n <namespace-query>] [pod-query] <source-port:destination-port | port>

-a                    -  Search in all namespaces
-h                    -  Show help
-n <namespace-query>  -  Find namespaces matching <namespace-query> and do fzf.
                         If there is only one match then it is selected automatically.
-C <context>          -  Use the given context name.
-o                    -  Open in Browser after port-forwarding
-c                    -  Copy to Clipboard
EOF
      ;;
    describepod)
      cat << EOF
describepod [-a | -n <namespace-query>] [pod-query]

-a                    -  Search in all namespaces
-h                    -  Show help
-n <namespace-query>  -  Find namespaces matching <namespace-query> and do fzf.
                         If there is only one match then it is selected automatically.
-C <context>          -  Use the given context name.
EOF
      ;;
  esac
}

_kube_fzf_handler() {
  local opt namespace_query pod_query cmd
  local open=false
  local copy=false
  local context="minikube"
  local OPTIND=1
  local func=$1

  shift $((OPTIND))

  while getopts ":hn:aocC:" opt; do
    case $opt in
      h)
        _kube_fzf_usage "$func"
        return 1
        ;;
      n)
        namespace_query="$OPTARG"
        ;;
      a)
        namespace_query="--all-namespaces"
        ;;
      o)
        open=true
        ;;
      c)
        copy=true
        ;;
      C)
        context="$OPTARG"
        ;;
      \?)
        echo "Invalid Option: -$OPTARG."
        _kube_fzf_usage "$func"
        return 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument."
        _kube_fzf_usage "$func"
        return 1
        ;;
    esac
  done

  shift $((OPTIND - 1))
  if [ "$func" = "execpod" ] || [ "$func" = "pfpod" ]; then
    if [ $# -eq 1 ]; then
      cmd=$1
      [ -z "$cmd" ] && cmd="sh"
    elif [ $# -eq 2 ]; then
      pod_query=$1
      cmd=$2
      if [ -z "$cmd" ]; then
        if [ "$func" = "execpod" ]; then
          echo "Command required." && _kube_fzf_usage "$func" && return 1
        elif [ "$func" = "pfpod" ]; then
          echo "Port required." && _kube_fzf_usage "$func" && return 1
        fi
      fi
    else
      if [ -z "$cmd" ]; then
        if [ "$func" = "execpod" ]; then
          cmd="sh"
        elif [ "$func" = "pfpod" ]; then
          echo "Port required." && _kube_fzf_usage "$func" && return 1
        fi
      fi
    fi
  else
    pod_query=$1
  fi

  args="$context|$namespace_query|$pod_query|$cmd|$open|$copy"
}

_kube_fzf_fzf_args() {
  local search_query=$1
  local extra_args=$2
  local fzf_args="--height=10 --ansi --reverse $extra_args"
  [ -n "$search_query" ] && fzf_args="$fzf_args --query=$search_query"
  echo "$fzf_args"
}

_kube_fzf_search_pod() {
  local namespace pod_name
  local context=$1
  local namespace_query=$2
  local pod_query=$3
  local pod_fzf_args=$(_kube_fzf_fzf_args "$pod_query")

  if [ -z "$namespace_query" ]; then
      namespace=$(kubectl config get-contexts --no-headers $context \
        | awk '{ print $6 }')

      namespace=${namespace:=default}
      pod_name=$(kubectl get pod --context=$context --namespace=$namespace --no-headers \
          | fzf $(echo $pod_fzf_args) \
        | awk '{ print $2 }')
  elif [ "$namespace_query" = "--all-namespaces" ]; then
    read namespace pod_name <<< $(kubectl get pod --context=$context --all-namespaces --no-headers \
        | fzf $(echo $pod_fzf_args) \
      | awk '{ print $2, $3 }')
  else
    local namespace_fzf_args=$(_kube_fzf_fzf_args "$namespace_query" "--select-1")
    namespace=$(kubectl get namespaces --context=$context --no-headers \
        | fzf $(echo $namespace_fzf_args) \
      | awk '{ print $2 }')

    namespace=${namespace:=default}
    pod_name=$(kubectl get pod --context=$context --namespace=$namespace --no-headers \
        | fzf $(echo $pod_fzf_args) \
      | awk '{ print $2 }')
  fi

  [ -z "$pod_name" ] && return 1

  echo "$namespace|$pod_name"
}

_kube_fzf_echo() {
  local reset_color="\033[0m"
  local bold_green="\033[1;32m"
  local message=$1
  echo -e "\n$bold_green $message $reset_color\n"
}
