# Funkcio FIND_SUBNETS_AGGREGATE (MySQL)

Ĉi tiu funkcio kalkulas la minimuman agregitan subreton kiu ampleksas ĉiujn donitajn IP-subretojn.

## Dokumentadaj Lingvoj

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

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

-- Helpa funkcio por akiri la disendadreson el IP kaj CIDR
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

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE:
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
    
    -- Dispartigu la subretan liston per komoj kaj kalkulu subretojn
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Inicializu min kaj max IP
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Procezu ĉiun subreton por trovi min kaj max IP-ojn
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
    
    -- Trovu komunajn bitojn de maldekstre al dekstre
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Kalkulu la agregitan CIDR
    SET aggregate_cidr = common_bits;
    
    -- Kalkulu la agregitan retan adreson
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redonu la rezulton
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

## Uzado

### Sintakso

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parametroj

- **subnet_list**: Komo-apartigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.2.0/24')

### Redonata Valoro

Redonas ĉenon reprezentantan la minimuman agregitan subreton (en CIDR-notacio) kiu ampleksas ĉiujn donitajn subretojn.

## Ekzemploj

1. Trovu la agregaĵon de du apudaj /24 subretoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Redonas '192.168.0.0/23'
```

2. Trovu la agregaĵon de neapudaj subretoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Redonas '192.168.0.0/22'
```

3. Trovu la agregaĵon de subretoj kun malsamaj CIDR-longoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Redonas '10.0.0.0/22'
```

4. Trovu la agregaĵon de subretoj el malsamaj adresspacioj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Redonas '0.0.0.0/0' (la tuta IPv4 adresspacio)
```

5. Trovu la agregaĵon de unuopa subreto (redonas la saman subreton):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Redonas '192.168.1.0/24'
```

## Kiel Ĝi Funkcias

La funkcio operacias en pluraj paŝoj:

1. **Analizu la subretan liston**: Dispartigas la komo-apartigitan liston kaj kalkulas la nombron de subretoj.

2. **Trovu la minimumajn kaj maksimumajn IP-adresojn**: 
   - Konvertas ĉiun subreton al ĝia reta adreso kaj disendadreso
   - Sekvas la plej malaltan retan adreson kaj la plej altan disendadreson

3. **Kalkulu la komunan prefikson**:
   - Komencante de la plej maldekstra bito, kalkulas kiom da bitoj estas identaj inter la minimuma kaj maksimuma IP-adreso
   - Ĉi tiu kalkulo fariĝas la CIDR-prefiksa longo por la agregita subreto

4. **Kalkulu la retan adreson**:
   - Apliku la maskon derivitan de la prefiksa longo al la minimuma IP-adreso
   - Tio certigas ke la reta adreso estas taŭge vicigita al la CIDR-limo

5. **Generu la CIDR-notacion**:
   - Kombinas la retan adreson kun la prefiksa longo por krei la agregitan subretan specifon

## Notoj

- La funkcio ĉiam redonas la plej malgrandan eblan agregaĵon kiu enhavas ĉiujn enigitajn subretojn.
- Kiam subretoj estas fora unu de la alia, la agregaĵo povas inkluzivi signifan nombron da nedezirataj IP-adresoj.
- Por subretoj el malsamaj ĉefaj blokoj (ekz., 10.x.x.x kaj 192.168.x.x), la agregaĵo estos tre granda.
- Por identigi nedeziratajn subretojn inkluzivitajn en la agregaĵo, uzu la proceduron `LIST_UNWANTED_SUBNETS`.
