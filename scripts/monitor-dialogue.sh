#!/bin/bash
# Qwen Dialogue Monitor
# Monitors Gist for new messages from task_mbt

GIST_DIR="/home/kench/workspace/beads_mbt/.qwen-dialogue"
LAST_CHECK="$GIST_DIR/.last_check"

echo "📡 Starting dialogue monitor..."
echo "Monitoring: $GIST_DIR"
echo ""

# Initialize last check timestamp
if [ ! -f "$LAST_CHECK" ]; then
    date +%s > "$LAST_CHECK"
fi

while true; do
    # Pull latest changes
    cd "$GIST_DIR"
    git pull origin main > /dev/null 2>&1
    
    # Check if dialogue.md was updated
    if [ "dialogue.md" -nt "$LAST_CHECK" ]; then
        echo "📬 New message detected!"
        echo ""
        echo "=== Latest Message ==="
        head -20 dialogue.md
        echo "..."
        echo ""
        echo "📖 Full message: cat $GIST_DIR/dialogue.md"
        echo ""
        
        # Update last check
        date +%s > "$LAST_CHECK"
        
        # Notify user
        echo "🔔 Check Gist for reply: https://gist.github.com/d2f30f68370797333d1e3365794502f3"
    fi
    
    # Wait 60 seconds
    sleep 60
done
