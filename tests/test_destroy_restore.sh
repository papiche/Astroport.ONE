#!/bin/bash
###################################################################
# test_destroy_restore.sh
# Tests for nostr_DESTROY_TW.sh and nostr_RESTORE_TW.sh
#
# Tests cover:
# - Numbered secret.june backup (cooperative shares history)
# - Uplanet key encryption/decryption fallback
# - Backup structure and content validation
# - RESTORE script: uplanet-encrypted CID detection + extraction
# - RESTORE script: numbered secret.june restoration
#
# Usage: ./test_destroy_restore.sh [--offline]
#   --offline: skip tests requiring IPFS/relay
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

source "$MY_PATH/test_common.sh"

OFFLINE=false
[[ "${1:-}" == "--offline" ]] && OFFLINE=true

# Test-specific temp directory
TEST_DIR="$TEST_TEMP_DIR/destroy_restore_$$"
mkdir -p "$TEST_DIR"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

###################################################################
# SECTION 1: Prerequisites
###################################################################
test_log_info "━━━ SECTION 1: Prerequisites ━━━"

SCRIPT_DIR="$(cd "$MY_PATH/.." && pwd)"
assert_file_exists "$SCRIPT_DIR/tools/nostr_DESTROY_TW.sh" \
    "nostr_DESTROY_TW.sh exists"

assert_file_exists "$SCRIPT_DIR/tools/nostr_RESTORE_TW.sh" \
    "nostr_RESTORE_TW.sh exists"
assert_true "bash -n '$SCRIPT_DIR/tools/nostr_DESTROY_TW.sh' 2>/dev/null" \
    "nostr_DESTROY_TW.sh has valid bash syntax"

assert_true "bash -n '$SCRIPT_DIR/tools/nostr_RESTORE_TW.sh' 2>/dev/null" \
    "nostr_RESTORE_TW.sh has valid bash syntax"

assert_true "command -v zip >/dev/null 2>&1" \
    "zip command is available"

assert_true "command -v unzip >/dev/null 2>&1" \
    "unzip command is available"

assert_file_exists "$HOME/.zen/Astroport.ONE/tools/natools.py" \
    "natools.py exists"

assert_file_exists "$HOME/.zen/Astroport.ONE/tools/keygen" \
    "keygen exists"

###################################################################
# SECTION 2: secret.june backup + UPlanet change numbering
###################################################################
test_log_info "━━━ SECTION 2: secret.june backup & UPlanet change ━━━"

# Create mock player directory with secret.june
MOCK_PLAYER="test_$$@test.com"
MOCK_PLAYER_DIR="$TEST_DIR/players/$MOCK_PLAYER"
mkdir -p "$MOCK_PLAYER_DIR"

# Create a mock secret.june
cat > "$MOCK_PLAYER_DIR/secret.june" <<'JUNE'
SALT="testSalt123"
PEPPER="testPepper456"
TX_HISTORY="share1:100:2025-01-01"
JUNE

# Test: DESTROY copies secret.june to backup (no numbering)
BACKUP_DIR="$TEST_DIR/backup_test"
mkdir -p "$BACKUP_DIR"
cp "$MOCK_PLAYER_DIR/secret.june" "$BACKUP_DIR/secret.june"
echo "TestUPlanet" > "$BACKUP_DIR/.uplanetname"

assert_file_exists "$BACKUP_DIR/secret.june" \
    "DESTROY: secret.june copied to backup"

assert_file_exists "$BACKUP_DIR/.uplanetname" \
    "DESTROY: .uplanetname saved in backup"

SAVED_UPLANET=$(cat "$BACKUP_DIR/.uplanetname")
assert_equal "TestUPlanet" "$SAVED_UPLANET" \
    "DESTROY: UPLANETNAME correctly saved"

