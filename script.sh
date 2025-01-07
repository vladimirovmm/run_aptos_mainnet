#!/bin/bash

ROOT_DIR=$(realpath '.')
BIN_DIR=${ROOT_DIR}/bin
GENESIS_DIR=${ROOT_DIR}/genesis
NODE_DIR=${ROOT_DIR}/node
SVALIDATOR_PORT=10000
SFULLNODE_PORT=10100
NODE_COUNT=5
NODE_BALANCE=100000000000000000
MIN_AMOUNT=100000000000000
ADDITIONAL_ACCOUNTS=10
ADDITIONAL_ACCOUNT_BALNACE=100000000000000000
ADDITIONAL_ACCOUNTS_DIR=${ROOT_DIR}/additional_accounts

APTOS_BIN_NAME='aptos'
APTOS_BIN=${BIN_DIR}/${APTOS_BIN_NAME}
APTOS_NODE_BIN_NAME='aptos-node'
APTOS_NODE_BIN=${BIN_DIR}/${APTOS_NODE_BIN_NAME}

VALIDATOR_CONFIG='base:
  data_dir: "data_validator"
  role: "validator"
  waypoint:
    from_file: "GENESIS_DIR/waypoint.txt"

consensus:
  safety_rules:
    service:
      type: "local"
    backend:
      type: "on_disk_storage"
      path: "secure-data.json"
      namespace: ~
    initial_safety_rules_config:
      from_file:
        waypoint:
          from_file: "GENESIS_DIR/waypoint.txt"
        identity_blob_path: "keys/validator-identity.yaml"

execution:
  genesis_file_location: "GENESIS_DIR/genesis.blob"

validator_network:
  discovery_method: "onchain"
  listen_address: "/ip4/0.0.0.0/tcp/VALIDATOR_NETWORK_PORT"
  identity:
    type: "from_file"
    path: "keys/validator-identity.yaml"
  network_id: "validator"
  mutual_authentication: true
  max_frame_size: 4194304 # 4 MiB
storage:
  backup_service_address: "0.0.0.0:0"
  rocksdb_configs:
    enable_storage_sharding: false
api:
  enabled: true
  address: "0.0.0.0:API_PORT"
state_sync:
  state_sync_driver:
    enable_auto_bootstrapping: true
    bootstrapping_mode: "ApplyTransactionOutputsFromGenesis"
admin_service:
  enabled: false
  port: 0
inspection_service:
  port: 0'

FULLNODE_CONFIG='base:
    data_dir: "./data_validator"
    role: "full_node"
    waypoint:
        from_file: "GENESIS_DIR/waypoint.txt"

consensus:
    safety_rules:
        service:
            type: "local"
        backend:
            type: "on_disk_storage"
            path: "secure-data.json"
            namespace: ~
        initial_safety_rules_config:
            from_file:
                waypoint:
                    from_file: "GENESIS_DIR/waypoint.txt"
                identity_blob_path: "validator-identity.yaml"

execution:
    genesis_file_location: "GENESIS_DIR/genesis.blob"

storage:
    rocksdb_configs:
        enable_storage_sharding: true
  
full_node_networks:
    - network_id:
          private: "vfn"
      listen_address: "/ip4/0.0.0.0/tcp/VALIDATOR_NETWORK_PORT"
      identity:
          type: "from_file"
          path: "validator-identity.yaml"

    - network_id: "public"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/PUBLIC_NETWORK_PORT"
      identity:
          type: "from_file"
          path: "validator-full-node-identity.yaml"
api:
    enabled: true
    address: "0.0.0.0:API_PORT"
state_sync:
    state_sync_driver:
        enable_auto_bootstrapping: true
        bootstrapping_mode: "ApplyTransactionOutputsFromGenesis"
admin_service:
    enabled: false
    port: 0
inspection_service:
    port: 0
'

# wget -O config/validator.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/validator.yaml
VFN_CONFIG='base:
  role: "validator"
  data_dir: "./data"
  waypoint:
    from_file: "GENESIS_DIR/waypoint.txt"

