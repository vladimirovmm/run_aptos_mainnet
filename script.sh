#!/bin/bash

ROOT_DIR=$(realpath '.')
BIN_DIR=${ROOT_DIR}/bin
GENESIS_DIR=${ROOT_DIR}/genesis
NODE_DIR=${ROOT_DIR}/node
SVALIDATOR_PORT=10000
SFULLNODE_PORT=10100
SPUBLIC_PORT=10200
NODE_COUNT=6
NODE_BALANCE=100000000000000000
MIN_AMOUNT=100000000000000
ADDITIONAL_ACCOUNTS=10
ADDITIONAL_ACCOUNT_BALANCE=100000000000000000
ADDITIONAL_ACCOUNTS_DIR=${ROOT_DIR}/additional_accounts

NAME=${NAME:-'aptos'}
CLI_BIN_NAME=${NAME}
CLI_BIN=${BIN_DIR}/${CLI_BIN_NAME}
NODE_BIN_NAME=${NAME}'-node'
NODE_BIN=${BIN_DIR}/${NODE_BIN_NAME}

DEBUGGER_BIN_NAME=${NAME}'-debugger'
DEBUGGER_BIN=${BIN_DIR}/${DEBUGGER_BIN_NAME}

# wget -O validator.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/validator.yaml
VALIDATOR_CONFIG='base:
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

validator_network:
    discovery_method: "onchain"
    network_id: "validator"
    mutual_authentication: true
    identity:
        type: "from_file"
        path: ./keys/validator-identity.yaml
    listen_address: "/ip4/0.0.0.0/tcp/VALIDATOR_NETWORK_PORT"

full_node_networks:
    - network_id: 
        private: "vfn"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/FULLNODE_NETWORK_PORT"
      identity:
        type: "from_file"
        path: ./keys/validator-full-node-identity.yaml
      seeds: FULLNODE_SEEDS_LIST

    - network_id: "public"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/PUBLIC_PORT"
      identity:
        type: "from_file"
        path: ./keys/validator-full-node-identity.yaml
      seeds: PUBLIC_SEEDS_LIST

storage:
    backup_service_address: "0.0.0.0:0"
    rocksdb_configs:
        enable_storage_sharding: true
    enable_indexer: false # To enable the indexer

indexer_grpc:
    enabled: false # To enable the indexer
    address: 0.0.0.0:50051
    processor_task_count: 10
    processor_batch_size: 100
    output_batch_size: 100
    # use_data_service_interface: true

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

# wget -O fullnode.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/fullnode.yaml
FULLNODE_CONFIG='base:
    role: "full_node"
    data_dir: "data"
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

full_node_networks:
    - network_id: 
        private: "vfn"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/FULLNODE_NETWORK_PORT"
      identity:
        type: "from_file"
        path: ./keys/validator-full-node-identity.yaml
      seeds: FULLNODE_SEEDS_LIST

    - network_id: "public"
      discovery_method: "onchain"
      listen_address: "/ip4/0.0.0.0/tcp/PUBLIC_PORT"
      identity:
          type: "from_file"
          path: "keys/validator-full-node-identity.yaml"
    #   mutual_authentication: false
      seeds: PUBLIC_SEEDS_LIST

storage:
    backup_service_address: "0.0.0.0:0"
    rocksdb_configs:
        enable_storage_sharding: true
    enable_indexer: false # To enable the indexer

indexer:
    enabled: false
    postgres_uri: postgresql://_USER_:_PASS_@localhost:5432/_DB_NAME_
    processor: "token_processor"

indexer_grpc:
    enabled: false # To enable the indexer
    address: 0.0.0.0:50051
    processor_task_count: 10
    processor_batch_size: 100
    output_batch_size: 100

indexer_db_config:
    enable_transaction: false # To enable the indexer
    enable_event: false # To enable the indexer
    enable_event_v2_translation: false # To enable the indexer
    enable_statekeys: false # To enable the indexer

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

    if [ -z ${GIT_SOURCE} ]; then
        echo 'The path to `SOURCE` not specified. Specify it through the environment `GIT_SOURCE`'
        exit 11
    fi

    mkdir -p ${BIN_DIR} || exit 14

    declare -A list
    
    list[0,0]="${CLI_BIN}" 
    list[0,1]="${CLI_BIN_NAME}";
    list[0,2]='--features indexer';

    list[1,0]="${NODE_BIN}" 
    list[1,1]="${NODE_BIN_NAME}";
    list[1,2]='--features indexer';

    list[2,0]="${DEBUGGER_BIN}" 
    list[2,1]="${DEBUGGER_BIN_NAME}";

    for ((i=0;i < 3; i++)); do
        path=${list[$i,0]};
        package=${list[$i,1]};
        flag=${list[$i,2]};

        if [ -f ${path} ]; then
            echo '*' ${path} ${package} 'exist'
            continue
        fi

        echo '*' ${package}

        cd ${GIT_SOURCE}

        echo cargo build -p $package --release $flag;
        cargo build -p $package --release $flag  || exit 12
        cp target/release/$package ${path} || exit 13

        cd -
    done
}

