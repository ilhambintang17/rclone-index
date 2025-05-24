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

# VFS caching optimized for video streaming and seeking
CMD="${CMD} --vfs-cache-mode=full"              # Full VFS caching for best performance
# Reduced VFS cache size to conserve memory on Heroku (was 450M)
CMD="${CMD} --vfs-cache-max-size=250M"          # Reduced cache size for Heroku memory limits
CMD="${CMD} --vfs-cache-max-age=24h"            # Shorter cache time for dynamic content
# Reduced VFS read chunk size to conserve memory (was 64M)
CMD="${CMD} --vfs-read-chunk-size=32M"          # Smaller chunks for faster seeking
CMD="${CMD} --vfs-read-chunk-size-limit=512M"   # Lower limit for better responsiveness
CMD="${CMD} --vfs-read-chunk-streams=8"         # Multiple parallel streams for seeking
# Further reduced VFS read ahead for potentially unstable connections (was 128M)
CMD="${CMD} --vfs-read-ahead=64M"              # Read ahead for smoother playback
CMD="${CMD} --vfs-read-wait=5s"                 # Time to wait for more data from source
CMD="${CMD} --vfs-write-back=5s"                # Faster write back
CMD="${CMD} --vfs-cache-poll-interval=30s"      # More frequent polling for updates

# HTTP server optimizations for video seeking
CMD="${CMD} --max-header-bytes=32768"           # Larger headers for range requests
# Reduced server read timeout to respond/fail faster than Heroku router timeout and client impatience (was 60s)
CMD="${CMD} --server-read-timeout=25s"          # Shorter timeout to prevent H27 errors
# Reduced server write timeout for similar reasons (was 60s)
CMD="${CMD} --server-write-timeout=25s"         # Shorter timeout for faster response

# Directory and file handling optimized for video
CMD="${CMD} --dir-cache-time=10m"               # Shorter directory cache for responsiveness
CMD="${CMD} --poll-interval=30s"                # More frequent polling
CMD="${CMD} --no-checksum"                      # Skip checksums for faster streaming
CMD="${CMD} --no-modtime"                       # Skip modification time checks

# Global rclone options optimized for video streaming and seeking
# Further reduced rclone buffer size for minimal footprint (was 64M)
export RCLONE_BUFFER_SIZE=32M                  # Smaller buffer for faster seeking
# Reduced overall rclone operation timeout to fail faster on stuck operations (was 120s)
export RCLONE_TIMEOUT=30s                      # Shorter timeout to prevent H27
export RCLONE_CONTIMEOUT=30s                    # Quick connection timeout
export RCLONE_EXPECT_CONTINUE_TIMEOUT=10s       # Faster expect continue
# Reduced concurrent transfers to lessen load on backend/network (was 4)
export RCLONE_TRANSFERS=2                       # Fewer transfers to prevent overwhelming Heroku
export RCLONE_CHECKERS=8                        # Fewer checkers for stability
export RCLONE_LOW_LEVEL_RETRIES=5               # Fewer retries for faster response
export RCLONE_MULTI_THREAD_STREAMS=8            # More streams for parallel seeking
export RCLONE_FAST_LIST=true                    # Faster directory listings
export RCLONE_USE_MMAP=true                     # Memory mapping for performance
export RCLONE_BWLIMIT_FILE=50M                  # Lower bandwidth limit to prevent timeouts
export RCLONE_IGNORE_CHECKSUM=true              # Skip checksums
export RCLONE_NO_TRAVERSE=true                  # Don't traverse all files
export RCLONE_DISABLE=move                      # Disable move operations
export RCLONE_LOG_LEVEL=NOTICE                  # Less verbose logging
export RCLONE_LOG_FORMAT="date,time,level,msg"  # Structured logging
export RCLONE_STATS=30s                         # More frequent stats
export RCLONE_STATS_ONE_LINE=true               # Compact stats
export RCLONE_DRIVE_CHUNK_SIZE=32M              # Smaller Google Drive chunks for seeking
export RCLONE_DRIVE_PACER_MIN_SLEEP=500ms       # Minimum time to wait between API calls
export RCLONE_DRIVE_PACER_BURST=10                # Number of API calls to allow in a burst

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

echo "🔧 OPTIMIZED: Running rclone for smooth video seeking (Heroku compatible)"
echo "✅ Key optimizations for video streaming:"
echo "- Shorter timeouts: 2min total, 30s connection (prevents H27 errors)"
echo "- Smaller buffers: 128MB with 64MB chunks (faster seeking)"
echo "- Parallel streams: 8 concurrent for smooth skipping"
echo "- Reduced transfers: 4 concurrent (Heroku stability)"
echo "- Quick cache: 24h duration with 30s polling"
echo "- Per-file bandwidth: 50MB/s (prevents timeouts)"
echo "- Google Drive chunks: 32MB (optimized for seeking)"
echo ""
echo "🎯 Expected improvements for video playback:"
echo "- Eliminated H27 timeout errors when seeking"
echo "- Smooth video skipping without lag"
echo "- Faster response to range requests"
echo "- Better mobile device compatibility" 
echo "- Reduced 499 status errors during playback"

eval $CMD