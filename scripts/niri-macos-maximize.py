#!/usr/bin/env python3
import json
import os
import subprocess
import sys

STATE_FILE = "/tmp/niri-maximized-windows.json"

def run_niri_cmd(args):
    res = subprocess.run(["niri", "msg", "--json"] + args, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error running niri msg: {res.stderr}", file=sys.stderr)
        return None
    try:
        return json.loads(res.stdout)
    except json.JSONDecodeError:
        return res.stdout

def get_focused_window(windows):
    for w in windows:
        if w.get("is_focused"):
            return w
    return None

def main():
    # 1. Get all windows
    windows = run_niri_cmd(["windows"])
    if not windows:
        return
    
    focused = get_focused_window(windows)
    if not focused:
        print("No focused window found.")
        return
    
    window_id = str(focused["id"])
    
    # Load state
    state = {}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
        except Exception:
            pass
            
    # Cleanup state for closed windows
    open_window_ids = {str(w["id"]) for w in windows}
    state = {k: v for k, v in state.items() if k in open_window_ids}
            
    # 2. Check if this window is currently in the state (maximized on dedicated workspace)
    if window_id in state:
        original_workspace_id = state[window_id]
        
        # Unmaximize first (toggle maximize off)
        run_niri_cmd(["action", "maximize-column"])
        
        # Move back to original workspace
        run_niri_cmd(["action", "move-window-to-workspace", str(original_workspace_id)])
        run_niri_cmd(["action", "focus-workspace", str(original_workspace_id)])
        
        # Remove from state
        del state[window_id]
    else:
        original_workspace_id = focused["workspace_id"]
        
        # Get workspaces to find the empty one at the bottom
        workspaces = run_niri_cmd(["workspaces"])
        if not workspaces:
            return
            
        empty_workspace = None
        for ws in workspaces:
            if ws.get("active_window_id") is None:
                empty_workspace = ws
                break
                
        if empty_workspace is None:
            print("No empty workspace found.")
            return
            
        empty_workspace_idx = empty_workspace["idx"]
        
        # Save state before moving
        state[window_id] = original_workspace_id
        
        # Move window to the empty workspace
        run_niri_cmd(["action", "move-window-to-workspace", str(empty_workspace_idx)])
        # Focus the workspace
        run_niri_cmd(["action", "focus-workspace", str(empty_workspace_idx)])
        # Maximize the window
        run_niri_cmd(["action", "maximize-column"])
        
    # Save state
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
    except Exception as e:
        print(f"Failed to write state: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