function fn__build_framework {
    echo 'Building framework'

    framework_path=${GENESIS_DIR}/framework.mrb

    if [ -f ${framework_path} ]; then
        echo '*' ${framework_path} 'exist'
        return
    fi

    mkdir -p genesis

    cd ${GIT_SOURCE}
    cargo run --package ${NAME}-framework -- release --target mainnet || 21
    cd -

    mv ${GIT_SOURCE}/mainnet.mrb $framework_path || 22
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

    account_address=$(${CLI_BIN} key generate --vanity-prefix 0x --output-file $1 --assume-yes | grep -om 1 "0x[0-9a-f]*") || exit 37
    echo $account_address >$1.address
    echo '*' $1 'has been generated'
}

function fn__generating_keys_for_node {
    node_path=$1
    validator_port=$2
    fullnode_port=$3

    echo '['$node_path'] Generating a configuration file with keys:'
    if [ ! -f $node_path/keys/public-keys.yaml ]; then
        ${CLI_BIN} genesis generate-keys --output-dir $node_path/keys --assume-yes || exec 33
        echo '* `'$node_path'/keys/public-keys.yaml` has been generated'
    else
        echo '* The `'$node_path'/keys/public-keys.yaml` keys already exist'
    fi

    echo 'Validator config:'
    if [ ! -f $node_path/keys/validator/operator.yaml ]; then
        ${CLI_BIN} genesis set-validator-configuration \
            --local-repository-dir $node_path/keys \
            --owner-public-identity-file $node_path/keys/public-keys.yaml \
            --username validator \
            --validator-host 0.0.0.0:$validator_port \
            --full-node-host 0.0.0.0:$fullnode_port \
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
            sed -i 's/'$tp'_account_address:.*/'$tp'_account_address: '$account_address'/g' $fpath
            sed -i 's/'$tp'_account_public_key:.*/'$tp'_account_public_key: '$public_key'/g' $fpath
            sed -i 's/'$tp'_account_private_key:.*/'$tp'_account_private_key: '$public_key'/g' $fpath
            sed -i 's/'$tp'_network_public_key:.*/'$tp'_network_public_key: '$public_key'/g' $fpath
        done
    done

    echo 'Config:'
    echo '* Owner address: '$(cat $important_keys/owner.address)
    echo '* Operator address: '$(cat $important_keys/operator.address)
    echo '* Voter address: '$(cat $important_keys/voter.address)
    echo '* Validator port: '$validator_port
    echo '* Fullnode port: '$fullnode_port
}

function fn__validators_keys {
    echo 'Generating keys:'

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        node_path=${NODE_DIR}/v$i

        let validator_port=${SVALIDATOR_PORT}+$i
        let fullnode_port=${SFULLNODE_PORT}+$i

        fn__generating_keys_for_node $node_path $validator_port $fullnode_port || exit 31
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
            echo '-' $address': '${ADDITIONAL_ACCOUNT_BALANCE} >>$balances_path
        done

        echo '* `'$balances_path'` has been created'
    fi

    layout_path=${GENESIS_DIR}/layout.yaml
    ${CLI_BIN} genesis generate-layout-template \
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
    let total_supply=${NODE_COUNT}*3*${NODE_BALANCE}+${ADDITIONAL_ACCOUNTS}*${ADDITIONAL_ACCOUNT_BALANCE}
    sed -i 's/total_supply: ~/total_supply: '$total_supply'/g' $layout_path
    
    # @todo
    # sed -i 's/voting_duration_secs:.*/voting_duration_secs: 300/g' $layout_path
    # @todo
    # sed -i 's/epoch_duration_secs:.*/epoch_duration_secs: 120/g' $layout_path

    echo '* `'$layout_path'` has been created'

    echo "RUN: " ${CLI_BIN} genesis generate-genesis \
        --local-repository-dir ${GENESIS_DIR} \
        --output-dir ${GENESIS_DIR} \
        --mainnet \
        --assume-yes;

    ${CLI_BIN} genesis generate-genesis \
        --local-repository-dir ${GENESIS_DIR} \
        --output-dir ${GENESIS_DIR} \
        --mainnet \
        --assume-yes || exit 42
}

