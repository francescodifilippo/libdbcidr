# Helpaj Funkcioj por IP-Subreta Administrado (Oracle)

Ĉi tiu dokumento priskribas la esencajn helpajn funkciojn necesajn por IP-subretaj operacioj en Oracle Database. Ĉi tiuj funkcioj provizas la fundamentajn konstrubrikojn por la pli kompleksaj subretaj administraj operacioj kaj kompensigas pro la manko de naturaj funkcioj por manipulado de IP-adresoj en Oracle.

## Dokumentaj Lingvoj

- [English](./HELPER_FUNCTIONS_Oracle.en.md)
- [Italiano](./HELPER_FUNCTIONS_Oracle.it.md)
- [Latina](./HELPER_FUNCTIONS_Oracle.la.md)
- [Esperanto](./HELPER_FUNCTIONS_Oracle.eo.md)

## Instalado

Por instali ĉi tiujn helpajn funkciojn en via Oracle-datumbazo, plenumu la sekvajn SQL-komandojn:

[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

## Funkcio-Priskriboj

### IP_TO_NUM

Ĉi tiu funkcio konvertas IPv4-adreson en punktigita decimala notacio al ĝia nombra reprezentaĵo.

#### Sintakso

```sql
IP_TO_NUM(ip_address)
```

#### Parametroj

- **ip_address**: Ĉeno reprezentanta IPv4-adreson (ekz., '192.168.1.1')

#### Redonvaloro

Redonas NUMBER reprezentantan la nombran valoron de la IP-adreso.

#### Kiel Ĝi Funkcias

La funkcio:
1. Uzas Oracle `REGEXP_SUBSTR` por eltiri ĉiun oktedon el la punktigita decimala notacio
2. Konvertas ĉiun oktedon al nombro per `TO_NUMBER`
3. Kalkulas la finan nombran reprezentaĵon per multipliki ĉiun oktedon per la taŭga potenco de 256
4. Redonas la sumon, kiu estas la nombra reprezentaĵo de la IPv4-adreso

### NUM_TO_IP

Ĉi tiu funkcio konvertas nombran reprezentaĵon de IPv4-adreso reen al punktigita decimala notacio.

#### Sintakso

```sql
NUM_TO_IP(ip_num)
```

#### Parametroj

- **ip_num**: NUMBER reprezentanta la nombran valoron de IPv4-adreso

#### Redonvaloro

Redonas ĉenon enhavanta la IP-adreson en punktigita decimala notacio.

#### Kiel Ĝi Funkcias

La funkcio:
1. Eltiras ĉiun oktedon per efektivigi divido- kaj modulo-operaciojn sur la enira nombro
2. Uzas `TRUNC` por certigi tutaj rezultoj
3. Kunmetas la oktetojn kun punktoj por formi la punktigitan decimalan reprezentaĵon

### GET_NETWORK_ADDRESS

Ĉi tiu funkcio kalkulas la retan adreson por donita IP-adreso kaj CIDR-prefikslongo.

#### Sintakso

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parametroj

- **ip**: Ĉeno reprezentanta IPv4-adreson (ekz., '192.168.1.1')
- **cidr**: Nombro reprezentanta la CIDR-prefikslongon (0-32)

#### Redonvaloro

Redonas ĉenon enhavanta la retan adreson en punktigita decimala notacio.

#### Kiel Ĝi Funkcias

La funkcio:
1. Konvertas la IP-adreson al nombra valoro uzante `IP_TO_NUM`
2. Kalkulas la subretan maskon el la CIDR-prefikslongo
3. Aplikas bitecajn KAJ-operacion uzante Oracle-funkcion `BITAND` inter la IP kaj la masko por akiri la retan adreson
4. Konvertas la rezulton reen al punktigita decimala notacio uzante `NUM_TO_IP`

### GET_BROADCAST_ADDRESS

Ĉi tiu funkcio kalkulas la dissendadreson por donita IP-adreso kaj CIDR-prefikslongo.

#### Sintakso

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parametroj

- **ip**: Ĉeno reprezentanta IPv4-adreson (ekz., '192.168.1.1')
- **cidr**: Nombro reprezentanta la CIDR-prefikslongon (0-32)

#### Redonvaloro

Redonas ĉenon enhavanta la dissendadreson en punktigita decimala notacio.

#### Kiel Ĝi Funkcias

La funkcio:
1. Konvertas la IP-adreson al nombra valoro uzante `IP_TO_NUM`
2. Kalkulas la subretan maskon el la CIDR-prefikslongo
3. Aldonas la nombron da gastigantoj en la subreto (2^(32-cidr) - 1) al la reta adreso por akiri la dissendadreson
4. Konvertas la rezulton reen al punktigita decimala notacio uzante `NUM_TO_IP`

## Ekzemploj

### Konvertado Inter IP-Formatoj

```sql
-- Konverti IP-adreson al nombro
SELECT IP_TO_NUM('192.168.1.1') AS ip_num FROM DUAL;
-- Redonas 3232235777

-- Konverti nombron reen al IP-adreso
SELECT NUM_TO_IP(3232235777) AS ip_address FROM DUAL;
-- Redonas '192.168.1.1'
```

### Trovi Retajn kaj Dissendadresojn

```sql
-- Trovi la retan adreson por subreto
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24) AS reta_adreso FROM DUAL;
-- Redonas '192.168.1.0'

-- Trovi la dissendadreson por subreto
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24) AS dissenda_adreso FROM DUAL;
-- Redonas '192.168.1.255'

-- Trovi ambaŭ por malsama subreto
SELECT 
    GET_NETWORK_ADDRESS('10.45.67.89', 16) AS reta_adreso,
    GET_BROADCAST_ADDRESS('10.45.67.89', 16) AS dissenda_adreso
FROM DUAL;
-- Redonas:
-- reta_adreso: '10.45.0.0'
-- dissenda_adreso: '10.45.255.255'
```

### Uzi Funkciojn en Demandoj

```sql
-- Kontroli ĉu IP estas en specifa subreto
WITH test_data AS (
    SELECT '10.20.30.40' AS ip FROM DUAL
)
SELECT 
    ip,
    '10.20.0.0/16' AS subreto,
    CASE 
        WHEN IP_TO_NUM(ip) BETWEEN 
            IP_TO_NUM(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
            IP_TO_NUM(GET_BROADCAST_ADDRESS('10.20.0.0', 16))
        THEN 'JES'
        ELSE 'NE'
    END AS estas_en_subreto
FROM test_data;
-- Redonas 'JES' indikante ke la IP estas en la subreto
```

## Diferencoj Kompare kun MySQL

Ĉi tiuj Oracle helpaj funkcioj estis kreitaj por anstataŭigi la enkonstruitajn funkciojn de MySQL por manipulado de IP-adresoj:

1. **IP_TO_NUM kaj NUM_TO_IP**: Anstataŭigas MySQL-funkciojn `INET_ATON()` kaj `INET_NTOA()` respektive.

2. **Ĉentrakado**: Oracle uzas `REGEXP_SUBSTR` por analizi IP-oktetojn, dum MySQL povas uzi `SUBSTRING_INDEX`.

3. **Bitmanipulado**: Oracle uzas `BITAND` por bitecaj KAJ-operacioj, dum MySQL uzas la `&` operatoron.

4. **Funkcio-Sintakso**: Oracle postulas oblikvan strekon antaŭen (/) post la funkciodifino por indiki la finon de la funkcikorpo.

## Notoj

- Ĉi tiuj helpaj funkcioj estas necesaj antaŭkondiĉoj por la aliaj subretaj administraj funkcioj en Oracle.
- La nuna implemento subtenas nur IPv4-adresojn.
- Oracle traktas nombrajn IP-adresojn kiel normalajn nombrojn, do kalkuloj koncernantaj tre grandajn subretojn povas bezoni specialan atenton por certigi nombran precizecon.
- En Oracle, la funkcio `IP_TO_NUM` redonas NUMBER-datumtipon, kiu havas sufiĉan precizecon por trakti la plenan gamon de IPv4-adresoj (0 ĝis 4,294,967,295).
