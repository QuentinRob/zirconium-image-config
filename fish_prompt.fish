function fish_prompt --description 'Write out the prompt'
    set -l last_pipestatus $pipestatus
    set -lx __fish_last_status $status # Export for __fish_print_pipestatus.
    set -l normal (set_color --reset)

    # Color the prompt differently when we're root
    set -l color_cwd $fish_color_cwd
    set -l suffix '>'
    if functions -q fish_is_root_user; and fish_is_root_user
        if set -q fish_color_cwd_root
            set color_cwd $fish_color_cwd_root
        end
        set suffix '#'
    end

    # Write pipestatus
    # If the status was carried over (if no command is issued or if `set` leaves the status untouched), don't bold it.
    set -l bold_flag --bold
    set -q __fish_prompt_status_generation; or set -g __fish_prompt_status_generation $status_generation
    if test $__fish_prompt_status_generation = $status_generation
        set bold_flag
    end
    set __fish_prompt_status_generation $status_generation
    set -l status_color (set_color $fish_color_status)
    set -l statusb_color (set_color $bold_flag $fish_color_status)
    set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)

    # VPN status detection
    set -l vpn_interfaces
    for dev in /sys/class/net/*
        set -l dev_name (string replace '/sys/class/net/' '' $dev)
        if string match -q -r '^(tun|tap|wg|tailscale|cscotun|proton|ppp)' $dev_name
            # Only count the interface if it has active routing in /proc/net/route
            if string match -q -r "^$dev_name\\s" (cat /proc/net/route 2>/dev/null)
                set -a vpn_interfaces $dev_name
            end
        end
    end
    set -l vpn_segment ""
    if test (count $vpn_interfaces) -gt 0
        set -l vpn_list (string join "," $vpn_interfaces)
        set -l color_blue (set_color brblue)
        set -l color_normal (set_color normal)
        set vpn_segment "🔒 $color_blue$vpn_list$color_normal"
    end

    # Collect and format prompt segments
    set -l segments

    # 1. Login and Path segment (pwd)
    set -l login (prompt_login)
    set -l pwd_val (prompt_pwd)
    set -l color_pwd (set_color $color_cwd)
    set -l login_and_path ""
    if test -n "$login"
        set login_and_path "$login $color_pwd$pwd_val$normal"
    else
        set login_and_path "$color_pwd$pwd_val$normal"
    end
    set -a segments $login_and_path

    # 3. VCS segment (Git/Hg/Jujutsu)
    set -l vcs (fish_vcs_prompt)
    if test -n "$vcs"
        set vcs (string trim $vcs)
        set -a segments $vcs
    end

    # Kubernetes segment
    set -l k8s_segment ""
    if command -sq kubectl
        set -l kube_context (kubectl config current-context 2>/dev/null)
        if test -n "$kube_context"
            set -l kube_namespace (kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
            if test -z "$kube_namespace"
                set kube_namespace "default"
            end
            
            # Shorten the context/cluster name if it's too long or contains cloud prefixes
            if string match -q "*/*" $kube_context
                set kube_context (string split -r -m 1 "/" $kube_context)[-1]
            end
            if string match -q "*_*" $kube_context
                set kube_context (string split -r -m 1 "_" $kube_context)[-1]
            end
            if string match -q "*:*" $kube_context
                set kube_context (string split -r -m 1 ":" $kube_context)[-1]
            end
            
            # Truncate to a max length of 15 characters
            if test (string length $kube_context) -gt 15
                set kube_context (string sub -l 12 $kube_context)"..."
            end
            
            set -l color_k8s (set_color brcyan)
            set -l color_normal (set_color normal)
            set k8s_segment "☸ $color_k8s$kube_context$color_normal/$kube_namespace"
            set -a segments (string trim $k8s_segment)
        end
    end

    # 4. VPN segment (if active)
    if test -n "$vpn_segment"
        set -a segments (string trim $vpn_segment)
    end

    # 5. Pipestatus segment (if any command failed)
    if test -n "$prompt_status"
        set -a segments (string trim $prompt_status)
    end

    # Join the segments with a stylish grey vertical bar separator
    set -l color_sep (set_color brblack)
    set -l color_norm (set_color normal)
    set -l sep "$color_sep | $color_norm"
    set -l prompt_line (string join "$sep" $segments)

    # Print prompt details
    echo -n $prompt_line
    
    # Place the cursor/suffix on a new line
    echo ""
    echo -n -s $suffix " "
end
