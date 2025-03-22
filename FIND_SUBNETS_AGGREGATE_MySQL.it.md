# Funzione FIND_SUBNETS_AGGREGATE (MySQL)

Questa funzione calcola la subnet aggregata minima che comprende tutte le subnet IP fornite.

## Lingue della Documentazione

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

## Installazione

Per installare questa funzione nel tuo database MySQL, esegui i seguenti comandi SQL in ordine:

1. Prima, installa le funzioni di supporto se non l'hai già fatto:
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

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE:
```sql
CREATE FUNCTION FIND_SUBNETS_AGGREGATE(subnet_list TEXT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE total_subnets INT;
    DECLARE current_subnet VARCHAR(50);
    DECLARE ip VARCHAR(15);
    DECLARE cidr INT;
    DECLARE min_ip BIGINT;
    DECLARE max_ip BIGINT;
    DECLARE current_ip BIGINT;
    DECLARE common_bits INT DEFAULT 32;
    DECLARE aggregate_cidr INT;
    DECLARE aggregate_ip BIGINT;
    
    -- Dividi la lista di subnet per virgola e conta le subnet
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Inizializza IP min e max
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Elabora ogni subnet per trovare IP min e max
    WHILE i < total_subnets DO
        SET i = i + 1;
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        SET current_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
        
        IF current_ip < min_ip THEN
            SET min_ip = current_ip;
        END IF;
        
        SET current_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
        
        IF current_ip > max_ip THEN
            SET max_ip = current_ip;
        END IF;
    END WHILE;
    
    -- Trova i bit comuni da sinistra a destra
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Calcola il CIDR dell'aggregato
    SET aggregate_cidr = common_bits;
    
    -- Calcola l'indirizzo di rete dell'aggregato
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Restituisci il risultato
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

## Utilizzo

### Sintassi

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')

### Valore di Ritorno

Restituisce una stringa che rappresenta la subnet aggregata minima (in notazione CIDR) che comprende tutte le subnet fornite.

## Esempi

1. Trova l'aggregato di due subnet /24 adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Restituisce '192.168.0.0/23'
```

2. Trova l'aggregato di subnet non adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Restituisce '192.168.0.0/22'
```

3. Trova l'aggregato di subnet con lunghezze CIDR diverse:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Restituisce '10.0.0.0/22'
```

4. Trova l'aggregato di subnet da spazi di indirizzi diversi:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Restituisce '0.0.0.0/0' (l'intero spazio di indirizzi IPv4)
```

5. Trova l'aggregato di una singola subnet (restituisce la stessa subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Restituisce '192.168.1.0/24'
```

## Come Funziona

La funzione opera in diverse fasi:

1. **Analisi della lista di subnet**: Divide la lista separata da virgole e conta il numero di subnet.

2. **Trova gli indirizzi IP minimi e massimi**: 
   - Converte ciascuna subnet nel suo indirizzo di rete e indirizzo di broadcast
   - Tiene traccia dell'indirizzo di rete più basso e dell'indirizzo di broadcast più alto

3. **Calcola il prefisso comune**:
   - Partendo dal bit più a sinistra, conta quanti bit sono identici tra l'indirizzo IP minimo e massimo
   - Questo conteggio diventa la lunghezza del prefisso CIDR per la subnet aggregata

4. **Calcola l'indirizzo di rete**:
   - Applica la maschera derivata dalla lunghezza del prefisso all'indirizzo IP minimo
   - Questo assicura che l'indirizzo di rete sia correttamente allineato al confine CIDR

5. **Genera la notazione CIDR**:
   - Combina l'indirizzo di rete con la lunghezza del prefisso per creare la specifica della subnet aggregata

## Note

- La funzione restituisce sempre l'aggregato più piccolo possibile che contiene tutte le subnet di input.
- Quando le subnet sono molto distanti, l'aggregato può includere un numero significativo di indirizzi IP indesiderati.
- Per subnet da blocchi principali diversi (es., 10.x.x.x e 192.168.x.x), l'aggregato sarà molto grande.
- Per identificare le subnet indesiderate incluse nell'aggregato, usa la procedura `LIST_UNWANTED_SUBNETS`.
