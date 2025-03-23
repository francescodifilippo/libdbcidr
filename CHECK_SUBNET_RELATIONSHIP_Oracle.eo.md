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
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE (necesa por kelkaj rilataj kontroloj):
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

3. Fine, instalu la funkcion CHECK_SUBNET_RELATIONSHIP:
[`CHECK_SUBNET_RELATIONSHIP_Oracle.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_Oracle.sql)

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
