# Funzione CHECK_SUBNET_RELATIONSHIP (MySQL)

Questa funzione analizza le relazioni tra più subnet IP e determina se soddisfano criteri specifici.

## Lingue della Documentazione

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

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

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE (richiesta per alcuni controlli di relazione):
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

3. Infine, installa la funzione CHECK_SUBNET_RELATIONSHIP:
```sql
CREATE FUNCTION CHECK_SUBNET_RELATIONSHIP(
    subnet_list TEXT,
    relationship_type VARCHAR(20)
) RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE i, j INT;
    DECLARE total_subnets INT;
    DECLARE subnet1, subnet2 VARCHAR(50);
    DECLARE ip1, ip2 VARCHAR(15);
    DECLARE cidr1, cidr2 INT;
    DECLARE all_match BOOLEAN DEFAULT TRUE;
    DECLARE any_match BOOLEAN DEFAULT FALSE;
    
    -- Conta il totale delle subnet
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Se ci sono meno di 2 subnet, certe relazioni non si applicano
    IF total_subnets < 2 AND relationship_type NOT IN ('VALID') THEN
        RETURN FALSE;
    END IF;
    
    -- Controlla le relazioni che si applicano a tutte le coppie di subnet
    CASE relationship_type
        -- Tutte le subnet sono adiacenti e possono formare un blocco continuo?
        WHEN 'ADJACENT_CHAIN' THEN
            -- Ordina le subnet per IP (questo richiederebbe un'implementazione più complessa)
            -- Per semplicità, assumiamo che l'input sia già ordinato
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i+1), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Controlla se la coppia corrente è adiacente
                IF NOT (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 = 
                        INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Tutte le subnet sono perfettamente aggregabili come un tutto?
        WHEN 'AGGREGABLE' THEN
            -- Prima, controlla se tutte le subnet hanno lo stesso CIDR
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                IF cidr1 != cidr2 THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            
            -- Calcola l'aggregato
            DECLARE aggregate VARCHAR(50);
            SET aggregate = FIND_SUBNETS_AGGREGATE(subnet_list);
            
            -- Controlla se il CIDR dell'aggregato è esattamente 1 bit meno specifico
            DECLARE agg_cidr INT;
            SET agg_cidr = CAST(SUBSTRING_INDEX(aggregate, '/', -1) AS UNSIGNED);
            
            -- L'aggregato dovrebbe essere esattamente un bit meno specifico delle subnet originali
            IF agg_cidr != cidr1 - 1 THEN
                RETURN FALSE;
            END IF;
            
            -- Controlla se il numero totale di subnet è esattamente 2^1 (2)
            -- Questo deve essere modificato per differenze di più bit
            IF total_subnets != POWER(2, cidr1 - agg_cidr) THEN
                RETURN FALSE;
            END IF;
            
            RETURN TRUE;
            
        -- Tutte le subnet sono disgiunte (nessuna sovrapposizione)?
        WHEN 'ALL_DISJOINT' THEN
            SET i = 1;
            WHILE i < total_subnets DO
                SET j = i + 1;
                WHILE j <= total_subnets DO
                    SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                    SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                    SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                    
                    SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', j), ',', -1);
                    SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                    SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                    
                    -- Controlla se le subnet si sovrappongono
                    IF NOT ((INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) < INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) OR 
                            (INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2)) < INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)))) THEN
                        RETURN FALSE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Tutte le subnet sono contenute in una singola subnet?
        WHEN 'ALL_INSIDE' THEN
            -- L'ultima subnet nella lista è considerata il contenitore
            SET subnet2 = SUBSTRING_INDEX(subnet_list, ',', -1);
            SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
            SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
            
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Controlla se subnet1 è dentro subnet2
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Tutte le subnet sono identiche?
        WHEN 'ALL_IDENTICAL' THEN
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Controlla se le subnet sono identiche
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) = INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) = INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Ci sono due subnet nella lista che si sovrappongono?
        WHEN 'ANY_OVERLAPPING' THEN
            SET i = 1;
            WHILE i < total_subnets DO
                SET j = i + 1;
                WHILE j <= total_subnets DO
                    SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                    SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                    SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                    
                    SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', j), ',', -1);
                    SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                    SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                    
                    -- Controlla se le subnet si sovrappongono
                    IF (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                        RETURN TRUE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN FALSE;
            
        -- Controlla se tutte le subnet sono subnet IPv4 valide
        WHEN 'VALID' THEN
            SET i = 1;
            WHILE i <= total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Controlla se la subnet è valida
                IF cidr1 < 0 OR cidr1 > 32 OR INET_ATON(ip1) IS NULL THEN
                    RETURN FALSE;
                END IF;
                
                -- Controlla se l'indirizzo di rete corrisponde alla notazione CIDR
                IF INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) != INET_ATON(ip1) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        ELSE
            RETURN FALSE;
    END CASE;
END;
```

## Utilizzo

### Sintassi

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Il tipo di relazione da verificare. I valori validi sono:
  - 'ADJACENT_CHAIN': Verifica se tutte le subnet formano una catena continua
  - 'AGGREGABLE': Verifica se tutte le subnet possono essere perfettamente aggregate
  - 'ALL_DISJOINT': Verifica se tutte le subnet sono disgiunte (nessuna sovrapposizione)
  - 'ALL_INSIDE': Verifica se tutte le subnet sono contenute all'interno dell'ultima subnet nella lista
  - 'ALL_IDENTICAL': Verifica se tutte le subnet sono identiche
  - 'ANY_OVERLAPPING': Verifica se due subnet qualsiasi nella lista si sovrappongono
  - 'VALID': Verifica se tutte le subnet sono subnet IPv4 valide

### Valore di Ritorno

Restituisce un BOOLEAN (1 o 0) che indica se la relazione specificata vale per le subnet date.

## Esempi

1. Verifica se le subnet sono adiacenti e formano una catena:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Restituisce 1 (TRUE)
```

2. Verifica se le subnet possono essere perfettamente aggregate:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Restituisce 1 (TRUE) perché possono essere aggregate in 192.168.0.0/23
```

3. Verifica se le subnet sono tutte dentro una subnet contenitore:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Restituisce 1 (TRUE) perché entrambe le subnet /24 sono dentro la subnet /22
```

4. Verifica se ci sono subnet che si sovrappongono:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Restituisce 1 (TRUE) perché 192.168.1.0/24 si sovrappone con 192.168.1.128/25
```

5. Verifica se tutte le subnet sono valide:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Restituisce 1 (TRUE) perché tutte le subnet sono valide
```

## Note

- La funzione assume che le specifiche delle subnet siano nel formato corretto.
- Per 'ADJACENT_CHAIN', le subnet dovrebbero essere fornite in ordine.
- Il controllo 'AGGREGABLE' funziona meglio quando tutte le subnet hanno la stessa lunghezza di prefisso CIDR.
- Quando si usa 'ALL_INSIDE', la subnet contenitore dovrebbe essere l'ultima nella lista.
