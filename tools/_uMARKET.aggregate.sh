#!/bin/bash

# uMARKET Global Aggregator
# Aggregates market data from local and swarm sources to provide a complete marketplace view

set -e

# Configuration
OUTPUT_DIR="/tmp/flashmem/umarket_global"
LOG_FILE="/tmp/flashmem/umarket_aggregator.log"
MAX_AGE_HOURS=168  # 7 days
VERBOSE=false
LOCAL_ONLY=false
SWARM_ONLY=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Show help
show_help() {
    cat << 'HELP_EOF'
🛒 uMARKET Global Aggregator

USAGE:
    ./_uMARKET.aggregate.sh [OPTIONS]

OPTIONS:
    --output DIR     Output directory (default: /tmp/flashmem/umarket_global)
    --max-age HOURS  Maximum age of advertisements in hours (default: 168)
    --local-only     Only process local data
    --swarm-only     Only process swarm data
    --verbose        Enable verbose logging
    --help           Show this help message

DESCRIPTION:
    Aggregates market data from local UMAPs and swarm nodes to create
    a comprehensive global marketplace view.

EXAMPLES:
    ./_uMARKET.aggregate.sh                    # Process all data
    ./_uMARKET.aggregate.sh --local-only       # Only local data
    ./_uMARKET.aggregate.sh --max-age 24       # Only recent ads (24h)
    ./_uMARKET.aggregate.sh --verbose          # With detailed logging

HELP_EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --max-age)
            MAX_AGE_HOURS="$2"
            shift 2
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --swarm-only)
            SWARM_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR/ads"
mkdir -p "$OUTPUT_DIR/Images"
mkdir -p "$OUTPUT_DIR/public"

# Get current timestamp for age filtering
CURRENT_TIME=$(date +%s)
MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 3600))

log_message "🔍 Starting uMARKET global aggregation..."
log_message "📁 Output directory: $OUTPUT_DIR"
log_message "⏰ Max age: ${MAX_AGE_HOURS}h (${MAX_AGE_SECONDS}s)"

# Function to validate and copy advertisement
process_advertisement() {
    local source_file="$1"
    local source_type="$2"  # "local" or "swarm"
    
    # Validate JSON
    if ! jq . "$source_file" >/dev/null 2>&1; then
        log_message "⚠️  Invalid JSON: $source_file"
        return 1
    fi
    
    # Check age
    local created_at=$(jq -r '.created_at' "$source_file" 2>/dev/null)
    if [[ ! "$created_at" =~ ^[0-9]+$ ]]; then
        log_message "⚠️  Invalid created_at in: $source_file"
        return 1
    fi
    
    local age=$((CURRENT_TIME - created_at))
    if [[ $age -gt $MAX_AGE_SECONDS ]]; then
        log_message "⏰ Advertisement too old (${age}s): $source_file"
        return 1
    fi
    
    # Get advertisement ID
    local ad_id=$(jq -r '.id' "$source_file" 2>/dev/null)
    if [[ -z "$ad_id" || "$ad_id" == "null" ]]; then
        log_message "⚠️  Missing ID in: $source_file"
        return 1
    fi
    
    # Copy to output with source tracking
    local target_file="$OUTPUT_DIR/ads/${ad_id}.json"
    
    # Add source metadata to the advertisement
    local enhanced_ad=$(jq --arg source "$source_type" --arg source_file "$source_file" \
        '. + {"_source": $source, "_source_file": $source_file, "_aggregated_at": '"$CURRENT_TIME"'}' \
        "$source_file")
    
    echo "$enhanced_ad" > "$target_file"
    
    if [[ "$VERBOSE" == true ]]; then
        log_message "✅ Processed: $ad_id (${source_type})"
    fi
    
    return 0
}

