# Funzioni di Supporto (Oracle)

Queste funzioni di supporto forniscono le operazioni fondamentali per la manipolazione degli indirizzi IP all'interno di Oracle Database, consentendo alle funzioni principali di eseguire calcoli e analisi sulle subnet IP.

## Lingue della Documentazione

- [English](./HELPER_FUNCTIONS_Oracle.en.md)
- [Italiano](./HELPER_FUNCTIONS_Oracle.it.md)
- [Latina](./HELPER_FUNCTIONS_Oracle.la.md)
- [Esperanto](./HELPER_FUNCTIONS_Oracle.eo.md)

## Installazione

Per installare queste funzioni di supporto nel tuo database Oracle, esegui i comandi SQL contenuti nel file [`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql).

## Funzioni Incluse

### IP_TO_NUM

Converte un indirizzo IP in formato stringa in un valore numerico.

#### Sintassi

```sql
IP_TO_NUM(ip_address IN VARCHAR2) RETURN NUMBER
```

#### Parametri

- **ip_address**: Un indirizzo IPv4 in formato stringa (es. '192.168.1.1')

#### Valore di Ritorno

Restituisce una rappresentazione numerica dell'indirizzo IP.

#### Esempi

```sql
SELECT IP_TO_NUM('192.168.1.1') FROM DUAL;
-- Restituisce 3232235777
```

### NUM_TO_IP

Converte un valore numerico in un indirizzo IP in formato stringa.

#### Sintassi

```sql
NUM_TO_IP(ip_num IN NUMBER) RETURN VARCHAR2
```

#### Parametri

- **ip_num**: Un valore numerico che rappresenta un indirizzo IPv4

#### Valore di Ritorno

Restituisce l'indirizzo IP in formato stringa (es. '192.168.1.1').

#### Esempi

```sql
SELECT NUM_TO_IP(3232235777) FROM DUAL;
-- Restituisce '192.168.1.1'
```

### GET_NETWORK_ADDRESS

Calcola l'indirizzo di rete da un indirizzo IP e un prefisso CIDR.

#### Sintassi

```sql
GET_NETWORK_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER) RETURN VARCHAR2
```

#### Parametri

- **ip**: Un indirizzo IPv4 in formato stringa
- **cidr**: La lunghezza del prefisso di rete CIDR (0-32)

#### Valore di Ritorno

Restituisce l'indirizzo di rete in formato stringa.

#### Esempi

```sql
SELECT GET_NETWORK_ADDRESS('192.168.1.100', 24) FROM DUAL;
-- Restituisce '192.168.1.0'
```

### GET_BROADCAST_ADDRESS

Calcola l'indirizzo di broadcast da un indirizzo IP e un prefisso CIDR.

#### Sintassi

```sql
GET_BROADCAST_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER) RETURN VARCHAR2
```

#### Parametri

- **ip**: Un indirizzo IPv4 in formato stringa
- **cidr**: La lunghezza del prefisso di rete CIDR (0-32)

#### Valore di Ritorno

Restituisce l'indirizzo di broadcast in formato stringa.

#### Esempi

```sql
SELECT GET_BROADCAST_ADDRESS('192.168.1.100', 24) FROM DUAL;
-- Restituisce '192.168.1.255'
```

## Come Funzionano

### IP_TO_NUM

Questa funzione scompone un indirizzo IP nei suoi 4 ottetti utilizzando le espressioni regolari, quindi calcola un valore numerico a 32 bit utilizzando la formula:

```
(ottetto1 * 256³) + (ottetto2 * 256²) + (ottetto3 * 256¹) + (ottetto4 * 256⁰)
```

### NUM_TO_IP

Questa funzione esegue l'operazione inversa di IP_TO_NUM, estraendo i 4 ottetti da un valore numerico a 32 bit utilizzando divisioni e moduli successivi, quindi li unisce nel formato standard per gli indirizzi IP.

### GET_NETWORK_ADDRESS

Questa funzione:
1. Converte l'indirizzo IP in un numero utilizzando IP_TO_NUM
2. Crea una maschera di rete basata sul valore CIDR dato
3. Applica l'operazione di bit AND tra il numero IP e la maschera
4. Converte il risultato in un indirizzo IP in formato stringa

### GET_BROADCAST_ADDRESS

Questa funzione:
1. Converte l'indirizzo IP in un numero utilizzando IP_TO_NUM
2. Calcola l'indirizzo di broadcast aggiungendo il numero totale di indirizzi IP nella subnet (2^(32-cidr) - 1) all'indirizzo di rete
3. Converte il risultato in un indirizzo IP in formato stringa

## Note

- Queste funzioni di supporto sono progettate per IPv4 e non funzionano con indirizzi IPv6.
- Nelle versioni più recenti di Oracle, potresti considerare l'uso del pacchetto UTL_INADDR per alcune operazioni sugli indirizzi IP, sebbene le funzioni personalizzate qui fornite offrano maggiore flessibilità per i calcoli delle subnet.
- Sono funzioni deterministische, il che significa che restituiranno sempre lo stesso output per lo stesso input, consentendo potenzialmente a Oracle di memorizzare nella cache i risultati per prestazioni migliori.
