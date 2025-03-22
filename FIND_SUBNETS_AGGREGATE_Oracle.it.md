# Funzione FIND_SUBNETS_AGGREGATE (Oracle)

Questa funzione calcola la subnet aggregata minima che comprende tutte le subnet IP fornite. L'implementazione Oracle gestisce la manipolazione delle stringhe e le operazioni bit a bit in modo diverso rispetto alla versione MySQL a causa delle differenze nelle funzioni integrate disponibili.

## Lingue della Documentazione

- [English](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)

## Installazione

Per installare questa funzione nel tuo database Oracle, esegui i seguenti comandi SQL in ordine:

1. Per prima cosa, installa le funzioni di supporto se non l'hai già fatto:
```sql
-- Converti indirizzo IP in numero
CREATE OR REPLACE FUNCTION IP_TO_NUM(ip_address IN VARCHAR2)
RETURN NUMBER IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 1));
    v_octet2 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 2));
    v_octet3 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 3));
    v_octet4 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 4));
    
    RETURN (v_octet1 * 256 * 256 * 256) + 
           (v_octet2 * 256 * 256) + 
           (v_octet3 * 256) + 
           v_octet4;
END;
/

-- Converti numero in indirizzo IP
CREATE OR REPLACE FUNCTION NUM_TO_IP(ip_num IN NUMBER)
RETURN VARCHAR2 IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TRUNC(ip_num / (256 * 256 * 256));
    v_octet2 := TRUNC(MOD(ip_num, 256 * 256 * 256) / (256 * 256));
    v_octet3 := TRUNC(MOD(ip_num, 256 * 256) / 256);
    v_octet4 := MOD(ip_num, 256);
    
    RETURN v_octet1 || '.' || v_octet2 || '.' || v_octet3 || '.' || v_octet4;
END;
/

-- Funzione di supporto per ottenere l'indirizzo di rete da un IP e CIDR
CREATE OR REPLACE FUNCTION GET_NETWORK_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN NUM_TO_IP(BITAND(ip_num, mask));
END;
/

-- Funzione di supporto per ottenere l'indirizzo di broadcast da un IP e CIDR
CREATE OR REPLACE FUNCTION GET_BROADCAST_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
    broadcast NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    broadcast := ip_num + POWER(2, 32 - cidr) - 1;
    
    RETURN NUM_TO_IP(broadcast);
END;
/
```

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE:
```sql
CREATE OR REPLACE FUNCTION FIND_SUBNETS_AGGREGATE(
    subnet_list IN VARCHAR2
) RETURN VARCHAR2 IS
    i NUMBER := 1;
    total_subnets NUMBER;
    current_subnet VARCHAR2(50);
    ip VARCHAR2(15);
    cidr NUMBER;
    min_ip NUMBER;
    max_ip NUMBER;
    current_ip NUMBER;
    common_bits NUMBER := 32;
    aggregate_cidr NUMBER;
    aggregate_ip NUMBER;
    delimiter_count NUMBER;
BEGIN
    -- Conta le occorrenze del delimitatore
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Inizializza IP min e max
    current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
    ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
    cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
    min_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
    max_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Elabora ogni subnet per trovare IP min e max
    WHILE i < total_subnets LOOP
        i := i + 1;
        current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
        ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
        cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
        current_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
        
        IF current_ip < min_ip THEN
            min_ip := current_ip;
        END IF;
        
        current_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
        
        IF current_ip > max_ip THEN
            max_ip := current_ip;
        END IF;
    END LOOP;
    
    -- Trova i bit comuni da sinistra a destra
    common_bits := 0;
    WHILE common_bits < 32 LOOP
        IF BITAND(FLOOR(min_ip / POWER(2, 31 - common_bits)), 1) = 
           BITAND(FLOOR(max_ip / POWER(2, 31 - common_bits)), 1) THEN
            common_bits := common_bits + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Calcola il CIDR dell'aggregato
    aggregate_cidr := common_bits;
    
    -- Calcola l'indirizzo di rete dell'aggregato
    aggregate_ip := BITAND(min_ip, POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Restituisci il risultato
    RETURN NUM_TO_IP(aggregate_ip) || '/' || aggregate_cidr;
END;
/
```