# Function to copy associated images
copy_images() {
    local source_dir="$1"
    local target_dir="$2"
    
    if [[ ! -d "$source_dir" ]]; then
        return 0
    fi
    
    while IFS= read -r -d '' image; do
        local image_name=$(basename "$image")
        local target_image="$target_dir/$image_name"
        
        if [[ ! -f "$target_image" ]]; then
            cp "$image" "$target_image" 2>/dev/null || true
            if [[ "$VERBOSE" == true ]]; then
                log_message "📷 Copied image: $image_name"
            fi
        fi
    done < <(find "$source_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0 2>/dev/null)
}

# Process local data
if [[ "$SWARM_ONLY" != true ]]; then
    log_message "🏠 Processing local uMARKET data..."
    
    local_count=0
    while IFS= read -r -d '' json_file; do
        if process_advertisement "$json_file" "local"; then
            ((local_count++))
            
            # Copy associated images
            local umap_dir=$(dirname "$(dirname "$(dirname "$json_file")")")
            local images_dir="$umap_dir/APP/uMARKET/Images"
            copy_images "$images_dir" "$OUTPUT_DIR/Images"
        fi
    done < <(find ~/.zen/tmp/${IPFSNODEID:-$(hostname)}/UPLANET -path "*/APP/uMARKET/ads/*.json" -print0 2>/dev/null)
    
    log_message "✅ Processed $local_count local advertisements"
fi

# Process swarm data
if [[ "$LOCAL_ONLY" != true ]]; then
    log_message "🌐 Processing swarm uMARKET data..."
    
    swarm_count=0
    while IFS= read -r -d '' json_file; do
        if process_advertisement "$json_file" "swarm"; then
            ((swarm_count++))
            
            # Copy associated images
            local umap_dir=$(dirname "$(dirname "$(dirname "$json_file")")")
            local images_dir="$umap_dir/APP/uMARKET/Images"
            copy_images "$images_dir" "$OUTPUT_DIR/Images"
        fi
    done < <(find ~/.zen/tmp/swarm -path "*/UPLANET/*/*/*/APP/uMARKET/ads/*.json" -print0 2>/dev/null)
    
    log_message "✅ Processed $swarm_count swarm advertisements"
fi

# Generate statistics
total_ads=$(find "$OUTPUT_DIR/ads" -name "*.json" | wc -l)
total_images=$(find "$OUTPUT_DIR/Images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) | wc -l)

log_message "📊 Aggregation Statistics:"
log_message "   - Total advertisements: $total_ads"
log_message "   - Total images: $total_images"
log_message "   - Local advertisements: ${local_count:-0}"
log_message "   - Swarm advertisements: ${swarm_count:-0}"

# Generate market.json
if [[ $total_ads -gt 0 ]]; then
    log_message "🔄 Generating market.json..."
    
    echo '{"ads": [' > "$OUTPUT_DIR/public/market.json"
    
    first=true
    while IFS= read -r -d '' json_file; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >> "$OUTPUT_DIR/public/market.json"
        fi
        cat "$json_file" >> "$OUTPUT_DIR/public/market.json"
    done < <(find "$OUTPUT_DIR/ads" -name "*.json" -print0)
    
    echo "]}" >> "$OUTPUT_DIR/public/market.json"
    
    log_message "✅ market.json generated with $total_ads advertisements"
else
    log_message "⚠️  No advertisements found, creating empty market.json"
    echo '{"ads": []}' > "$OUTPUT_DIR/public/market.json"
fi

# Generate enhanced web interface
log_message "🌐 Generating enhanced web interface..."
cat > "$OUTPUT_DIR/_index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🛒 Global uMARKET - UPlanet Marketplace</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            min-height: 100vh;
        }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { font-size: 3em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.5); }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .stats { 
            display: flex; justify-content: space-around; margin-bottom: 30px;
            background: rgba(255,255,255,0.1); padding: 20px; border-radius: 15px;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
        }
        .stat-item { text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; color: #00aaff; }
        .stat-label { font-size: 0.9em; opacity: 0.8; }
        .filters {
            display: flex; gap: 15px; margin-bottom: 20px; flex-wrap: wrap;
        }
        .filter-btn {
            padding: 10px 20px; border: none; border-radius: 25px;
            background: rgba(255,255,255,0.1); color: #fff; cursor: pointer;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
            transition: all 0.3s ease;
        }
        .filter-btn:hover, .filter-btn.active {
            background: rgba(0,170,255,0.3); transform: translateY(-2px);
        }
        .search-bar {
            width: 100%; padding: 15px; font-size: 1.1em; border: none; border-radius: 25px;
            background: rgba(255,255,255,0.1); color: #fff; margin-bottom: 30px;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
        }
        .search-bar::placeholder { color: rgba(255,255,255,0.7); }
        .market-grid {
            display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 20px; margin-top: 20px;
        }
        .ad-card {
            background: rgba(255,255,255,0.1); border-radius: 15px; overflow: hidden;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease; cursor: pointer;
        }
        .ad-card:hover {
            transform: translateY(-5px); box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .ad-card .image-container {
            height: 200px; background-size: cover; background-position: center;
            position: relative;
        }
        .ad-card .source-badge {
            position: absolute; top: 10px; left: 10px;
            background: rgba(0,170,255,0.9); color: #fff;
            padding: 3px 8px; border-radius: 10px; font-size: 0.8em;
            font-weight: bold;
        }
        .ad-card .info {
            padding: 15px;
        }
        .ad-card .info h3 {
            margin: 0 0 10px 0;
            color: #00aaff;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .ad-card .info .description {
            font-size: 0.9em;
            height: 40px;
            overflow: hidden;
            text-overflow: ellipsis;
            color: #aaa;
        }
        .ad-card .author {
            font-size: 0.8em;
            color: #777;
            padding: 10px 15px;
            border-top: 1px solid #333;
            margin-top: 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .author-avatar {
            width: 24px;
            height: 24px;
            border-radius: 50%;
            background: #555;
            margin-right: 10px;
        }
        .location-info {
            font-size: 0.7em;
            color: #666;
        }
        /* Modal */
        .modal {
            display: none; position: fixed; z-index: 1000; left: 0; top: 0;
            width: 100%; height: 100%; overflow: auto; background-color: rgba(0,0,0,0.9);
        }
        .modal-content {
            background-color: #1e1e1e; margin: 5% auto; padding: 0;
            border: 1px solid #555; width: 80%; max-width: 800px; border-radius: 15px;
            display: flex; flex-direction: column;
        }
        .modal-images { height: 400px; background-size: contain; background-position: center; background-repeat: no-repeat; background-color: #000; border-radius: 15px 15px 0 0; }
        .modal-info { padding: 20px; }
        .modal-info h2 { color: #00aaff; }
        .modal-info .author { font-size: 1em; color: #888; margin-top: 1rem; }
        .close { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛒 Global uMARKET</h1>
            <p>Complete UPlanet marketplace - Local and Swarm data</p>
        </div>
        
        <div class="stats" id="stats">
            <div class="stat-item">
                <div class="stat-number" id="total-ads">0</div>
                <div class="stat-label">Total Ads</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="local-ads">0</div>
                <div class="stat-label">Local</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="swarm-ads">0</div>
                <div class="stat-label">Swarm</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="total-images">0</div>
                <div class="stat-label">Images</div>
            </div>
        </div>
        
        <div class="filters">
            <button class="filter-btn active" data-filter="all">All Sources</button>
            <button class="filter-btn" data-filter="local">Local Only</button>
            <button class="filter-btn" data-filter="swarm">Swarm Only</button>
        </div>
        
        <input type="text" id="search-input" class="search-bar" placeholder="Search for products, services, or sellers...">
        <div id="market-grid" class="market-grid"></div>
    </div>

    <div id="adModal" class="modal">
      <div class="modal-content">
        <span class="close">&times;</span>
        <div id="modal-images" class="modal-images"></div>
        <div id="modal-info" class="modal-info">
          <h2 id="modal-title"></h2>
          <p id="modal-description"></p>
          <div id="modal-author" class="author"></div>
        </div>
      </div>
    </div>

    <script>
        $(document).ready(function() {
            let allAds = [];
            let currentFilter = 'all';

            function updateStats() {
                const total = allAds.length;
                const local = allAds.filter(ad => ad._source === 'local').length;
                const swarm = allAds.filter(ad => ad._source === 'swarm').length;
                const images = allAds.reduce((sum, ad) => sum + (ad.local_images ? ad.local_images.length : 0), 0);
                
                $('#total-ads').text(total);
                $('#local-ads').text(local);
                $('#swarm-ads').text(swarm);
                $('#total-images').text(images);
            }

            function renderAds(ads) {
                const grid = $('#market-grid');
                grid.empty();
                
                if (ads.length === 0) {
                    grid.html('<p style="text-align: center; grid-column: 1/-1; padding: 40px;">No ads found matching your criteria.</p>');
                    return;
                }
                
                ads.forEach(ad => {
                    const firstImage = ad.local_images && ad.local_images.length > 0 ? '../Images/' + ad.local_images[0] : 'https://via.placeholder.com/300x200';
                    const titleMatch = ad.content.match(/^.*?(?=\n|#)/);
                    const title = titleMatch ? titleMatch[0].trim() : "Ad";
                    const sourceBadge = ad._source === 'local' ? '🏠 Local' : '🌐 Swarm';

                    const card = `
                        <div class="ad-card" data-id="${ad.id}" data-source="${ad._source}">
                            <div class="image-container" style="background-image: url('${firstImage}')">
                                <div class="source-badge">${sourceBadge}</div>
                            </div>
                            <div class="info">
                                <h3>${title}</h3>
                                <div class="description">${ad.content.replace(/\n/g, '<br>')}</div>
                            </div>
                            <div class="author">
                                <div>
                                    <img class="author-avatar" src="https://robohash.org/${ad.author_pubkey}?set=set4" alt="avatar">
                                    <span>${ad.author_nprofile ? ad.author_nprofile.substring(0,20) : ad.author_pubkey.substring(0,20)}...</span>
                                </div>
                                <div class="location-info">
                                    📍 ${ad.location.lat.toFixed(4)}, ${ad.location.lon.toFixed(4)}
                                </div>
                            </div>
                        </div>
                    `;
                    grid.append(card);
                });
            }

            function filterAds() {
                let filteredAds = allAds;
                
                if (currentFilter === 'local') {
                    filteredAds = allAds.filter(ad => ad._source === 'local');
                } else if (currentFilter === 'swarm') {
                    filteredAds = allAds.filter(ad => ad._source === 'swarm');
                }
                
                renderAds(filteredAds);
            }

            $.getJSON('./public/market.json', function(data) {
                allAds = data.ads.sort((a,b) => b.created_at - a.created_at);
                updateStats();
                renderAds(allAds);
            }).fail(function() {
                $('#market-grid').html('<p style="color:red; text-align: center; grid-column: 1/-1;">Error: Could not load market.json.</p>');
            });

            $('#search-input').on('input', function() {
                const searchTerm = $(this).val().toLowerCase();
                let filteredAds = allAds.filter(ad =>
                    ad.content.toLowerCase().includes(searchTerm) ||
                    (ad.author_nprofile && ad.author_nprofile.toLowerCase().includes(searchTerm))
                );
                
                if (currentFilter === 'local') {
                    filteredAds = filteredAds.filter(ad => ad._source === 'local');
                } else if (currentFilter === 'swarm') {
                    filteredAds = filteredAds.filter(ad => ad._source === 'swarm');
                }
                
                renderAds(filteredAds);
            });
            
            $('.filter-btn').click(function() {
                $('.filter-btn').removeClass('active');
                $(this).addClass('active');
                currentFilter = $(this).data('filter');
                filterAds();
            });
            
            // Modal logic
            const modal = $("#adModal");
            $(document).on('click', '.ad-card', function() {
                const adId = $(this).data('id');
                const ad = allAds.find(a => a.id === adId);
                if(ad) {
                    const firstImage = ad.local_images && ad.local_images.length > 0 ? '../Images/' + ad.local_images[0] : 'https://via.placeholder.com/300x200';
                    const titleMatch = ad.content.match(/^.*?(?=\n|#)/);
                    const title = titleMatch ? titleMatch[0].trim() : "Ad";
                    const sourceBadge = ad._source === 'local' ? '🏠 Local' : '🌐 Swarm';

                    $('#modal-title').text(title);
                    $('#modal-description').html(ad.content.replace(/\n/g, '<br>'));
                    $('#modal-author').html(`
                        <div>
                            <img class="author-avatar" src="https://robohash.org/${ad.author_pubkey}?set=set4" alt="avatar">
                            <span>${ad.author_nprofile || ad.author_pubkey}</span>
                        </div>
                        <div class="location-info">
                            📍 ${ad.location.lat.toFixed(4)}, ${ad.location.lon.toFixed(4)} | ${sourceBadge}
                        </div>
                    `);
                    $('#modal-images').css('background-image', `url('${firstImage}')`);
                    modal.show();
                }
            });
            $('.close').click(() => modal.hide());
            $(window).click(event => {
                if (event.target == modal[0]) {
                    modal.hide();
                }
            });
        });
    </script>
</body>
</html>
HTML_EOF

# Create redirect index.html
cat > "$OUTPUT_DIR/index.html" << REDIRECT_EOF
<!DOCTYPE html>
<html>
<head>
    <title>Redirecting to Global uMARKET</title>
    <meta http-equiv="refresh" content="0; url=./_index.html" />
</head>
<body>
    <p>If you are not redirected, <a href="./_index.html">click here</a>.</p>
</body>
</html>
REDIRECT_EOF

# Generate IPFS CID
log_message "🔗 Publishing to IPFS..."
FINAL_CID=$(ipfs add -r "$OUTPUT_DIR" | tail -n1 | awk '{print $2}')

if [[ -n "$FINAL_CID" ]]; then
    log_message "✅ Global uMARKET published to IPFS: $FINAL_CID"
    echo "$FINAL_CID"
else
    log_message "❌ Failed to publish to IPFS"
    exit 1
fi

log_message "🎉 Global uMARKET aggregation completed successfully!"
log_message "🌐 Access: http://127.0.0.1:8080/ipfs/$FINAL_CID/" 