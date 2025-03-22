# Procedura LIST_UNWANTED_SUBNETS (Oracle)

Haec procedura identificat subretes quae includerentur in aggregatione sed non sunt pars elenchi subretium originalis. Adiuvat administratores retis ad analysandum "prodigalitatem" quando aggregant subretes non contiguas.

## Linguae Documentationis

- [Anglica](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Italica](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)

## Installatio

Ad hanc proceduram in tua basi datorum Oracle installandam, primum functiones auxiliares installare debes si nondum eas habes. Deinde, proceduram LIST_UNWANTED_SUBNETS ipsam installare potes.

Omnem codicem SQL necessarium in file [`LIST_UNWANTED_SUBNETS_Oracle.sql`](./sql/LIST_UNWANTED_SUBNETS_Oracle.sql) invenies.

## Usus

### Syntaxis

```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);
PRINT result_cursor;
```

### Parametri

- **subnet_list**: Elenchus subretium separatarum commatis in notatione CIDR (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: Specificatio subretis aggregatae in notatione CIDR (e.g., '192.168.0.0/22')
- **result_cursor**: Cursor referentiae qui regressus est a procedura

### Valor Redditus

Reddit cursum resultantem cum columna una nominata 'subnet' cum unaquaque linea representante subretem indesideratam (in notatione CIDR) inclusam in aggregato sed non partem subretium originalium.

## Exempla

1. Invenire subretes indesideratas quando aggregamus subretes /24 non adiacentes:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);
PRINT result_cursor;
```
Resultatum:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Invenire subretes indesideratas quando aggregamus subretes cum diversis longitudinibus praefixorum:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22', :result_cursor);
PRINT result_cursor;
```
Resultatum:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verificare nullas subretes indesideratas pro subretibus perfecte aggregabilibus:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23', :result_cursor);
PRINT result_cursor;
```
Resultatum: Nulla (nullae subretes indesideratae)

4. Invenire subretes indesideratas in aggregato magno:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0', :result_cursor);
PRINT result_cursor;
```
Resultatum: Multae lineae continentes omnes retes /24 in spatio IPv4 exceptis duabus specificatis.

## Quomodo Operatur

Procedura operatur in pluribus gradibus:

1. **Analysare Input**: 
   - Analysat elenchum originalem subretium et subretem aggregatam
   - Identificat minimam longitudinem praefixae CIDR inter subretes originales

2. **Creare Structuras Datorum**:
   - Creat catalogum temporarium ad conservandas addressas retis et emissionis subretium originalium
   - Creat tabulam temporariam ad conservanda resultata

3. **Enumerare Subretes**:
   - Iterat per omnes subretes possibiles eiusdem magnitudinis ac minima subretis originalis quae in aggregatam conveniunt
   - Pro unaquaque subrete possibili, verificat si congruit cum aliqua subretium originalium
   - Si non, addit ad elenchum subretium indesideratarum

4. **Reddere Resultata**:
   - Reddit elenchum subretium indesideratarum in ordine disposito

## Notae

- Procedura identificat subretes cum eadem longitudine praefixae ac subretis maxime specificae in elencho originali
- Pro aggregatis magnis, cursus resultans potest esse valde magnus
- Procedura utilis est ad:
  - Planificandum schemas adressarum IP
  - Evaluandum efficientiam aggregationis rutarum
  - Identificandum spatium IP liberum intra aggregatum
  - Aestimandum impactum summarizationis subretis in tabulis rutarum
