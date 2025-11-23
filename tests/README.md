# UPlanet Systems Test Suite

Comprehensive test suite for validating all UPlanet systems according to their specifications.

**🎮 Captain Validation Test**: The `test_captain_validation.sh` script creates REAL data and allows the captain to validate the complete UPlanet game loop.

## Overview

This test suite validates:
- **DID System**: Decentralized Identifier implementation and W3C compliance
- **Oracle System**: Official permits and multi-signature validation
- **WoTx2 System**: Auto-proclaimed masteries with automatic progression
- **ORE System**: Environmental contracts and UMAP DIDs
- **Badge System**: NIP-58 badge definitions, awards, and profile badges

## Prerequisites

Before running tests, ensure:
1. **Environment variables** are set:
   - `CAPTAINEMAIL`: Captain's email address
   - `UPLANETNAME_G1`: UPlanet G1 authority key
   - `IPFSNODEID`: IPFS node identifier
   - `UPLANETNAME`: UPlanet name

2. **Required files** exist:
   - `~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr`: Captain's NOSTR keys
   - `~/.zen/game/uplanet.G1.nostr`: UPLANETNAME_G1 keys
   - Nostr relay accessible at `$myRELAY`

3. **Services** are running:
   - Nostr relay (strfry)
   - IPFS node
   - Oracle system API (if testing permit creation)

## Usage

### Run All Tests

```bash
cd ~/.zen/Astroport.ONE/tests
./test_all_systems.sh
```

### Run Specific System Tests

```bash
# Test DID system only
./test_all_systems.sh --system did

# Test Oracle system only
./test_all_systems.sh --system oracle

# Test WoTx2 system only
./test_all_systems.sh --system wotx2

# Test ORE system only
./test_all_systems.sh --system ore

# Test Badge system only
./test_all_systems.sh --system badge

# Captain Validation Test (creates real data)
./test_captain_validation.sh
./test_captain_validation.sh --cleanup  # Clean up after test
```

### Verbose Output

```bash
./test_all_systems.sh --verbose
```

### Run Individual Test Scripts

```bash
# DID System
./test_did_system.sh

# Oracle System
./test_oracle_system.sh

# WoTx2 System
./test_wotx2_system.sh

# ORE System
./test_ore_system.sh

# Badge System
./test_badge_system.sh
```

## Test Configuration

### Captain as WoTx2 User

Tests use the captain's keys (`~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr`) for:
- WoTx2 permit requests (PERMIT_DRAGON)
- Permit attestations
- Profile badge selection

### UMAP 0.00 0.00 for ORE

Tests use UMAP coordinates `0.00, 0.00` for:
- ORE contract activation
- UMAP DID creation
- Environmental obligation testing

### UPLANETNAME_G1 for Oracle

Tests use `UPLANETNAME_G1` keys for:
- Official permit definitions
- Credential issuance
- Badge emission

### IPFSNODEID Filtering

Tests verify that events are properly tagged with `ipfs_node` tag containing `IPFSNODEID` to ensure proper filtering in constellation environments.

## Test Structure

Each test script follows this structure:

1. **Prerequisites Check**: Verify required files and environment
2. **Functional Tests**: Test core functionality
3. **Integration Tests**: Test system integration
4. **Compliance Tests**: Verify specification compliance
5. **Summary**: Print test results

## Test Results

Test results are stored in:
```
~/.zen/tmp/tests/
```

Each test run creates timestamped log files:
- `{system}_{timestamp}.log`: Detailed test output

## Expected Test Outcomes

### Passing Tests
- ✅ Green checkmark indicates successful test
- All assertions pass
- Exit code: 0

### Warning Tests
- ⚠️ Yellow warning indicates optional/expected behavior
- Test may pass but indicates missing data (e.g., no events published yet)
- Does not fail the test suite

### Failing Tests
- ❌ Red X indicates failed test
- Assertion failed or error occurred
- Exit code: 1

## Common Issues

### "CAPTAINEMAIL not set"
**Solution**: Source `~/.zen/Astroport.ONE/tools/my.sh` or set environment variables manually.

### "Captain's secret file not found"
**Solution**: Ensure captain's MULTIPASS is created via `make_NOSTRCARD.sh`.

