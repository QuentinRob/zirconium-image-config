function fish_jj_prompt --description 'Print the Jujutsu status'
    # If jj isn't installed, there's nothing we can do
    if not command -sq jj
        return 1
    end

    # Run jj once to get status of current commit (@) and the closest bookmark(s).
    # We use --ignore-working-copy for performance, in line with fish standards.
    set -l jj_raw (jj --no-pager log --no-graph --ignore-working-copy -r '@ | heads(::@ & bookmarks())' -T 'change_id.short(8) ++ ":" ++ empty ++ ":" ++ conflict ++ ":" ++ diff.files().len() ++ ":" ++ local_bookmarks.map(|b| b.name()).join(",") ++ "\n"' 2>/dev/null)
    
    # If exit status is non-zero or output is empty, we are not in a jj repo
    if test $status -ne 0 -o -z "$jj_raw"
        return 1
    end

    set -l at_line ""
    set -l bookmark_line ""

    # Parse the output lines. If there is 1 line, @ has the bookmark. If 2, @ is ahead of it.
    set -l line_count (count $jj_raw)
    if test $line_count -eq 1
        set at_line $jj_raw[1]
    else if test $line_count -ge 2
        set at_line $jj_raw[1]
        set bookmark_line $jj_raw[2]
    end

    # Split the @ commit line: change_id:empty:conflict:files_count:bookmarks
    set -l at_parts (string split ":" $at_line)
    set -l change_id $at_parts[1]
    set -l is_empty $at_parts[2]
    set -l is_conflict $at_parts[3]
    set -l files_count $at_parts[4]
    set -l at_bookmarks $at_parts[5]

    set -l bookmark_name ""
    set -l is_ancestor_bookmark false

    if test -n "$at_bookmarks"
        set bookmark_name $at_bookmarks
    else if test -n "$bookmark_line"
        set -l bookmark_parts (string split ":" $bookmark_line)
        set bookmark_name $bookmark_parts[5]
        set is_ancestor_bookmark true
    end

    # Color definitions
    set -l color_jj (set_color brpurple) # purple/magenta for jj identifier
    set -l color_bm (set_color green)    # green for clean/active bookmarks
    set -l color_bm_anc (set_color brgreen) # slightly different green/brgreen for ancestor bookmarks
    set -l color_id (set_color cyan)    # cyan for change ID
    set -l color_dirty (set_color yellow) # yellow for modified count
    set -l color_conf (set_color -o red)  # bold red for conflicts
    set -l color_sep (set_color brblack)  # grey for separators
    set -l normal (set_color normal)

    # Build prompt string
    set -l jj_prompt " ($color_jj"jj"$color_sep:"

    if test -n "$bookmark_name"
        if test "$is_ancestor_bookmark" = "true"
            set jj_prompt "$jj_prompt$color_bm_anc$bookmark_name~$normal"
        else
            set jj_prompt "$jj_prompt$color_bm$bookmark_name$normal"
        end
        set jj_prompt "$jj_prompt$color_sep|$normal"
    end

    set jj_prompt "$jj_prompt$color_id$change_id$normal"

    # Status indicators
    if test "$is_conflict" = "true"
        set jj_prompt "$jj_prompt $color_conf"×"$normal"
    else if test "$is_empty" = "false"
        set jj_prompt "$jj_prompt $color_dirty*$files_count$normal"
    end

    set jj_prompt "$jj_prompt)"
    echo -n $jj_prompt
end
