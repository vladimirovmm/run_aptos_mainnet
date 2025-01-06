#!/bin/bash

ROOT_DIR=$(realpath '.')
BIN_DIR=${ROOT_DIR}/bin
GENESIS_DIR=${ROOT_DIR}/genesis
GENESIS_USERS_DIR_NAME=users
GENESIS_USERS_DIR=${GENESIS_DIR}/${GENESIS_USERS_DIR_NAME}
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
        identity_blob_path: "validator-identity.yaml"

execution:
  genesis_file_location: "GENESIS_DIR/genesis.blob"

validator_network:
  discovery_method: "onchain"
  listen_address: "/ip4/0.0.0.0/tcp/VALIDATOR_NETWORK_PORT"
  identity:
    type: "from_file"
    path: "validator-identity.yaml"
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

VFN_CONFIG='base:
  role: "validator"
  data_dir: "./data"
  waypoint:
    from_file: WAYPOINT_PATH

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
          from_file: WAYPOINT_PATH
        identity_blob_path: ./keys/validator-identity.yaml

execution:
  genesis_file_location: GENESIS_PATH

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
        from_file: WAYPOINT_PATH

execution:
    genesis_file_location: GENESIS_PATH

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

function fn__bins {
    echo 'Preparing binaries'

    if [ -z ${APTOS_SOURCE} ]; then
        echo 'The path to `Aptos` not specified. Specify it through the environment `APTOS_SOURCE`'
        exit 12
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
        cargo build -p $package --release
        cp target/release/$package ${BIN_DIR}/$package
    done
    cd -
}

function fn__keys {
    echo 'Generating keys'

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        node_path=${NODE_DIR}/v$i
        if [ ! -d $node_path ]; then
            ${APTOS_BIN} genesis generate-keys --output-dir $node_path --assume-yes
            echo '* `'$node_path'` has been generated'
        else
            echo '* `'$node_path'` already exists'
        fi
    done

    # genesis keys
    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        user_dir=${GENESIS_USERS_DIR}/v$i

        if [ -d $user_dir ]; then
            echo '* '$user_dir' already exist'
            continue
        fi

        let vport=${SVALIDATOR_PORT}+$i
        let fport=${SFULLNODE_PORT}+$i

        ${APTOS_BIN} genesis set-validator-configuration \
            --username v$i \
            --owner-public-identity-file ${NODE_DIR}/v$i/public-keys.yaml \
            --validator-host 0.0.0.0:$vport \
            --full-node-host 0.0.0.0:$fport \
            --local-repository-dir ${GENESIS_USERS_DIR} \
            --stake-amount ${MIN_AMOUNT} \
            --join-during-genesis \
            --commission-percentage 10
    done

    echo 'Keys for genesis:'
    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        for tp in 'owner' 'operator' 'voter'; do
            path_dir=${NODE_DIR}/v$i/additional
            mkdir -p $path_dir
            file_path=$path_dir/$tp

            if [ ! -f $file_path ]; then
                account_address=$(${APTOS_BIN} key generate --vanity-prefix 0x --output-file $file_path --assume-yes | grep -om 1 "0x[0-9a-f]*")
                echo $account_address >$file_path.address
                echo '*' $file_path 'has been generated'

                public_key=$(cat $path_dir/$tp'.pub')

                for conf in 'operator.yaml' 'owner.yaml'; do
                    path=${GENESIS_USERS_DIR}/v$i/$conf

                    sed -i 's/'$tp'_account_public_key:.*/'$tp'_account_public_key: '$public_key'/g' $path
                    sed -i 's/'$tp'_network_public_key:.*/'$tp'_network_public_key: '$public_key'/g' $path
                    sed -i 's/'$tp'_account_address:.*/'$tp'_account_address: "'$account_address'"/g' $path

                    echo '* * ' $tp 'in' $path 'has been replaced'
                done

            else
                echo '* '$file_path' already exists'
            fi
        done
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
        account_address=$(${APTOS_BIN} key generate --vanity-prefix 0x --output-file $file_path --assume-yes | grep -om 1 "0x[0-9a-f]*")
        echo $account_address >$file_path.address
        echo '*' $file_path 'has been generated'

    done
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
    cargo run --package aptos-framework -- release --target mainnet
    cd -

    mv ${APTOS_SOURCE}/mainnet.mrb $framefork_path
}