consensus:
  safety_rules:
    service:
      type: "local"
    backend:
      type: "on_disk_storage"
      path: secure-data.json
      namespace: ~
    initial_safety_rules_config:
      from_file:
        waypoint:
          from_file: "GENESIS_DIR/waypoint.txt"
        identity_blob_path: ./keys/validator-identity.yaml

execution:
  genesis_file_location: "GENESIS_DIR/genesis.blob"

storage:
  rocksdb_configs:
    enable_storage_sharding: true

validator_network:
  discovery_method: "onchain"
  mutual_authentication: true
  identity:
    type: "from_file"
    path: ./keys/validator-identity.yaml

full_node_networks:
  - network_id:
      private: "vfn"
    listen_address: "/ip4/0.0.0.0/tcp/FULL_NODE_NETWORKS_PORT"
    identity:
        type: "from_file"
        path: ./keys/validator-full-node-identity.yaml
    seeds: SEEDS_LIST
api:
  enabled: true
  address: "0.0.0.0:18080"
'
PFN_CONFIG='base:
    role: "full_node"
    data_dir: "./data"
    waypoint:
        from_file: "GENESIS_DIR/waypoint.txt"

execution:
    genesis_file_location: "GENESIS_DIR/genesis.blob"

storage:
    rocksdb_configs:
        enable_storage_sharding: true

full_node_networks:
    - network_id:
          private: "vfn"
      listen_address: "/ip4/0.0.0.0/tcp/VFN_PORT"
      seeds: VALIDATOR_SEEDS_LIST

    - network_id: "public"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/PUBLIC_PORT"
      identity:
          type: "from_file"
          path: "./keys/validator-full-node-identity.yaml"
      seeds: FULLNODE_SEEDS_LIST
api:
    enabled: true
    address: "0.0.0.0:18081"
'

function fn__necessary_programs {
    echo "Checking for the existence of the necessary programs:"

    for item in 'cargo' 'sed' 'grep' 'curl' 'printf' 'tr'; do
        echo "*" ${item}
        if [ -z "$(command -v $item)" ]; then
            echo "The '$item' program is not installed"
            exit 11
        fi
    done
}

function fn__build_binaries {
    echo 'Preparing binaries'

    if [ -z ${APTOS_SOURCE} ]; then
        echo 'The path to `Aptos` not specified. Specify it through the environment `APTOS_SOURCE`'
        exit 11
    fi

    if [ -f ${APTOS_BIN} ] && [ -f ${APTOS_NODE_BIN} ]; then
        echo '*' ${APTOS_BIN} 'exist'
        echo '*' ${APTOS_NODE_BIN} 'exist'
        return
    fi

    mkdir -p ${BIN_DIR}

    cd ${APTOS_SOURCE}

    for package in ${APTOS_BIN_NAME} ${APTOS_NODE_BIN_NAME}; do
        echo "*" $package
        cargo build -p $package --release || exit 12
        cp target/release/$package ${BIN_DIR}/$package
    done

    cd -
}

function fn__build_framefork {
    echo 'Building framefork'

    framefork_path=${GENESIS_DIR}/framework.mrb

    if [ -f ${framefork_path} ]; then
        echo '*' ${framefork_path} 'exist'
        return
    fi

    mkdir -p genesis

    cd ${APTOS_SOURCE}
    cargo run --package aptos-framework -- release --target mainnet || 21
    cd -

    mv ${APTOS_SOURCE}/mainnet.mrb $framefork_path || 22
}

function fn__generate_key {
    if [ -z "$1" ]; then
        echo 'Error: An empty path was passed'
        exit 36
    fi

    if [ -f $1 ]; then
        echo '* '$1' already exists'
        return
    fi

    account_address=$(${APTOS_BIN} key generate --vanity-prefix 0x --output-file $1 --assume-yes | grep -om 1 "0x[0-9a-f]*") || exit 37
    echo $account_address >$1.address
    echo '*' $1 'has been generated'
}

