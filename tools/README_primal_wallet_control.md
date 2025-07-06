# Primal Wallet Control

## Overview

The `primal_wallet_control.sh` script provides a generic solution for monitoring wallet transactions and ensuring that incoming transactions come from wallets with the same primal source. This implements a security system that detects unauthorized transactions and automatically handles refunds and account termination.

## Implementation Summary

This implementation extracts and generalizes the primal transaction control functionality from `NOSTRCARD.refresh.sh` and `G1PalPay.sh` into a reusable, generic solution that eliminates cache dependencies and provides real-time security monitoring.

### Key Features Implemented

#### 1. Generic Primal Transaction Control
- **Real-time Verification**: Uses `silkaj --json money primal` for live primal source verification
- **Smart Cache Usage**: Uses existing cache files when available and recent for performance optimization
- **History-based Detection**: Analyzes transaction history to count existing intrusions without cache dependency
- **Automatic Refund**: Immediately refunds unauthorized transactions
- **Intrusion Tracking**: Counts intrusion attempts with fixed threshold
- **Account Termination**: Automatically terminates accounts after maximum intrusions

#### 2. Security Enhancements
- **Progressive Penalties**: Tracks intrusion count with termination at threshold
- **Email Alerts**: Sends detailed alerts for intrusions and terminations
- **Wallet Emptying**: Transfers remaining balance to master primal before termination
- **Fixed Threshold**: Maximum 3 intrusions before termination
- **History-based Detection**: Analyzes transaction history to count existing intrusions without cache

#### 3. Integration Points
- **NOSTR Card Refresh**: Monitors NOSTR wallet transactions
- **G1PalPay**: Monitors player wallet transactions
- **Extensible**: Can be used for any wallet requiring primal control

## Features

- **Primal Transaction Verification**: Uses `silkaj --json money primal` to verify the primal source of incoming transactions
- **Automatic Refund**: Automatically refunds unauthorized transactions
- **Intrusion Detection**: Tracks intrusion attempts and terminates accounts after a configurable threshold
- **Email Alerts**: Sends detailed alerts for intrusions and account terminations
- **Smart Cache Usage**: Uses existing cache files when available and recent for performance optimization
- **History-based Detection**: Analyzes transaction history to count existing intrusions without cache dependency
- **Fixed Threshold**: Maximum 3 intrusions before account termination

## Technical Implementation

### Core Functions

1. **`get_primal_source()`** - Retrieves primal source using silkaj
2. **`get_wallet_history()`** - Gets transaction history with retry logic
3. **`send_alert_email()`** - Sends email alerts using templates
4. **`terminate_wallet()`** - Empties wallet and terminates account
5. **`count_existing_intrusions()`** - Analyzes transaction history to count existing intrusion refunds
6. **`control_primal_transactions()`** - Main control function

### How It Works

1. **Cache Check**: Checks for existing cache files (`~/.zen/tmp/coucou/$pubkey.primal` and `~/.zen/tmp/coucou/$pubkey.history`)
2. **Transaction History Retrieval**: Gets the wallet's complete transaction history using `silkaj --json money history` (or from cache if recent)
3. **Existing Intrusion Analysis**: Scans transaction history for existing intrusion refunds to avoid cache dependency
4. **Primal Source Verification**: For each incoming transaction, verifies the primal source using `silkaj --json money primal` (or from cache if recent)
5. **Intrusion Detection**: Compares the primal source with the expected master primal
6. **Automatic Refund**: If an intrusion is detected, automatically refunds the transaction
7. **Alert System**: Sends email alerts for intrusions and account terminations
8. **Account Termination**: After reaching the maximum intrusion threshold, empties the wallet and terminates the account

## Usage

### Direct Script Execution

```bash
./primal_wallet_control.sh <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>
```

### Parameters

- `wallet_dunikey`: Path to the wallet's dunikey file
- `wallet_pubkey`: Wallet's public key
- `master_primal`: Expected master primal source
- `player_email`: Player's email for alerts

### Function Call

```bash
# Source the script
source ./primal_wallet_control.sh

# Call the function
control_primal_transactions \
    "/path/to/wallet.dunikey" \
    "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" \
    "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" \
    "player@example.com"
```

## Integration Examples

### NOSTR Card Integration

```bash
# In NOSTRCARD.refresh.sh
${MY_PATH}/../tools/primal_wallet_control.sh \
    "${HOME}/.zen/game/nostr/${PLAYER}/.secret.dunikey" \
    "${G1PUBNOSTR}" \
    "${UPLANETG1PUB}" \
    "${PLAYER}"
```

### G1PalPay Integration