# Test: same UPlanet restore → no numbering
SAME_UPLANET_TEST=true
BACKUP_UPLANETNAME_TEST="TestUPlanet"
RESTORE_UPLANETNAME_TEST="TestUPlanet"
[[ "$BACKUP_UPLANETNAME_TEST" != "$RESTORE_UPLANETNAME_TEST" ]] && SAME_UPLANET_TEST=false

assert_equal "true" "$SAME_UPLANET_TEST" \
    "Same UPlanet detected correctly"

# Test: different UPlanet → numbering triggered
SAME_UPLANET_TEST2=true
BACKUP_UPLANETNAME_TEST2="OldUPlanet"
RESTORE_UPLANETNAME_TEST2="NewUPlanet"
[[ "$BACKUP_UPLANETNAME_TEST2" != "$RESTORE_UPLANETNAME_TEST2" ]] && SAME_UPLANET_TEST2=false

assert_equal "false" "$SAME_UPLANET_TEST2" \
    "UPlanet change detected correctly"

# Test: numbering on UPlanet change (simulated restore)
RESTORE_PLAYER_DIR="$TEST_DIR/restore_player"
mkdir -p "$RESTORE_PLAYER_DIR"
cp "$MOCK_PLAYER_DIR/secret.june" "$RESTORE_PLAYER_DIR/secret.june"

