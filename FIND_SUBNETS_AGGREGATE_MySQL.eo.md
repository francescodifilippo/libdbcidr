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
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE:
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

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
