#!/bin/bash

# Default options
DRY_RUN=true
VERSION="1.0.2"
PRIVATE_KEY=""
NETWORK="testnet"
SCRIPT_PATH=""
CONFIG_PATH="./script/configs"
FORCE=false
SAFE_ADDRESS=""
EXTRA_ENV=""

# Chain configurations
declare -a MAINNET_CHAINS=("eth-mainnet" "base-mainnet" "arb-mainnet" "op-mainnet" "sonic-mainnet")
declare -a MAINNET_CHAIN_IDS=(1 8453 42161 10 146)
declare -a TESTNET_CHAINS=("base-sepolia" "arb-sepolia" "op-sepolia" "monad-testnet" "bera-bepolia" "sonic-testnet" "unichain-sepolia")
declare -a TESTNET_CHAIN_IDS=(84532 421614 11155420 10143 80069 57054 1301)

# Set active chains based on network
if [[ "$NETWORK" == "mainnet" ]]; then
    CHAINS=("${MAINNET_CHAINS[@]}")
    CHAIN_IDS=("${MAINNET_CHAIN_IDS[@]}")
else
    CHAINS=("${TESTNET_CHAINS[@]}")
    CHAIN_IDS=("${TESTNET_CHAIN_IDS[@]}")
fi

declare -a SELECTED_CHAINS=()
declare -a SKIP_CHAINS=()

# Help function
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            Show this help message"
    echo "  -b, --broadcast       Enable broadcasting (disables dry run)"
    echo "  -v, --version VERSION Specify version (default: $VERSION)"
    echo "  -c, --chains CHAIN1,CHAIN2 Specify chains (comma-separated)"
    echo "  -s, --skip CHAIN1,CHAIN2 Skip chains (comma-separated)"
    echo "  -p, --private-key KEY Private key for deployments"
    echo "  -n, --network NETWORK Network: mainnet or testnet (default: $NETWORK)"
    echo "  -f, --force           Force overwrite deployments"
    echo "  --script SCRIPT       Path to Solidity script (required)"
    echo "  --config-path PATH    Config directory (default: $CONFIG_PATH)"
    echo "  --safe-address ADDR   Safe address for Safe-based deployment"
    echo "  --extra 'KEY=VAL ...' Extra environment variables (space-separated)"
    echo "Available mainnet chains: ${MAINNET_CHAINS[*]}"
    echo "Available testnet chains: ${TESTNET_CHAINS[*]}"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -b|--broadcast) DRY_RUN=false ;;
        -v|--version) VERSION="$2"; shift ;;
        -c|--chains) IFS=',' read -r -a SELECTED_CHAINS <<< "$2"; shift ;;
        -s|--skip) IFS=',' read -r -a SKIP_CHAINS <<< "$2"; shift ;;
        -p|--private-key) PRIVATE_KEY="$2"; shift ;;
        -n|--network)
            NETWORK="$2"
            [[ "$NETWORK" != "mainnet" && "$NETWORK" != "testnet" ]] && { echo "Error: Network must be 'mainnet' or 'testnet'"; exit 1; }
            if [[ "$NETWORK" == "mainnet" ]]; then CHAINS=("${MAINNET_CHAINS[@]}"); CHAIN_IDS=("${MAINNET_CHAIN_IDS[@]}"); else CHAINS=("${TESTNET_CHAINS[@]}"); CHAIN_IDS=("${TESTNET_CHAIN_IDS[@]}"); fi
            shift ;;
        -f|--force) FORCE=true ;;
        --script) SCRIPT_PATH="$2"; shift ;;
        --config-path) CONFIG_PATH="$2"; shift ;;
        --safe-address) SAFE_ADDRESS="$2"; shift ;;
        --extra) EXTRA_ENV="$2"; shift ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done

# Validate script path
[[ -z "$SCRIPT_PATH" ]] && { echo "Error: Script path required. Use --script."; show_help; }
[[ ! -f "$SCRIPT_PATH" ]] && { echo "Error: Script file not found: $SCRIPT_PATH"; exit 1; }

# Extract script name
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
SCRIPT_BASE_NAME=${SCRIPT_NAME%.s.sol}
SCRIPT_BASE_NAME=${SCRIPT_BASE_NAME%.sol}

