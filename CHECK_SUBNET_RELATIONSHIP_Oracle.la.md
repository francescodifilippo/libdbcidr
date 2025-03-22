# Functio CHECK_SUBNET_RELATIONSHIP (Oracle)

Haec functio relationes inter plures subretes IP examinat et determinat si criteria specifica satisfaciunt.

## Linguae Documentationis

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installatio

Ad hanc functionem in base dati Oracle installandam, hos iussos SQL per ordinem exequere:

1. Primum, functiones auxiliares installa si nondum fecisti:
```sql
-- Conversio inscriptionis IP in numerum
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

-- Conversio numeri in inscriptionem IP
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

-- Functio auxiliaris ad obtinendum inscriptionem retis ab IP et CIDR
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

-- Functio auxiliaris ad obtinendum inscriptionem divulgationis ab IP et CIDR
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

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE (necessaria pro quibusdam relationum inspectionibus):
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
    -- Numera occurrentia delimitatorum
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Initia IP minimos et maximos
    current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
    ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
    cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
    min_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
    max_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Processa quamque subretem ad inveniendos IPs minimos et maximos
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
    
    -- Inveni bits communes a sinistra ad dextram
    common_bits := 0;
    WHILE common_bits < 32 LOOP
        IF BITAND(FLOOR(min_ip / POWER(2, 31 - common_bits)), 1) = 
           BITAND(FLOOR(max_ip / POWER(2, 31 - common_bits)), 1) THEN
            common_bits := common_bits + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Calcula CIDR aggregati
    aggregate_cidr := common_bits;
    
    -- Calcula inscriptionem retis aggregati
    aggregate_ip := BITAND(min_ip, POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redde resultatum
    RETURN NUM_TO_IP(aggregate_ip) || '/' || aggregate_cidr;
END;
/
```

3. Tandem, installa functionem CHECK_SUBNET_RELATIONSHIP:
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
    -- Numera occurrentia delimitatorum ad determinandum numerum subretium
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Si pauciores quam 2 subretes, quaedam relationes non applicantur
    IF total_subnets < 2 AND relationship_type != 'VALID' THEN
        RETURN 0;
    END IF;
    
    -- Inspice relationes quae ad omnia paria subretium applicantur
    IF relationship_type = 'ADJACENT_CHAIN' THEN
        -- Omnesne subretes adiacentes sunt et possuntne formare catena continua?
        -- Assumimus input iam ordinatum esse
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i+1);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            -- Inspice si par currens adiacens est
            IF IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 != 
               IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2)) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'AGGREGABLE' THEN
        -- Omnesne subretes perfecte aggregabiles sunt ut totum?
        -- Primum, inspice si omnes subretes habent idem CIDR
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
        
        -- Calcula aggregatum
        aggregate := FIND_SUBNETS_AGGREGATE(subnet_list);
        
        -- Inspice si CIDR aggregati est exacte 1 bit minus specificum
        aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate, '[^/]+', 1, 2));
        
        -- Aggregatum deberet esse exacte unum bit minus specificum quam subretes originales
        IF aggregate_cidr != cidr1 - 1 THEN
            RETURN 0;
        END IF;
        
        -- Inspice si numerus totalis subretium est exacte 2^1 (2)
        -- Hoc modificandum est pro differentiis plurium bitorum
        IF total_subnets != POWER(2, cidr1 - aggregate_cidr) THEN
            RETURN 0;
        END IF;
        
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_DISJOINT' THEN
        -- Omnesne subretes disiunctae sunt (nullae superpositionis)?
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
                
                -- Inspice si subretes superponunt
                IF NOT ((net1_end < net2_start) OR (net2_end < net1_start)) THEN
                    RETURN 0;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_INSIDE' THEN
        -- Omnesne subretes continentur in una subrete?
        -- Ultima subres in lista consideratur esse container
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
            
            -- Inspice si subnet1 est intra subnet2
            IF NOT (net1_start >= net2_start AND net1_end <= net2_end) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_IDENTICAL' THEN
        -- Omnesne subretes identicae sunt?
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
            
            -- Inspice si subretes sunt identicae
            IF net1_start != net2_start OR net1_end != net2_end THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ANY_OVERLAPPING' THEN
        -- Suntne duae subretes in lista quae superponunt?
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
                
                -- Inspice si subretes superponunt
                IF net1_end >= net2_start AND net1_start <= net2_end THEN
                    RETURN 1;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 0;
        
    ELSIF relationship_type = 'VALID' THEN
        -- Inspice si omnes subretes sunt subretes IPv4 validae
        i := 1;
        WHILE i <= total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            -- Inspice si subres est valida
            IF cidr1 < 0 OR cidr1 > 32 THEN
                RETURN 0;
            END IF;
            
            -- Inspice si inscriptio retis congruit notationi CIDR
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

## Usus

### Syntaxis

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
```

### Parametri

- **subnet_list**: Lista specificationum subretium separatarum per comma in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Typus relationis inspiciendae. Valores validi sunt:
  - 'ADJACENT_CHAIN': Inspicit si omnes subretes formant catenam continuam
  - 'AGGREGABLE': Inspicit si omnes subretes possunt perfecte aggregari
  - 'ALL_DISJOINT': Inspicit si omnes subretes sunt disiunctae (nulla superpositio)
  - 'ALL_INSIDE': Inspicit si omnes subretes continentur intra ultimam subretem in lista
  - 'ALL_IDENTICAL': Inspicit si omnes subretes sunt identicae
  - 'ANY_OVERLAPPING': Inspicit si duae subretes quaecumque in lista superponunt
  - 'VALID': Inspicit si omnes subretes sunt subretes IPv4 validae

### Valor Reditus

Reddit NUMBER (1 vel 0) indicans si relatio specificata valet pro subretibus datis.

## Exempla

1. Inspice si subretes sunt adiacentes et formant catenam:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') FROM DUAL;
-- Reddit 1 (VERUM)
```

2. Inspice si subretes possunt perfecte aggregari:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') FROM DUAL;
-- Reddit 1 (VERUM) quia possunt aggregari in 192.168.0.0/23
```

3. Inspice si subretes sunt omnes intra subretem continentem:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') FROM DUAL;
-- Reddit 1 (VERUM) quia ambae subretes /24 sunt intra subretem /22
```

4. Inspice si sunt subretes quae superponunt:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') FROM DUAL;
-- Reddit 1 (VERUM) quia 192.168.1.0/24 superponit cum 192.168.1.128/25
```

5. Inspice si omnes subretes sunt validae:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') FROM DUAL;
-- Reddit 1 (VERUM) quia omnes subretes sunt validae
```

## Notae

- Functio assumit specificationes subretium esse in formato correcto.
- Pro 'ADJACENT_CHAIN', subretes deberent praeberi in ordine.
- Inspectio 'AGGREGABLE' optime operatur quando omnes subretes habent eandem longitudinem praefixae CIDR.
- Quando uteris 'ALL_INSIDE', subres continens deberet esse ultima in lista.
- In Oracle, functio reddit 1 pro VERO et 0 pro FALSO, dissimiliter a MySQL quae reddit valores booleanos directos.
