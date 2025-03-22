# Funkcioj por Administrado de IP-Subretoj

Kolekto de SQL-funkcioj por administri, analizi kaj manipuli IP-subretojn en MySQL kaj Oracle datumbazoj.

## Projekta Historio

Ĉi tiu projekto komenciĝis en 2004 kun la disvolviĝo de `libmysqlcidr` kaj `liboraclecidr`, du C-moduloj por MySQL kaj Oracle datumbazoj respektive. Tiutempe, neniu el la du datumbazoj proponis naturajn funkciojn por manipulado de IP-adresoj:

- MySQL mankis la funkciojn `INET_ATON()`, `INET_NTOA()`, `INET6_ATON()`, kaj `INET6_NTOA()`
- Oracle ne havis ekvivalenton al la paketo `UTL_INADDR`

MySQL permesis bitŝovajn operaciojn kiuj povis esti uzataj por IP-kalkuloj, sed Oracle mankis eĉ tiujn kapablojn, farante la administradon de IP-subretoj aparte malfacila.

La originalaj C-moduloj provizis efikajn ilojn por subreto-kalkuloj kaj komparoj, plenumante kritikan mankon en datumbaza funkcionaleco por retadministradaj aplikaĵoj.

Hodiaŭ, ambaŭ MySQL kaj Oracle inkluzivas naturajn funkciojn por traktado de IP-adresoj, farante la originalajn C-modulojn malpli necesaj. Tamen, la altnivelaj funkcioj por analizo de subretaj rilatoj restas valoraj kaj estis konvertitaj de C al naturaj SQL-funkcioj por pli facila integriĝo kaj prizorgado.

## Celo

Ĉi tiuj funkcioj permesas al datumbazaj administrantoj kaj programistoj plenumi altnivelojn subretajn operaciojn rekte ene de la datumbazo, forigante la bezonon por ekstera procezado kaj simpligante retadministrajn taskojn.

Ĉefaj kapabloj inkluzivas:

1. **Rilata Analizo**: Kontroli diversajn tipojn de rilatoj inter multoblaj IP-subretoj (apudeco, enhaveco, superpozicio)
2. **Agregado**: Trovi la optimuman agregitan subreton kiu ampleksas multoblajn subretojn
3. **Manka Analizo**: Identigi nedeziratajn subretojn kiuj estus inkluzivitaj en agregaĵo

Ĉi tiuj kapabloj subtenas kritikajn retadministrajn taskojn kiel:
- IPAM (IP-Adresa Administrado)
- Retplanado kaj optimumigo
- Fajroŝirmila regulo-analizo kaj konsolidado
- Rutotabela optimumigo
- IP-adresa migrada planado

## Funkcia Dokumentado

### MySQL Funkcioj

- [CHECK_SUBNET_RELATIONSHIP (MySQL)](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)
- [FIND_SUBNETS_AGGREGATE (MySQL)](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)
- [LIST_UNWANTED_SUBNETS (MySQL)](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)
- [Helpaj Funkcioj (MySQL)](./HELPER_FUNCTIONS_MySQL.eo.md)

### Oracle Funkcioj

- [CHECK_SUBNET_RELATIONSHIP (Oracle)](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)
- [FIND_SUBNETS_AGGREGATE (Oracle)](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)
- [LIST_UNWANTED_SUBNETS (Oracle)](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)
- [Helpaj Funkcioj (Oracle)](./HELPER_FUNCTIONS_Oracle.eo.md)

## Instalado

Vidu la dokumentadon por ĉiu specifa funkcio por detalaj instalinstrukcioj por via datumbaza platformo.

## Licenco

Ĉi tiu projekto estas malfermfonta kaj disponebla sub la MIT Licenco.
