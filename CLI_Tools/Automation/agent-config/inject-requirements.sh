#!/bin/bash

# CONFIGURATION
# WARNING: Use absolute paths!
WATCH_DIR="Insert Watch Directory Here"
SOURCE_REQ="Insert Source Directory of requirements"
PROMPT_TEXT="Please use the requirements.md file located in this directory as the primary context when building or suggesting code for this project."

# MONITORING LOOP
inotifywait -m -r -e create --format '%w%f' "$WATCH_DIR" | while read NEW_ITEM
do
    # 1. Check if the detection is a directory
    if [ -d "$NEW_ITEM" ]; then

        # 2. Wait 3 seconds to let "mkdir -p" finish creating the tree
        sleep 3

        # 3. Find this directory and any sub-directories created inside it
        find "$NEW_ITEM" -type d | while read INNER_DIR
        do
            # We look inside the folder. if we find *any* other directory (mindepth 1),
            # then this is a "parent" folder, not the "last" directory.
            HAS_SUBDIRS=$(find "$INNER_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

            if [ -n "$HAS_SUBDIRS" ]; then
                # This folder contains other folders. Skip it.
                continue
            fi
            # -----------------------------

            # Check if we already processed this folder (to avoid overwriting) (or agents.md or other md file depending on your cli tool of choice)
            if [ ! -f "$INNER_DIR/gemini.md" ]; then 

                # Copy requirements.md
                if [ -f "$SOURCE_REQ" ]; then
                    cp "$SOURCE_REQ" "$INNER_DIR/requirements.md"
                fi

                # Create gemini.md (or agents.md or other md file depending on your cli tool of choice)
                echo "$PROMPT_TEXT" > "$INNER_DIR/gemini.md"

                # Log to journal (viewable with journalctl)
                echo "Processed Leaf Directory: $INNER_DIR"
            fi
        done
    fi
done
