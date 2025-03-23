# Funkcio CHECK_SUBNET_RELATIONSHIP (MySQL)

Ĉi tiu funkcio analizas rilatojn inter pluraj IP-subretoj kaj determinas ĉu ili plenumas specifajn kriteriojn.

## Dokumentaj Lingvoj

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

## Instalado

Por instali ĉi tiun funkcion en via MySQL-datumbazo, plenumu la sekvajn SQL-komandojn laŭorde:

1. Unue, instalu la helpajn funkciojn se vi ankoraŭ ne faris tion:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Poste instalu la funkcion FIND_SUBNETS_AGGREGATE (necesa por kelkaj rilataj kontroloj):
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

3. Fine, instalu la funkcion CHECK_SUBNET_RELATIONSHIP:
[`CHECK_SUBNET_RELATIONSHIP_MySQL.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_MySQL.sql)

## Uzado

### Sintakso

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
```

### Parametroj

- **subnet_list**: Komodisigita listo de subretaj specifoj en CIDR-notacio (ekz., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: La tipo de rilato kontrolenda. Validaj valoroj estas:
  - 'ADJACENT_CHAIN': Kontrolas ĉu ĉiuj subretoj formas kontinuan ĉenon
  - 'AGGREGABLE': Kontrolas ĉu ĉiuj subretoj povas esti perfekte agregitaj
  - 'ALL_DISJOINT': Kontrolas ĉu ĉiuj subretoj estas disjunktaj (sen superlapo)
  - 'ALL_INSIDE': Kontrolas ĉu ĉiuj subretoj estas enhavitaj en la lasta subreto de la listo
  - 'ALL_IDENTICAL': Kontrolas ĉu ĉiuj subretoj estas identaj
  - 'ANY_OVERLAPPING': Kontrolas ĉu iuj du subretoj en la listo superlapiĝas
  - 'VALID': Kontrolas ĉu ĉiuj subretoj estas validaj IPv4-subretoj

### Redonvaloro

Redonas BOOLEAN (1 aŭ 0) indikante ĉu la specifita rilato validas por la donitaj subretoj.

## Ekzemploj

1. Kontrolu ĉu subretoj estas apudaj kaj formas ĉenon:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Redonas 1 (TRUE)
```

2. Kontrolu ĉu subretoj povas esti perfekte agregitaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Redonas 1 (TRUE) ĉar ili povas esti agregitaj al 192.168.0.0/23
```

3. Kontrolu ĉu subretoj estas ĉiuj ene de enhava subreto:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Redonas 1 (TRUE) ĉar ambaŭ /24 subretoj estas ene de la /22 subreto
```

4. Kontrolu ĉu iuj subretoj superlapiĝas:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Redonas 1 (TRUE) ĉar 192.168.1.0/24 superlapiĝas kun 192.168.1.128/25
```

5. Kontrolu ĉu ĉiuj subretoj estas validaj:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Redonas 1 (TRUE) ĉar ĉiuj subretoj estas validaj
```

## Notoj

- La funkcio supozas ke la subretaj specifoj estas en la ĝusta formato.
- Por 'ADJACENT_CHAIN', la subretoj devus esti provizitaj laŭorde.
- La 'AGGREGABLE' kontrolo funkcias plej bone kiam ĉiuj subretoj havas la saman CIDR-prefikslongon.
- Kiam oni uzas 'ALL_INSIDE', la enhavanta subreto devus esti la lasta en la listo.
