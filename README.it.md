# Funzioni per la Gestione delle Subnet IP

Una collezione di funzioni SQL per gestire, analizzare e manipolare subnet IP nei database MySQL e Oracle.

## Storia del Progetto

Questo progetto è iniziato nel 2004 con lo sviluppo di `libmysqlcidr` e `liboraclecidr`, due moduli C rispettivamente per i database MySQL e Oracle. A quel tempo, nessuno dei due database offriva funzioni native per la manipolazione degli indirizzi IP:

- MySQL non disponeva delle funzioni `INET_ATON()`, `INET_NTOA()`, `INET6_ATON()` e `INET6_NTOA()`
- Oracle non aveva un equivalente del pacchetto `UTL_INADDR`

MySQL permetteva operazioni di shift dei bit che potevano essere utilizzate per i calcoli IP, ma Oracle mancava anche di queste capacità, rendendo particolarmente complessa la gestione delle subnet IP.

I moduli C originali fornivano strumenti efficienti per i calcoli e i confronti tra subnet, colmando una lacuna critica nella funzionalità dei database per le applicazioni di gestione delle reti.

Oggi, sia MySQL che Oracle includono funzioni native per la gestione degli indirizzi IP, rendendo i moduli C originali meno necessari. Tuttavia, le funzioni avanzate di analisi delle relazioni tra subnet rimangono preziose e sono state convertite da C a funzioni SQL native per una più facile integrazione e manutenzione.

## Finalità

Queste funzioni consentono agli amministratori di database e agli sviluppatori di eseguire operazioni avanzate sulle subnet direttamente all'interno del database, eliminando la necessità di elaborazioni esterne e semplificando le attività di gestione della rete.

Le capacità principali includono:

1. **Analisi delle Relazioni**: Verificare vari tipi di relazioni tra multiple subnet IP (adiacenza, contenimento, sovrapposizione)
2. **Aggregazione**: Trovare la subnet aggregata ottimale che comprenda multiple subnet
3. **Analisi dei Gap**: Identificare le subnet indesiderate che sarebbero incluse in un aggregato

Queste capacità supportano attività critiche di gestione delle reti come:
- IPAM (Gestione degli Indirizzi IP)
- Pianificazione e ottimizzazione della rete
- Analisi e consolidamento delle regole del firewall
- Ottimizzazione delle tabelle di routing
- Pianificazione della migrazione degli indirizzi IP

## Documentazione delle Funzioni

### Funzioni MySQL

- [CHECK_SUBNET_RELATIONSHIP (MySQL)](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [FIND_SUBNETS_AGGREGATE (MySQL)](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [LIST_UNWANTED_SUBNETS (MySQL)](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Funzioni di Supporto (MySQL)](./HELPER_FUNCTIONS_MySQL.it.md)

### Funzioni Oracle

- [CHECK_SUBNET_RELATIONSHIP (Oracle)](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [FIND_SUBNETS_AGGREGATE (Oracle)](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [LIST_UNWANTED_SUBNETS (Oracle)](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Funzioni di Supporto (Oracle)](./HELPER_FUNCTIONS_Oracle.it.md)

## Installazione

Consultare la documentazione di ciascuna funzione specifica per istruzioni dettagliate sull'installazione per la propria piattaforma di database.

## Licenza

Questo progetto è open source e disponibile sotto la Licenza MIT.
