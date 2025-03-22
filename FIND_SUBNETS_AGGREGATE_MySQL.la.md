# Functio FIND_SUBNETS_AGGREGATE (MySQL)

Haec functio calculat minimam subretem aggregatam quae omnes subretes IP provisas comprehendit.

## Linguae Documentationis

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

## Installatio

Ad hanc functionem in base dati MySQL installandam, hos iussos SQL per ordinem exequere:

1. Primum, functiones auxiliares installa si nondum fecisti:
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

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE:
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
    
    -- Initia IP minimos et maximos
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Processa quamque subretem ad inveniendos IPs minimos et maximos
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
    
    -- Inveni bits communes a sinistra ad dextram
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Calcula CIDR aggregati
    SET aggregate_cidr = common_bits;
    
    -- Calcula inscriptionem retis aggregati
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redde resultatum
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

## Usus

### Syntaxis

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parametri

- **subnet_list**: Lista specificationum subretium separatarum per comma in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')

### Valor Reditus

Reddit catenam repraesentantem minimam subretem aggregatam (in notatione CIDR) quae omnes subretes provisas comprehendit.

## Exempla

1. Inveni aggregatum duarum subretium /24 adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Reddit '192.168.0.0/23'
```

2. Inveni aggregatum subretium non adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Reddit '192.168.0.0/22'
```

3. Inveni aggregatum subretium cum diversis longitudinibus CIDR:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Reddit '10.0.0.0/22'
```

4. Inveni aggregatum subretium ex diversis spatiis inscriptionum:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Reddit '0.0.0.0/0' (totum spatium inscriptionum IPv4)
```

5. Inveni aggregatum unius subretis (reddit eandem subretem):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Reddit '192.168.1.0/24'
```

## Quomodo Operatur

Functio operatur in pluribus gradibus:

1. **Examina elenchum subretium**: Dividit elenchum separatum per commata et numerat numerum subretium.

2. **Invenit inscriptiones IP minimas et maximas**: 
   - Convertit quamque subretem in suam inscriptionem retis et inscriptionem divulgationis
   - Vestigat inscriptionem retis minimam et inscriptionem divulgationis maximam

3. **Calculat praefixum commune**:
   - Incipiens a bit maxime sinistrorsum, numerat quot bits identici sunt inter inscriptionem IP minimam et maximam
   - Hic numerus fit longitudo praefixae CIDR pro subrete aggregata

4. **Computat inscriptionem retis**:
   - Applicat personam derivatam a longitudine praefixae ad inscriptionem IP minimam
   - Hoc assecurat inscriptionem retis recte alineatam esse ad limitem CIDR

5. **Generat notationem CIDR**:
   - Coniungit inscriptionem retis cum longitudine praefixae ad creandam specificationem subretis aggregatae

## Notae

- Functio semper reddit aggregatum minimum possibile quod continet omnes subretes input.
- Quando subretes longe distant, aggregatum potest includere numerum significantem inscriptionum IP non desideratarum.
- Pro subretibus ex diversis blocis principalibus (e.g., 10.x.x.x et 192.168.x.x), aggregatum erit valde magnum.
- Ad identificandas subretes non desideratas inclusas in aggregato, utere proceduram `LIST_UNWANTED_SUBNETS`.
