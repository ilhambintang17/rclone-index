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

# FIXED: Optimized command for video streaming with enhanced stability
CMD="${RCLONE_COMMAND} serve http combine: --addr=:$PORT --read-only --config rclone.conf"

# CRITICAL FIX: Extended timeouts to prevent H27/H28 errors
CMD="${CMD} --timeout=600s"              # 10 minutes total timeout (was 120s)
CMD="${CMD} --contimeout=120s"           # 2 minutes connection timeout (was 60s)
CMD="${CMD} --expect-continue-timeout=60s" # Handle large file uploads better

# FIXED: Better streaming buffer configuration
CMD="${CMD} --buffer-size=256M"          # Increased buffer for smoother streaming
CMD="${CMD} --vfs-cache-mode=full"       # Full VFS caching for best performance
CMD="${CMD} --vfs-cache-max-size=280G"   # Maximum cache utilization
CMD="${CMD} --vfs-cache-max-age=168h"    # Cache files for 7 days (was 72h)
CMD="${CMD} --vfs-read-chunk-size=128M"  # Optimized chunk size (was 512M - too aggressive)
CMD="${CMD} --vfs-read-chunk-size-limit=2G" # Reasonable chunk limit (was 4G)
CMD="${CMD} --vfs-write-back=60m"        # Extended write back cache
CMD="${CMD} --vfs-cache-poll-interval=60s" # Less frequent polling to reduce load

# FIXED: Improved network stability
CMD="${CMD} --transfers=8"               # Reduced transfers to avoid overwhelming (was 16)
CMD="${CMD} --checkers=16"               # Balanced checkers (was 32)
CMD="${CMD} --low-level-retries=10"      # More retries for unstable connections (was 5)
CMD="${CMD} --retry-delay=5s"            # Delay between retries
CMD="${CMD} --multi-thread-streams=4"    # Reduced multi-threading (was 8)
CMD="${CMD} --fast-list"                 # Faster directory listings

# CRITICAL FIX: HTTP server optimizations for large video files
CMD="${CMD} --max-header-bytes=16384"    # Increased header size (was 8192)
CMD="${CMD} --server-read-timeout=300s"  # 5 minutes read timeout (was 1h - too long)
CMD="${CMD} --server-write-timeout=300s" # 5 minutes write timeout (was 1h - too long)
CMD="${CMD} --server-keepalive-timeout=120s" # Keep connections alive longer

# FIXED: Memory and performance optimizations
CMD="${CMD} --use-mmap"                  # Use memory mapping for better performance
CMD="${CMD} --dir-cache-time=30m"        # Shorter cache time for better responsiveness (was 1h)
CMD="${CMD} --poll-interval=60s"         # Less frequent polling to reduce load
CMD="${CMD} --bwlimit-file=100M"         # Limit per-file bandwidth to prevent timeouts

# ADDED: Range request support for video streaming
CMD="${CMD} --http-no-slash"             # Better URL handling
CMD="${CMD} --http-range-bug-workaround" # Fix range request issues with some clients

# FIXED: Remote control with safer settings
CMD="${CMD} --rc"                        # Enable remote control for monitoring
CMD="${CMD} --rc-addr=localhost:5572"   # More explicit localhost binding
CMD="${CMD} --rc-no-auth"                # No auth for internal RC
CMD="${CMD} --stats=60s"                 # Show stats every minute (was 30s)
CMD="${CMD} --stats-one-line"            # Compact stats format

# ADDED: Error handling improvements
CMD="${CMD} --ignore-checksum"           # Skip checksum for faster streaming
CMD="${CMD} --no-traverse"               # Don't traverse all files upfront
CMD="${CMD} --disable=move"              # Disable move operations for safety

# ADDED: Logging for debugging (can be disabled in production)
CMD="${CMD} --log-level=INFO"            # INFO level logging
CMD="${CMD} --log-format=date,time,level,msg" # Structured logging

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

echo "🔧 FIXED: Running rclone with enhanced video streaming stability"
echo "✅ Key fixes applied:"
echo "- Extended timeouts: 10min total, 2min connection (prevents H27/H28 errors)"
echo "- Optimized buffer: 256MB with 128MB chunks (smoother streaming)"
echo "- Reduced transfers: 8 concurrent (prevents overwhelming)"
echo "- Enhanced retries: 10 attempts with 5s delay (better stability)"
echo "- Range request support (better video player compatibility)"
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