function fn__validator_config {
    let validator_port=${SVALIDATOR_PORT}+$1
    let fullnode_port=${SFULLNODE_PORT}+$i
    let public_port=${SPUBLIC_PORT}+$i
    let api_port=8079+$1

    declare -A configs
    configs[validator_config]=${VALIDATOR_CONFIG}
    configs[fullnode_config]=${FULLNODE_CONFIG}

    for var_name in validator_config fullnode_config; do
        config="${configs[$var_name]//GENESIS_DIR/"${GENESIS_DIR}"}"
        config="${config//API_PORT/"$api_port"}"
        config="${config//PUBLIC_PORT/"$public_port"}"
        config="${config//VALIDATOR_NETWORK_PORT/"$validator_port"}"
        configs[$var_name]="${config//FULLNODE_NETWORK_PORT/"$fullnode_port"}"
    done

    configs_path=${NODE_DIR}/v$1/configs
    mkdir -p $configs_path

    echo "${configs[validator_config]}" >$configs_path/validator.yaml
    echo "${configs[fullnode_config]}" >$configs_path/fullnode.yaml
}

function fn__set_pool_address {
    node_path=$1
    owner_address=$(cat $node_path/keys/important/owner.address)
    pool_address=$(${CLI_BIN} node get-stake-pool --owner-address $owner_address --url $node_url | jq .Result[0].pool_address | tr -d '"') || exit 38

    echo 'Pool address: ' $pool_address;
    if [[ $pool_address == ""] || [$pool_address == "null" ]]; then
        exit 39;
    fi
    echo $pool_address > $node_path/keys/important/pool.address

    find $node_path -type f -name "*.yaml" -exec \
        sed -i 's|^account_address:.*|account_address: '$pool_address'|g' {} \;
}

function fn__generate_seeds {
    node_url=http://localhost:8080
    output=$(${CLI_BIN} node show-validator-set --url $node_url)
    count=$(echo $output | jq '.Result.active_validators | length')

    validator_seeds=""
    seeds_fullnode=""
    for ((i = 0; i < $count; i++)); do
        account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
        validator_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.validator_network_addresses[0])
        fullnode_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.fullnode_network_addresses[0])

        validator_seeds="$validator_seeds
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
    validators) echo "$validator_seeds" ;;
    fullnodes) echo "$seeds_fullnode" ;;
    publics)
        echo "${seeds_fullnode//\/ip4\/0.0.0.0\/tcp\/101/\/ip4\/0.0.0.0\/tcp\/102}"
        ;;
    *)
        echo "$1 is not an option"
        exit 1
        ;;
    esac
}

function fn__init {
    fn__build_binaries || exit 10
    fn__build_framework || exit 20
    fn__validators_keys || exit 30
    fn__genesis || exit 40

    echo 'Node config:'
    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        fn__validator_config $i || exit 50
        echo ' * #'$i 'Success'
    done

    rm -rf ${NODE_DIR}/v1/data $config_path'.tmp' || true

    node_path=${NODE_DIR}/v1
    cd $node_path

    config_path=$node_path'/configs/validator.yaml'
    cp $config_path $config_path'.tmp'
    sed -i 's/FULLNODE_SEEDS_LIST/ {}/g' $config_path'.tmp'
    sed -i 's/PUBLIC_SEEDS_LIST/ {}/g' $config_path'.tmp'

    rm -rf ./data
    waypoint=$(cat ${GENESIS_DIR}/waypoint.txt);
    ${DEBUGGER_BIN} ${NAME}-db bootstrap ./data/db \
        --genesis-txn-file ${GENESIS_DIR}/genesis.blob \
        --waypoint-to-verify $waypoint \
        --commit || exit 51

    echo 'Run node:' ${NODE_BIN} --config $config_path'.tmp'
    ${NODE_BIN} --config $config_path'.tmp' &>/dev/null &
    node_pid=$!

    cd -

    node_url=http://localhost:8080
    curl $node_url --head -X GET \
        --retry-connrefused \
        --retry 30 \
        --retry-delay 1 &>/dev/null || exit 60;

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        echo "#$i set pool address"
        fn__set_pool_address ${NODE_DIR}/v$i
    done

    validator_seeds=$(fn__generate_seeds validators)
    fullnode_seeds=$(fn__generate_seeds fullnodes)
    public_seeds=$(fn__generate_seeds publics)

    kill $node_pid || exit 70

    rm -rf ${node_path}/v1/data ${node_path}/v1/db  $config_path'.tmp' || true

    echo 'Set seeds:'
    for path in $(
        find ${NODE_DIR} -type f \
            -name 'validator.yaml' -or \
            -name 'fullnode.yaml'
    ); do
        source=$(cat $path)
        source="${source//VALIDATOR_SEEDS_LIST/"${validator_seeds}"}"
        source="${source//FULLNODE_SEEDS_LIST/"${fullnode_seeds}"}"
        source="${source//PUBLIC_SEEDS_LIST/"${public_seeds}"}"
        echo "$source" >$path
    done
    echo "* success"

    echo 'v1: indexer is enabled'
    sed -i 's/false \# To enable the indexer/true \# To enable the indexer/g' ${NODE_DIR}/v1/configs/fullnode.yaml

    echo '= = = end = = ='
}