function fn__genesis {
    echo 'Building genesis'

    genesis_path=${GENESIS_DIR}/genesis.blob
    if [ -f ${genesis_path} ]; then
        echo '*' ${genesis_path} 'exist'
        return
    fi

    emp_path=${GENESIS_DIR}/employee_vesting_accounts.yaml
    if [ -f ${emp_path} ]; then
        echo '*' ${emp_path} 'exist'
    else
        echo '* `'$emp_path'` has been created'
        echo '[]' >$emp_path
    fi

    bal_path=${GENESIS_DIR}/balances.yaml

    if [ -f ${bal_path} ]; then
        echo '*' ${bal_path} 'exist'
    else
        echo '' >$bal_path
        for file in $(find ${NODE_DIR} -name *.address -type f); do
            address=$(cat $file)
            echo '-' $address': '${NODE_BALANCE} >>$bal_path
        done
        for file in $(find ${ADDITIONAL_ACCOUNTS_DIR} -name *.address -type f); do
            address=$(cat $file)
            echo '-' $address': '${ADDITIONAL_ACCOUNT_BALNACE} >>$bal_path
        done

        echo '* `'$bal_path'` has been created'
    fi

    layout_path=${GENESIS_DIR}/layout.yaml
    if [ ! -f $layout_path ]; then
        ${APTOS_BIN} genesis generate-layout-template --output-file $layout_path --assume-yes
        sed -i 's/root_key: ~//g' $layout_path

        users=""
        for ((i = 1; i <= ${NODE_COUNT}; i++)); do
            users=${users}'"'${GENESIS_USERS_DIR_NAME}'/v'$i'", '
        done

        users=$(printf '%s' ${users::-2})

        sed -i 's|users: \[\]|users: \['${users}'\]|g' $layout_path
        sed -i 's/chain_id: 4/chain_id: 1/g' $layout_path
        sed -i 's/allow_new_validators: false/allow_new_validators: true/g' $layout_path
        sed -i 's/is_test: true/is_test: false/g' $layout_path
        let total_supply=${NODE_COUNT}*3*${NODE_BALANCE}+${ADDITIONAL_ACCOUNTS}*${ADDITIONAL_ACCOUNT_BALNACE}
        sed -i 's/total_supply: ~/total_supply: '$total_supply'/g' $layout_path
        echo '* `'$layout_path'` has been created'
    else
        echo '* `'$layout_path'` already exists'
    fi

    cd genesis

    ${APTOS_BIN} genesis generate-genesis \
        --local-repository-dir . \
        --mainnet \
        --assume-yes
    cd -
}

function fn__validator_config {
    let vport=${SVALIDATOR_PORT}+$1
    let fport=${SFULLNODE_PORT}+$i
    let api_port=8079+$1

    config=${VALIDATOR_CONFIG}
    config="${config//GENESIS_DIR/"${GENESIS_DIR}"}"
    config="${config//API_PORT/"$api_port"}"
    config="${config//VALIDATOR_NETWORK_PORT/"$vport"}"

    echo "$config" >${NODE_DIR}/v$1/validator.yaml
}

function fn__init {

    fn__bins || { exit 21; }
    fn__build_framefork || { exit 22; }
    fn__keys || { exit 23; }
    fn__genesis || { exit 24; }

    for ((i = 1; i <= ${NODE_COUNT}; i++)); do
        fn__validator_config $i || { exit 25; }
    done

    node_url=http://localhost:8080

    cd ${NODE_DIR}/v1

    ${APTOS_NODE_BIN} --config validator.yaml &
    node_pid=$!

    curl $node_url --head -X GET \
        --retry-connrefused \
        --retry 30 \
        --retry-delay 1 &>/dev/null

    output=$(${APTOS_BIN} node show-validator-set --url $node_url)
    kill $node_pid

    rm -rf data_validator

    cd -

    for ((i = 0; i < ${NODE_COUNT}; i++)); do
        account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
        consensus_public_key=$(echo $output | jq .Result.active_validators[$i].config.consensus_public_key)

        echo $account_address

        folder=$(dirname $(grep -rl 'consensus_public_key: '$consensus_public_key --include='public-keys.yaml'))

        find $folder -type f -name "*.yaml" -exec \
            sed -i 's|account_address:.*|account_address: '$account_address'|g' {} \;
    done
    echo '= = = end = = ='
}

function fn__clear {
    rm -rf v1 v2 v3 v4 v5 genesis
}

