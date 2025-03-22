# Funkcio CHECK_SUBNET_RELATIONSHIP (Oracle)

Ĉi tiu funkcio analizas rilatojn inter pluraj IP-subretoj kaj determinas ĉu ili plenumas specifajn kriteriojn. La Oracle-implemento redonas nombran valoron (1 por vera, 0 por malvera) anstataŭ bulea valoro ĉar Oracle PL/SQL ne havas naturan bulean redontipon por funkcioj.

## Dokumentaj Lingvoj

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Instalado

Por instali ĉi tiun funkcion en via Oracle-datumbazo, plenumu la sekvajn SQL-komandojn laŭorde:

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

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE (necesa por kelkaj rilataj kontroloj):
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
    -- Kalkulu diferencigantojn por determini la nombron da subretoj
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Komencigu minimuman kaj maksimuman IP
    current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
    ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
    cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
    min_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
    max_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Traktu ĉiun subreton por trovi minimumajn kaj maksimumajn IP-adresojn
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
    
    -- Trovu komunajn bitojn de maldekstre dekstren
    common_bits := 0;
    WHILE common_bits < 32 LOOP
        IF BITAND(FLOOR(min_ip / POWER(2, 31 - common_bits)), 1) = 
           BITAND(FLOOR(max_ip / POWER(2, 31 - common_bits)), 1) THEN
            common_bits := common_bits + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Kalkulu la agregatan CIDR
    aggregate_cidr := common_bits;
    
    -- Kalkulu la agregatan retan adreson
    aggregate_ip := BITAND(min_ip, POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Redonu la rezulton
    RETURN NUM_TO_IP(aggregate_ip) || '/' || aggregate_cidr;
END;
/
```

3. Fine, instalu la funkcion CHECK_SUBNET_RELATIONSHIP:
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
    -- Kalkulu diferencigantojn por determini la nombron da subretoj
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Se malpli ol 2 subretoj, certaj rilatoj ne aplikiĝas
    IF total_subnets < 2 AND relationship_type != 'VALID' THEN
        RETURN 0;
    END IF;
    
    -- Kontrolu rilatojn kiuj aplikiĝas al ĉiuj subretaj paroj
    IF relationship_type = 'ADJACENT_CHAIN' THEN
        -- Ĉu ĉiuj subretoj estas apudaj kaj povas formi kontinuan blokon?
        -- Supozas ke enigo estas antaŭordigita
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i+1);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            -- Kontrolu ĉu la nuna paro estas apuda
            IF IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 != 
               IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2)) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'AGGREGABLE' THEN
        -- Ĉu ĉiuj subretoj estas perfekte agregeblaj kiel tutaĵo?
        -- Unue, kontrolu ĉu ĉiuj subretoj havas la saman CIDR
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
        
        -- Kalkulu la agregaĵon
        aggregate := FIND_SUBNETS_AGGREGATE(subnet_list);
        
        -- Kontrolu ĉu la agregata CIDR estas ĝuste 1 bito malpli specifa
        aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate, '[^/]+', 1, 2));
        
        -- La agregaĵo devus esti ĝuste unu bito malpli specifa ol la originaj subretoj
        IF aggregate_cidr != cidr1 - 1 THEN
            RETURN 0;
        END IF;
        
        -- Kontrolu ĉu la totala nombro da subretoj estas ĝuste 2^1 (2)
        -- Ĉi tio devas esti modifita por pluraj bitaj diferencoj
        IF total_subnets != POWER(2, cidr1 - aggregate_cidr) THEN
            RETURN 0;
        END IF;
        
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_DISJOINT' THEN
        -- Ĉu ĉiuj subretoj estas disjunktaj (sen superlapo)?
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
                
                -- Kontrolu ĉu la subretoj superlapiĝas
                IF NOT ((net1_end < net2_start) OR (net2_end < net1_start)) THEN
                    RETURN 0;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_INSIDE' THEN
        -- Ĉu ĉiuj subretoj estas enhavitaj en unu subreto?
        -- La lasta subreto en la listo estas supozita esti la enhavanto
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
            
            -- Kontrolu ĉu subreto1 estas ene de subreto2
            IF NOT (net1_start >= net2_start AND net1_end <= net2_end) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_IDENTICAL' THEN
        -- Ĉu ĉiuj subretoj estas identaj?
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
            
            -- Kontrolu ĉu subretoj estas identaj
            IF net1_start != net2_start OR net1_end != net2_end THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ANY_OVERLAPPING' THEN
        -- Ĉu iuj du subretoj en la listo superlapiĝas?
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
                
                -- Kontrolu ĉu la subretoj superlapiĝas
                IF net1_end >= net2_start AND net1_start <= net2_end THEN
                    RETURN 1;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 0;
        
    ELSIF relationship_type = 'VALID' THEN
        -- Kontrolu ĉu ĉiuj subretoj estas validaj IPv4-subretoj
        i := 1;
        WHILE i <= total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            -- Kontrolu ĉu subreto estas valida
            IF cidr1 < 0 OR cidr1 > 32 THEN
                RETURN 0;
            END IF;
            
            -- Kontrolu ĉu reta adreso kongruas kun CIDR-notacio
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

## Uzado

### Sintakso

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
```

### Parametroj

- **subnet_list**: Komadisigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: La tipo de rilato kontrolenda. Validaj valoroj estas:
  - 'ADJACENT_CHAIN': Kontrolas ĉu ĉiuj subretoj formas kontinuan ĉenon
  - 'AGGREGABLE': Kontrolas ĉu ĉiuj subretoj povas esti perfekte agregitaj
  - 'ALL_DISJOINT': Kontrolas ĉu ĉiuj subretoj estas disjunktaj (sen superlapo)
  - 'ALL_INSIDE': Kontrolas ĉu ĉiuj subretoj estas enhavitaj en la lasta subreto de la listo
  - 'ALL_IDENTICAL': Kontrolas ĉu ĉiuj subretoj estas identaj
  - 'ANY_OVERLAPPING': Kontrolas ĉu iuj du subretoj en la listo superlapiĝas
  - 'VALID': Kontrolas ĉu ĉiuj subretoj estas validaj IPv4-subretoj

### Redonvaloro

Redonas 1 (vera) aŭ 0 (malvera) indikante ĉu la specifita rilato validas por la donitaj subretoj.

## Ekzemploj

1. Kontrolu ĉu subretoj estas apudaj kaj formas ĉenon:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') AS rezulto FROM DUAL;
-- Redonas 1 (vera)
```

2. Kontrolu ĉu subretoj povas esti perfekte agregitaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') AS rezulto FROM DUAL;
-- Redonas 1 (vera) ĉar ili povas esti agregitaj al 192.168.0.0/23
```

3. Kontrolu ĉu subretoj estas ĉiuj ene de enhava subreto:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') AS rezulto FROM DUAL;
-- Redonas 1 (vera) ĉar ambaŭ /24 subretoj estas ene de la /22 subreto
```

4. Kontrolu ĉu iuj subretoj superlapiĝas:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') AS rezulto FROM DUAL;
-- Redonas 1 (vera) ĉar 192.168.1.0/24 superlapiĝas kun 192.168.1.128/25
```

5. Kontrolu ĉu ĉiuj subretoj estas validaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') AS rezulto FROM DUAL;
-- Redonas 1 (vera) ĉar ĉiuj subretoj estas validaj
```

## Diferencoj kompare kun la MySQL-Implemento

La Oracle-implemento diferencas de la MySQL-versio en pluraj manieroj:

1. **Redontipon**: Oracle-funkcioj ne povas redoni bulean valoron rekte, do ĉi tiu funkcio redonas 1 por vera kaj 0 por malvera.

2. **Ĉentrajtado**: Oracle uzas `REGEXP_SUBSTR` por ĉenparsado anstataŭ MySQL-a `SUBSTRING_INDEX`.

3. **IP-Konverto**: Ĉar Oracle ne havas enkonstruitajn funkciojn kiel `INET_ATON` kaj `INET_NTOA`, ni uzas proprajn funkciojn `IP_TO_NUM` kaj `NUM_TO_IP`.

4. **Bitmanipulado**: Oracle uzas `BITAND` por bitecaj KAJ-operacioj, kaj malsaman logikon por bitŝovado ĉar ĝi ne havas rektajn bitŝovajn operatorojn.

5. **Fluo-Regado**: Oracle uzas `IF-ELSIF-ELSE`-konstruaĵojn anstataŭ MySQL-aj `CASE`-deklaro por la ĉefa rilata logiko.

## Notoj

- La funkcio supozas ke la subretaj specifoj estas en la ĝusta formato.
- Por 'ADJACENT_CHAIN', la subretoj devus esti provizitaj laŭorde.
- La 'AGGREGABLE' kontrolo funkcias plej bone kiam ĉiuj subretoj havas la saman CIDR-prefikslongon.
- Kiam oni uzas 'ALL_INSIDE', la enhavanta subreto devus esti la lasta en la listo.
- Oracle PL/SQL postulas ke ĉiuj deklaroj havu punktokomon (;) finaĵon, kaj funkcioj finiĝu per oblikva streko (/) por indiki la finon de la funkcidefino.
