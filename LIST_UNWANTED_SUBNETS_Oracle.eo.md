# Proceduro LIST_UNWANTED_SUBNETS (Oracle)

Ĉi tiu proceduro identigas subretojn kiuj estus inkluzivitaj en agregaĵo sed ne estas parto de la originala subreto-listo. Ĝi helpas ret-administrantojn analizi la "malŝparaĵon" kiam oni agregas neapudajn subretojn.

## Dokumentaj Lingvoj

- [English](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)

## Instalado

Por instali ĉi tiun proceduron en via Oracle-datumbazo, plenumu la jenajn SQL-komandojn laŭorde:

1. Unue, instalu la helpajn funkciojn se vi ankoraŭ ne faris tion:
```sql
-- Konverti IP-adreson al nombro
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

-- Konverti nombron al IP-adreso
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

-- Helpa funkcio por akiri la retan adreson el IP kaj CIDR
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

-- Helpa funkcio por akiri la dissendadreson el IP kaj CIDR
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

2. Poste instalu la proceduron LIST_UNWANTED_SUBNETS:
```sql
CREATE OR REPLACE PROCEDURE LIST_UNWANTED_SUBNETS(
    subnet_list IN VARCHAR2,
    aggregate_subnet IN VARCHAR2,
    result_cursor OUT SYS_REFCURSOR
) IS
    TYPE subnet_rec IS RECORD (
        network_address NUMBER,
        broadcast_address NUMBER,
        cidr NUMBER
    );
    
    TYPE subnet_table IS TABLE OF subnet_rec;
    original_subnets subnet_table := subnet_table();
    
    i NUMBER := 1;
    total_subnets NUMBER;
    current_subnet VARCHAR2(50);
    original_ip VARCHAR2(15);
    original_cidr NUMBER;
    aggregate_ip VARCHAR2(15);
    aggregate_cidr NUMBER;
    smallest_cidr NUMBER := 0;
    aggregate_start NUMBER;
    aggregate_end NUMBER;
    subnet_size NUMBER;
    current_subnet_start NUMBER;
    current_subnet_end NUMBER;
    is_original BOOLEAN;
    delimiter_count NUMBER;
BEGIN
    -- Analizu la agregatan subreton
    aggregate_ip := REGEXP_SUBSTR(aggregate_subnet, '[^/]+', 1, 1);
    aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate_subnet, '[^/]+', 1, 2));
    aggregate_start := IP_TO_NUM(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    aggregate_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Kalkulu diferencigantojn
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Traktu ĉiun originalan subreton
    WHILE i <= total_subnets LOOP
        current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
        original_ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
        original_cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
        
        -- Konservu la plej specifan CIDR (la plej altan numeron)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            smallest_cidr := original_cidr;
        END IF;
        
        -- Aldonu al originala subreto-kolekto
        original_subnets.EXTEND;
        original_subnets(original_subnets.LAST).network_address := 
            IP_TO_NUM(GET_NETWORK_ADDRESS(original_ip, original_cidr));
        original_subnets(original_subnets.LAST).broadcast_address := 
            IP_TO_NUM(GET_BROADCAST_ADDRESS(original_ip, original_cidr));
        original_subnets(original_subnets.LAST).cidr := original_cidr;
        
        i := i + 1;
    END LOOP;
    
    -- Kreu provizoran tabelon por rezultoj se ĝi ne jam ekzistas
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE unwanted_subnets_temp';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    
    EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE unwanted_subnets_temp (
        subnet VARCHAR2(50)
    ) ON COMMIT PRESERVE ROWS';
    
    -- Determinu la subretan grandecon bazitan sur la plej specifa CIDR
    subnet_size := POWER(2, 32 - smallest_cidr);
    
    -- Trairu ĉiujn eblajn subretojn en la agregaĵo
    current_subnet_start := aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end LOOP
        -- Kalkulu la finon de ĉi tiu subreto
        current_subnet_end := current_subnet_start + subnet_size - 1;
        
        -- Kontrolu ĉu ĉi tiu subreto estas parto de la originalaj subretoj
        is_original := FALSE;
        FOR j IN 1..original_subnets.COUNT LOOP
            IF original_subnets(j).network_address = current_subnet_start AND 
               original_subnets(j).broadcast_address = current_subnet_end THEN
                is_original := TRUE;
                EXIT;
            END IF;
        END LOOP;
        
        IF NOT is_original THEN
            -- Ĉi tiu estas maldezirata subreto, aldonu ĝin al rezultoj
            EXECUTE IMMEDIATE 'INSERT INTO unwanted_subnets_temp VALUES (:1)' 
            USING NUM_TO_IP(current_subnet_start) || '/' || smallest_cidr;
        END IF;
        
        -- Movu al sekva subreto
        current_subnet_start := current_subnet_start + subnet_size;
    END LOOP;
    
    -- Redonu la rezultojn
    OPEN result_cursor FOR
        SELECT subnet FROM unwanted_subnets_temp ORDER BY subnet;
END;
/
```

## Uzado

### Sintakso

```sql
-- Deklaru kurson variablon
VARIABLE result_cursor REFCURSOR;

-- Voku la proceduron
EXEC LIST_UNWANTED_SUBNETS('subnet_list', 'aggregate_subnet', :result_cursor);

-- Presu la rezultojn
PRINT result_cursor;
```

### Parametroj

- **subnet_list**: Komodisigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: La agregaĵa subreta specifo en CIDR-notacio (ekz., '192.168.0.0/22')
- **result_cursor**: Elira parametro kiu redonas kursoron kun la rezultoj

### Redonvaloro

Redonas kursoron montrante al rezultaro enhavantan unu kolonon nomitan 'subnet' kun ĉiu vico reprezentanta maldezirata subreto (en CIDR-notacio) inkluzivita en la agregaĵo sed ne parto de la originalaj subretoj.

## Ekzemploj

1. Trovi maldeziratajn subretojn kiam oni agregas neapudajn /24 subretojn:
```sql
-- Deklaru kursoron variablon
VARIABLE result_cursor REFCURSOR;

-- Plenumu proceduron
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);

