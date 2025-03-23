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
1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Poste instalu la proceduron LIST_UNWANTED_SUBNETS:
[`LIST_UNWANTED_SUBNETS_MySQL.sql`](./sql/LIST_UNWANTED_SUBNETS_MySQL.sql)

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
