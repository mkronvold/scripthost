#!/usr/bin/env bash

list_app_pods() {
    local namespace="$1"
    local app_name="$2"

    kubectl -n "$namespace" get pods -l "app=${app_name}" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
}

restart_app_deployment() {
    local namespace="$1"
    local app_name="$2"

    kubectl -n "$namespace" rollout restart "deployment/${app_name}"
    kubectl -n "$namespace" rollout status "deployment/${app_name}"
}

push_directory_to_pods() {
    local namespace="$1"
    local app_name="$2"
    local local_dir="$3"
    local remote_dir="$4"
    local label="$5"
    local pod
    local found=0

    while IFS= read -r pod; do
        [ -n "$pod" ] || continue
        found=1
        kubectl -n "$namespace" exec "$pod" -- sh -c \
            "mkdir -p '$remote_dir' && find '$remote_dir' -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        tar -C "$local_dir" -czf - . | kubectl -n "$namespace" exec -i "$pod" -- sh -c \
            "mkdir -p '$remote_dir' && tar -xzf - -C '$remote_dir'"
        echo "Pushed ${label} into pod ${pod}:${remote_dir}"
    done < <(list_app_pods "$namespace" "$app_name")

    if [ "$found" -ne 1 ]; then
        echo "No pods found matching app=${app_name} in namespace ${namespace}" >&2
        return 1
    fi
}

prompt_post_apply_action() {
    local prompt_enabled="$1"
    local namespace="$2"
    local app_name="$3"
    local local_dir="$4"
    local remote_dir="$5"
    local label="$6"
    local reply

    if [ "$prompt_enabled" != "1" ]; then
        return
    fi

    printf 'Update running pods now? [r]estart deployment / [p]ush %s into pod storage / [n]either: ' "$label"
    read -r reply
    case "$reply" in
        [Rr]|[Rr][Ee][Ss][Tt][Aa][Rr][Tt])
            restart_app_deployment "$namespace" "$app_name"
            ;;
        [Pp]|[Pp][Uu][Ss][Hh])
            push_directory_to_pods "$namespace" "$app_name" "$local_dir" "$remote_dir" "$label"
            ;;
        ""|[Nn]|[Nn][Ee][Ii][Tt][Hh][Ee][Rr])
            echo "Left running pods unchanged"
            ;;
        *)
            echo "Unrecognized choice: $reply" >&2
            return 1
            ;;
    esac
}