-- Presu rezultojn
PRINT result_cursor;
```
Rezulto:
```
SUBNET
----------------
192.168.0.0/24
192.168.2.0/24
```

2. Trovi maldeziratajn subretojn kiam oni agregas subretojn kun malsamaj prefikslongoj:
```sql
-- Deklaru kursoron variablon
VARIABLE result_cursor REFCURSOR;

-- Plenumu proceduron
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22', :result_cursor);

-- Presu rezultojn
PRINT result_cursor;
```
Rezulto:
```
SUBNET
-------------
10.0.1.0/24
10.0.2.0/24
```

3. Kontrolu ke ne estas maldezirataj subretoj por perfekte agregeblaj subretoj:
```sql
-- Deklaru kursoron variablon
VARIABLE result_cursor REFCURSOR;

-- Plenumu proceduron
EXEC LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23', :result_cursor);

-- Presu rezultojn
PRINT result_cursor;
```
Rezulto: Malplena rezultaro (neniuj maldezirataj subretoj)

## Kiel Ĝi Funkcias

La proceduro funkcias laŭ pluraj paŝoj:

1. **Analizo de Enigo**: 
   - Analizas la originalan subreto-liston kaj la agregatan subreton
   - Identigas la plej specifan CIDR-prefikslongon inter la originalaj subretoj

2. **Kreado de Data-Strukturoj**:
   - Kreas kolekton por konservi la retajn kaj dissendajn adresojn de la originalaj subretoj
   - Kreas provizoran tabelon por konservi la rezultojn

3. **Enumeracio de Subretoj**:
   - Trairas ĉiujn eblajn subretojn de la sama grandeco kiel la plej specifa originala subreto kiuj taŭgas ene de la agregaĵo
   - Por ĉiu ebla subreto, kontrolas ĉu ĝi kongruas kun iu ajn el la originalaj subretoj
   - Se ne, aldonas ĝin al la listo de maldezirataj subretoj

4. **Redono de Rezultoj**:
   - Malfermas kursoron enhavanta la liston de maldezirataj subretoj laŭ ordigita ordo

## Diferencoj kompare kun la MySQL-Implemento

La Oracle-implemento diferencas de la MySQL-versio en pluraj manieroj:

1. **Metodo de Redonado de Rezultoj**: Oracle uzas REF CURSOR por redoni la rezultaron, dum MySQL rekte redonas rezultaron de la proceduro.

2. **Kolektoj kontraŭ Provizoraj Tabeloj**: Oracle uzas PL/SQL-kolektojn (nestitajn tabelojn) por konservi originalajn subretajn datumojn en memoro antaŭ ol kontroli maldeziratajn subretojn, dum MySQL kreas provizoran tabelon.

3. **Ĉentraktado**: Oracle uzas `REGEXP_SUBSTR` por ĉenparsado anstataŭ MySQL-a `SUBSTRING_INDEX`.

4. **IP-Konverto**: Oracle uzas proprajn funkciojn `IP_TO_NUM` kaj `NUM_TO_IP` ĉar ĝi mankas enkonstruitajn funkciojn kiel MySQL-aj `INET_ATON` kaj `INET_NTOA`.

5. **Erartraktado**: La Oracle-versio inkluzivas esceptotraktadon por forfaligo de la provizora tabelo se ĝi ne ekzistas.

6. **Provizoraj Tabeloj**: Oracle uzas tutmondajn provizorajn tabelojn kun la opcio `ON COMMIT PRESERVE ROWS`, certigante ke la datumoj restas haveblaj post la transakcio.

## Notoj

- La proceduro identigas subretojn je la sama prefikslongo kiel la plej specifa subreto en la originala listo
- Por grandaj agregaĵoj, la rezultaro povas esti tre granda
- La proceduro estas utila por:
  - Planado de IP-adresaj skemoj
  - Taksado de la efikeco de ruta agregado
  - Identigado de libera IP-spaco ene de agregaĵo
  - Taksado de la efiko de subreta resumado sur retaj tabeloj
- En Oracle, por vidi la rezultojn, vi devas uzi la komandon `PRINT` post la procedurplenumado, aŭ akiri el la kursoro en PL/SQL-bloko
- La deklaroj `EXECUTE IMMEDIATE` estas uzataj por dinamika SQL por krei kaj manipuli la provizoran tabelon
