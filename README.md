# Поднятие Aptos Mainnet для локального тестирования

## Демо развертывание

### Создание генезиса и конфигурация для нод

Будет создано 6 нод

```bash
APTOS_SOURCE=<PATH/TO/SOURCE/APTOS-CORE>  ./script.sh init
```

### Запуск нод

```bash
./script.sh run
```

### Инициализация VFN

```bash
./script.sh vfn
```

## $ Запуск VFN

> ВНИМАНИЕ: Новая нода начнёт работать только со следующей эпохи
> Проверить статус ноды можно командой
>
> ```bash
> aptos node show-validator-set --url http://localhost:8080
> ```

```bash
./script.sh vfn_run
```

## Как поднять вручную

### Заметки

#### Порты

В конфигах будут использоваться порты

* network_id: "validator" - 1000***N***
* network_id: "vfn" - 1010***N***
* network_id: "public" - 1020***N***

Где ***N*** порядковый номер ноды

Любой из указанных портов может быть заменен, на свободный порт

#### Директории

Назначение директорий

* bin - для хранения программ
* genesis - Настройки, framework и собранный генезис
* node - Папки для нод.
* additional_accounts - Аккаунты которые будут добавлены в генезис и содержать баланс.

### 1. Создании директорий для проекта

Имя может быть любое.

```bash
mkdir -p project_dir \
    project_dir/bin \
    project_dir/genesis \
    project_dir/node \
    project_dir/additional_accounts
```

Переходим в директорию

```bash
cd project_dir
```

Все остальные инструкции будут выполняться из под этой директории. \
Кроме сборки aptos, aptos-node, framework

### 2. Подготовка: aptos-node | aptos

