# Proceduro LIST_UNWANTED_SUBNETS (MySQL)

Ĉi tiu proceduro identigas subretojn kiuj estus inkluzivitaj en agregaĵo sed ne estas parto de la originala subreto-listo. Ĝi helpas ret-administrantojn analizi la "malŝparaĵon" kiam oni agregas neapudajn subretojn.

## Dokumentaj Lingvoj

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Instalado

Por instali ĉi tiun proceduron en via MySQL-datumbazo, plenumu la jenajn SQL-komandojn laŭorde:

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

2. Poste instalu la proceduron LIST_UNWANTED_SUBNETS:
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
    
    -- Kreu provizoran tabelon por originalaj subretoj
    DROP TEMPORARY TABLE IF EXISTS original_subnets;
    CREATE TEMPORARY TABLE original_subnets (
        network_address BIGINT,
        broadcast_address BIGINT,
        cidr INT
    );
    
    -- Analizu la agregatan subreton
    SET aggregate_ip = SUBSTRING_INDEX(aggregate_subnet, '/', 1);
    SET aggregate_cidr = CAST(SUBSTRING_INDEX(aggregate_subnet, '/', -1) AS UNSIGNED);
    SET aggregate_start = INET_ATON(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    SET aggregate_end = INET_ATON(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Dividu la subreto-liston per komoj kaj nombru subretojn
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Traktu ĉiun originalan subreton
    WHILE i <= total_subnets DO
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET original_ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET original_cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        
        -- Konservu la plej specifan CIDR (la plej altan numeron)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            SET smallest_cidr = original_cidr;
        END IF;
        
        -- Aldonu al originala subreta tabelo
        INSERT INTO original_subnets VALUES (
            INET_ATON(GET_NETWORK_ADDRESS(original_ip, original_cidr)),
            INET_ATON(GET_BROADCAST_ADDRESS(original_ip, original_cidr)),
            original_cidr
        );
        
        SET i = i + 1;
    END WHILE;
    
    -- Kreu provizoran tabelon por rezultoj
    DROP TEMPORARY TABLE IF EXISTS unwanted_subnets;
    CREATE TEMPORARY TABLE unwanted_subnets (
        subnet VARCHAR(50)
    );
    
    -- Determinu la subretan grandecon bazitan sur la plej specifa CIDR
    SET subnet_size = POWER(2, 32 - smallest_cidr);
    
    -- Trairu ĉiujn eblajn subretojn en la agregaĵo
    SET current_subnet_start = aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end DO
        -- Kalkulu la finon de ĉi tiu subreto
        SET current_subnet_end = current_subnet_start + subnet_size - 1;
        
        -- Kontrolu ĉu ĉi tiu subreto estas parto de la originalaj subretoj
        IF NOT EXISTS (
            SELECT 1 FROM original_subnets 
            WHERE network_address = current_subnet_start AND broadcast_address = current_subnet_end
        ) THEN
            -- Ĉi tiu estas maldezirata subreto, aldonu ĝin al rezultoj
            INSERT INTO unwanted_subnets VALUES (
                CONCAT(INET_NTOA(current_subnet_start), '/', smallest_cidr)
            );
        END IF;
        
        -- Movu al sekva subreto
        SET current_subnet_start = current_subnet_start + subnet_size;
    END WHILE;
    
    -- Redonu la rezultojn
    SELECT subnet FROM unwanted_subnets ORDER BY subnet;
END;
```

## Uzado

### Sintakso

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parametroj

- **subnet_list**: Komodisigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: La agregaĵa subreta specifo en CIDR-notacio (ekz., '192.168.0.0/22')

### Redonvaloro

Redonas rezultaron enhavantan unu kolonon nomitan 'subnet' kun ĉiu vico reprezentanta maldezirata subreto (en CIDR-notacio) inkluzivita en la agregaĵo sed ne parto de la originalaj subretoj.

## Ekzemploj

1. Trovu maldeziratajn subretojn kiam oni agregas neapudajn /24 subretojn:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Rezulto:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Trovu maldeziratajn subretojn kiam oni agregas subretojn kun malsamaj prefikslongoj:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Rezulto:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Kontrolu ke ne estas maldezirataj subretoj por perfekte agregeblaj subretoj:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Rezulto: Malplena rezultaro (neniuj maldezirataj subretoj)

4. Trovu maldeziratajn subretojn en granda agregaĵo:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Rezulto: Tre granda rezultaro enhavanta ĉiujn /24 retojn en la IPv4-spaco krom la du specifitaj.

## Kiel Ĝi Funkcias

La proceduro funkcias laŭ pluraj paŝoj:

1. **Analizo de Enigo**: 
   - Analizas la originalan subreto-liston kaj la agregatan subreton
   - Identigas la plej specifan CIDR-prefikslongon inter la originalaj subretoj

2. **Kreado de Data-Strukturoj**:
   - Kreas provizoran tabelon por konservi la retajn kaj dissendajn adresojn de la originalaj subretoj
   - Kreas provizoran tabelon por konservi la rezultojn

3. **Enumeracio de Subretoj**:
   - Trairas ĉiujn eblajn subretojn de la sama grandeco kiel la plej specifa originala subreto kiuj taŭgas ene de la agregaĵo
   - Por ĉiu ebla subreto, kontrolas ĉu ĝi kongruas kun iu ajn el la originalaj subretoj
   - Se ne, aldonas ĝin al la listo de maldezirataj subretoj

4. **Redono de Rezultoj**:
   - Redonas la liston de maldezirataj subretoj laŭ ordigita ordo

## Notoj

- La proceduro identigas subretojn je la sama prefikslongo kiel la plej specifa subreto en la originala listo
- Por grandaj agregaĵoj, la rezultaro povas esti tre granda
- La proceduro estas utila por:
  - Planado de IP-adresaj skemoj
  - Taksado de la efikeco de ruta agregado
  - Identigado de libera IP-spaco ene de agregaĵo
  - Taksado de la efiko de subreta resumado sur retaj tabeloj