function fn__generating_keys_for_node {
    node_path=$1
    vport=$2
    fport=$3

    echo '['$node_path'] Generating a configuration file with keys:'
    if [ ! -f $node_path/keys/public-keys.yaml ]; then
        ${APTOS_BIN} genesis generate-keys --output-dir $node_path/keys --assume-yes || exec 33
        echo '* `'$node_path'/keys/public-keys.yaml` has been generated'
    else
        echo '* The `'$node_path'/keys/public-keys.yaml` keys already exist'
    fi

    echo 'Validator config:'
    if [ ! -f $node_path/keys/validator/operator.yaml ]; then
        ${APTOS_BIN} genesis set-validator-configuration \
            --local-repository-dir $node_path/keys \
            --owner-public-identity-file $node_path/keys/public-keys.yaml \
            --username validator \
            --validator-host 0.0.0.0:$vport \
            --full-node-host 0.0.0.0:$fport \
            --stake-amount ${MIN_AMOUNT} \
            --join-during-genesis || exec 34 # `--join-during-genesis`:  - A required parameter when generating genesis
        echo '* '$node_path'/keys/validator has been generated'
    else
        echo '* `'$node_path'/keys/validator/operator.yaml` already exists'
    fi

    echo 'Key generation:'

    important_keys=$node_path/keys/important
    mkdir -p $important_keys

    for tp in 'owner' 'operator' 'voter'; do
        nkey=$important_keys/$tp

        fn__generate_key $nkey || 35

        private_key=$(cat $nkey)
        account_address=$(cat $nkey'.address')
        public_key=$(cat $nkey'.pub')

        for fpath in $(find $node_path -type f -name '*.yaml'); do
            sed -i 's/'$tp'_account_public_key:.*/'$tp'_account_public_key: '$public_key'/g' $fpath
            sed -i 's/'$tp'_account_private_key:.*/'$tp'_account_public_key: '$public_key'/g' $fpath
            sed -i 's/'$tp'_network_public_key:.*/'$tp'_network_public_key: '$public_key'/g' $fpath
            sed -i 's/'$tp'_account_address:.*/'$tp'_account_address: "'$account_address'"/g' $fpath
        done
    done

    echo 'Config:'
    echo '* Owner address: '$(cat $important_keys/owner.address)
    echo '* Operator address: '$(cat $important_keys/operator.address)
    echo '* Voter address: '$(cat $important_keys/voter.address)
    echo '* Validator port: '$vport
    echo '* Fullnode port: '$fport
}

function fn__validators_keys {
    echo 'Generating keys:'

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        node_path=${NODE_DIR}/v$i

        let vport=${SVALIDATOR_PORT}+$i
        let fport=${SFULLNODE_PORT}+$i

        fn__generating_keys_for_node $node_path $vport $fport || exit 31
    done

    echo 'Additional accounts:'
    for ((i = 1; i <= ${ADDITIONAL_ACCOUNTS}; i++)); do
        dir=${ADDITIONAL_ACCOUNTS_DIR}/u$i

        if [ -d $dir ]; then
            echo '* '$dir' already exist'
            continue
        fi

        mkdir -p $dir
        file_path=$dir'/user'

        fn__generate_key $file_path || 32
    done
}