### "UPLANETNAME_G1 keyfile not found"
**Solution**: Run `UPLANET.init.sh` to initialize UPlanet wallets and keys.

### "No events found on Nostr relay"
**Solution**: This is expected if systems haven't been used yet. Tests will show warnings but not fail.

### "strfry not available"
**Solution**: Ensure strfry relay is running and accessible at `$myRELAY`.

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```bash
#!/bin/bash
# CI test script
cd ~/.zen/Astroport.ONE/tests
./test_all_systems.sh --verbose > test_results.log 2>&1
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo "All tests passed"
else
    echo "Some tests failed"
    cat test_results.log
fi

exit $exit_code
```

## Captain Validation Test

The **Captain Validation Test** (`test_captain_validation.sh`) is a comprehensive test that creates REAL data on your UPlanet:

### What It Does

1. **Creates WoTx2 Permit**: Creates `PERMIT_CAPTAINEMAIL_X1` for the captain
2. **Self-Request**: Captain requests their own permit (kind 30501)
3. **Self-Attestation**: Captain attests their own request (kind 30502) - valid for WoTx2 X1
4. **Credential Issuance**: Triggers credential issuance (kind 30503) via API
5. **Badge Generation**: Generates badge images automatically using AI
6. **ORE Contract**: Creates ORE contract for UMAP 0.00 0.00
7. **UX Explanation**: Explains the complete UPlanet game loop

### Usage

```bash
# Run validation test (creates real data)
./test_captain_validation.sh

# Run with automatic cleanup
./test_captain_validation.sh --cleanup
```

### What Gets Created

- **Permit Definition** (kind 30500): `PERMIT_CAPTAINEMAIL_X1`
- **Permit Request** (kind 30501): Captain's application
- **Permit Attestation** (kind 30502): Self-attestation
- **Credential** (kind 30503): W3C Verifiable Credential
- **Badge Definition** (kind 30009): Badge for the permit
- **Badge Award** (kind 8): Badge awarded to captain
- **ORE Contract**: Environmental contract for UMAP 0.00 0.00
- **ORE Meeting Space** (kind 30312): Persistent space for verification
- **UMAP DID** (kind 30800): DID for UMAP with ORE obligations

### Cleanup

After running tests, clean up test events:

```bash
# Clean up using events file
./cleanup_test_events.sh --file ~/.zen/tmp/tests/captain_test_events.json

# Clean up with confirmation
./cleanup_test_events.sh --file ~/.zen/tmp/tests/captain_test_events.json --confirm
```

## Test Coverage

### DID System
- ✅ DID document creation and structure
- ✅ DID resolution (Nostr, IPFS, cache)
- ✅ DID updates and metadata
- ✅ UMAP DID for geographic cells
- ✅ W3C DID Core v1.1 compliance

### Oracle System
- ✅ Permit definition creation (kind 30500)
- ✅ Permit request submission (kind 30501)
- ✅ Permit attestation (kind 30502)
- ✅ Credential issuance (kind 30503)
- ✅ Badge emission (kind 30009, 8)
- ✅ IPFSNODEID filtering

### WoTx2 System
- ✅ WoTx2 permit creation (PERMIT_*_X1)
- ✅ Auto-progression (X1 → X2 → X3...)
- ✅ Competency revelation
- ✅ PERMIT_DRAGON for captain
- ✅ NIP-42 authentication
- ✅ IPFSNODEID filtering

### ORE System
- ✅ UMAP DID creation (kind 30800)
- ✅ ORE contract activation
- ✅ ORE Meeting Space (kind 30312)
- ✅ ORE Verification Meeting (kind 30313)
- ✅ UMAP 0.00 0.00 as test territory
- ✅ ORE badge emission

### Badge System
- ✅ Badge definition (kind 30009)
- ✅ Badge award (kind 8)
- ✅ Profile badges (kind 30008)
- ✅ Badge image generation
- ✅ Badge display functions
- ✅ Badge synchronization

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Use `test_common.sh` functions for assertions
3. Add appropriate logging with `test_log_*` functions
4. Update this README with new test coverage

## License

AGPL-3.0 - Same as UPlanet/Astroport.ONE

