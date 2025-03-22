# Functio CHECK_SUBNET_RELATIONSHIP (MySQL)

Haec functio examinat relationes inter plures subretes IP et determinat utrum criteria specifica implent.

## Linguae Documentationis

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

## Installatio

Ad hanc functionem in tua base datorum MySQL installandam, exsequere haec mandata SQL per ordinem:

1. Primo, installa functiones auxiliares si nondum fecisti:
```sql
-- Functio auxiliaris ad obtinendum inscriptionem retis ab IP et CIDR
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

-- Functio auxiliaris ad obtinendum inscriptionem divulgationis ab IP et CIDR
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

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE (necessariam pro quibusdam relationum examinationibus):
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
    
    -- Divide elenchum subretium per commata et numera subretes
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Initializa IP minimum et maximum
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Processa quamque subretem ad inveniendum IPs minima et maxima
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
    
    -- Inveni bits communes a sinistro ad dextrum
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Calcula CIDR aggregatum
    SET aggregate_cidr = common_bits;
    
    -- Calcula inscriptionem retis aggregati
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redde resultatum
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

3. Tandem, installa functionem CHECK_SUBNET_RELATIONSHIP:
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
    
    -- Numera subretes totales
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Si minus quam 2 subretes, quaedam relationes non applicantur
    IF total_subnets < 2 AND relationship_type NOT IN ('VALID') THEN
        RETURN FALSE;
    END IF;
    
    -- Examina relationes quae applicantur ad omnes pares subretium
    CASE relationship_type
        -- Suntne omnes subretes adiacentes et possuntne formare tractum continuum?
        WHEN 'ADJACENT_CHAIN' THEN
            -- Ordina subretes per IP (hoc requireret implementationem complexiorem)
            -- Pro simplicitate, supponimus ingressum iam esse ordinatum
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i+1), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Examina si par currens est adiacens
                IF NOT (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 = 
                        INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Suntne omnes subretes perfecte aggregabiles ut totum?
        WHEN 'AGGREGABLE' THEN
            -- Primo, examina si omnes subretes habent idem CIDR
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
            
            -- Calcula aggregatum
            DECLARE aggregate VARCHAR(50);
            SET aggregate = FIND_SUBNETS_AGGREGATE(subnet_list);
            
            -- Examina si CIDR aggregatum est exacte 1 bit minus specificum
            DECLARE agg_cidr INT;
            SET agg_cidr = CAST(SUBSTRING_INDEX(aggregate, '/', -1) AS UNSIGNED);
            
            -- Aggregatum debet esse exacte uno bit minus specificum quam subretes originales
            IF agg_cidr != cidr1 - 1 THEN
                RETURN FALSE;
            END IF;
            
            -- Examina si numerus totalis subretium est exacte 2^1 (2)
            -- Hoc debet modificari pro plurium bitorum differentia
            IF total_subnets != POWER(2, cidr1 - agg_cidr) THEN
                RETURN FALSE;
            END IF;
            
            RETURN TRUE;
            
        -- Suntne omnes subretes disiunctae (sine superpositionibus)?
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
                    
                    -- Examina si subretes superponuntur
                    IF NOT ((INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) < INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) OR 
                            (INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2)) < INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)))) THEN
                        RETURN FALSE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Suntne omnes subretes contentae intra unicam subretem?
        WHEN 'ALL_INSIDE' THEN
            -- Ultima subretis in elencho supponitur esse containerem
            SET subnet2 = SUBSTRING_INDEX(subnet_list, ',', -1);
            SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
            SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
            
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Examina si subnet1 est intra subnet2
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Suntne omnes subretes identicae?
        WHEN 'ALL_IDENTICAL' THEN
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Examina si subretes sunt identicae
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) = INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) = INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Suntne aliquae duae subretes in elencho superponentes?
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
                    
                    -- Examina si subretes superponuntur
                    IF (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                        RETURN TRUE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN FALSE;
            
        -- Examina si omnes subretes sunt validae subretes IPv4
        WHEN 'VALID' THEN
            SET i = 1;
            WHILE i <= total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Examina si subretis est valida
                IF cidr1 < 0 OR cidr1 > 32 OR INET_ATON(ip1) IS NULL THEN
                    RETURN FALSE;
                END IF;
                
                -- Examina si inscriptio retis congruit cum notatione CIDR
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

## Usus

### Syntaxis

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
```

### Parametri

- **subnet_list**: Elenchus subretium separatarum per commata in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Typus relationis examinandae. Valores validi sunt:
  - 'ADJACENT_CHAIN': Examinat si omnes subretes formant catenam continuam
  - 'AGGREGABLE': Examinat si omnes subretes possunt perfecte aggregari
  - 'ALL_DISJOINT': Examinat si omnes subretes sunt disiunctae (sine superpositione)
  - 'ALL_INSIDE': Examinat si omnes subretes continentur intra ultimam subretem in elencho
  - 'ALL_IDENTICAL': Examinat si omnes subretes sunt identicae
  - 'ANY_OVERLAPPING': Examinat si duae subretes quaelibet in elencho superponuntur
  - 'VALID': Examinat si omnes subretes sunt validae subretes IPv4

### Valor Reditus

Reddit BOOLEAN (1 vel 0) indicans utrum relatio specificata valet pro subretibus datis.

## Exempla

1. Examina si subretes sunt adiacentes et formant catenam:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Reddit 1 (VERUM)
```

2. Examina si subretes possunt perfecte aggregari:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Reddit 1 (VERUM) quia possunt aggregari ad 192.168.0.0/23
```

3. Examina si subretes sunt omnes intra subretem continentem:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Reddit 1 (VERUM) quia ambae subretes /24 sunt intra subretem /22
```

4. Examina si aliquae subretes superponuntur:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Reddit 1 (VERUM) quia 192.168.1.0/24 superponit cum 192.168.1.128/25
```

5. Examina si omnes subretes sunt validae:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Reddit 1 (VERUM) quia omnes subretes sunt validae
```

## Notae

- Functio supponit specificationes subretium esse in formato correcto.
- Pro 'ADJACENT_CHAIN', subretes debent praeberi in ordine.
- Examinatio 'AGGREGABLE' optime operatur quando omnes subretes habent eandem longitudinem praefixorum CIDR.
- Quando utens 'ALL_INSIDE', subretis continens debet esse ultima in elencho.
