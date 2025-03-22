# FIND_SUBNETS_AGGREGATE Funkcio (Oracle)

Ĉi tiu funkcio kalkulas la minimuman agregatan subreton kiu ampleksas ĉiujn provizitajn IP-subretojn.

## Dokumentada Lingvoj

- [English](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)

## Instalado

Por instali ĉi tiun funkcion en via Oracle datumbazo, unue vi devas instali la helpajn funkciojn se vi ankoraŭ ne havas ilin. Poste, vi povas instali la FIND_SUBNETS_AGGREGATE funkcion mem.

Vi povas trovi la tutan necesan SQL-kodon en la dosiero [`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql).

## Uzado

### Sintakso

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list) FROM DUAL;
```

### Parametroj

- **subnet_list**: Komo-apartigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.2.0/24')

### Revena Valoro

Redonas ĉenon reprezentantan la minimuman agregatan subreton (en CIDR-notacio) kiu ampleksas ĉiujn provizitajn subretojn.

## Ekzemploj

1. Trovi la agregaĵon de du apudaj /24 subretoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24') FROM DUAL;
-- Redonas '192.168.0.0/23'
```

2. Trovi la agregaĵon de neapudaj subretoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24') FROM DUAL;
-- Redonas '192.168.0.0/22'
```

3. Trovi la agregaĵon de subretoj kun malsamaj CIDR-longecoj:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23') FROM DUAL;
-- Redonas '10.0.0.0/22'
```

4. Trovi la agregaĵon de subretoj el malsamaj adrespaco:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24') FROM DUAL;
-- Redonas '0.0.0.0/0' (la tuta IPv4 adrespaco)
```

5. Trovi la agregaĵon de unuopa subreto (redonas la saman subreton):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24') FROM DUAL;
-- Redonas '192.168.1.0/24'
```

## Kiel Ĝi Funkcias

La funkcio operacias en pluraj paŝoj:

1. **Analizi la subretan liston**: Disigas la komo-apartigitan liston kaj kalkulas la nombron de subretoj.

2. **Trovi la minimumajn kaj maksimumajn IP-adresojn**: 
   - Konvertas ĉiun subreton al ĝia retadreso kaj dissendadreso
   - Konservas la plej malaltan retadreson kaj la plej altan dissendadreson

3. **Kalkuli la komunan prefikson**:
   - Komencante de la plej maldekstra bito, kalkulas kiom da bitoj estas identaj inter la minimumaj kaj maksimumaj IP-adresoj
   - Ĉi tiu kalkulo fariĝas la CIDR-prefiksa longo por la agregata subreto

4. **Komputi la retadreson**:
   - Aplikas la maskon derivitan de la prefiksa longo al la minimuma IP-adreso
   - Tio certigas ke la retadreso estas ĝuste vicigita al la CIDR-limo

5. **Generi la CIDR-notacion**:
   - Kombinas la retadreson kun la prefiksa longo por krei la agregatan subretan specifon

## Notoj

- La funkcio ĉiam redonas la plej malgrandan eblan agregaĵon kiu enhavas ĉiujn enigajn subretojn.
- Kiam subretoj estas malproksimaj, la agregaĵo povas inkluzivi signifan nombron da nedezirataj IP-adresoj.
- Por subretoj el malsamaj ĉefaj blokoj (ekz. 10.x.x.x kaj 192.168.x.x), la agregaĵo estos tre granda.
- Por identigi nedeziratajn subretojn inkluzivitajn en la agregaĵo, uzu la `LIST_UNWANTED_SUBNETS` proceduron.
