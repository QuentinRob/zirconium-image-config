function k8s_resources --description 'Show Kubernetes requested vs allocatable resources'
    if not command -q kubectl
        echo "kubectl not found" >&2
        return 1
    end

    set -l show_nodes false
    for arg in $argv
        if test "$arg" = "--nodes"
            set show_nodes true
        end
    end

    # Retrieve all nodes first to get names
    set -l nodes_json (kubectl get nodes -o json)
    or return $status
    set -l node_names (string join \n -- $nodes_json | jq -r '.items[].metadata.name')

    # Create temporary files
    set -l pods_file (mktemp)
    set -l nodes_file (mktemp)
    set -l stats_file (mktemp)

    # Dump nodes json
    echo "$nodes_json" > $nodes_file

    # Retrieve all pods
    kubectl get pods -A -o json > $pods_file
    or begin
        rm -f $pods_file $nodes_file $stats_file
        return $status
    end

    # Retrieve stats summary for each node
    echo "[" > $stats_file
    set -l first true
    for node in $node_names
        set -l summary (kubectl get --raw "/api/v1/nodes/$node/proxy/stats/summary" 2>/dev/null)
        if test $status -eq 0 -a -n "$summary"
            if not test "$first" = "true"
                echo "," >> $stats_file
            end
            set first false
            echo "$summary" >> $stats_file
        end
    end
    echo "]" >> $stats_file

    # Run the Python processor
    python3 -c '
import sys
import json

def parse_cpu(val):
    if not val:
        return 0.0
    val = str(val).strip()
    if val.endswith("n"):
        return float(val[:-1]) / 1000000.0
    elif val.endswith("u"):
        return float(val[:-1]) / 1000.0
    elif val.endswith("m"):
        return float(val[:-1])
    else:
        try:
            return float(val) * 1000.0
        except ValueError:
            return 0.0

def parse_memory_to_mi(val):
    if not val:
        return 0.0
    val = str(val).strip()
    if val.endswith("Ki"):
        return float(val[:-2]) / 1024.0
    elif val.endswith("Mi"):
        return float(val[:-2])
    elif val.endswith("Gi"):
        return float(val[:-2]) * 1024.0
    elif val.endswith("Ti"):
        return float(val[:-2]) * 1024.0 * 1024.0
    elif val.endswith("Pi"):
        return float(val[:-2]) * 1024.0 * 1024.0 * 1024.0
    elif val.endswith("Ei"):
        return float(val[:-2]) * 1024.0 * 1024.0 * 1024.0 * 1024.0
    elif val.endswith("K"):
        return float(val[:-1]) * 1000.0 / (1024.0 * 1024.0)
    elif val.endswith("M"):
        return float(val[:-1]) * 1000.0 * 1000.0 / (1024.0 * 1024.0)
    elif val.endswith("G"):
        return float(val[:-1]) * 1000.0 * 1000.0 * 1000.0 / (1024.0 * 1024.0)
    elif val.endswith("T"):
        return float(val[:-1]) * 1000.0 * 1000.0 * 1000.0 * 1000.0 / (1024.0 * 1024.0)
    elif val.endswith("P"):
        return float(val[:-1]) * 1000.0 * 1000.0 * 1000.0 * 1000.0 * 1000.0 / (1024.0 * 1024.0)
    elif val.endswith("E"):
        return float(val[:-1]) * 1000.0 * 1000.0 * 1000.0 * 1000.0 * 1000.0 * 1000.0 / (1024.0 * 1024.0)
    else:
        try:
            return float(val) / (1024.0 * 1024.0)
        except ValueError:
            return 0.0

def pct(used, total):
    return (used / total * 100.0) if total > 0.0 else 0.0