function fn__generate_key {
    if [ -z "$1" ]; then
        echo 'Error: An empty path was passed'
        exit 41
    fi

    if [ -f $1 ]; then
        echo '* '$1' already exists'
        return
    fi

    account_address=$(${APTOS_BIN} key generate --vanity-prefix 0x --output-file $1 --assume-yes | grep -om 1 "0x[0-9a-f]*") || exit 42
    echo $account_address >$1.address
    echo '*' $1 'has been generated'
}

function fn__vfn {
    echo 'VFN'

    mkdir -p vfn
    cd vfn

    echo 'Generating a configuration file with keys:'
    vport=10201
    fport=10202
    if [ ! -f keys/public-keys.yaml ]; then
        ${APTOS_BIN} genesis generate-keys --output-dir ./keys --assume-yes
        ${APTOS_BIN} genesis set-validator-configuration \
            --local-repository-dir . \
            --username vfn \
            --owner-public-identity-file keys/public-keys.yaml \
            --validator-host 0.0.0.0:$vport \
            --full-node-host 0.0.0.0:$fport \
            --stake-amount ${MIN_AMOUNT}
        echo '* The `public-keys.yaml` keys have been generated'
    else
        echo '* The `public-keys.yaml` keys already exist'
    fi

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

    echo 'Gensesis:'
    genesis_path=${GENESIS_DIR}/genesis.blob
    waypoint_path=${GENESIS_DIR}/waypoint.txt
    echo '* genesis_path: '$genesis_path
    echo '* waypoint_path: '$waypoint_path

    echo 'Configs:'

    if [ ! -f config/validator.yaml ]; then
        mkdir -p config

        node_url=http://localhost:8080
        output=$(${APTOS_BIN} node show-validator-set --url $node_url)
        count=$(echo $output | jq '.Result.active_validators | length')

        seeds_validator=""
        seeds_full_node=""
        for ((i = 0; i < $count; i++)); do
            account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
            validator_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.validator_network_addresses[0])
            fullnode_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.fullnode_network_addresses[0])

            seeds_validator="$seeds_validator
        $account_address:
            addresses:
                - $validator_network_addresses
            role: Validator"
            seeds_full_node="$seeds_full_node
        $account_address:
            addresses:
                - $fullnode_network_addresses
            role: ValidatorFullNode"
        done
        echo '* seeds config has been genirated'
        # wget -O config/validator.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/validator.yaml

        config=${VFN_CONFIG}

        config="${config//WAYPOINT_PATH/"$waypoint_path"}"
        config="${config//GENESIS_PATH/"$genesis_path"}"
        config="${config//FULL_NODE_NETWORKS_PORT/"$fport"}"
        config="${config//SEEDS_LIST/"$seeds_validator"}"
        echo "$config" >config/validator.yaml
        echo '* config/validator.yaml has been generated'
    else
        echo '* config has already exist '
    fi

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
    seeds_full_node=""
    for ((i = 0; i < $count; i++)); do
        account_address=$(echo $output | jq .Result.active_validators[$i].account_address)
        validator_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.validator_network_addresses[0])
        fullnode_network_addresses=$(echo $output | jq .Result.active_validators[$i].config.fullnode_network_addresses[0])

        seeds_validator="$seeds_validator
          $account_address:
              addresses:
                  - $validator_network_addresses
              role: Validator"
        seeds_full_node="$seeds_full_node
          $account_address:
              addresses:
                  - $fullnode_network_addresses
              role: ValidatorFullNode"
    done
    echo '* seeds config has been genirated'

    # wget -O config/fullnode.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/mainnet/docker/compose/aptos-node/fullnode.yaml

    config=${PFN_CONFIG}

    config="${config//WAYPOINT_PATH/"$waypoint_path"}"
    config="${config//GENESIS_PATH/"$genesis_path"}"
    config="${config//VFN_PORT/"$vport"}"
    config="${config//PUBLIC_PORT/"$fport"}"
    config="${config//VALIDATOR_SEEDS_LIST/"$seeds_validator"}"
    config="${config//FULLNODE_SEEDS_LIST/"$seeds_full_node"}"
    echo "$config" >config/fullnode.yaml
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
pfn) fn__pfn ;;
clear) rm -rf additional_accounts genesis node vfn ;;
clear_data) find ./ -type d -name data_validator -exec rm -rf {} \; ;;
*) echo "$1 is not an option" ;;
esac

# APTOS_SOURCE=<PATH/TO/SOURCE> ./script.sh init
# ./script.sh run
# ./script.sh vfn
# ./script.sh clear