# Function to check chain processing
should_process_chain() {
    local chain=$1
    if [[ ${#SELECTED_CHAINS[@]} -gt 0 ]]; then
        for selected in "${SELECTED_CHAINS[@]}"; do
            [[ "$selected" == "$chain" ]] && { for skip in "${SKIP_CHAINS[@]}"; do [[ "$skip" == "$chain" ]] && return 1; done; return 0; }
        done
        return 1
    fi
    for skip in "${SKIP_CHAINS[@]}"; do [[ "$skip" == "$chain" ]] && return 1; done
    return 0
}

# Function to get chain ID
get_chain_id() {
    local chain=$1
    for i in "${!CHAINS[@]}"; do
        [[ "${CHAINS[$i]}" == "$chain" ]] && echo "${CHAIN_IDS[$i]}" && return
    done
    echo "Unknown"
}

# Function to check config existence
check_config_exists() {
    local chain=$1
    local version=$2
    local config_file="$CONFIG_PATH/$chain/$version.json"
    [[ ! -f "$config_file" ]] && { echo "Warning: No config file found for $chain at $config_file"; return 1; }
    return 0
}

# Handle private key for broadcasting
if [[ "$DRY_RUN" == "false" ]]; then
    if [[ -n "$SAFE_ADDRESS" ]]; then
        # Safe mode: WALLET_TYPE and PRIVATE_KEY/MNEMONIC_INDEX are set separately
        WALLET_TYPE="${WALLET_TYPE:-local}"
        if [[ "$WALLET_TYPE" == "local" && -z "$PRIVATE_KEY" ]]; then
            echo -n "Enter private key for Safe signing: "
            read -s PRIVATE_KEY
            echo
            [[ -z "$PRIVATE_KEY" ]] && { echo "Error: Private key required for Safe signing"; exit 1; }
        fi
    elif [[ -z "$PRIVATE_KEY" ]]; then
        echo -n "Enter private key for EOA deployments: "
        read -s PRIVATE_KEY
        echo
        [[ -z "$PRIVATE_KEY" ]] && { echo "Error: Private key required for broadcasting"; exit 1; }
    fi
fi

# Deployment summary
echo "Starting deployments with version: $VERSION"
echo "Script: $SCRIPT_NAME"
echo "Network: $NETWORK"
echo "Mode: $( [[ "$DRY_RUN" == "true" ]] && echo "Dry run" || echo "Broadcasting" )"
[[ -n "$SAFE_ADDRESS" ]] && echo "Safe Address: $SAFE_ADDRESS" || echo "Using EOA mode"
echo "Available chains: ${CHAINS[*]}"
[[ ${#SELECTED_CHAINS[@]} -gt 0 ]] && echo "Selected chains: ${SELECTED_CHAINS[*]}"
[[ ${#SKIP_CHAINS[@]} -gt 0 ]] && echo "Skipped chains: ${SKIP_CHAINS[*]}"
[[ "$DRY_RUN" == "false" && -z "$SAFE_ADDRESS" ]] && echo "Private key: ${PRIVATE_KEY:0:6}...${PRIVATE_KEY: -4}"
[[ -n "$EXTRA_ENV" ]] && echo "Extra env vars: $EXTRA_ENV"

# Run deployments
for chain in "${CHAINS[@]}"; do
    if should_process_chain "$chain"; then
        echo "Processing chain: $chain"
        chain_id=$(get_chain_id "$chain")
        if ! check_config_exists "$chain" "$VERSION"; then
            echo "Skipping deployment for $chain due to missing config file"
            continue
        fi
        log_dir="./logs/$VERSION/$chain"
        mkdir -p "$log_dir"
        log_file="$log_dir/${SCRIPT_BASE_NAME}_$(date +%Y%m%d_%H%M%S).log"
        
        # Set environment variables
        env_vars="CHAIN=$chain CHAIN_ID=$chain_id VERSION=${VERSION:-1.0.0} DRY_RUN=$DRY_RUN CONFIG_PATH=$CONFIG_PATH/$chain/$VERSION.json"
        if [[ -n "$SAFE_ADDRESS" ]]; then
            env_vars="$env_vars SAFE_ADDRESS=$SAFE_ADDRESS"
        fi
        if [[ -n "$EXTRA_ENV" ]]; then
            env_vars="$env_vars $EXTRA_ENV"
        fi
        
        cmd="forge script $SCRIPT_PATH -vvv"
        if [[ "$DRY_RUN" == "false" ]]; then
            if [[ -n "$SAFE_ADDRESS" ]]; then
                env_vars="$env_vars WALLET_TYPE=${WALLET_TYPE:-local}"
                [[ "$WALLET_TYPE" == "local" ]] && env_vars="$env_vars PRIVATE_KEY=$PRIVATE_KEY"
                [[ "$WALLET_TYPE" == "ledger" ]] && env_vars="$env_vars MNEMONIC_INDEX=${MNEMONIC_INDEX:-0}"
                cmd="$cmd --broadcast"
            else
                env_vars="$env_vars PRIVATE_KEY=$PRIVATE_KEY"
                cmd="$cmd --broadcast"
            fi
        fi
        
        # Use env to ensure variables are passed
        full_cmd="env $env_vars $cmd"
        
        echo "Running: $full_cmd"
        echo "Output saved to: $log_file"
        if [[ "$SUDO" == "true" ]]; then
            sudo -E bash -c "$full_cmd" 2>&1 | tee "$log_file"
        else
            eval "$full_cmd" 2>&1 | tee "$log_file"
        fi
        [[ ${PIPESTATUS[0]} -eq 0 ]] && echo "Deployment for $chain completed successfully" || echo "Deployment for $chain failed"
        
        unset CHAIN CHAIN_ID CONFIG_PATH DRY_RUN PRIVATE_KEY VERSION SAFE_ADDRESS WALLET_TYPE MNEMONIC_INDEX
    else
        echo "Skipping deployment for $chain"
    fi
done

echo "All deployments completed"