# Procedura LIST_UNWANTED_SUBNETS (Oracle)

Questa procedura identifica le subnet che sarebbero incluse in un aggregato ma non fanno parte dell'elenco originale delle subnet. Aiuta gli amministratori di rete ad analizzare lo "spreco" quando si aggregano subnet non contigue.

## Lingue della Documentazione

- [English](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)

## Installazione

Per installare questa procedura nel tuo database Oracle, devi prima installare le funzioni di supporto se non le hai già. Quindi, puoi installare la procedura LIST_UNWANTED_SUBNETS.

Puoi trovare tutto il codice SQL necessario nel file [`LIST_UNWANTED_SUBNETS_Oracle.sql`](./sql/LIST_UNWANTED_SUBNETS_Oracle.sql).

## Utilizzo

### Sintassi

```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);
PRINT result_cursor;
```

### Parametri

- **subnet_list**: Un elenco di specifiche di subnet separate da virgola in notazione CIDR (es. '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: La specifica della subnet aggregata in notazione CIDR (es. '192.168.0.0/22')
- **result_cursor**: Un cursor di riferimento che viene restituito dalla procedura

### Valore di Ritorno

Restituisce un result set con una colonna denominata 'subnet' con ogni riga che rappresenta una subnet indesiderata (in notazione CIDR) inclusa nell'aggregato ma non parte delle subnet originali.

## Esempi

1. Trovare le subnet indesiderate quando si aggregano subnet /24 non adiacenti:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);
PRINT result_cursor;
```
Risultato:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Trovare le subnet indesiderate quando si aggregano subnet con diverse lunghezze di prefisso:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22', :result_cursor);
PRINT result_cursor;
```
Risultato:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verificare che non ci siano subnet indesiderate per subnet perfettamente aggregabili:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23', :result_cursor);
PRINT result_cursor;
```
Risultato: Set di risultati vuoto (nessuna subnet indesiderata)

4. Trovare le subnet indesiderate in un aggregato ampio:
```sql
VARIABLE result_cursor REFCURSOR;
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0', :result_cursor);
PRINT result_cursor;
```
Risultato: Set di risultati molto ampio contenente tutte le reti /24 nello spazio IPv4 eccetto le due specificate.

## Come Funziona

La procedura opera in diverse fasi:

1. **Analisi dell'Input**: 
   - Analizza l'elenco originale delle subnet e la subnet aggregata
   - Identifica la lunghezza minima del prefisso CIDR tra le subnet originali

2. **Creazione di Strutture Dati**:
   - Crea una collection per memorizzare gli indirizzi di rete e broadcast delle subnet originali
   - Crea una tabella temporanea per memorizzare i risultati

3. **Enumerazione delle Subnet**:
   - Itera attraverso tutte le possibili subnet delle stesse dimensioni della subnet originale più specifica che rientrano nell'aggregato
   - Per ogni possibile subnet, verifica se corrisponde a una delle subnet originali
   - In caso contrario, la aggiunge all'elenco delle subnet indesiderate

4. **Restituzione dei Risultati**:
   - Restituisce l'elenco delle subnet indesiderate in ordine

## Note

- La procedura identifica le subnet con la stessa lunghezza di prefisso della subnet più specifica nell'elenco originale
- Per aggregati ampi, il result set può essere molto grande
- La procedura è utile per:
  - Pianificare schemi di indirizzamento IP
  - Valutare l'efficienza dell'aggregazione dei percorsi
  - Identificare spazio IP libero all'interno di un aggregato
  - Valutare l'impatto della summarizzazione delle subnet sulle tabelle di routing
