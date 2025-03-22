# Funzione CHECK_SUBNET_RELATIONSHIP (Oracle)

Questa funzione analizza le relazioni tra più subnet IP e determina se soddisfano criteri specifici.

## Lingue della Documentazione

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installazione

Per installare questa funzione nel tuo database Oracle, esegui i seguenti comandi SQL in ordine:

1. Prima, installa le funzioni di supporto se non l'hai già fatto:
```sql
-- Convertire indirizzo IP in numero
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

-- Convertire numero in indirizzo IP
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

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE (richiesta per alcuni controlli di relazione):
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
    -- Conta occorrenze del delimitatore
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

3. Infine, installa la funzione CHECK_SUBNET_RELATIONSHIP:
```sql
CREATE OR REPLACE FUNCTION CHECK_SUBNET_RELATIONSHIP(
    subnet_list IN VARCHAR2,
    relationship_type IN VARCHAR2
) RETURN NUMBER IS
    i NUMBER;
    j NUMBER;
    total_subnets NUMBER;
    subnet1 VARCHAR2(50);
    subnet2 VARCHAR2(50);
    ip1 VARCHAR2(15);
    ip2 VARCHAR2(15);
    cidr1 NUMBER;
    cidr2 NUMBER;
    net1_start NUMBER;
    net1_end NUMBER;
    net2_start NUMBER;
    net2_end NUMBER;
    delimiter_count NUMBER;
    aggregate VARCHAR2(50);
    aggregate_cidr NUMBER;
BEGIN
    -- Conta occorrenze del delimitatore per determinare il numero di subnet
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Se ci sono meno di 2 subnet, certe relazioni non si applicano
    IF total_subnets < 2 AND relationship_type != 'VALID' THEN
        RETURN 0;
    END IF;
    
    -- Controlla le relazioni che si applicano a tutte le coppie di subnet
    IF relationship_type = 'ADJACENT_CHAIN' THEN
        -- Tutte le subnet sono adiacenti e possono formare un blocco continuo?
        -- Assumiamo che l'input sia già ordinato
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i+1);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            -- Controlla se la coppia corrente è adiacente
            IF IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 != 
               IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2)) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'AGGREGABLE' THEN
        -- Tutte le subnet sono perfettamente aggregabili come un tutto?
        -- Prima, controlla se tutte le subnet hanno lo stesso CIDR
        subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
        cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
        
        i := 2;
        WHILE i <= total_subnets LOOP
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            IF cidr1 != cidr2 THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        
        -- Calcola l'aggregato
        aggregate := FIND_SUBNETS_AGGREGATE(subnet_list);
        
        -- Controlla se il CIDR dell'aggregato è esattamente 1 bit meno specifico
        aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate, '[^/]+', 1, 2));
        
        -- L'aggregato dovrebbe essere esattamente un bit meno specifico delle subnet originali
        IF aggregate_cidr != cidr1 - 1 THEN
            RETURN 0;
        END IF;
        
        -- Controlla se il numero totale di subnet è esattamente 2^1 (2)
        -- Questo deve essere modificato per differenze di più bit
        IF total_subnets != POWER(2, cidr1 - aggregate_cidr) THEN
            RETURN 0;
        END IF;
        
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_DISJOINT' THEN
        -- Tutte le subnet sono disgiunte (nessuna sovrapposizione)?
        i := 1;
        WHILE i < total_subnets LOOP
            j := i + 1;
            WHILE j <= total_subnets LOOP
                subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
                ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
                cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
                
                subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, j);
                ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
                cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
                
                net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
                net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
                net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
                net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
                
                -- Controlla se le subnet si sovrappongono
                IF NOT ((net1_end < net2_start) OR (net2_end < net1_start)) THEN
                    RETURN 0;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_INSIDE' THEN
        -- Tutte le subnet sono contenute in una singola subnet?
        -- L'ultima subnet nella lista è considerata il contenitore
        subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, total_subnets);
        ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
        cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
        
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
            net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
            net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
            net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
            
            -- Controlla se subnet1 è dentro subnet2
            IF NOT (net1_start >= net2_start AND net1_end <= net2_end) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_IDENTICAL' THEN
        -- Tutte le subnet sono identiche?
        subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
        ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
        cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
        
        net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
        net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
        
        i := 2;
        WHILE i <= total_subnets LOOP
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
            net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
            
            -- Controlla se le subnet sono identiche
            IF net1_start != net2_start OR net1_end != net2_end THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ANY_OVERLAPPING' THEN
        -- Ci sono due subnet nella lista che si sovrappongono?
        i := 1;
        WHILE i < total_subnets LOOP
            j := i + 1;
            WHILE j <= total_subnets LOOP
                subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
                ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
                cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
                
                subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, j);
                ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
                cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
                
                net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
                net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
                net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
                net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
                
                -- Controlla se le subnet si sovrappongono
                IF net1_end >= net2_start AND net1_start <= net2_end THEN
                    RETURN 1;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 0;
        
    ELSIF relationship_type = 'VALID' THEN
        -- Controlla se tutte le subnet sono subnet IPv4 valide
        i := 1;
        WHILE i <= total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            -- Controlla se la subnet è valida
            IF cidr1 < 0 OR cidr1 > 32 THEN
                RETURN 0;
            END IF;
            
            -- Controlla se l'indirizzo di rete corrisponde alla notazione CIDR
            IF IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1)) != IP_TO_NUM(ip1) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSE
        RETURN 0;
    END IF;
END;
/
```

## Utilizzo

### Sintassi

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
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

Restituisce un NUMBER (1 o 0) che indica se la relazione specificata vale per le subnet date.

## Esempi

1. Verifica se le subnet sono adiacenti e formano una catena:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') FROM DUAL;
-- Restituisce 1 (TRUE)
```

2. Verifica se le subnet possono essere perfettamente aggregate:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') FROM DUAL;
-- Restituisce 1 (TRUE) perché possono essere aggregate in 192.168.0.0/23
```

3. Verifica se le subnet sono tutte dentro una subnet contenitore:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') FROM DUAL;
-- Restituisce 1 (TRUE) perché entrambe le subnet /24 sono dentro la subnet /22
```

4. Verifica se ci sono subnet che si sovrappongono:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') FROM DUAL;
-- Restituisce 1 (TRUE) perché 192.168.1.0/24 si sovrappone con 192.168.1.128/25
```

5. Verifica se tutte le subnet sono valide:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') FROM DUAL;
-- Restituisce 1 (TRUE) perché tutte le subnet sono valide
```

## Note

- La funzione assume che le specifiche delle subnet siano nel formato corretto.
- Per 'ADJACENT_CHAIN', le subnet dovrebbero essere fornite in ordine.
- Il controllo 'AGGREGABLE' funziona meglio quando tutte le subnet hanno la stessa lunghezza di prefisso CIDR.
- Quando si usa 'ALL_INSIDE', la subnet contenitore dovrebbe essere l'ultima nella lista.
- In Oracle, la funzione restituisce 1 per TRUE e 0 per FALSE, a differenza di MySQL che restituisce valori boolean diretti.
