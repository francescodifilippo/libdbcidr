# Procedura LIST_UNWANTED_SUBNETS (MySQL)

Questa procedura identifica le subnet che sarebbero incluse in un aggregato ma non fanno parte dell'elenco originale delle subnet. Aiuta gli amministratori di rete ad analizzare lo "spreco" quando si aggregano subnet non contigue.

## Lingue della Documentazione

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Installazione

Per installare questa procedura nel tuo database MySQL, esegui i seguenti comandi SQL in ordine:

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

2. Quindi installa la procedura LIST_UNWANTED_SUBNETS:
```sql
CREATE PROCEDURE LIST_UNWANTED_SUBNETS(
    subnet_list TEXT,
    aggregate_subnet VARCHAR(50)
)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE total_subnets INT;
    DECLARE current_subnet VARCHAR(50);
    DECLARE original_ip VARCHAR(15);
    DECLARE original_cidr INT;
    DECLARE aggregate_ip VARCHAR(15);
    DECLARE aggregate_cidr INT;
    DECLARE smallest_cidr INT DEFAULT 0;
    DECLARE aggregate_start BIGINT;
    DECLARE aggregate_end BIGINT;
    DECLARE subnet_size BIGINT;
    DECLARE current_subnet_start BIGINT;
    DECLARE current_subnet_end BIGINT;
    
    -- Crea una tabella temporanea per le subnet originali
    DROP TEMPORARY TABLE IF EXISTS original_subnets;
    CREATE TEMPORARY TABLE original_subnets (
        network_address BIGINT,
        broadcast_address BIGINT,
        cidr INT
    );
    
    -- Analizza la subnet aggregata
    SET aggregate_ip = SUBSTRING_INDEX(aggregate_subnet, '/', 1);
    SET aggregate_cidr = CAST(SUBSTRING_INDEX(aggregate_subnet, '/', -1) AS UNSIGNED);
    SET aggregate_start = INET_ATON(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    SET aggregate_end = INET_ATON(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Dividi l'elenco delle subnet per virgola e conta le subnet
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Elabora ogni subnet originale
    WHILE i <= total_subnets DO
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET original_ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET original_cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        
        -- Tieni traccia del CIDR più piccolo (subnet più specifica)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            SET smallest_cidr = original_cidr;
        END IF;
        
        -- Inserisci nella tabella delle subnet originali
        INSERT INTO original_subnets VALUES (
            INET_ATON(GET_NETWORK_ADDRESS(original_ip, original_cidr)),
            INET_ATON(GET_BROADCAST_ADDRESS(original_ip, original_cidr)),
            original_cidr
        );
        
        SET i = i + 1;
    END WHILE;
    
    -- Crea una tabella temporanea per i risultati
    DROP TEMPORARY TABLE IF EXISTS unwanted_subnets;
    CREATE TEMPORARY TABLE unwanted_subnets (
        subnet VARCHAR(50)
    );
    
    -- Determina la dimensione della subnet basata sul CIDR più piccolo
    SET subnet_size = POWER(2, 32 - smallest_cidr);
    
    -- Itera attraverso tutte le possibili subnet nell'aggregato
    SET current_subnet_start = aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end DO
        -- Calcola la fine di questa subnet
        SET current_subnet_end = current_subnet_start + subnet_size - 1;
        
        -- Controlla se questa subnet fa parte delle subnet originali
        IF NOT EXISTS (
            SELECT 1 FROM original_subnets 
            WHERE network_address = current_subnet_start AND broadcast_address = current_subnet_end
        ) THEN
            -- Questa è una subnet indesiderata, aggiungila ai risultati
            INSERT INTO unwanted_subnets VALUES (
                CONCAT(INET_NTOA(current_subnet_start), '/', smallest_cidr)
            );
        END IF;
        
        -- Passa alla prossima subnet
        SET current_subnet_start = current_subnet_start + subnet_size;
    END WHILE;
    
    -- Restituisci i risultati
    SELECT subnet FROM unwanted_subnets ORDER BY subnet;
END;
```

## Utilizzo

### Sintassi

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parametri

- **subnet_list**: Un elenco di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: La specifica della subnet aggregata in notazione CIDR (es., '192.168.0.0/22')

### Valore di Ritorno

Restituisce un insieme di risultati contenente una colonna denominata 'subnet' con ogni riga che rappresenta una subnet indesiderata (in notazione CIDR) inclusa nell'aggregato ma non facente parte delle subnet originali.

## Esempi

1. Trovare le subnet indesiderate quando si aggregano subnet /24 non adiacenti:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Risultato:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Trovare le subnet indesiderate quando si aggregano subnet con lunghezze di prefisso diverse:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Risultato:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verificare che non ci siano subnet indesiderate per subnet perfettamente aggregabili:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Risultato: Insieme di risultati vuoto (nessuna subnet indesiderata)

4. Trovare le subnet indesiderate in un grande aggregato:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Risultato: Insieme di risultati molto grande contenente tutte le reti /24 nello spazio IPv4 tranne le due specificate.

## Come Funziona

La procedura opera in diverse fasi:

1. **Analisi dell'Input**: 
   - Analizza l'elenco delle subnet originali e la subnet aggregata
   - Identifica la lunghezza del prefisso CIDR più piccola (più specifica) tra le subnet originali

2. **Creazione delle Strutture Dati**:
   - Crea una tabella temporanea per memorizzare gli indirizzi di rete e broadcast delle subnet originali
   - Crea una tabella temporanea per memorizzare i risultati

3. **Enumerazione delle Subnet**:
   - Itera attraverso tutte le possibili subnet della stessa dimensione della subnet originale più specifica che si adattano all'interno dell'aggregato
   - Per ogni possibile subnet, verifica se corrisponde a una delle subnet originali
   - In caso contrario, la aggiunge all'elenco delle subnet indesiderate

4. **Restituzione dei Risultati**:
   - Restituisce l'elenco delle subnet indesiderate in ordine ordinato

## Note

- La procedura identifica le subnet alla stessa lunghezza di prefisso della subnet più specifica nell'elenco originale
- Per aggregati grandi, l'insieme dei risultati può essere molto grande
- La procedura è utile per:
  - Pianificazione degli schemi di indirizzi IP
  - Valutazione dell'efficienza dell'aggregazione delle rotte
  - Identificazione dello spazio IP libero all'interno di un aggregato
  - Valutazione dell'impatto della summarizzazione delle subnet sulle tabelle di routing
