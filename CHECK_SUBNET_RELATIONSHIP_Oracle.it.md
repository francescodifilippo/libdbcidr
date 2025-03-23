# Funzione CHECK_SUBNET_RELATIONSHIP (Oracle)

Questa funzione analizza le relazioni tra più subnet IP e determina se soddisfano criteri specifici.

## Lingue della Documentazione

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installazione

Per installare questa funzione nel tuo database Oracle, esegui i seguenti comandi SQL in ordine:

1. Prima, installa le funzioni di supporto se non l'hai già fatto:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE (richiesta per alcuni controlli di relazione):
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

3. Infine, installa la funzione CHECK_SUBNET_RELATIONSHIP:
[`CHECK_SUBNET_RELATIONSHIP_Oracle.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_Oracle.sql)

## Utilizzo

### Sintassi

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Il tipo di relazione da verificare. I valori validi sono:
  - 'ADJACENT_CHAIN': Verifica se tutte le subnet formano una catena continua
  - 'AGGREGABLE': Verifica se tutte le subnet possono essere perfettamente aggregate
  - 'ALL_DISJOINT': Verifica se tutte le subnet sono disgiunte (nessuna sovrapposizione)
  - 'ALL_INSIDE': Verifica se tutte le subnet sono contenute all'interno dell'ultima subnet nella lista
  - 'ALL_IDENTICAL': Verifica se tutte le subnet sono identiche
  - 'ANY_OVERLAPPING': Verifica se due subnet qualsiasi nella lista si sovrappongono
  - 'VALID': Verifica se tutte le subnet sono subnet IPv4 valide

### Valore di Ritorno

Restituisce un NUMBER (1 o 0) che indica se la relazione specificata vale per le subnet date.

## Esempi

1. Verifica se le subnet sono adiacenti e formano una catena:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') FROM DUAL;
-- Restituisce 1 (TRUE)
```

2. Verifica se le subnet possono essere perfettamente aggregate:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') FROM DUAL;
-- Restituisce 1 (TRUE) perché possono essere aggregate in 192.168.0.0/23
```

3. Verifica se le subnet sono tutte dentro una subnet contenitore:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') FROM DUAL;
-- Restituisce 1 (TRUE) perché entrambe le subnet /24 sono dentro la subnet /22
```

4. Verifica se ci sono subnet che si sovrappongono:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') FROM DUAL;
-- Restituisce 1 (TRUE) perché 192.168.1.0/24 si sovrappone con 192.168.1.128/25
```

5. Verifica se tutte le subnet sono valide:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') FROM DUAL;
-- Restituisce 1 (TRUE) perché tutte le subnet sono valide
```

## Note

- La funzione assume che le specifiche delle subnet siano nel formato corretto.
- Per 'ADJACENT_CHAIN', le subnet dovrebbero essere fornite in ordine.
- Il controllo 'AGGREGABLE' funziona meglio quando tutte le subnet hanno la stessa lunghezza di prefisso CIDR.
- Quando si usa 'ALL_INSIDE', la subnet contenitore dovrebbe essere l'ultima nella lista.
- In Oracle, la funzione restituisce 1 per TRUE e 0 per FALSE, a differenza di MySQL che restituisce valori boolean diretti.
