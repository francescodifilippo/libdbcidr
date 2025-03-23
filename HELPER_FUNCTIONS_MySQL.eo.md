# Helpaj Funkcioj por IP-Subreta Administrado (MySQL)

Ĉi tiu dokumento priskribas la esencajn helpajn funkciojn necesajn por IP-subretaj operacioj en MySQL. Ĉi tiuj funkcioj provizas la fundamentajn konstrubrikojn por la pli kompleksaj subretaj administraj operacioj.

## Dokumentaj Lingvoj

- [English](./HELPER_FUNCTIONS_MySQL.en.md)
- [Italiano](./HELPER_FUNCTIONS_MySQL.it.md)
- [Latina](./HELPER_FUNCTIONS_MySQL.la.md)
- [Esperanto](./HELPER_FUNCTIONS_MySQL.eo.md)

## Instalado

Por instali ĉi tiujn helpajn funkciojn en via MySQL-datumbazo, plenumu la sekvajn SQL-komandojn:

[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

## Funkcio-Priskriboj

### GET_NETWORK_ADDRESS

Ĉi tiu funkcio kalkulas la retan adreson por donita IP-adreso kaj CIDR-prefikslongo.

#### Sintakso

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parametroj

- **ip**: Ĉeno reprezentanta IPv4-adreson (ekz., '192.168.1.1')
- **cidr**: Entjero reprezentanta la CIDR-prefikslongon (0-32)

#### Redonvaloro

Redonas ĉenon enhavanta la retan adreson en punktigita decimala notacio.

#### Kiel Ĝi Funkcias

La funkcio:
1. Konvertas la IP-adreson al nombra valoro uzante la funkcion `INET_ATON()` de MySQL
2. Kalkulas la subretan maskon el la CIDR-prefikslongo
3. Aplikas bitecajn KAJ-operacion inter la IP kaj la masko por akiri la retan adreson
4. Konvertas la rezulton reen al punktigita decimala notacio uzante `INET_NTOA()`

### GET_BROADCAST_ADDRESS

Ĉi tiu funkcio kalkulas la dissendadreson por donita IP-adreso kaj CIDR-prefikslongo.

#### Sintakso

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parametroj

- **ip**: Ĉeno reprezentanta IPv4-adreson (ekz., '192.168.1.1')
- **cidr**: Entjero reprezentanta la CIDR-prefikslongon (0-32)

#### Redonvaloro

Redonas ĉenon enhavanta la dissendadreson en punktigita decimala notacio.

#### Kiel Ĝi Funkcias

La funkcio:
1. Konvertas la IP-adreson al nombra valoro uzante la funkcion `INET_ATON()` de MySQL
2. Kalkulas la subretan maskon el la CIDR-prefikslongo
3. Aplikas bitecajn AŬ-operacion inter la IP kaj la inversiĝita masko por akiri la dissendadreson
4. Konvertas la rezulton reen al punktigita decimala notacio uzante `INET_NTOA()`

## Ekzemploj

### Trovi la Retan Adreson

```sql
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24);
-- Redonas '192.168.1.0'

SELECT GET_NETWORK_ADDRESS('10.45.67.89', 16);
-- Redonas '10.45.0.0'

SELECT GET_NETWORK_ADDRESS('172.16.28.30', 20);
-- Redonas '172.16.16.0'
```

### Trovi la Dissendadreson

```sql
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24);
-- Redonas '192.168.1.255'

SELECT GET_BROADCAST_ADDRESS('10.45.67.89', 16);
-- Redonas '10.45.255.255'

SELECT GET_BROADCAST_ADDRESS('172.16.28.30', 20);
-- Redonas '172.16.31.255'
```

### Uzi Ambaŭ Funkciojn Kune

```sql
-- Trovi kaj la retan adreson kaj la dissendadreson por subreto
SELECT 
    GET_NETWORK_ADDRESS('192.168.5.37', 22) AS reta_adreso,
    GET_BROADCAST_ADDRESS('192.168.5.37', 22) AS dissenda_adreso;
-- Redonas:
-- reta_adreso: '192.168.4.0'
-- dissenda_adreso: '192.168.7.255'

-- Kontroli ĉu IP estas en specifa subreto
SELECT 
    '10.20.30.40' AS ip,
    '10.20.0.0/16' AS subreto,
    (INET_ATON('10.20.30.40') BETWEEN 
     INET_ATON(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
     INET_ATON(GET_BROADCAST_ADDRESS('10.20.0.0', 16))) AS estas_en_subreto;
-- Redonas 1 (TRUE) indikante ke la IP estas en la subreto
```

## Notoj

- Ĉi tiuj funkcioj dependas de la enkonstruitaj funkcioj `INET_ATON()` kaj `INET_NTOA()` de MySQL, kiuj disponeblas en MySQL 5.6.3 kaj poste.
- La funkcioj havas la atributon `DETERMINISTIC`, kio helpas pri peto-optimumigo.
- Ĉi tiuj helpaj funkcioj estas necesaj antaŭkondiĉoj por la aliaj subretaj administraj funkcioj:
  - `CHECK_SUBNET_RELATIONSHIP`
  - `FIND_SUBNETS_AGGREGATE`
  - `LIST_UNWANTED_SUBNETS`
- La nuna implemento subtenas nur IPv4-adresojn.
