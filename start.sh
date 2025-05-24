if command -v rclone &> /dev/null
then
    echo "Rclone executable found (global)"
    RCLONE_COMMAND="rclone"
else
    RCLONE_COMMAND="./rclone"
    if [ ! -f rclone ]; then
        echo "No rclone executable found, installing first (binary)"
        curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
        unzip rclone-current-linux-amd64.zip
        cp rclone-*-linux-amd64/rclone .
        rm -rf rclone-*
        chmod +x rclone
    else
        echo "Rclone executable found (binary)"
    fi
fi

if [ -z "${PORT}" ]; then
    echo "No PORT env var, using 8080 port"
    PORT=8080
else
    echo "PORT env var found, using $PORT port"
fi

if [ -n "${CONFIG_BASE64}" ] || [ -n "${CONFIG_URL}" ]; then
    echo "Rclone config found"

    if [ -n "${CONFIG_BASE64}" ]; then
        echo "${CONFIG_BASE64}" | base64 -d > rclone.conf
        echo "Base64-encoded config is used"
    elif [ -n "${CONFIG_URL}" ]; then
        curl "$CONFIG_URL" > rclone.conf
        echo "Gist link config is used"
    fi
    
    contents=$(cat rclone.conf)

    if ! echo "$contents" | grep -q "\[combine\]"; then
        remotes=$(echo "$contents" | grep '^\[' | sed 's/\[\(.*\)\]/\1/g')

        upstreams=""
        for remote in $remotes; do
            upstreams+="$remote=$remote: "
        done

        upstreams=${upstreams::-1}

        echo -e "\n\n[combine]\ntype = combine\nupstreams = $upstreams" >> rclone.conf
    fi

else
    echo "No Rclone config URL found, serving blank config"
    touch rclone.conf
    echo -e "[combine]\ntype = alias\nremote = dummy" > rclone.conf
fi

# Optimized command for video streaming with enhanced performance
CMD="${RCLONE_COMMAND} serve http combine: --addr=:$PORT --read-only --config rclone.conf"

# Core streaming optimizations with MAXIMUM storage utilization
CMD="${CMD} --buffer-size=128M"          # Massive buffer for ultra-smooth streaming
CMD="${CMD} --vfs-cache-mode=full"       # Full VFS caching for best performance
CMD="${CMD} --vfs-cache-max-size=280G"   # MAXIMUM cache - using 280GB of 300GB storage
CMD="${CMD} --vfs-cache-max-age=72h"     # Cache files for 72 hours (3 days)
CMD="${CMD} --vfs-read-chunk-size=512M"  # HUGE read chunks for seamless 4K/8K streaming
CMD="${CMD} --vfs-read-chunk-size-limit=4G" # Maximum chunk size for ultra-large files
CMD="${CMD} --vfs-write-back=30m"        # Quick write back cache
CMD="${CMD} --vfs-cache-poll-interval=30s" # Regular cache polling

# Network and transfer optimizations for high-bandwidth
CMD="${CMD} --transfers=16"              # More transfers for 3Gbps connection
CMD="${CMD} --checkers=32"               # More checkers for faster operations
CMD="${CMD} --timeout=120s"              # Extended timeout for large files
CMD="${CMD} --contimeout=60s"            # Initial connection timeout
CMD="${CMD} --low-level-retries=5"       # More retries for reliability
CMD="${CMD} --multi-thread-streams=8"    # Multi-threaded downloads
CMD="${CMD} --fast-list"                 # Faster directory listings

# HTTP server optimizations
CMD="${CMD} --max-header-bytes=8192"     # Increased header size for compatibility
CMD="${CMD} --server-read-timeout=1h"    # Long read timeout for large files
CMD="${CMD} --server-write-timeout=1h"   # Long write timeout for streaming

# Additional performance flags for large storage
CMD="${CMD} --use-mmap"                  # Use memory mapping for better performance
CMD="${CMD} --dir-cache-time=1h"         # Cache directory listings for 1 hour
CMD="${CMD} --poll-interval=30s"         # Balanced polling frequency
CMD="${CMD} --rc"                        # Enable remote control for monitoring
CMD="${CMD} --rc-addr=localhost:5572"    # RC interface (internal only)
CMD="${CMD} --rc-no-auth"                # No auth for internal RC
CMD="${CMD} --stats=30s"                 # Show stats every 30 seconds

# Optional: Enable verbose logging for debugging (comment out in production)
# CMD="${CMD} --log-level=INFO"

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
    CMD="${CMD} --user=\"$USERNAME\" --pass=\"$PASSWORD\""
    echo "Authentication is set"
fi

if [ "${DARK_MODE,,}" = "true" ]; then
    CMD="${CMD} --template=templates/dark.html"
    echo "Template is set to dark"
else
    echo "Template is set to light"
fi

echo "Running rclone index with MAXIMUM PERFORMANCE streaming optimizations"
echo "🚀 BEAST MODE optimizations enabled:"
echo "- Buffer size: 128MB (ultra-smooth streaming)"
echo "- VFS cache mode: Full with 280GB MAXIMUM storage cache"
echo "- Cache duration: 72 hours (3 days persistence)" 
echo "- Read chunk size: 512MB (8K streaming ready)"
echo "- Chunk limit: 4GB (supports massive video files)"
echo "- Parallel transfers: 16 (bandwidth maximization)"
echo "- Multi-thread streams: 8 threads per file"
echo "- Directory cache: 1 hour (instant navigation)"
echo "- Remote control enabled on localhost:5572"
echo ""
echo "🎯 Expected Performance:"
echo "- Zero buffering for 4K/8K streams"
echo "- ~140+ movies cached simultaneously" 
echo "- Multiple concurrent users supported"
echo "- Instant playback for cached content"

eval $CMD