function fn__vfn {
    echo 'VFN'

    validator_port=10301
    fullnode_port=10302
    public_port=10303

    node_path=${NODE_DIR}/vfn
    owner_dir=$node_path/keys/important
    owner_path=$owner_dir/owner

    mkdir -p $owner_dir

    source_key=${ROOT_DIR}/additional_accounts/u1/user
    cp $source_key $owner_path
    cp $source_key.pub $owner_path.pub
    cp $source_key.address $owner_path.address

    fn__generating_keys_for_node $node_path $validator_port $fullnode_port || exit 1

    cd $node_path

    important_keys=$node_path/keys/important

    echo 'Creating profiles:'
    for tp in 'owner' 'operator' 'voter'; do
        ${CLI_BIN} init \
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

    echo 'Checking the owner balance:'
    balance=$(${CLI_BIN} account balance --profile mainnet-owner | jq .Result[0].balance) || exit 2
    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo 'Error: Insufficient balance '$balance
        exit 31
    else
        echo '* Owner balance: '$balance
    fi

    echo 'Checking the operator balance:'
    balance=$(${CLI_BIN} account balance --profile mainnet-operator | jq .Result[0].balance) || exit 3

    if [ $balance -lt ${MIN_AMOUNT} ]; then
        echo ${MIN_AMOUNT}
        ${CLI_BIN} account transfer \
            --account $operator_address \
            --amount ${MIN_AMOUNT} \
            --profile mainnet-owner \
            --assume-yes || exit 4
        echo '* The operator`s '$operator_address' balance has been replenished' ${MIN_AMOUNT}
    else
        echo '* Operator balance: '$balance
    fi

    echo 'Run the following command to initialize the staking pool:'

    ${CLI_BIN} stake create-staking-contract \
        --operator $operator_address \
        --voter $voter_address \
        --amount 100000000000000 \
        --commission-percentage 10 \
        --profile mainnet-owner \
        --assume-yes

    pool_address=$(${CLI_BIN} node get-stake-pool --owner-address $owner_address --profile mainnet-owner | jq .Result[0].pool_address | tr -d '"') || exit 6
    echo '* pool address created: '$pool_address

    echo 'Update on-chain network addresses:'
    ${CLI_BIN} node update-validator-network-addresses \
        --pool-address $pool_address \
        --operator-config-file keys/validator/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Update on-chain consensus key: '
    ${CLI_BIN} node update-consensus-key \
        --pool-address $pool_address \
        --operator-config-file keys/validator/operator.yaml \
        --profile mainnet-operator \
        --assume-yes

    echo 'Join the validator set:'
    ${CLI_BIN} node join-validator-set \
        --pool-address $pool_address \
        --profile mainnet-operator \
        --assume-yes

    for path in 'keys/validator-identity.yaml' 'keys/validator-full-node-identity.yaml'; do
        sed -i 's|account_address:.*|account_address: '$pool_address'|g' $path
        echo '* account_address has been updated in '$path
    done

    echo 'Genesis:'
    genesis_path=${GENESIS_DIR}/genesis.blob
    waypoint_path=${GENESIS_DIR}/waypoint.txt
    echo '* genesis_path: '$genesis_path
    echo '* waypoint_path: '$waypoint_path

    echo 'Configs:'
    mkdir -p config

    validator_seeds=$(fn__generate_seeds validators)
    fullnode_seeds=$(fn__generate_seeds fullnodes)
    public_seeds=$(fn__generate_seeds publics)

    config="${VALIDATOR_CONFIG//GENESIS_DIR/"${GENESIS_DIR}"}"
    config="${config//VALIDATOR_NETWORK_PORT/"$validator_port"}"
    config="${config//FULLNODE_NETWORK_PORT/"$fullnode_port"}"
    config="${config//PUBLIC_PORT/"$public_port"}"
    config="${config//VALIDATOR_SEEDS_LIST/"$validator_seeds"}"
    config="${config//FULLNODE_SEEDS_LIST/"$fullnode_seeds"}"
    config="${config//PUBLIC_SEEDS_LIST/"$public_seeds"}"
    echo "${config//API_PORT/18080}" >config/vfn.yaml
    echo '* config/vfn.yaml has been generated'

    cd -
}

