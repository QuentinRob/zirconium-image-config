function k8s_resources --description 'Show Kubernetes requested vs allocatable resources'
    if not command -q kubectl
        echo "kubectl not found" >&2
        return 1
    end

    if not command -q jq
        echo "jq not found" >&2
        return 1
    end

    set -l pods_json (kubectl get pods -A -o json)
    or return $status

    set -l nodes_json (kubectl get nodes -o json)
    or return $status

    set -l current_usage (kubectl top nodes --no-headers | awk '
        function cpu_to_m(value) {
          if (value ~ /n$/) return substr(value, 1, length(value) - 1) / 1000000
          if (value ~ /u$/) return substr(value, 1, length(value) - 1) / 1000
          if (value ~ /m$/) return substr(value, 1, length(value) - 1)
          return value * 1000
        }

        function mem_to_mi(value) {
          if (value ~ /Ki$/) return substr(value, 1, length(value) - 2) / 1024
          if (value ~ /Mi$/) return substr(value, 1, length(value) - 2)
          if (value ~ /Gi$/) return substr(value, 1, length(value) - 2) * 1024
          if (value ~ /Ti$/) return substr(value, 1, length(value) - 2) * 1024 * 1024
          if (value ~ /K$/) return substr(value, 1, length(value) - 1) * 1000 / 1024 / 1024
          if (value ~ /M$/) return substr(value, 1, length(value) - 1) * 1000 * 1000 / 1024 / 1024
          if (value ~ /G$/) return substr(value, 1, length(value) - 1) * 1000 * 1000 * 1000 / 1024 / 1024
          return value / 1024 / 1024
        }

        {
          cpu_m += cpu_to_m($2)
          memory_mi += mem_to_mi($4)
        }

        END {
          printf "%s %s\n", cpu_m + 0, memory_mi + 0
        }
    ')
    or return $status

    set -l requested_limits (string join \n -- $pods_json | jq -r '
        def cpu_to_m:
          if endswith("n") then sub("n$";"") | tonumber / 1000000
          elif endswith("u") then sub("u$";"") | tonumber / 1000
          elif endswith("m") then sub("m$";"") | tonumber
          else tonumber * 1000
          end;

        def mem_to_mi:
          if endswith("Ki") then sub("Ki$";"") | tonumber / 1024
          elif endswith("Mi") then sub("Mi$";"") | tonumber
          elif endswith("Gi") then sub("Gi$";"") | tonumber * 1024
          elif endswith("Ti") then sub("Ti$";"") | tonumber * 1024 * 1024
          elif endswith("Pi") then sub("Pi$";"") | tonumber * 1024 * 1024 * 1024
          elif endswith("Ei") then sub("Ei$";"") | tonumber * 1024 * 1024 * 1024 * 1024
          elif endswith("K") then sub("K$";"") | tonumber * 1000 / 1024 / 1024
          elif endswith("M") then sub("M$";"") | tonumber * 1000 * 1000 / 1024 / 1024
          elif endswith("G") then sub("G$";"") | tonumber * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("T") then sub("T$";"") | tonumber * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("P") then sub("P$";"") | tonumber * 1000 * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("E") then sub("E$";"") | tonumber * 1000 * 1000 * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          else tonumber / 1024 / 1024
          end;

        [
          .items[]
          | select(.spec.nodeName != null)
          | .spec.containers[]
          | {
              cpu: (.resources.requests.cpu // "0"),
              memory: (.resources.requests.memory // "0"),
              cpu_limit: (.resources.limits.cpu // "0"),
              memory_limit: (.resources.limits.memory // "0")
            }
        ]
        | reduce .[] as $c (
            {cpu_m: 0, memory_mi: 0, cpu_limit_m: 0, memory_limit_mi: 0};
            .cpu_m += ($c.cpu | cpu_to_m)
            | .memory_mi += ($c.memory | mem_to_mi)
            | .cpu_limit_m += ($c.cpu_limit | cpu_to_m)
            | .memory_limit_mi += ($c.memory_limit | mem_to_mi)
        )
        | "\(.cpu_m) \(.memory_mi) \(.cpu_limit_m) \(.memory_limit_mi)"
    ')
    or return $status

    set -l allocatable (string join \n -- $nodes_json | jq -r '
        def cpu_to_m:
          if endswith("n") then sub("n$";"") | tonumber / 1000000
          elif endswith("u") then sub("u$";"") | tonumber / 1000
          elif endswith("m") then sub("m$";"") | tonumber
          else tonumber * 1000
          end;

        def mem_to_mi:
          if endswith("Ki") then sub("Ki$";"") | tonumber / 1024
          elif endswith("Mi") then sub("Mi$";"") | tonumber
          elif endswith("Gi") then sub("Gi$";"") | tonumber * 1024
          elif endswith("Ti") then sub("Ti$";"") | tonumber * 1024 * 1024
          elif endswith("Pi") then sub("Pi$";"") | tonumber * 1024 * 1024 * 1024
          elif endswith("Ei") then sub("Ei$";"") | tonumber * 1024 * 1024 * 1024 * 1024
          elif endswith("K") then sub("K$";"") | tonumber * 1000 / 1024 / 1024
          elif endswith("M") then sub("M$";"") | tonumber * 1000 * 1000 / 1024 / 1024
          elif endswith("G") then sub("G$";"") | tonumber * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("T") then sub("T$";"") | tonumber * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("P") then sub("P$";"") | tonumber * 1000 * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          elif endswith("E") then sub("E$";"") | tonumber * 1000 * 1000 * 1000 * 1000 * 1000 * 1000 / 1024 / 1024
          else tonumber / 1024 / 1024
          end;

        [
          .items[]
          | {
              cpu: .status.allocatable.cpu,
              memory: .status.allocatable.memory
            }
        ]
        | reduce .[] as $n (
            {cpu_m: 0, memory_mi: 0};
            .cpu_m += ($n.cpu | cpu_to_m)
            | .memory_mi += ($n.memory | mem_to_mi)
        )
        | "\(.cpu_m) \(.memory_mi)"
    ')
    or return $status

    set -l usage_cpu_m (string split ' ' -- $current_usage)[1]
    set -l usage_mem_mi (string split ' ' -- $current_usage)[2]
    set -l req_cpu_m (string split ' ' -- $requested_limits)[1]
    set -l req_mem_mi (string split ' ' -- $requested_limits)[2]
    set -l limit_cpu_m (string split ' ' -- $requested_limits)[3]
    set -l limit_mem_mi (string split ' ' -- $requested_limits)[4]
    set -l alloc_cpu_m (string split ' ' -- $allocatable)[1]
    set -l alloc_mem_mi (string split ' ' -- $allocatable)[2]

    awk -v usage_cpu_m="$usage_cpu_m" \
        -v usage_mem_mi="$usage_mem_mi" \
        -v req_cpu_m="$req_cpu_m" \
        -v req_mem_mi="$req_mem_mi" \
        -v limit_cpu_m="$limit_cpu_m" \
        -v limit_mem_mi="$limit_mem_mi" \
        -v alloc_cpu_m="$alloc_cpu_m" \
        -v alloc_mem_mi="$alloc_mem_mi" '
        BEGIN {
          printf "%-8s %16s %16s %16s %14s\n", "RESOURCE", "CURRENT", "REQUESTED", "LIMIT", "ALLOCATABLE"
          printf "%-8s %9.3f %5.1f%% %9.3f %5.1f%% %9.3f %5.1f%% %14.3f\n",
            "CPU",
            usage_cpu_m / 1000, pct(usage_cpu_m, alloc_cpu_m),
            req_cpu_m / 1000, pct(req_cpu_m, alloc_cpu_m),
            limit_cpu_m / 1000, pct(limit_cpu_m, alloc_cpu_m),
            alloc_cpu_m / 1000
          printf "%-8s %9.2f %5.1f%% %9.2f %5.1f%% %9.2f %5.1f%% %14.2f\n",
            "Memory",
            usage_mem_mi / 1024, pct(usage_mem_mi, alloc_mem_mi),
            req_mem_mi / 1024, pct(req_mem_mi, alloc_mem_mi),
            limit_mem_mi / 1024, pct(limit_mem_mi, alloc_mem_mi),
            alloc_mem_mi / 1024
        }

        function pct(used, total) {
          return total > 0 ? used / total * 100 : 0
        }
    '
end
