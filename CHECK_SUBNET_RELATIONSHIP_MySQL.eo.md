# Funkcio CHECK_SUBNET_RELATIONSHIP (MySQL)

Ĉi tiu funkcio analizas rilatojn inter pluraj IP-subretoj kaj determinas ĉu ili plenumas specifajn kriteriojn.

## Dokumentaj Lingvoj

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

## Instalado

Por instali ĉi tiun funkcion en via MySQL-datumbazo, plenumu la sekvajn SQL-komandojn laŭorde:

1. Unue, instalu la helpajn funkciojn se vi ankoraŭ ne faris tion:
```sql
-- Helpa funkcio por akiri la retan adreson el IP kaj CIDR
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

-- Helpa funkcio por akiri la dissendadreson el IP kaj CIDR
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

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE (necesa por kelkaj rilataj kontroloj):
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
    
    -- Dividu la subreto-liston per komoj kaj nombru subretojn
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Komencigu minimuman kaj maksimuman IP
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Traktu ĉiun subreton por trovi minimumajn kaj maksimumajn IP-adresojn
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
    
    -- Trovu komunajn bitojn de maldekstre dekstren
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Kalkulu la agregatan CIDR
    SET aggregate_cidr = common_bits;
    
    -- Kalkulu la agregatan retan adreson
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redonu la rezulton
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

3. Fine, instalu la funkcion CHECK_SUBNET_RELATIONSHIP:
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
    
    -- Nombru la totalan subretojn
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Se malpli ol 2 subretoj, certaj rilatoj ne aplikiĝas
    IF total_subnets < 2 AND relationship_type NOT IN ('VALID') THEN
        RETURN FALSE;
    END IF;
    
    -- Kontrolu rilatojn kiuj aplikiĝas al ĉiuj subretaj paroj
    CASE relationship_type
        -- Ĉu ĉiuj subretoj estas apudaj kaj povas formi kontinuan ĉenon?
        WHEN 'ADJACENT_CHAIN' THEN
            -- Ordigi subretojn laŭ IP (tio postulus pli kompleksan implementon)
            -- Por simpleco, ni supozas ke la enigo jam estas ordigita
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i+1), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Kontrolu ĉu la nuna paro estas apuda
                IF NOT (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 = 
                        INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Ĉu ĉiuj subretoj estas perfekte agregeblaj kiel tutaĵo?
        WHEN 'AGGREGABLE' THEN
            -- Unue, kontrolu ĉu ĉiuj subretoj havas la saman CIDR
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
            
            -- Kalkulu la agregaĵon
            DECLARE aggregate VARCHAR(50);
            SET aggregate = FIND_SUBNETS_AGGREGATE(subnet_list);
            
            -- Kontrolu ĉu la agregata CIDR estas ĝuste 1 bito malpli specifa
            DECLARE agg_cidr INT;
            SET agg_cidr = CAST(SUBSTRING_INDEX(aggregate, '/', -1) AS UNSIGNED);
            
            -- La agregaĵo devus esti ĝuste unu bito malpli specifa ol la originaj subretoj
            IF agg_cidr != cidr1 - 1 THEN
                RETURN FALSE;
            END IF;
            
            -- Kontrolu ĉu la totala nombro da subretoj estas ĝuste 2^1 (2)
            -- Ĉi tio devas esti modifita por pluraj bitaj diferencoj
            IF total_subnets != POWER(2, cidr1 - agg_cidr) THEN
                RETURN FALSE;
            END IF;
            
            RETURN TRUE;
            
        -- Ĉu ĉiuj subretoj estas disjunktaj (sen superlapo)?
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
                    
                    -- Kontrolu ĉu la subretoj superlapiĝas
                    IF NOT ((INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) < INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) OR 
                            (INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2)) < INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)))) THEN
                        RETURN FALSE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Ĉu ĉiuj subretoj estas enhavitaj en unu subreto?
        WHEN 'ALL_INSIDE' THEN
            -- La lasta subreto en la listo estas supozita esti la enhavanto
            SET subnet2 = SUBSTRING_INDEX(subnet_list, ',', -1);
            SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
            SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
            
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Kontrolu ĉu subreto1 estas ene de subreto2
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Ĉu ĉiuj subretoj estas identaj?
        WHEN 'ALL_IDENTICAL' THEN
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Kontrolu ĉu subretoj estas identaj
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) = INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) = INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Ĉu iuj du subretoj en la listo superlapiĝas?
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
                    
                    -- Kontrolu ĉu la subretoj superlapiĝas
                    IF (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                        RETURN TRUE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN FALSE;
            
        -- Kontrolu ĉu ĉiuj subretoj estas validaj IPv4-subretoj
        WHEN 'VALID' THEN
            SET i = 1;
            WHILE i <= total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Kontrolu ĉu subreto estas valida
                IF cidr1 < 0 OR cidr1 > 32 OR INET_ATON(ip1) IS NULL THEN
                    RETURN FALSE;
                END IF;
                
                -- Kontrolu ĉu reta adreso kongruas kun CIDR-notacio
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

## Uzado

### Sintakso

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
```

### Parametroj

- **subnet_list**: Komodisigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: La tipo de rilato kontrolenda. Validaj valoroj estas:
  - 'ADJACENT_CHAIN': Kontrolas ĉu ĉiuj subretoj formas kontinuan ĉenon
  - 'AGGREGABLE': Kontrolas ĉu ĉiuj subretoj povas esti perfekte agregitaj
  - 'ALL_DISJOINT': Kontrolas ĉu ĉiuj subretoj estas disjunktaj (sen superlapo)
  - 'ALL_INSIDE': Kontrolas ĉu ĉiuj subretoj estas enhavitaj en la lasta subreto de la listo
  - 'ALL_IDENTICAL': Kontrolas ĉu ĉiuj subretoj estas identaj
  - 'ANY_OVERLAPPING': Kontrolas ĉu iuj du subretoj en la listo superlapiĝas
  - 'VALID': Kontrolas ĉu ĉiuj subretoj estas validaj IPv4-subretoj

### Redonvaloro

Redonas BOOLEAN (1 aŭ 0) indikante ĉu la specifita rilato validas por la donitaj subretoj.

## Ekzemploj

1. Kontrolu ĉu subretoj estas apudaj kaj formas ĉenon:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Redonas 1 (TRUE)
```

2. Kontrolu ĉu subretoj povas esti perfekte agregitaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Redonas 1 (TRUE) ĉar ili povas esti agregitaj al 192.168.0.0/23
```

3. Kontrolu ĉu subretoj estas ĉiuj ene de enhava subreto:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Redonas 1 (TRUE) ĉar ambaŭ /24 subretoj estas ene de la /22 subreto
```

4. Kontrolu ĉu iuj subretoj superlapiĝas:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Redonas 1 (TRUE) ĉar 192.168.1.0/24 superlapiĝas kun 192.168.1.128/25
```

5. Kontrolu ĉu ĉiuj subretoj estas validaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Redonas 1 (TRUE) ĉar ĉiuj subretoj estas validaj
```

## Notoj

- La funkcio supozas ke la subretaj specifoj estas en la ĝusta formato.
- Por 'ADJACENT_CHAIN', la subretoj devus esti provizitaj laŭorde.
- La 'AGGREGABLE' kontrolo funkcias plej bone kiam ĉiuj subretoj havas la saman CIDR-prefikslongon.
- Kiam oni uzas 'ALL_INSIDE', la enhavanta subreto devus esti la lasta en la listo.
