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
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Poste instalu la proceduron LIST_UNWANTED_SUBNETS:
[`LIST_UNWANTED_SUBNETS_Oracle.sql`](./sql/LIST_UNWANTED_SUBNETS_Oracle.sql)

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