function fn__vote_test {
    echo
    echo "Список голосования"
    echo

    ${CLI_BIN} governance list-proposals \
	    --url http://localhost:8080 || exit 1

    echo
    echo "Собрать скрипт"
    echo

    ${CLI_BIN} governance generate-upgrade-proposal \
        --account 0x1 \
        --package-dir test_update/ \
        --output ./update.move || exit 2

    echo
    echo "(V1) Предложить на голосование"
    echo
    
    private_key=$(cat ${NODE_DIR}/v1/keys/important/voter)
    pool_address=$(cat ${NODE_DIR}/v1/keys/important/pool.address)


    echo ${CLI_BIN} governance propose \
        --script-path ./update.move \
        --url http://localhost:8080 \
        --private-key $private_key \
        --pool-address $pool_address \
        --metadata-url "https://raw.githubusercontent.com/aptos-foundation/mainnet-proposals/refs/heads/main/metadata/2023-05-26-disable-signature-checker-v2/disable-signature-checker.json" \
        --max-gas 100000 \
        --expiration-secs 600 \
        --assume-yes


    proposal_id=$(${CLI_BIN} governance propose \
        --script-path ./update.move \
        --url http://localhost:8080 \
        --private-key $private_key \
        --pool-address $pool_address \
        --metadata-url "https://raw.githubusercontent.com/aptos-foundation/mainnet-proposals/refs/heads/main/metadata/2023-05-26-disable-signature-checker-v2/disable-signature-checker.json" \
        --max-gas 100000 \
        --expiration-secs 600 \
        --assume-yes ) || exit 3

    proposal_id="{ ${proposal_id#*{}" ;
    proposal_id=$(echo $proposal_id | jq .Result.proposal_id)

    echo
    echo "[$proposal_id] Статус голосования"
    echo 

    ${CLI_BIN} governance show-proposal \
        --url http://localhost:8080 \
        --proposal-id $proposal_id || exit 4


    echo "[$proposal_id] Голосование других участников"

    for i in {2..6}; do

        echo
        echo "[$proposal_id] Голосование участника $i"
        echo

        private_key=$(cat ${NODE_DIR}/v${i}/keys/important/voter)
        pool_address=$(cat ${NODE_DIR}/v${i}/keys/important/pool.address)

        ${CLI_BIN} governance vote \
            --proposal-id $proposal_id \
            --pool-addresses $pool_address \
            --private-key $private_key \
            --voting-power 100000000000000 \
            --url http://localhost:8080 \
            --yes \
            --assume-yes || exit 5
    done

    echo
    echo "[$proposal_id] Статус голосования"
    echo 

    echo "${CLI_BIN} governance show-proposal \
        --url http://localhost:8080 \
        --proposal-id $proposal_id"
    
    ${CLI_BIN} governance show-proposal \
        --url http://localhost:8080 \
        --proposal-id $proposal_id || exit 7


    echo
    echo "[$proposal_id] Выполнение скрипта."
    echo "Нужно выполнить после завершения времени на голосование"
    echo "Достаточно выполнить на одной машине и на остальные само раскатится"
    echo 

    private_key=$(cat ${NODE_DIR}/v6/keys/important/voter)
    pool_address=$(cat ${NODE_DIR}/v6/keys/important/pool.address)

    echo "${CLI_BIN} governance execute-proposal \
        --proposal-id $proposal_id \
        --private-key $private_key \
        --url http://localhost:8085 \
        --script-path ./update.move"

}

fn__necessary_programs

case $1 in
init) fn__init ;;
run) process-compose -p 8070 ;;
stop) pkill 'process-compose' -9 ;;
clear) rm -rf additional_accounts genesis node ;;
clear_data) find ./ -type d -name data -exec rm -rf {} \; ;;
clear_db) find ./ -type d -name db -exec rm -rf {} \; ;;
vfn) fn__vfn ;;
vfn_run)
    cd node/vfn
    ${NODE_BIN} --config config/vfn.yaml
    ;;
vote) fn__vote_test ;;
*) echo "$1 is not an option" ;;
esac

# GIT_SOURCE=<PATH/TO/SOURCE> ./script.sh init
# ./script.sh run
# ./script.sh vfn
# ./script.sh clear