## Utilizzo

### Sintassi

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list) FROM DUAL;
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')

### Valore di Ritorno

Restituisce una stringa che rappresenta la subnet aggregata minima (in notazione CIDR) che comprende tutte le subnet fornite.

## Esempi

1. Trovare l'aggregato di due subnet /24 adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.0.0/23'
```

2. Trovare l'aggregato di subnet non adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.0.0/22'
```

3. Trovare l'aggregato di subnet con lunghezze CIDR diverse:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23') AS subnet_aggregata FROM DUAL;
-- Restituisce '10.0.0.0/22'
```

4. Trovare l'aggregato di subnet da spazi di indirizzi diversi:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '0.0.0.0/0' (l'intero spazio di indirizzi IPv4)
```

5. Trovare l'aggregato di una singola subnet (restituisce la stessa subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.1.0/24'
```

## Come Funziona

La funzione opera in diverse fasi:

1. **Analizza la lista delle subnet**: Utilizza le funzioni REGEXP di Oracle per dividere la lista separata da virgole e contare il numero di subnet.

2. **Trova gli indirizzi IP minimi e massimi**: 
   - Converte ogni subnet nel suo indirizzo di rete e indirizzo di broadcast utilizzando le funzioni di supporto
   - Tiene traccia dell'indirizzo di rete più basso e dell'indirizzo di broadcast più alto

3. **Calcola il prefisso comune**:
   - Partendo dal bit più a sinistra, conta quanti bit sono identici tra l'indirizzo IP minimo e massimo
   - Poiché Oracle non ha operatori di shift di bit diretti come MySQL, utilizza operazioni di divisione e BITAND per controllare ogni bit
   - Questo conteggio diventa la lunghezza del prefisso CIDR per la subnet aggregata

4. **Calcola l'indirizzo di rete**:
   - Applica la maschera derivata dalla lunghezza del prefisso all'indirizzo IP minimo usando BITAND
   - Questo assicura che l'indirizzo di rete sia correttamente allineato al confine CIDR

5. **Genera la notazione CIDR**:
   - Combina l'indirizzo di rete con la lunghezza del prefisso per creare la specifica della subnet aggregata

## Differenze dall'Implementazione MySQL

L'implementazione Oracle differisce dalla versione MySQL in diversi modi:

1. **Manipolazione delle Stringhe**: Oracle usa `REGEXP_SUBSTR` per l'elaborazione delle stringhe invece di `SUBSTRING_INDEX` di MySQL.

2. **Conversione IP**: Oracle richiede funzioni personalizzate `IP_TO_NUM` e `NUM_TO_IP` poiché manca delle funzioni integrate `INET_ATON()` e `INET_NTOA()` di MySQL.

3. **Operazioni Bit a Bit**: Oracle non supporta operatori di shift di bit diretti come `>>` di MySQL. Invece, la funzione utilizza divisione per potenze di 2 insieme a `FLOOR()` e `BITAND()` per simulare le operazioni di shift di bit.

4. **Dichiarazione delle Variabili**: PL/SQL di Oracle richiede che tutte le variabili siano dichiarate all'inizio di un blocco, mentre MySQL consente una maggiore flessibilità nelle dichiarazioni di variabili.

5. **Differenze di Sintassi**: Oracle richiede una barra obliqua (/) dopo le definizioni di funzione e utilizza una sintassi di struttura di loop diversa.

## Note

- La funzione restituisce sempre l'aggregato più piccolo possibile che contiene tutte le subnet di input.
- Quando le subnet sono molto distanti, l'aggregato può includere un numero significativo di indirizzi IP indesiderati.
- Per subnet da blocchi principali diversi (es., 10.x.x.x e 192.168.x.x), l'aggregato sarà molto grande.
- Per identificare le subnet indesiderate incluse nell'aggregato, utilizzare la procedura `LIST_UNWANTED_SUBNETS`.
- Questa funzione è una dipendenza per la funzione `CHECK_SUBNET_RELATIONSHIP` quando si testano le relazioni 'AGGREGABLE'.