def main():
    show_nodes = sys.argv[1].lower() == "true"
    pods_file = sys.argv[2]
    nodes_file = sys.argv[3]
    stats_file = sys.argv[4]

    try:
        with open(pods_file, "r") as f:
            pods_data = json.load(f)
        with open(nodes_file, "r") as f:
            nodes_data = json.load(f)
        with open(stats_file, "r") as f:
            stats_data = json.load(f)
    except Exception as e:
        print(f"Error loading JSON input files: {e}", file=sys.stderr)
        return

    nodes = {}
    for item in nodes_data.get("items", []):
        name = item["metadata"]["name"]
        alloc_cpu = parse_cpu(item["status"]["allocatable"].get("cpu", "0"))
        alloc_mem = parse_memory_to_mi(item["status"]["allocatable"].get("memory", "0"))
        alloc_disk = parse_memory_to_mi(item["status"]["allocatable"].get("ephemeral-storage", "0"))
        
        nodes[name] = {
            "name": name,
            "allocatable": {
                "cpu": alloc_cpu,
                "memory": alloc_mem,
                "disk": alloc_disk
            },
            "current": {"cpu": 0.0, "memory": 0.0, "disk": 0.0},
            "requested": {"cpu": 0.0, "memory": 0.0, "disk": 0.0},
            "limits": {"cpu": 0.0, "memory": 0.0, "disk": 0.0}
        }

    for stat in stats_data:
        node_name = stat.get("node", {}).get("nodeName")
        if node_name in nodes:
            cpu_nano = stat["node"].get("cpu", {}).get("usageNanoCores", 0)
            nodes[node_name]["current"]["cpu"] = float(cpu_nano) / 1000000.0
            
            mem_bytes = stat["node"].get("memory", {}).get("workingSetBytes", 0)
            nodes[node_name]["current"]["memory"] = float(mem_bytes) / (1024.0 * 1024.0)
            
            disk_bytes = stat["node"].get("fs", {}).get("usedBytes", 0)
            nodes[node_name]["current"]["disk"] = float(disk_bytes) / (1024.0 * 1024.0)

    for item in pods_data.get("items", []):
        node_name = item.get("spec", {}).get("nodeName")
        if node_name in nodes:
            for container in item.get("spec", {}).get("containers", []):
                resources = container.get("resources", {})
                requests = resources.get("requests", {})
                limits = resources.get("limits", {})
                
                nodes[node_name]["requested"]["cpu"] += parse_cpu(requests.get("cpu", "0"))
                nodes[node_name]["requested"]["memory"] += parse_memory_to_mi(requests.get("memory", "0"))
                nodes[node_name]["requested"]["disk"] += parse_memory_to_mi(requests.get("ephemeral-storage", "0"))
                
                nodes[node_name]["limits"]["cpu"] += parse_cpu(limits.get("cpu", "0"))
                nodes[node_name]["limits"]["memory"] += parse_memory_to_mi(limits.get("memory", "0"))
                nodes[node_name]["limits"]["disk"] += parse_memory_to_mi(limits.get("ephemeral-storage", "0"))

    # Headers and labels definitions
    node_hdr = "NODE"
    res_hdr = "RESOURCE"
    curr_hdr = "CURRENT"
    req_hdr = "REQUESTED"
    lim_hdr = "LIMIT"
    alloc_hdr = "ALLOCATABLE"
    
    cpu_lbl = "CPU"
    mem_lbl = "Memory"
    disk_lbl = "Disk"
    empty_lbl = ""

    if show_nodes:
        print(f"{node_hdr:<32} {res_hdr:<8} {curr_hdr:>16} {req_hdr:>16} {lim_hdr:>16} {alloc_hdr:>14}")
        first = True
        for name in sorted(nodes.keys()):
            if not first:
                print("-" * 108)
            first = False
            n = nodes[name]
            
            # CPU
            cpu_curr = n["current"]["cpu"] / 1000.0
            cpu_req = n["requested"]["cpu"] / 1000.0
            cpu_lim = n["limits"]["cpu"] / 1000.0
            cpu_alloc = n["allocatable"]["cpu"] / 1000.0
            cpu_curr_pct = pct(n["current"]["cpu"], n["allocatable"]["cpu"])
            cpu_req_pct = pct(n["requested"]["cpu"], n["allocatable"]["cpu"])
            cpu_lim_pct = pct(n["limits"]["cpu"], n["allocatable"]["cpu"])
            print(f"{name:<32} {cpu_lbl:<8} {cpu_curr:9.3f} {cpu_curr_pct:5.1f}% {cpu_req:9.3f} {cpu_req_pct:5.1f}% {cpu_lim:9.3f} {cpu_lim_pct:5.1f}% {cpu_alloc:14.3f}")
            
            # Memory
            mem_curr = n["current"]["memory"] / 1024.0
            mem_req = n["requested"]["memory"] / 1024.0
            mem_lim = n["limits"]["memory"] / 1024.0
            mem_alloc = n["allocatable"]["memory"] / 1024.0
            mem_curr_pct = pct(n["current"]["memory"], n["allocatable"]["memory"])
            mem_req_pct = pct(n["requested"]["memory"], n["allocatable"]["memory"])
            mem_lim_pct = pct(n["limits"]["memory"], n["allocatable"]["memory"])
            print(f"{empty_lbl:<32} {mem_lbl:<8} {mem_curr:9.2f} {mem_curr_pct:5.1f}% {mem_req:9.2f} {mem_req_pct:5.1f}% {mem_lim:9.2f} {mem_lim_pct:5.1f}% {mem_alloc:14.2f}")
            
            # Disk
            disk_curr = n["current"]["disk"] / 1024.0
            disk_req = n["requested"]["disk"] / 1024.0
            disk_lim = n["limits"]["disk"] / 1024.0
            disk_alloc = n["allocatable"]["disk"] / 1024.0
            disk_curr_pct = pct(n["current"]["disk"], n["allocatable"]["disk"])
            disk_req_pct = pct(n["requested"]["disk"], n["allocatable"]["disk"])
            disk_lim_pct = pct(n["limits"]["disk"], n["allocatable"]["disk"])
            print(f"{empty_lbl:<32} {disk_lbl:<8} {disk_curr:9.2f} {disk_curr_pct:5.1f}% {disk_req:9.2f} {disk_req_pct:5.1f}% {disk_lim:9.2f} {disk_lim_pct:5.1f}% {disk_alloc:14.2f}")
    else:
        total_curr_cpu = sum(n["current"]["cpu"] for n in nodes.values())
        total_req_cpu = sum(n["requested"]["cpu"] for n in nodes.values())
        total_lim_cpu = sum(n["limits"]["cpu"] for n in nodes.values())
        total_alloc_cpu = sum(n["allocatable"]["cpu"] for n in nodes.values())
        
        total_curr_mem = sum(n["current"]["memory"] for n in nodes.values())
        total_req_mem = sum(n["requested"]["memory"] for n in nodes.values())
        total_lim_mem = sum(n["limits"]["memory"] for n in nodes.values())
        total_alloc_mem = sum(n["allocatable"]["memory"] for n in nodes.values())
        
        total_curr_disk = sum(n["current"]["disk"] for n in nodes.values())
        total_req_disk = sum(n["requested"]["disk"] for n in nodes.values())
        total_lim_disk = sum(n["limits"]["disk"] for n in nodes.values())
        total_alloc_disk = sum(n["allocatable"]["disk"] for n in nodes.values())
        
        print(f"{res_hdr:<8} {curr_hdr:>16} {req_hdr:>16} {lim_hdr:>16} {alloc_hdr:>14}")
        
        # CPU
        cpu_curr = total_curr_cpu / 1000.0
        cpu_req = total_req_cpu / 1000.0
        cpu_lim = total_lim_cpu / 1000.0
        cpu_alloc = total_alloc_cpu / 1000.0
        cpu_curr_pct = pct(total_curr_cpu, total_alloc_cpu)
        cpu_req_pct = pct(total_req_cpu, total_alloc_cpu)
        cpu_lim_pct = pct(total_lim_cpu, total_alloc_cpu)
        print(f"{cpu_lbl:<8} {cpu_curr:9.3f} {cpu_curr_pct:5.1f}% {cpu_req:9.3f} {cpu_req_pct:5.1f}% {cpu_lim:9.3f} {cpu_lim_pct:5.1f}% {cpu_alloc:14.3f}")
        
        # Memory
        mem_curr = total_curr_mem / 1024.0
        mem_req = total_req_mem / 1024.0
        mem_lim = total_lim_mem / 1024.0
        mem_alloc = total_alloc_mem / 1024.0
        mem_curr_pct = pct(total_curr_mem, total_alloc_mem)
        mem_req_pct = pct(total_req_mem, total_alloc_mem)
        mem_lim_pct = pct(total_lim_mem, total_alloc_mem)
        print(f"{mem_lbl:<8} {mem_curr:9.2f} {mem_curr_pct:5.1f}% {mem_req:9.2f} {mem_req_pct:5.1f}% {mem_lim:9.2f} {mem_lim_pct:5.1f}% {mem_alloc:14.2f}")
        
        # Disk
        disk_curr = total_curr_disk / 1024.0
        disk_req = total_req_disk / 1024.0
        disk_lim = total_lim_disk / 1024.0
        disk_alloc = total_alloc_disk / 1024.0
        disk_curr_pct = pct(total_curr_disk, total_alloc_disk)
        disk_req_pct = pct(total_req_disk, total_alloc_disk)
        disk_lim_pct = pct(total_lim_disk, total_alloc_disk)
        print(f"{disk_lbl:<8} {disk_curr:9.2f} {disk_curr_pct:5.1f}% {disk_req:9.2f} {disk_req_pct:5.1f}% {disk_lim:9.2f} {disk_lim_pct:5.1f}% {disk_alloc:14.2f}")

if __name__ == "__main__":
    main()
' "$show_nodes" "$pods_file" "$nodes_file" "$stats_file"

    # Cleanup temporary files
    rm -f $pods_file $nodes_file $stats_file
end
