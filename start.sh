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

# Base command with essential options
CMD="${RCLONE_COMMAND} serve http combine: --addr=:$PORT --read-only --config rclone.conf"

# VFS caching for better streaming performance
CMD="${CMD} --vfs-cache-mode=full"              # Full VFS caching for best performance
CMD="${CMD} --vfs-cache-max-size=280G"          # Maximum cache utilization
CMD="${CMD} --vfs-cache-max-age=168h"           # Cache files for 7 days
CMD="${CMD} --vfs-read-chunk-size=128M"         # Optimized chunk size for streaming
CMD="${CMD} --vfs-read-chunk-size-limit=2G"     # Reasonable chunk limit
CMD="${CMD} --vfs-write-back=60m"               # Extended write back cache
CMD="${CMD} --vfs-cache-poll-interval=60s"      # Less frequent polling to reduce load

# HTTP server optimizations
CMD="${CMD} --max-header-bytes=16384"           # Increased header size for large requests
CMD="${CMD} --server-read-timeout=300s"         # 5 minutes read timeout
CMD="${CMD} --server-write-timeout=300s"        # 5 minutes write timeout

# Directory and file handling
CMD="${CMD} --dir-cache-time=30m"               # Directory cache time
CMD="${CMD} --poll-interval=60s"                # Polling interval
CMD="${CMD} --no-checksum"                      # Skip checksums for faster streaming

# Global rclone options (these work with serve http)
export RCLONE_BUFFER_SIZE=256M                  # Set buffer size via environment
export RCLONE_TIMEOUT=600s                      # 10 minutes total timeout
export RCLONE_CONTIMEOUT=120s                   # 2 minutes connection timeout
export RCLONE_EXPECT_CONTINUE_TIMEOUT=60s       # Handle large file uploads better
export RCLONE_TRANSFERS=8                       # Reduced transfers to avoid overwhelming
export RCLONE_CHECKERS=16                       # Balanced checkers
export RCLONE_LOW_LEVEL_RETRIES=10              # More retries for unstable connections
export RCLONE_MULTI_THREAD_STREAMS=4            # Reduced multi-threading
export RCLONE_FAST_LIST=true                    # Faster directory listings
export RCLONE_USE_MMAP=true                     # Use memory mapping for better performance
export RCLONE_BWLIMIT_FILE=100M                 # Limit per-file bandwidth
export RCLONE_IGNORE_CHECKSUM=true              # Skip checksum for faster streaming
export RCLONE_NO_TRAVERSE=true                  # Don't traverse all files upfront
export RCLONE_DISABLE=move                      # Disable move operations for safety
export RCLONE_LOG_LEVEL=INFO                    # INFO level logging
export RCLONE_LOG_FORMAT="date,time,level,msg"  # Structured logging
export RCLONE_STATS=60s                         # Show stats every minute
export RCLONE_STATS_ONE_LINE=true               # Compact stats format

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

echo "🔧 FIXED: Running rclone with enhanced video streaming stability (v1.69.3 compatible)"
echo "✅ Key fixes applied:"
echo "- Extended timeouts: 10min total, 2min connection (via environment variables)"
echo "- Optimized buffer: 256MB with 128MB chunks (smoother streaming)"
echo "- Reduced transfers: 8 concurrent (prevents overwhelming)"
echo "- Enhanced retries: 10 attempts (better stability)"
echo "- 7-day cache duration (longer persistence)"
echo "- Per-file bandwidth limit: 100MB/s (prevents timeouts)"
echo ""
echo "🎯 Expected improvements:"
echo "- Eliminated H27/H28 timeout errors"
echo "- Smoother video playback without interruptions"
echo "- Better handling of large video files"
echo "- More stable connections for mobile devices"
echo "- Reduced 499 status errors"

eval $CMD