function fn__genesis {
    echo 'Building genesis'

    genesis_path=${GENESIS_DIR}/genesis.blob
    if [ -f ${genesis_path} ]; then
        echo '*' ${genesis_path} 'exist'
        return
    fi

    employee_path=${GENESIS_DIR}/employee_vesting_accounts.yaml
    if [ -f ${employee_path} ]; then
        echo '*' ${employee_path} 'exist'
    else
        echo '* `'$employee_path'` has been created'
        echo '[]' >$employee_path
    fi

    balances_path=${GENESIS_DIR}/balances.yaml

    if [ -f ${balances_path} ]; then
        echo '*' ${balances_path} 'exist'
    else
        echo '' >$balances_path
        for file in $(find ${NODE_DIR} -name *.address -type f); do
            address=$(cat $file)
            echo '-' $address': '${NODE_BALANCE} >>$balances_path
        done
        for file in $(find ${ADDITIONAL_ACCOUNTS_DIR} -name *.address -type f); do
            address=$(cat $file)
            echo '-' $address': '${ADDITIONAL_ACCOUNT_BALNACE} >>$balances_path
        done

        echo '* `'$balances_path'` has been created'
    fi

    layout_path=${GENESIS_DIR}/layout.yaml
    ${APTOS_BIN} genesis generate-layout-template \
        --output-file $layout_path \
        --assume-yes || exit 41
    sed -i 's/root_key: ~//g' $layout_path

    users=""
    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        users=${users}'"../node/v'$i'/keys/validator", '
    done

    users=$(printf '%s' ${users::-2})

    sed -i 's|users: \[\]|users: \['${users}'\]|g' $layout_path
    sed -i 's/chain_id: 4/chain_id: 1/g' $layout_path

    sed -i 's/allow_new_validators: false/allow_new_validators: true/g' $layout_path
    sed -i 's/is_test: true/is_test: false/g' $layout_path
    let total_supply=${NODE_COUNT}*3*${NODE_BALANCE}+${ADDITIONAL_ACCOUNTS}*${ADDITIONAL_ACCOUNT_BALNACE}
    sed -i 's/total_supply: ~/total_supply: '$total_supply'/g' $layout_path
    # @todo
    sed -i 's/epoch_duration_secs:.*/epoch_duration_secs: 120/g' $layout_path
    echo '* `'$layout_path'` has been created'

    ${APTOS_BIN} genesis generate-genesis \
        --local-repository-dir ${GENESIS_DIR} \
        --output-dir ${GENESIS_DIR} \
        --mainnet \
        --assume-yes || exit 42
}

function fn__validator_config {
    let vport=${SVALIDATOR_PORT}+$1
    let fport=${SFULLNODE_PORT}+$i
    let api_port=8079+$1

    validator_config=${VALIDATOR_CONFIG}
    validator_config="${validator_config//GENESIS_DIR/"${GENESIS_DIR}"}"
    validator_config="${validator_config//API_PORT/"$api_port"}"
    validator_config="${validator_config//VALIDATOR_NETWORK_PORT/"$vport"}"

    fullnode_config=${FULLNODE_CONFIG}
    fullnode_config="${fullnode_config//GENESIS_DIR/"${GENESIS_DIR}"}"
    fullnode_config="${fullnode_config//API_PORT/"$api_port"}"
    fullnode_config="${fullnode_config//VALIDATOR_NETWORK_PORT/"$vport"}"
    fullnode_config="${fullnode_config//PUBLIC_NETWORK_PORT/"$fport"}"

    echo "$validator_config" >${NODE_DIR}/v$1/validator.yaml
    echo "$fullnode_config" >${NODE_DIR}/v$1/fullnode.yaml
}

function fn__set_pool_address {
    node_path=$1
    owner_address=$(cat $node_path/keys/important/owner.address)
    pool_address=$(${APTOS_BIN} node get-stake-pool --owner-address $owner_address --url $node_url | jq .Result[0].pool_address | tr -d '"') || exit 38
    find $node_path -type f -name "*.yaml" -exec \
        sed -i 's|account_address:.*|account_address: '$pool_address'|g' {} \;
}

function fn__init {
    fn__build_binaries || exit 10
    fn__build_framefork || exit 20
    fn__validators_keys || exit 30
    fn__genesis || exit 40

    echo 'Node config:'
    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        fn__validator_config $i || exit 50
        echo ' * #'$i 'Success'
    done

    cd ${NODE_DIR}/v1/

    ${APTOS_NODE_BIN} --config validator.yaml &
    node_pid=$!

    node_url=http://localhost:8080
    curl $node_url --head -X GET \
        --retry-connrefused \
        --retry 30 \
        --retry-delay 1 &>/dev/null

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        fn__set_pool_address ${NODE_DIR}/v$i
    done

    kill $node_pid
    rm -rf data_validator

    cd -

    echo '= = = end = = ='
}

function fn__clear {
    rm -rf v1 v2 v3 v4 v5 genesis
}

