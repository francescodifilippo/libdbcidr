# Procedura LIST_UNWANTED_SUBNETS (MySQL)

Haec procedura identificat subretes quae in aggregatione includerentur sed non sunt pars elenchi subretium originalis. Adiuvat administratores retis ad analysandum "dispendium" cum subretes non contiguae aggregantur.

## Linguae Documentationis

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Installatio

Ad hanc proceduram in tua base datorum MySQL installandam, exsequere haec mandata SQL per ordinem:

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

2. Deinde installa proceduram LIST_UNWANTED_SUBNETS:
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
    
    -- Crea tabulam temporariam pro subretibus originalibus
    DROP TEMPORARY TABLE IF EXISTS original_subnets;
    CREATE TEMPORARY TABLE original_subnets (
        network_address BIGINT,
        broadcast_address BIGINT,
        cidr INT
    );
    
    -- Analysa subretem aggregatam
    SET aggregate_ip = SUBSTRING_INDEX(aggregate_subnet, '/', 1);
    SET aggregate_cidr = CAST(SUBSTRING_INDEX(aggregate_subnet, '/', -1) AS UNSIGNED);
    SET aggregate_start = INET_ATON(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    SET aggregate_end = INET_ATON(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Divide elenchum subretium per commata et numera subretes
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Processa quamque subretem originalem
    WHILE i <= total_subnets DO
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET original_ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET original_cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        
        -- Serva CIDR minimum (maxime specificum)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            SET smallest_cidr = original_cidr;
        END IF;
        
        -- Insere in tabulam subretium originalium
        INSERT INTO original_subnets VALUES (
            INET_ATON(GET_NETWORK_ADDRESS(original_ip, original_cidr)),
            INET_ATON(GET_BROADCAST_ADDRESS(original_ip, original_cidr)),
            original_cidr
        );
        
        SET i = i + 1;
    END WHILE;
    
    -- Crea tabulam temporariam pro resultatis
    DROP TEMPORARY TABLE IF EXISTS unwanted_subnets;
    CREATE TEMPORARY TABLE unwanted_subnets (
        subnet VARCHAR(50)
    );
    
    -- Determina magnitudinem subretis basatam in CIDR minimo (maxime specifico)
    SET subnet_size = POWER(2, 32 - smallest_cidr);
    
    -- Itera per omnes subretes possibiles in aggregatione
    SET current_subnet_start = aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end DO
        -- Calcula finem huius subretis
        SET current_subnet_end = current_subnet_start + subnet_size - 1;
        
        -- Verifica si haec subretis est pars subretium originalium
        IF NOT EXISTS (
            SELECT 1 FROM original_subnets 
            WHERE network_address = current_subnet_start AND broadcast_address = current_subnet_end
        ) THEN
            -- Haec est subretis indesiderata, adde ad resultata
            INSERT INTO unwanted_subnets VALUES (
                CONCAT(INET_NTOA(current_subnet_start), '/', smallest_cidr)
            );
        END IF;
        
        -- Move ad proximam subretem
        SET current_subnet_start = current_subnet_start + subnet_size;
    END WHILE;
    
    -- Redde resultata
    SELECT subnet FROM unwanted_subnets ORDER BY subnet;
END;
```

## Usus

### Syntaxis

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parametri

- **subnet_list**: Elenchus subretium separatarum per commata in notatione CIDR (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: Specificatio subretis aggregatae in notatione CIDR (e.g., '192.168.0.0/22')

### Valor Reditus

Reddit resultatum continentem unam columnam nominatam 'subnet' cum unaquaque linea repraesentante subretem indesideratam (in notatione CIDR) inclusam in aggregatione sed non partem subretium originalium.

## Exempla

1. Inveni subretes indesideratas cum aggregas subretes /24 non contiguas:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Resultatum:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Inveni subretes indesideratas cum aggregas subretes cum diversis longitudinibus praefixorum:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Resultatum:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verifica nullas subretes indesideratas pro subretibus perfecte aggregabilibus:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Resultatum: Resultatum vacuum (nullae subretes indesideratae)

4. Inveni subretes indesideratas in aggregatione magna:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Resultatum: Resultatum valde magnum continens omnes retes /24 in spatio IPv4 exceptis duabus specificatis.

## Quomodo Procedura Operatur

Procedura operatur per plures gradus:

1. **Analysis Ingressus**: 
   - Analysat elenchum subretium originalem et subretem aggregatam
   - Identificat longitudinem praefixorum CIDR minime specificam (maximum) inter subretes originales

2. **Creatio Structurarum Datorum**:
   - Creat tabulam temporariam ad servandum inscriptiones retium et divulgationum subretium originalium
   - Creat tabulam temporariam ad servanda resultata

3. **Enumeratio Subretium**:
   - Iterat per omnes subretes possibiles eiusdem magnitudinis ac subretis originalibus maxime specificis quae cadunt intra aggregationem
   - Pro quaque subrete possibili, verificat si congruit cum aliqua subreti originali
   - Si non, addit ad elenchum subretium indesideratarum

4. **Redditio Resultatorum**:
   - Reddit elenchum subretium indesideratarum in ordine ordinato

## Notae

- Procedura identificat subretes ad eandem longitudinem praefixorum ac subretis maxime specifica in elencho originali
- Pro aggregationibus magnis, resultatum potest esse valde magnum
- Procedura est utilis pro:
  - Planificatione schematum inscriptionum IP
  - Aestimatione efficientiae aggregationis viarium
  - Identificatione spatii IP liberi intra aggregationem
  - Aestimatione impactus summarizationis subretium in tabulis directorialibus
