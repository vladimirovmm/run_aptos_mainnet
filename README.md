# Поднятие Aptos Mainnet для локального тестирования

## Подгатовка базовых нод
* Создать конфиги и ключи для нод
* Прописать ноды в генезисе и собрать генезис
* Прописать пулы в конфигах нод

```bash
APTOS_SOURCE=<PATH/TO/SOURCE/APTOS-CORE>  ./script.sh init
```

## Запуск нод

```bash
./script.sh run
```

# Динамическое добавление VFN ноды

## Инициализация VFN

```bash
./script.sh vfn
```

## Запуск VFN

```bash
./script.sh vfn_run
```