function fn__generate_seeds {
    node_url=http://localhost:8080
    output=$(${APTOS_BIN} node show-validator-set --url $node_url)
    count=$(echo $output | jq '.Result.active_validators | length')

    seeds_validator=""
    seeds_fullnode=""
    for ((i = 0; i < $count; i++)); do
        account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
        validator_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.validator_network_addresses[0])
        fullnode_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.fullnode_network_addresses[0])

        seeds_validator="$seeds_validator
        $account_address:
            addresses:
                - $validator_network_addresses
            role: Validator"
        seeds_fullnode="$seeds_fullnode
        $account_address:
            addresses:
                - $fullnode_network_addresses
            role: ValidatorFullNode"
    done

    case $1 in
    validators) echo "$seeds_validator" ;;
    fullnode) echo "$seeds_fullnode" ;;
    *)
        echo "$1 is not an option"
        exit 1
        ;;
    esac
}

function fn__vfn {
    echo 'VFN'

    vport=10201
    fport=10202
    node_path=${NODE_DIR}/vfn
    owner_dir=$node_path/keys/important
    owner_path=$owner_dir/owner

    echo $owner_dir
    mkdir -p $owner_dir

    source_key=${ROOT_DIR}/additional_accounts/u1/user
    cp $source_key $owner_path
    cp $source_key.pub $owner_path.pub
    cp $source_key.address $owner_path.address

    fn__generating_keys_for_node $node_path $vport $fport || exit 1

    cd $node_path

    important_keys=$node_path/keys/important

    echo 'Creating profiles:'
    for tp in 'owner' 'operator' 'voter'; do
        ${APTOS_BIN} init \
            --profile mainnet-$tp \
            --private-key-file $important_keys/$tp \
            --skip-faucet \
            --network local \
            --assume-yes &>/dev/null
    done

    owner_address=$(cat $important_keys/owner.address)
    operator_address=$(cat $important_keys/operator.address)
    voter_address=$(cat $important_keys/voter.address)

    echo 'Addresses:'
    echo '* Owner address: '$owner_address
    echo '* Operator address: '$operator_address
    echo '* Voter address: '$voter_address

    echo 'Checking the onwer balance:'
    balance=$(${APTOS_BIN} account balance --profile mainnet-owner | jq .Result[0].balance) || exit 2
    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo 'Error: Insufficient balance '$balance
        exit 31
    else
        echo '* Owner balance: '$balance
    fi

    echo 'Checking the operator balance:'
    balance=$(${APTOS_BIN} account balance --profile mainnet-operator | jq .Result[0].balance) || exit 3

    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo ${MIN_AMOUNT}
        ${APTOS_BIN} account transfer \
            --account $operator_address \
            --amount ${MIN_AMOUNT} \
            --profile mainnet-owner \
            --assume-yes || exit 4
        echo '* The operator`s '$operator_addresss' balance has been replenished' ${MIN_AMOUNT}
    else
        echo '* Operator balance: '$balance
    fi

    echo 'Run the following command to initialize the staking pool:'

    ${APTOS_BIN} stake create-staking-contract \
        --operator $operator_address \
        --voter $voter_address \
        --amount 100000000000000 \
        --commission-percentage 10 \
        --profile mainnet-owner \
        --assume-yes

    pool_address=$(${APTOS_BIN} node get-stake-pool --owner-address $owner_address --profile mainnet-owner | jq .Result[0].pool_address | tr -d '"') || exit 6
    echo '* pool address created: '$pool_address

    echo 'Update on-chain network addresses:'
    ${APTOS_BIN} node update-validator-network-addresses \
        --pool-address $pool_address \
        --operator-config-file keys/validator/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Update on-chain consensus key: '
    ${APTOS_BIN} node update-consensus-key \
        --pool-address $pool_address \
        --operator-config-file keys/validator/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Join the validator set:'
    ${APTOS_BIN} node join-validator-set \
        --pool-address $pool_address \
        --profile mainnet-operator \
        --assume-yes

    for path in 'keys/validator-identity.yaml' 'keys/validator-full-node-identity.yaml'; do
        sed -i 's|account_address:.*|account_address: '$pool_address'|g' $path
        echo '* account_address has been updated in '$path
    done

    echo 'Gensesis:'
    genesis_path=${GENESIS_DIR}/genesis.blob
    waypoint_path=${GENESIS_DIR}/waypoint.txt
    echo '* genesis_path: '$genesis_path
    echo '* waypoint_path: '$waypoint_path

    echo 'Configs:'

    mkdir -p config

    seeds_validator=$(fn__generate_seeds validators)

    validator_config=${VFN_CONFIG}
    validator_config="${validator_config//GENESIS_DIR/"${GENESIS_DIR}"}"
    validator_config="${validator_config//FULL_NODE_NETWORKS_PORT/"$fport"}"
    validator_config="${validator_config//SEEDS_LIST/"$seeds_validator"}"
    echo "$validator_config" >config/validator.yaml
    echo '* config/validator.yaml has been generated'

    cd -
}