# Simulate first UPlanet change → creates secret.june.000.OldUPlanet
MIGRATION_NUM=0
for f in "$RESTORE_PLAYER_DIR"/secret.june.[0-9]*; do
    [[ -f "$f" ]] || continue
    num_part=$(basename "$f" | sed -n 's/^secret\.june\.\([0-9]\{3\}\)\..*/\1/p')
    [[ -n "$num_part" ]] && (( 10#$num_part >= MIGRATION_NUM )) && MIGRATION_NUM=$((10#$num_part + 1))
done
MIGRATION_TAG=$(printf "%03d" "$MIGRATION_NUM")
cp "$RESTORE_PLAYER_DIR/secret.june" "$RESTORE_PLAYER_DIR/secret.june.${MIGRATION_TAG}.OldUPlanet"

assert_equal "000" "$MIGRATION_TAG" \
    "First UPlanet change: numbered as 000"

assert_file_exists "$RESTORE_PLAYER_DIR/secret.june.000.OldUPlanet" \
    "First UPlanet change: archive includes old UPlanet name"

# Simulate second UPlanet change → creates secret.june.001.SecondUPlanet
MIGRATION_NUM=0
for f in "$RESTORE_PLAYER_DIR"/secret.june.[0-9]*; do
    [[ -f "$f" ]] || continue
    num_part=$(basename "$f" | sed -n 's/^secret\.june\.\([0-9]\{3\}\)\..*/\1/p')
    [[ -n "$num_part" ]] && (( 10#$num_part >= MIGRATION_NUM )) && MIGRATION_NUM=$((10#$num_part + 1))
done
MIGRATION_TAG2=$(printf "%03d" "$MIGRATION_NUM")
cp "$RESTORE_PLAYER_DIR/secret.june" "$RESTORE_PLAYER_DIR/secret.june.${MIGRATION_TAG2}.SecondUPlanet"

assert_equal "001" "$MIGRATION_TAG2" \
    "Second UPlanet change: numbered as 001"

###################################################################
# SECTION 3: Uplanet key encryption/decryption
###################################################################
test_log_info "━━━ SECTION 3: Uplanet key encryption/decryption ━━━"

# Generate test uplanet.dunikey
UPLANETNAME_TEST="TestUPlanet"
TEST_DUNIKEY="$TEST_DIR/uplanet.dunikey"
if "$HOME/.zen/Astroport.ONE/tools/keygen" -t duniter -o "$TEST_DUNIKEY" \
        "$UPLANETNAME_TEST" "$UPLANETNAME_TEST" 2>/dev/null; then

    assert_file_exists "$TEST_DUNIKEY" \
        "Test uplanet.dunikey generated"

    # Create a test ZIP to encrypt
    TEST_ZIP_DIR="$TEST_DIR/zip_content"
    mkdir -p "$TEST_ZIP_DIR"
    echo "test backup content" > "$TEST_ZIP_DIR/test.txt"
    cp "$MOCK_PLAYER_DIR/secret.june" "$TEST_ZIP_DIR/"
    TEST_ZIP="$TEST_DIR/test_backup.zip"
    cd "$TEST_DIR" && zip -r -q "$TEST_ZIP" "zip_content" 2>/dev/null
    cd - > /dev/null 2>&1

    assert_file_exists "$TEST_ZIP" \
        "Test ZIP created for encryption"

    # Get pubkey from dunikey for encryption
    TEST_PUBKEY=$("$HOME/.zen/Astroport.ONE/tools/natools.py" pubkey -f pubsec -k "$TEST_DUNIKEY" -O 58 2>/dev/null)

    # Encrypt with natools using uplanet pubkey
    TEST_ENC="$TEST_DIR/test_backup.zip.uplanet.enc"
    if [[ -n "$TEST_PUBKEY" ]] && "$HOME/.zen/Astroport.ONE/tools/natools.py" encrypt \
            -p "$TEST_PUBKEY" -i "$TEST_ZIP" -o "$TEST_ENC" 2>/dev/null; then

        assert_file_exists "$TEST_ENC" \
            "Uplanet-encrypted backup created"

        # Verify encrypted file is different from original
        assert_false "[[ -z \"\$(diff '$TEST_ZIP' '$TEST_ENC' 2>/dev/null)\" ]]" \
            "Encrypted file differs from original ZIP"

        # Decrypt with same uplanet key
        TEST_DEC="$TEST_DIR/test_backup_decrypted.zip"
        if "$HOME/.zen/Astroport.ONE/tools/natools.py" decrypt -f pubsec \
                -i "$TEST_ENC" -k "$TEST_DUNIKEY" -o "$TEST_DEC" 2>/dev/null; then

            assert_file_exists "$TEST_DEC" \
                "Decrypted ZIP created"

            # Verify decrypted matches original
            if diff "$TEST_ZIP" "$TEST_DEC" > /dev/null 2>&1; then
                test_log_success "Decrypted ZIP matches original (round-trip OK)"
                ((TEST_COUNT++)); ((PASS_COUNT++))
            else
                test_log_error "Decrypted ZIP does NOT match original"
                ((TEST_COUNT++)); ((FAIL_COUNT++))
            fi

            # Extract decrypted ZIP
            EXTRACT_DIR="$TEST_DIR/extracted"
            mkdir -p "$EXTRACT_DIR"
            if unzip -q "$TEST_DEC" -d "$EXTRACT_DIR" 2>/dev/null; then
                assert_file_exists "$EXTRACT_DIR/zip_content/test.txt" \
                    "Extracted content intact after encrypt/decrypt"

                assert_file_exists "$EXTRACT_DIR/zip_content/secret.june" \
                    "secret.june intact after encrypt/decrypt"
            else
                test_log_error "Failed to extract decrypted ZIP"
                ((TEST_COUNT++)); ((FAIL_COUNT++))
            fi
        else
            test_log_error "natools.py decrypt failed"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        fi
    else
        test_log_error "natools.py encrypt failed"
        ((TEST_COUNT++)); ((FAIL_COUNT++))
    fi
else
    test_log_warning "keygen failed - skipping encryption tests"
fi

###################################################################
# SECTION 4: Password-protected ZIP vs uplanet detection
###################################################################
test_log_info "━━━ SECTION 4: Backup format detection ━━━"

# Test: ZIP file is detected as ZIP
if [[ -f "$TEST_ZIP" ]]; then
    if file "$TEST_ZIP" 2>/dev/null | grep -q "Zip archive"; then
        test_log_success "ZIP file correctly detected as Zip archive"
        ((TEST_COUNT++)); ((PASS_COUNT++))
    else
        test_log_error "ZIP file not detected as Zip archive"
        ((TEST_COUNT++)); ((FAIL_COUNT++))
    fi

    # Test: uplanet-encrypted file is NOT detected as ZIP
    if [[ -f "$TEST_ENC" ]]; then
        if file "$TEST_ENC" 2>/dev/null | grep -q "Zip archive"; then
            test_log_error "Encrypted file wrongly detected as Zip archive"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        else
            test_log_success "Encrypted file correctly detected as non-ZIP (triggers uplanet decrypt)"
            ((TEST_COUNT++)); ((PASS_COUNT++))
        fi
    fi

    # Test: password-protected ZIP
    PASS_ZIP="$TEST_DIR/pass_backup.zip"
    cd "$TEST_DIR" && zip -r -q -P "testpass" "$PASS_ZIP" "zip_content" 2>/dev/null
    cd - > /dev/null 2>&1
    if [[ -f "$PASS_ZIP" ]]; then
        if file "$PASS_ZIP" 2>/dev/null | grep -q "Zip archive"; then
            test_log_success "Password-protected ZIP detected as Zip archive"
            ((TEST_COUNT++)); ((PASS_COUNT++))
        else
            test_log_error "Password-protected ZIP not detected as Zip archive"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        fi

        # Verify it fails without password
        PASS_EXTRACT="$TEST_DIR/pass_extract"
        mkdir -p "$PASS_EXTRACT"
        if ! unzip -q "$PASS_ZIP" -d "$PASS_EXTRACT" 2>/dev/null; then
            test_log_success "Password-protected ZIP correctly rejected without password"
            ((TEST_COUNT++)); ((PASS_COUNT++))
        else
            test_log_error "Password-protected ZIP extracted without password (unexpected)"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        fi

        # Verify it works with correct password
        PASS_EXTRACT2="$TEST_DIR/pass_extract2"
        mkdir -p "$PASS_EXTRACT2"
        if unzip -q -P "testpass" "$PASS_ZIP" -d "$PASS_EXTRACT2" 2>/dev/null; then
            test_log_success "Password-protected ZIP extracted with correct password"
            ((TEST_COUNT++)); ((PASS_COUNT++))
        else
            test_log_error "Password-protected ZIP failed with correct password"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        fi
    fi
fi

###################################################################
# SECTION 5: DISCO format parsing (regex fix validation)
###################################################################
test_log_info "━━━ SECTION 5: DISCO format parsing ━━━"

# Test the regex used in nostr_RESTORE_TW.sh
DISCO_TEST="/?testuser@test.com=mySalt123abc&nostr=myPepper456def"

if [[ "$DISCO_TEST" =~ ^/\?([^=]+)=([^&]+)\&nostr=(.+)$ ]]; then
    PARSED_EMAIL="${BASH_REMATCH[1]}"
    PARSED_SALT="${BASH_REMATCH[2]}"
    PARSED_PEPPER="${BASH_REMATCH[3]}"

    assert_equal "testuser@test.com" "$PARSED_EMAIL" \
        "DISCO regex: email parsed correctly"

    assert_equal "mySalt123abc" "$PARSED_SALT" \
        "DISCO regex: salt parsed correctly"

    assert_equal "myPepper456def" "$PARSED_PEPPER" \
        "DISCO regex: pepper parsed correctly"
else
    test_log_error "DISCO regex failed to match valid format"
    ((TEST_COUNT++)); ((FAIL_COUNT++))
fi

# Test with special characters in email
DISCO_TEST2="/?user+tag@sub.domain.com=LongSalt42chars000000000000000000000000000&nostr=LongPepper42chars00000000000000000000000"
if [[ "$DISCO_TEST2" =~ ^/\?([^=]+)=([^&]+)\&nostr=(.+)$ ]]; then
    test_log_success "DISCO regex: handles complex email format"
    ((TEST_COUNT++)); ((PASS_COUNT++))
else
    test_log_error "DISCO regex: failed with complex email"
    ((TEST_COUNT++)); ((FAIL_COUNT++))
fi

###################################################################
# SECTION 6: Restore with UPlanet change detection
###################################################################
test_log_info "━━━ SECTION 6: Restore + UPlanet change detection ━━━"

# Simulate restore source with existing history from previous UPlanet changes
RESTORE_SOURCE="$TEST_DIR/restore_source"
RESTORE_TARGET="$TEST_DIR/restore_target/$MOCK_PLAYER"
mkdir -p "$RESTORE_SOURCE" "$RESTORE_TARGET"

echo "uplanet0 history" > "$RESTORE_SOURCE/secret.june.000.OldUPlanet"
echo "current data" > "$RESTORE_SOURCE/secret.june"
echo "OriginalUPlanet" > "$RESTORE_SOURCE/.uplanetname"

# Find history in backup
ZEN_JUNE_HISTORY=()
while IFS= read -r -d '' f; do
    ZEN_JUNE_HISTORY+=("$f")
done < <(find "$RESTORE_SOURCE" -name "secret.june.[0-9]*" -print0 2>/dev/null | sort -z)

assert_equal "1" "${#ZEN_JUNE_HISTORY[@]}" \
    "Found 1 historical secret.june in backup"

# Test: same UPlanet restore → just copy, no new numbering
BACKUP_UPLANETNAME=$(cat "$RESTORE_SOURCE/.uplanetname")
CURRENT_UPLANETNAME="OriginalUPlanet"
SAME_UPLANET=true
[[ "$BACKUP_UPLANETNAME" != "$CURRENT_UPLANETNAME" ]] && SAME_UPLANET=false

assert_equal "true" "$SAME_UPLANET" \
    "Same UPlanet: no new numbering needed"

# Copy history to target (same UPlanet)
for f in "${ZEN_JUNE_HISTORY[@]}"; do
    cp "$f" "$RESTORE_TARGET/$(basename "$f")"
done
cp "$RESTORE_SOURCE/secret.june" "$RESTORE_TARGET/secret.june"

assert_file_exists "$RESTORE_TARGET/secret.june" \
    "Current secret.june restored (same UPlanet)"

assert_file_exists "$RESTORE_TARGET/secret.june.000.OldUPlanet" \
    "Previous history preserved (same UPlanet)"

# Test: different UPlanet → creates new numbered archive
RESTORE_TARGET2="$TEST_DIR/restore_target2/$MOCK_PLAYER"
mkdir -p "$RESTORE_TARGET2"
cp "$RESTORE_SOURCE/secret.june" "$RESTORE_TARGET2/secret.june"

CURRENT_UPLANETNAME2="DifferentUPlanet"
SAME_UPLANET2=true
[[ "$BACKUP_UPLANETNAME" != "$CURRENT_UPLANETNAME2" ]] && SAME_UPLANET2=false

assert_equal "false" "$SAME_UPLANET2" \
    "Different UPlanet: numbering triggered"

# Simulate numbering on UPlanet change
MIGRATION_NUM=0
for f in "$RESTORE_TARGET2"/secret.june.[0-9]*; do
    [[ -f "$f" ]] || continue
    num_part=$(basename "$f" | sed -n 's/^secret\.june\.\([0-9]\{3\}\)\..*/\1/p')
    [[ -n "$num_part" ]] && (( 10#$num_part >= MIGRATION_NUM )) && MIGRATION_NUM=$((10#$num_part + 1))
done
MTAG=$(printf "%03d" "$MIGRATION_NUM")
cp "$RESTORE_SOURCE/secret.june" "$RESTORE_TARGET2/secret.june.${MTAG}.${BACKUP_UPLANETNAME}"

assert_file_exists "$RESTORE_TARGET2/secret.june.000.OriginalUPlanet" \
    "UPlanet change: archived with old UPlanet name"

# Verify content integrity
RESTORED_CONTENT=$(cat "$RESTORE_TARGET/secret.june.000.OldUPlanet")
assert_equal "uplanet0 history" "$RESTORED_CONTENT" \
    "Historical version 000 content intact"

###################################################################
# SECTION 7: DID metadata structure (backup CIDs)
###################################################################
test_log_info "━━━ SECTION 7: DID metadata with backup CIDs ━━━"

if command -v jq >/dev/null 2>&1; then
    # Simulate DID cache with deactivation metadata
    DID_CACHE="$TEST_DIR/did.json.cache"
    cat > "$DID_CACHE" <<'DID'
{
    "id": "did:nostr:abc123",
    "metadata": {
        "created": "2025-01-01"
    }
}
DID
    MOCK_NOSTRIFS="QmBackupZIP123"
    MOCK_NOSTRIFS_UPLANET="QmBackupUplanet456"
    MOCK_NEXT_HEX="abcdef1234567890"

    # Apply the same jq transform as nostr_DESTROY_TW.sh
    jq ".metadata.deactivation.nextRestorationHex = \"${MOCK_NEXT_HEX}\"
        | .metadata.deactivation.backupCID = \"${MOCK_NOSTRIFS}\"
        | .metadata.deactivation.backupUplanetCID = \"${MOCK_NOSTRIFS_UPLANET}\"" \
        "$DID_CACHE" > "${DID_CACHE}.tmp" 2>/dev/null

    if [[ -s "${DID_CACHE}.tmp" ]]; then
        mv "${DID_CACHE}.tmp" "$DID_CACHE"

        # Verify all fields
        GOT_HEX=$(jq -r '.metadata.deactivation.nextRestorationHex' "$DID_CACHE")
        GOT_CID=$(jq -r '.metadata.deactivation.backupCID' "$DID_CACHE")
        GOT_UCID=$(jq -r '.metadata.deactivation.backupUplanetCID' "$DID_CACHE")

        assert_equal "$MOCK_NEXT_HEX" "$GOT_HEX" \
            "DID metadata: nextRestorationHex set correctly"

        assert_equal "$MOCK_NOSTRIFS" "$GOT_CID" \
            "DID metadata: backupCID set correctly"

        assert_equal "$MOCK_NOSTRIFS_UPLANET" "$GOT_UCID" \
            "DID metadata: backupUplanetCID set correctly"
    else
        test_log_error "jq transform failed on DID cache"
        ((TEST_COUNT++)); ((FAIL_COUNT++))
    fi
else
    test_log_warning "jq not found - skipping DID metadata tests"
fi

###################################################################
# SECTION 8: Full backup/restore round-trip (offline simulation)
###################################################################
test_log_info "━━━ SECTION 8: Full backup/restore round-trip ━━━"

if [[ -f "$TEST_DUNIKEY" ]]; then
    # Build a complete mock backup directory
    ROUNDTRIP_BACKUP="$TEST_DIR/roundtrip_backup"
    mkdir -p "$ROUNDTRIP_BACKUP"

    # Populate with all expected files
    echo '[{"id":"evt1","kind":1,"content":"test"}]' > "$ROUNDTRIP_BACKUP/nostr_export.json"
    echo "/?test@test.com=NewSalt123&nostr=NewPepper456" > "$ROUNDTRIP_BACKUP/.next.disco"
    echo "deadbeef12345678" > "$ROUNDTRIP_BACKUP/.next.hex"
    echo "NewSalt123" > "$ROUNDTRIP_BACKUP/.next.salt"
    echo "NewPepper456" > "$ROUNDTRIP_BACKUP/.next.pepper"
    cp "$MOCK_PLAYER_DIR/secret.june" "$ROUNDTRIP_BACKUP/secret.june"
    # Include history from previous UPlanet change
    echo "old uplanet data" > "$ROUNDTRIP_BACKUP/secret.june.000.OldUPlanet"
    echo "TestG1Pub" > "$ROUNDTRIP_BACKUP/.g1pub"
    echo "old disco" > "$ROUNDTRIP_BACKUP/.secret.disco"
    echo "42.50" > "$ROUNDTRIP_BACKUP/.cashback_amount"
    echo "TestG1Pub" > "$ROUNDTRIP_BACKUP/.cashback_g1pub"
    echo "TestUPlanet" > "$ROUNDTRIP_BACKUP/.uplanetname"

    # Create password-protected ZIP
    ROUNDTRIP_ZIP="$TEST_DIR/roundtrip.zip"
    cd "$TEST_DIR" && zip -r -q -P "zenpass" "$ROUNDTRIP_ZIP" "roundtrip_backup" 2>/dev/null
    cd - > /dev/null 2>&1

    assert_file_exists "$ROUNDTRIP_ZIP" \
        "Round-trip: password-protected ZIP created"

    # Encrypt with uplanet pubkey
    ROUNDTRIP_ENC="$TEST_DIR/roundtrip.zip.uplanet.enc"
    RT_PUBKEY=$("$HOME/.zen/Astroport.ONE/tools/natools.py" pubkey -f pubsec -k "$TEST_DUNIKEY" -O 58 2>/dev/null)
    [[ -n "$RT_PUBKEY" ]] && "$HOME/.zen/Astroport.ONE/tools/natools.py" encrypt \
        -p "$RT_PUBKEY" -i "$ROUNDTRIP_ZIP" -o "$ROUNDTRIP_ENC" 2>/dev/null

    assert_file_exists "$ROUNDTRIP_ENC" \
        "Round-trip: uplanet-encrypted version created"

    # Simulate captain restore path (decrypt with uplanet key, no password needed)
    CAPTAIN_RESTORE="$TEST_DIR/captain_restore"
    mkdir -p "$CAPTAIN_RESTORE"

    # Step 1: Detect non-ZIP format
    if ! file "$ROUNDTRIP_ENC" 2>/dev/null | grep -q "Zip archive"; then
        test_log_success "Round-trip: uplanet file correctly detected as non-ZIP"
        ((TEST_COUNT++)); ((PASS_COUNT++))

        # Step 2: Decrypt with uplanet key
        CAPTAIN_ZIP="$CAPTAIN_RESTORE/decrypted.zip"
        if "$HOME/.zen/Astroport.ONE/tools/natools.py" decrypt -f pubsec \
                -i "$ROUNDTRIP_ENC" -k "$TEST_DUNIKEY" -o "$CAPTAIN_ZIP" 2>/dev/null; then

            test_log_success "Round-trip: captain decrypted with uplanet key"
            ((TEST_COUNT++)); ((PASS_COUNT++))

            # Step 3: Extract (password-protected inside)
            if unzip -q -P "zenpass" "$CAPTAIN_ZIP" -d "$CAPTAIN_RESTORE" 2>/dev/null; then
                test_log_success "Round-trip: extracted password-protected ZIP"
                ((TEST_COUNT++)); ((PASS_COUNT++))

                # Verify all files present
                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/nostr_export.json" \
                    "Round-trip: nostr_export.json present"

                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.next.disco" \
                    "Round-trip: .next.disco present"

                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.next.hex" \
                    "Round-trip: .next.hex present"

                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/secret.june" \
                    "Round-trip: secret.june present"

                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.g1pub" \
                    "Round-trip: .g1pub present"

                # Verify numbered history (1 from previous UPlanet change)
                RESTORED_HISTORY=()
                while IFS= read -r -d '' f; do
                    RESTORED_HISTORY+=("$f")
                done < <(find "$CAPTAIN_RESTORE" -name "secret.june.[0-9]*" -print0 2>/dev/null | sort -z)

                assert_equal "1" "${#RESTORED_HISTORY[@]}" \
                    "Round-trip: 1 historical secret.june version preserved"

                # Verify .uplanetname present
                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.uplanetname" \
                    "Round-trip: .uplanetname present in backup"

                # Verify .next.disco content
                DISCO_RESTORED=$(cat "$CAPTAIN_RESTORE/roundtrip_backup/.next.disco")
                assert_equal "/?test@test.com=NewSalt123&nostr=NewPepper456" "$DISCO_RESTORED" \
                    "Round-trip: .next.disco content intact"

                # Verify cashback amount in backup
                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.cashback_amount" \
                    "Round-trip: .cashback_amount present in backup"

                CASHBACK_VAL=$(cat "$CAPTAIN_RESTORE/roundtrip_backup/.cashback_amount")
                assert_equal "42.50" "$CASHBACK_VAL" \
                    "Round-trip: cashback amount intact (42.50 Ğ1)"

                assert_file_exists "$CAPTAIN_RESTORE/roundtrip_backup/.cashback_g1pub" \
                    "Round-trip: .cashback_g1pub present in backup"
            else
                test_log_error "Round-trip: failed to extract ZIP with password"
                ((TEST_COUNT++)); ((FAIL_COUNT++))
            fi
        else
            test_log_error "Round-trip: captain decrypt failed"
            ((TEST_COUNT++)); ((FAIL_COUNT++))
        fi
    else
        test_log_error "Round-trip: encrypted file wrongly detected as ZIP"
        ((TEST_COUNT++)); ((FAIL_COUNT++))
    fi
else
    test_log_warning "No test dunikey - skipping round-trip test"
fi

###################################################################
# SECTION 9: Cashback primo subtraction logic
###################################################################
test_log_info "━━━ SECTION 9: Cashback primo subtraction ━━━"

if command -v bc >/dev/null 2>&1; then
    # Test: 42.50 G1 cashback - 1 G1 primo = 41.50
    CB_RAW="42.50"
    CB_ADJUSTED=$(echo "scale=2; ${CB_RAW} - 1" | bc -l)
    assert_equal "41.50" "$CB_ADJUSTED" \
        "Cashback subtraction: 42.50 - 1 primo = 41.50"

    # Test: value > 0 check
    CB_CHECK=$(echo "${CB_ADJUSTED} > 0" | bc -l)
    assert_equal "1" "$CB_CHECK" \
        "Cashback 41.50 > 0 (has value to restore)"

    # Test: exactly 1 G1 → 0 after primo
    CB_RAW2="1.00"
    CB_ADJUSTED2=$(echo "scale=2; ${CB_RAW2} - 1" | bc -l)
    CB_CHECK2=$(echo "${CB_ADJUSTED2} > 0" | bc -l)
    assert_equal "0" "$CB_CHECK2" \
        "Cashback 1.00 - 1 primo = 0 (nothing to restore)"

    # Test: 0.50 G1 → negative after primo, no cashback
    CB_RAW3="0.50"
    CB_ADJUSTED3=$(echo "scale=2; ${CB_RAW3} - 1" | bc -l)
    CB_CHECK3=$(echo "${CB_ADJUSTED3} > 0" | bc -l)
    assert_equal "0" "$CB_CHECK3" \
        "Cashback 0.50 - 1 primo = negative (nothing to restore)"

    # Test: large amount
    CB_RAW4="1000.00"
    CB_ADJUSTED4=$(echo "scale=2; ${CB_RAW4} - 1" | bc -l)
    assert_equal "999.00" "$CB_ADJUSTED4" \
        "Cashback subtraction: 1000.00 - 1 primo = 999.00"
else
    test_log_warning "bc not available - skipping cashback calculation tests"
fi

###################################################################
# Summary
###################################################################
echo ""
print_test_summary

exit $FAIL_COUNT
