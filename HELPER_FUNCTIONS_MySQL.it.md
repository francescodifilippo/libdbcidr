# Funzioni di Supporto per la Gestione delle Subnet IP (MySQL)

Questo documento descrive le funzioni di supporto essenziali necessarie per le operazioni sulle subnet IP in MySQL. Queste funzioni forniscono i blocchi fondamentali per le operazioni di gestione delle subnet più complesse.

## Lingue della Documentazione

- [English](./HELPER_FUNCTIONS_MySQL.en.md)
- [Italiano](./HELPER_FUNCTIONS_MySQL.it.md)
- [Latina](./HELPER_FUNCTIONS_MySQL.la.md)
- [Esperanto](./HELPER_FUNCTIONS_MySQL.eo.md)

## Installazione

Per installare queste funzioni di supporto nel tuo database MySQL, esegui i seguenti comandi SQL:

```sql
-- Funzione di supporto per ottenere l'indirizzo di rete da un IP e CIDR
CREATE FUNCTION GET_NETWORK_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN INET_NTOA(ip_num & mask);
END;

-- Funzione di supporto per ottenere l'indirizzo di broadcast da un IP e CIDR
CREATE FUNCTION GET_BROADCAST_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    DECLARE broadcast BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    SET broadcast = ip_num | (POWER(2, 32 - cidr) - 1);
    
    RETURN INET_NTOA(broadcast);
END;
```

## Descrizione delle Funzioni

### GET_NETWORK_ADDRESS

Questa funzione calcola l'indirizzo di rete per un dato indirizzo IP e lunghezza di prefisso CIDR.

#### Sintassi

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Una stringa che rappresenta un indirizzo IPv4 (es., '192.168.1.1')
- **cidr**: Un intero che rappresenta la lunghezza del prefisso CIDR (0-32)

#### Valore di Ritorno

Restituisce una stringa contenente l'indirizzo di rete in notazione decimale puntata.

#### Come Funziona

La funzione:
1. Converte l'indirizzo IP in un valore numerico usando la funzione `INET_ATON()` di MySQL
2. Calcola la subnet mask dalla lunghezza del prefisso CIDR
3. Applica un'operazione AND bit a bit tra l'IP e la mask per ottenere l'indirizzo di rete
4. Converte il risultato in notazione decimale puntata usando `INET_NTOA()`

### GET_BROADCAST_ADDRESS

Questa funzione calcola l'indirizzo di broadcast per un dato indirizzo IP e lunghezza di prefisso CIDR.

#### Sintassi

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Una stringa che rappresenta un indirizzo IPv4 (es., '192.168.1.1')
- **cidr**: Un intero che rappresenta la lunghezza del prefisso CIDR (0-32)

#### Valore di Ritorno

Restituisce una stringa contenente l'indirizzo di broadcast in notazione decimale puntata.

#### Come Funziona

La funzione:
1. Converte l'indirizzo IP in un valore numerico usando la funzione `INET_ATON()` di MySQL
2. Calcola la subnet mask dalla lunghezza del prefisso CIDR
3. Applica un'operazione OR bit a bit tra l'IP e l'inverso della mask per ottenere l'indirizzo di broadcast
4. Converte il risultato in notazione decimale puntata usando `INET_NTOA()`

## Esempi

### Trovare l'Indirizzo di Rete

```sql
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24);
-- Restituisce '192.168.1.0'

SELECT GET_NETWORK_ADDRESS('10.45.67.89', 16);
-- Restituisce '10.45.0.0'

SELECT GET_NETWORK_ADDRESS('172.16.28.30', 20);
-- Restituisce '172.16.16.0'
```

### Trovare l'Indirizzo di Broadcast

```sql
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24);
-- Restituisce '192.168.1.255'

SELECT GET_BROADCAST_ADDRESS('10.45.67.89', 16);
-- Restituisce '10.45.255.255'

SELECT GET_BROADCAST_ADDRESS('172.16.28.30', 20);
-- Restituisce '172.16.31.255'
```

### Usare Entrambe le Funzioni Insieme

```sql
-- Trovare sia l'indirizzo di rete che di broadcast per una subnet
SELECT 
    GET_NETWORK_ADDRESS('192.168.5.37', 22) AS indirizzo_rete,
    GET_BROADCAST_ADDRESS('192.168.5.37', 22) AS indirizzo_broadcast;
-- Restituisce:
-- indirizzo_rete: '192.168.4.0'
-- indirizzo_broadcast: '192.168.7.255'

-- Verificare se un IP è in una specifica subnet
SELECT 
    '10.20.30.40' AS ip,
    '10.20.0.0/16' AS subnet,
    (INET_ATON('10.20.30.40') BETWEEN 
     INET_ATON(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
     INET_ATON(GET_BROADCAST_ADDRESS('10.20.0.0', 16))) AS è_nella_subnet;
-- Restituisce 1 (TRUE) indicando che l'IP è nella subnet
```

## Note

- Queste funzioni si basano sulle funzioni integrate `INET_ATON()` e `INET_NTOA()` di MySQL, disponibili in MySQL 5.6.3 e versioni successive.
- Le funzioni hanno l'attributo `DETERMINISTIC`, che aiuta con l'ottimizzazione delle query.
- Queste funzioni di supporto sono prerequisiti richiesti per le altre funzioni di gestione delle subnet:
  - `CHECK_SUBNET_RELATIONSHIP`
  - `FIND_SUBNETS_AGGREGATE`
  - `LIST_UNWANTED_SUBNETS`
- L'attuale implementazione supporta solo indirizzi IPv4.