function fn__pfn {
    echo 'PFN'

    mkdir -p pfn
    cd pfn

    echo 'Gensesis:'
    genesis_path=${GENESIS_DIR}/genesis.blob
    waypoint_path=${GENESIS_DIR}/waypoint.txt
    echo '* genesis_path: '$genesis_path
    echo '* waypoint_path: '$waypoint_path

    vport=10203
    fport=10204

    echo 'Generating a configuration file with keys:'

    if [ ! -f keys/public-keys.yaml ]; then
        ${APTOS_BIN} genesis generate-keys --output-dir ./keys --assume-yes
        ${APTOS_BIN} genesis set-validator-configuration \
            --local-repository-dir . \
            --username pfn \
            --owner-public-identity-file keys/public-keys.yaml \
            --validator-host 0.0.0.0:$vport \
            --full-node-host 0.0.0.0:$fport \
            --stake-amount ${MIN_AMOUNT}
        echo '* The `public-keys.yaml` keys have been generated'
    else
        echo '* The `public-keys.yaml` keys already exist'
    fi

    echo 'Configs:'

    # if [ ! -f config/fullnode.yaml ]; then
    mkdir -p config

    node_url=http://localhost:8080
    output=$(${APTOS_BIN} node show-validator-set --url $node_url)
    count=$(echo $output | jq '.Result.active_validators | length')

    seeds_validator=""
    seeds_fullnode=""
    for ((i = 0; i < $count; i++)); do
        account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
        validator_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.validator_network_addresses[0])
        fullnode_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.fullnode_network_addresses[0])

        seeds_validator="$seeds_validator
          $account_address:
              addresses:
                  - $validator_network_addresses
              role: Validator"
        seeds_fullnode="$seeds_fullnode
          $account_address:
              addresses:
                  - $fullnode_network_addresses
              role: ValidatorFullNode"
    done
    echo '* seeds config has been genirated'

    # wget -O config/fullnode.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/fullnode.yaml

    validator_config=${PFN_CONFIG}

    validator_config="${validator_config//WAYPOINT_PATH/"$waypoint_path"}"
    validator_config="${validator_config//GENESIS_PATH/"$genesis_path"}"
    validator_config="${validator_config//VFN_PORT/"$vport"}"
    validator_config="${validator_config//PUBLIC_PORT/"$fport"}"
    validator_config="${validator_config//VALIDATOR_SEEDS_LIST/"$seeds_validator"}"
    validator_config="${validator_config//FULLNODE_SEEDS_LIST/"$seeds_fullnode"}"
    echo "$validator_config" >config/fullnode.yaml
    echo '* config/fullnode.yaml has been generated'
    # else
    #     echo '* config has already exist '
    # fi

    return

    echo 'Key generation:'

    important_keys=keys/important
    mkdir -p $important_keys

    for tp in 'owner' 'operator' 'voter'; do
        nkey=$important_keys/$tp
        if [ -f $nkey ]; then
            echo '* '$nkey' already exists'
            continue
        fi

        if [ $tp == 'owner' ]; then
            path_key=../additional_accounts/u1/user
            cp $path_key $nkey
            cp $path_key.pub $nkey.pub
            cp $path_key.address $nkey.address
            echo '* The key for owner is copied from '$path_key
        else
            fn__generate_key $nkey
        fi

        account_address=$(cat $nkey'.address')
        public_key=$(cat $nkey'.pub')

        for path in 'keys' 'vfn'; do
            for fpath in $(find $path -type f -name '*.yaml'); do
                sed -i 's/'$tp'_account_public_key:.*/'$tp'_account_public_key: '$public_key'/g' $fpath
                sed -i 's/'$tp'_network_public_key:.*/'$tp'_network_public_key: '$public_key'/g' $fpath
                sed -i 's/'$tp'_account_address:.*/'$tp'_account_address: "'$account_address'"/g' $fpath
            done
        done

        ${APTOS_BIN} init \
            --profile mainnet-$tp \
            --private-key-file $important_keys/$tp \
            --skip-faucet \
            --network local \
            --assume-yes &>/dev/null
    done

    owner_address=$(cat $important_keys/owner.address)
    operator_address=$(cat $important_keys/operator.address)
    voter_address=$(cat $important_keys/voter.address)

    echo 'Addresses:'
    echo '* Owner address: '$owner_address
    echo '* Operator address: '$operator_address
    echo '* Voter address: '$voter_address

    echo 'Checking the onwer balance:'
    balance=$(${APTOS_BIN} account balance --profile mainnet-owner | jq .Result[0].balance)
    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo 'Error: Insufficient balance '$balance
        exit 31
    else
        echo '* Owner balance: '$balance
    fi

    echo 'Checking the operator balance:'
    balance=$(${APTOS_BIN} account balance --profile mainnet-operator | jq .Result[0].balance)

    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo ${MIN_AMOUNT}
        ${APTOS_BIN} account transfer \
            --account $operator_address \
            --amount ${MIN_AMOUNT} \
            --profile mainnet-owner \
            --assume-yes || exit 32
        echo '* The operator`s '$operator_addresss' balance has been replenished' ${MIN_AMOUNT}
    else
        echo '* Operator balance: '$balance
    fi

    echo 'Run the following command to initialize the staking pool:'

    ${APTOS_BIN} stake create-staking-contract \
        --operator $operator_address \
        --voter $voter_address \
        --amount 100000000000000 \
        --commission-percentage 10 \
        --profile mainnet-owner \
        --assume-yes

    pool_address=$(${APTOS_BIN} node get-stake-pool --owner-address $owner_address --profile mainnet-owner | jq .Result[0].pool_address | tr -d '"')
    echo '* pool address created: '$pool_address

    echo 'Join the validator set:'

    output=$(${APTOS_BIN} node show-validator-set --profile mainnet-operator | grep $pool_address)

    echo 'Update on-chain network addresses:'
    ${APTOS_BIN} node update-validator-network-addresses \
        --pool-address $pool_address \
        --operator-config-file vfn/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Update on-chain consensus key: '
    ${APTOS_BIN} node update-consensus-key \
        --pool-address $pool_address \
        --operator-config-file vfn/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Join the validator set:'
    ${APTOS_BIN} node join-validator-set \
        --pool-address $pool_address \
        --profile mainnet-operator \
        --assume-yes

    for path in 'keys/validator-identity.yaml' 'keys/validator-full-node-identity.yaml'; do
        sed -i 's|account_address:.*|account_address: '$pool_address'|g' $path
        echo '* account_address has been updated in '$path
    done

    cd -
}

fn__necessary_programs

case $1 in
init) fn__init ;;
run) process-compose -p 8070 ;;
vfn) fn__vfn ;;
vfn_run)
    cd node/vfn
    ${APTOS_NODE_BIN} --config config/validator.yaml
    ;;
pfn) fn__pfn ;;
clear) rm -rf additional_accounts genesis node vfn ;;
clear_data) find ./ -type d -name data_validator -exec rm -rf {} \; ;;
*) echo "$1 is not an option" ;;
esac

# APTOS_SOURCE=<PATH/TO/SOURCE> ./script.sh init
# ./script.sh run
# ./script.sh vfn
# ./script.sh clear
# pkill -9 process-compose

# bin/aptos genesis generate-genesis --local-repository-dir /home/vmm/projects/pontem/run_aptos/genesis --output-dir /home/vmm/projects/pontem/run_aptos/genesis --mainnet --assume-yes