Готовые бинари можно скачать из github
[Aptos-Core: Releases](https://github.com/aptos-labs/aptos-core/releases)

Или собрать локально, скачав исходник [aptos-core](https://github.com/aptos-labs/aptos-core) и запустив в корне проекта aptos-core

```bash
aptos-core$ cargo build -p aptos-node --release 
aptos-core$ cargo build -p aptos --release
```

Полученные бинари скопировать в папку <PROJECT_DIR>/bin.

```bash
cp target/release/aptos-node <PROJECT_DIR>/bin
cp target/release/aptos <PROJECT_DIR>/bin
```

<PROJECT_DIR>:

* bin
  * aptos-core
  * aptos

### 3. Подготовка: Aptos Framework

Собрать его можно из [исходников](https://github.com/aptos-labs/aptos-core) и запустив в корне проекта aptos-core

```bash
aptos-core$ cargo run --package aptos-framework -- release --target mainnet
```

Копируем его к себе в проект

```bash
cp mainnet.mrb <PROJECT_DIR>/genesis/framework.mrb
```

<PROJECT_DIR>:

* bin
  * aptos-core
  * aptos
* genesis
  * framework.mrb

### 4. Ключи

#### 4.1 Ключи для нод

Их будет 6

```bash
aptos genesis generate-keys --output-dir node/v1/keys --assume-yes
aptos genesis generate-keys --output-dir node/v2/keys --assume-yes
aptos genesis generate-keys --output-dir node/v3/keys --assume-yes
aptos genesis generate-keys --output-dir node/v4/keys --assume-yes
aptos genesis generate-keys --output-dir node/v5/keys --assume-yes
aptos genesis generate-keys --output-dir node/v6/keys --assume-yes
```

##### 4.1.1 Конфигурация для валидатора

**Повторить 6 раз** для каждой ноды где **N** номер ноды

```bash
aptos genesis set-validator-configuration \
    --local-repository-dir node/v__И__/keys \
    --owner-public-identity-file node/vИ/keys/keys/public-keys.yaml \
    --username validator \
    --validator-host 0.0.0.0:1000И \
    --full-node-host 0.0.0.0:1010И \
    --stake-amount 100000000000000 \
    --join-during-genesis
```

##### 4.1.2 Ключи для 'owner' 'operator' 'voter'

В конфигах для этих аккаунтов используется одни и те же данные. Нужно для них с генерировать новые ключи и подставить их во всех конфигах ноды

###### 4.1.2.1 Генерация ключей

Сгенерированные ключи будут храниться в папке
`node/vN/keys/important`

В конченом результате у каждой ноды будут эти файлы

* node/vN/keys/important/owner'
* node/vN/keys/important/owner.pub'
* node/vN/keys/important/owner.address'
* node/vN/keys/important/operator'
* node/vN/keys/important/operator.pub'
* node/vN/keys/important/operator.address'
* node/vN/keys/important/voter'
* node/vN/keys/important/voter.pub'
* node/vN/keys/important/voter.address'

Создание директории для ключей

```bash
mkdir -p node/vN/keys/important
```

Генерация для *owner*

```bash
( 
    account_address=$(aptos key generate --vanity-prefix 0x --output-file node/vN/keys/important/owner --assume-yes | grep -om 1 "0x[0-9a-f]*") 
    echo $account_address >node/vN/keys/important/owner.address 
)
```

Генерация для *operator*

```bash
( 
    account_address=$(aptos key generate --vanity-prefix 0x --output-file node/vN/keys/important/operator --assume-yes | grep -om 1 "0x[0-9a-f]*") 
    echo $account_address >node/vN/keys/important/operator.address 
)
```

Генерация для *voter*

```bash
( 
    account_address=$(aptos key generate --vanity-prefix 0x --output-file node/vN/keys/important/voter --assume-yes | grep -om 1 "0x[0-9a-f]*") 
    echo $account_address >node/vN/keys/important/voter.address 
)
```

##### 4.1.3 Замена в конфигах на новые ключи

В конфигах ноды необходимо найти данные

* <TYPE>_account_address
* <TYPE>_account_public_key

Где <TYPE> равен

* owner
* operator
* voter

и подставить на значения из папки `node/vN/keys/important`

```bash
(
    for fpath in $(find <NODE_PATH> -type f -name '*.yaml'); do
        sed -i 's/<TYPE>_account_address:.*/<TYPE>_account_address: <ACCOUNT_ADDRESS>/g' $fpath
        sed -i 's/<TYPE>_account_public_key:.*/<TYPE>_account_public_key: <PUBLIC_KEY>/g' $fpath
        sed -i 's/<TYPE>_account_private_key:.*/<TYPE>_account_public_key: <PUBLIC_KEY>/g' $fpath
    done
)
```

#### 4.2 Дополнительные аккаунты

Эти аккаунты будут использованы при генерации генезиса. На них будут зачислены конины.

Храниться ключи будут в <PROJECT_DIR>/additional_accounts/uN/

```bash
mkdir -p additional_accounts/uN
(
    account_address=$(aptos key generate --vanity-prefix 0x --output-file additional_accounts/uN/user --assume-yes | grep -om 1 "0x[0-9a-f]*")
    echo $account_address >additional_accounts/uN/user.address
)
```

### 5. Генезис

Для генерации генезиса потребуются эти файлы

* genesis/framework.mrb
* genesis/employee_vesting_accounts.yaml
* genesis/balances.yaml
* genesis/layout.yaml

В результате будут сгенерированныe

* genesis/genesis.blob
* genesis/waypoint.txt

#### 5.1 employee_vesting_accounts.yaml

В нашем случае этот конфиг будет пустым, так как будут использованы конфигурации валидатора. Они друг друга взаимозаменяют

Создаем пустой конфиг

```bash
echo '[]' >genesis/employee_vesting_accounts.yaml
```

#### 5.2 balances.yaml

Сюда необходимо добавить все созданные нами новые аккаунты.

Вот эти

```bash
find . -name *.address -exec cat {} \;
```

Формат записи

```yaml
- 0x45a492c3f33ee10cbf06f4714d5ea55d864a949b785b6e5fe22a75ddc524e2d: 100000000000000000
- 0xb76cff661db216a2fd78d47d443a533880c8467b7c156b4532d6f0f894b7f3e7: 100000000000000000
- 0x686ca7792507f30b032fec083e1b230e1fe624a9da0bc339f13f18f27eb3d979: 100000000000000000
...
- <ADDRESS>: <AMOUNT>
```

#### 5.3 layout.yaml

Это основной конфиг для genesis

Шаблон для layout.yaml

```bash
aptos genesis generate-layout-template \
    --output-file genesis/layout.yaml \
    --assume-yes
```

В нем нужно

* удалить
  * строку root_key: ~

* заменить

  * chain_id: `4` => chain_id: `1`
  * allow_new_validators: `false` => allow_new_validators: `true`
  * is_test: `true` => is_test: `false`
  * total_supply: `~` => total_supply: `На общую сумму из balances.yaml`
* Подставить список путей до конфигов валидатора
  * users: `[]` => users: `["../node/v1/keys/validator", "../node/v2/keys/validator", .... "../node/vN/keys/validator"]`

Результат

```yaml

---
users:
  [
    "../node/v1/keys/validator",
    "../node/v2/keys/validator",
    "../node/v3/keys/validator",
    "../node/v4/keys/validator",
    "../node/v5/keys/validator",
    "../node/v6/keys/validator",
  ]
chain_id: 1
allow_new_validators: true
epoch_duration_secs: 7200
is_test: false
min_stake: 100000000000000
min_voting_threshold: 100000000000000
max_stake: 100000000000000000
recurring_lockup_duration_secs: 86400
required_proposer_stake: 100000000000000
rewards_apy_percentage: 10
voting_duration_secs: 43200
voting_power_increase_limit: 20
total_supply: 2800000000000000000
employee_vesting_start: 1663456089
employee_vesting_period_duration: 300

...

```

#### 5.4 Генерация генезиса

```bash
aptos genesis generate-genesis \
    --local-repository-dir genesis \
    --output-dir genesis \
    --mainnet \
    --assume-yes
```

### 6. Конфигурации для нод

Нужно создать минимум 5 валидаторов

#### 6.1 Шаблоны

Что нужно заменить в шаблонах

* GENESIS_DIR - путь до папки с генезисом
* VALIDATOR_NETWORK_PORT - 1000***N***
* FULLNODE_NETWORK_PORT - 1010***N***
* PUBLIC_PORT - 1020***N***
* FULLNODE_SEEDS_LIST - берется из `aptos node show-validator-set --url <http://localhost:8080>` fullnode_network_addresses
* PUBLIC_SEEDS_LIST - берется из `aptos node show-validator-set --url <http://localhost:8080>` fullnode_network_addresses из подменяется порт 1020N на 1030N
* API_PORT - 808***N***

##### 6.1.1 Шаблон для Validator

```yaml
base:
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
    port: 0
```

##### 6.1.2 Шаблон для Fullnode

```yaml
base:
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
      listen_address: "/ip4/0.0.0.0/tcp/VALIDATOR_NETWORK_PORT"
      identity:
          type: "from_file"
          path: "keys/validator-identity.yaml"
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
    port: 0
```

#### 6.2 Копируем шаблон для всех нод

В директории каждой ноды создаём 2 конфига

node/vN/configs/validator.yaml - используется шаблон 6.1.1
node/vN/configs/fullnode.yaml - используется шаблон 6.1.2 (Можно пропустить)

заменяем в них

* GENESIS_DIR - на путь до genesis директории
* VALIDATOR_NETWORK_PORT - 1000N
* FULLNODE_NETWORK_PORT - 1010N
* PUBLIC_PORT - 1020N
* API_PORT - 808{N-1}

#### 6.2 Временый старт и замена `account_address` и `seeds`

Переходим в 1 ноду

```bash
cd node/v1
```

Закомментируем в configs/validator.yaml секцию full_node_networks

Запускаем

```bash
../../bin/aptos-node --config configs/validator.yaml
```

##### 6.2.1 pool_address

Для каждой ноды необходимо заменить account_address во всех конфигах на pool_address

Пример для v1

```bash
(
    owner_address=$(cat ../v1/keys/important/owner.address)
    pool_address=$(../../bin/aptos node get-stake-pool --owner-address $owner_address --url http://localhost:8080 | jq .Result[0].pool_address | tr -d '"') 
    find ../v1 -type f -name "*.yaml" -exec \
        sed -i 's|^account_address:.*|account_address: '$pool_address'|g' {} \;
)
```

Эту операцию нужно проделать для всех нод

##### 6.2.2 Список сидов

Если не установить в конфига список сидов то он будет установлен на aptos mainnet

Получаем данные из генезиса о валидаторах

```bash
aptos node show-validator-set --url http://localhost:8080 | jq .Result.active_validators 
```

Из списка нужно сформировать вот такого формата конфиг

```yaml
"e4a3f1f4214a935f5eabab759627f023c48ae0bfc325fa360be8a17c4a30e55d": # ACCTOUN_ADDRESS
    addresses:
        - "/ip4/0.0.0.0/tcp/10106/noise-ik/0xf3bc6a0eaa78f5e51f593735731c57ed3b6383e27cb40c22babde107cbdb4223/handshake/0"
    role: ValidatorFullNode
"91a6ccd59c808952baa5a9c74e80df870bb46ca29ad231e26bb7154120769aa2":
    addresses:
        - "/ip4/0.0.0.0/tcp/10105/noise-ik/0x0153aacf2ceb23e87ad13483c34715901729fe15a03557c90d3f01dc1e65d34c/handshake/0"
    role: ValidatorFullNode
    ...
```

и подставить его за место FULLNODE_SEEDS_LIST во всех файлах fullnode.yaml и validator.yaml
PUBLIC_SEEDS_LIST - тоже самое что и FULLNODE_SEEDS_LIST только в них нужно заменить порты с 1010N а 1020N

##### 6.2.3 Чистим v1

Нужно вернуть закомментированный блок из 6.2 и удалить директорию node/v1/data

### 7. Запуск

Открываем отдельный терминал для каждой ноды и запускаем её

```
cd node/vN
../../bin/aptos-node --config configs/validator.yaml
```