```bash
# In G1PalPay.sh
${MY_PATH}/../tools/primal_wallet_control.sh \
    "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" \
    "${G1PUB}" \
    "${UPLANETG1PUB}" \
    "${EMAIL}"
```

## Security Features

- **Smart Cache Usage**: Uses existing cache files when available and recent for performance optimization
- **Real-time Fallback**: Falls back to live verification when cache is not available or outdated
- **History-based Intrusion Detection**: Analyzes transaction history to count existing intrusions without cache dependency
- **Automatic Refund**: Unauthorized transactions are immediately refunded
- **Progressive Penalties**: Intrusion count tracking with fixed termination threshold (3 intrusions)
- **Email Notifications**: Detailed alerts for security events
- **Wallet Termination**: Automatic account termination with balance transfer to master

## Dependencies

### Required Tools
- `silkaj` - Blockchain interaction and primal verification
- `jq` - JSON parsing
- `bc` - Mathematical calculations
- `mailjet.sh` - Email notifications
- `PAYforSURE.sh` - Secure payments
- `duniter_getnode.sh` - BMAS node discovery

### Cache Files
The script uses existing cache files for performance optimization:

- `~/.zen/tmp/coucou/$pubkey.primal` - Cached primal source (permanently valid)
- `~/.zen/tmp/coucou/$pubkey.history` - Cached transaction history (valid for 30 minutes)

### Templates
The script uses HTML templates for email alerts:

- `templates/NOSTR/wallet_alert.html` - For intrusion alerts
- `templates/NOSTR/wallet_termination.html` - For account termination alerts

## Benefits Achieved

### 1. Code Reusability
- **Single Implementation**: One script handles all primal control scenarios
- **Consistent Behavior**: Same logic across different wallet types
- **Maintainability**: Centralized updates and bug fixes

### 2. Enhanced Security
- **Real-time Verification**: Uses live data when cache is not available or outdated
- **Smart Cache Usage**: Leverages existing cache for performance while maintaining security
- **History-based Detection**: Eliminates cache dependency for intrusion counting
- **Automatic Response**: Immediate refund and alert system
- **Progressive Protection**: Escalating security measures

### 3. Improved Reliability
- **Retry Logic**: Handles network failures gracefully
- **Error Handling**: Comprehensive error checking and reporting
- **Logging**: Detailed operation logging for debugging
- **Cache Management**: Automatic cache creation and validation

### 4. Flexibility
- **Fixed Security Level**: Consistent 3-intrusion threshold across all use cases
- **Template System**: Customizable email alerts
- **Extensible Design**: Easy to add new wallet types

## Error Handling

- **Network Failures**: Retries up to 3 times for network operations
- **Invalid JSON**: Validates JSON responses before processing
- **Missing Files**: Creates required files if they don't exist
- **Invalid Parameters**: Provides detailed usage information for incorrect parameters

## Logging

The script provides detailed logging for:
- Transaction processing
- Primal verification results
- Intrusion detection
- Refund operations
- Account termination

## Security Considerations

- **Private Key Security**: Ensure dunikey files have appropriate permissions (600)
- **Email Security**: Verify email addresses to prevent alert spoofing
- **Network Security**: Use secure connections for blockchain operations
- **File Permissions**: Protect intrusion count and check files from unauthorized access

## Troubleshooting

### Common Issues

1. **"silkaj not found"**: Install silkaj or ensure it's in PATH
2. **"Invalid JSON response"**: Check network connectivity to BMAS nodes
3. **"Permission denied"**: Check file permissions for dunikey and log files
4. **"Email sending failed"**: Verify mailjet.sh configuration

### Debug Mode

Add debug output by setting:

```bash
export DEBUG=1
```

## Future Enhancements

### Potential Improvements
1. **Database Integration**: Store intrusion history in database
2. **API Endpoints**: REST API for remote monitoring
3. **Dashboard**: Web interface for security monitoring
4. **Machine Learning**: Anomaly detection for suspicious patterns
5. **Multi-currency Support**: Extend to other cryptocurrencies

### Configuration Options
1. **Whitelist Management**: Allow specific exceptions
2. **Time-based Rules**: Different thresholds for different time periods
3. **Geographic Restrictions**: Location-based security rules
4. **Custom Alert Channels**: Slack, Discord, etc.

## Conclusion

The primal wallet control implementation successfully:

1. **Extracted** duplicate logic from multiple scripts
2. **Generalized** the solution for reuse across different wallet types
3. **Enhanced** security with real-time verification and automatic responses
4. **Eliminated** cache dependencies through transaction history analysis
5. **Improved** maintainability through centralized code
6. **Provided** comprehensive documentation

The solution is production-ready and can be easily extended for additional use cases while maintaining the security and reliability requirements of the UPlanet network.

## License

AGPL-3.0 - See LICENSE file for details. 