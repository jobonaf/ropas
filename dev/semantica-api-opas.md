# Note sulla semantica delle API OPAS

> Documento tecnico di lavoro.  
> Raccoglie informazioni ricavate dalla specifica OpenAPI, da prove effettuate sugli endpoint reali, da chiarimenti richiesti agli sviluppatori OPAS e da decisioni implementative adottate in `ropas`.

## Scopo del documento

Questo documento serve a rendere esplicite le assunzioni usate nello sviluppo di `ropas` e, più in generale, a facilitare lo sviluppo di altri client o pipeline basati sulle API OPAS.

In particolare distingue tra:

- quanto dichiarato nella specifica OpenAPI;
- quanto osservato interrogando gli endpoint reali;
- quanto confermato dagli sviluppatori OPAS;
- le decisioni implementative adottate nel client R `ropas`.

Il documento non sostituisce la documentazione ufficiale delle API, ma raccoglie note operative utili per interpretare correttamente campi, codici, identificativi, timestamp e fattori di conversione.

## Fonti delle informazioni

Le informazioni riportate possono provenire da fonti diverse. Quando possibile, ogni nota dovrebbe indicare una o più delle seguenti origini:

- **OpenAPI**: informazione ricavata da `openapi.yaml`.
- **Osservato**: comportamento verificato interrogando gli endpoint reali.
- **Chiarimento sviluppatori**: informazione ricevuta dagli sviluppatori o gestori OPAS.
- **Decisione `ropas`**: scelta implementativa adottata nel client R.

Esempio di annotazione:

```text
Fonte: Osservato
Fonte: OpenAPI + Osservato
Fonte: Chiarimento sviluppatori, email del YYYY-MM-DD
Fonte: Decisione ropas
```

## Inventario sintetico degli endpoint coperti

| Endpoint | Funzione `ropas` | Stato | Note |
|---|---|---|---|
| `/login` | `opas_auth()`, `opas_login()` | implementato | Autenticazione. |
| `/refresh-token` | `opas_refresh()` | implementato | Uso interno per refresh token. |
| `/logout` | `opas_logout()` | implementato | Best effort; pulizia stato locale sempre effettuata. |
| `/stations` | `opas_stations()` | implementato | Catalogo stazioni. |
| `/stations/{region}` | `opas_stations(region = ...)` | implementato | `region` normalizzato a due cifre. |
| `/stations/{station_id}` | `opas_station()` | implementato | Dettaglio stazione + parametri. |
| `/stations-parameters/{station_id}/{parameter_id}` | `opas_station_parameters()` | implementato | Dettaglio stazione filtrato per parametro. |
| `/sites` | `opas_sites()` | implementato | Siti fisici; `network_names` come list-column. |
| `/campaigns/{station_id}` | `opas_campaigns()` | implementato | Può restituire `allocations = null`. |
| `/campaigns/{station_id}/{date_time}` | `opas_campaigns(at = ...)` | implementato | `date_time` in formato ISO 8601. |
| `/series/{region}` | `opas_series(region = ...)` | implementato | Catalogo serie per regione. |
| `/series/{station_id}` | `opas_series(station = ...)` | implementato | Catalogo serie per stazione. |
| `/series-data/...` | `opas_get_data()` | implementato | Dati raw orari. |
| `/series-data-dd/...` | `opas_get_data(daily = TRUE)` / `last_days` | implementato | Aggregati giornalieri. |
| `/series-data-synchro/...` | `opas_sync_series()` | implementato | Sincronizzazione incrementale singola serie. |
| `/series-data-synchro-all/{station_id}/...` | `opas_sync_station()` | implementato | Sincronizzazione incrementale per stazione. |
| `/series-data-synchro-all/{region}/...` | `opas_sync_region()` | implementato | Sincronizzazione incrementale per regione. |
| `/statistics-station-data/Y/...` | `opas_get_station_stats()` | implementato | Statistiche annuali per stazione. |
| `/statistics-series-data/Y/...` | `opas_get_series_stats()` | implementato | Statistiche annuali per serie. |
| `/limits` | `opas_limits()` | implementato | Tabella limiti normativi. |
| `/statistics` | `opas_statistics()` | implementato | Tipi statistici. |
| `/statistics-limits` | `opas_statistics_limits()` | implementato | Relazioni statistica-inquinante-limite. |
| `/stations-log/{station_id}/{start}/{end}` | `opas_station_log()` | implementato | Verificato con timestamp ISO 8601 nel path. |

## Identificativi delle serie

### Comportamento osservato

Negli endpoint `/series/{region}` e `/series/{station_id}` viene restituito un campo `series_id`, usato correttamente per interrogare endpoint come:

```text
/series-data/{series_id}/...
```

Tuttavia, nelle risposte di `/series-data`, il campo `series_id` può assumere un valore diverso da quello usato nella chiamata.

Esempio osservato:

- `/series/{region}` restituisce una serie O3 con `series_id = 12375` per la stazione `1165`.
- La chiamata `/series-data/12375/...` restituisce dati corretti per quella stazione e quel parametro.
- Nella risposta dati, però, il campo `series_id` vale `7`.

### Chiarimento sviluppatori

Fonte: Chiarimento sviluppatori.

Gli sviluppatori OPAS hanno confermato che, nello stato attuale, l’identificativo restituito da `/series/{region}` è quello da usare per interrogare endpoint come `/series-data/{id}/...`.

È stato inoltre chiarito che il `series_id` presente nella risposta dati può attualmente riferirsi a un identificativo interno collegato alla tabella delle misure. Il campo `measure_id` è presente nella tabella dei dati e può coincidere con tale identificativo interno.

Gli sviluppatori hanno indicato che sarebbe preferibile che `series_id` nella risposta dati puntasse allo stesso identificativo restituito da `/series/{region}`. Questa discrepanza potrebbe quindi essere corretta lato API in futuro.

Esempio fornito dagli sviluppatori in una risposta dati:

```json
{
  "data": {
    "series_id": 18,
    "series_data": [
      {
        "measure_id": 18,
        "measure_value": 19.46
      }
    ]
  }
}
```

### Decisione `ropas`

Le funzioni low-level preservano il `series_id` restituito dall’API senza modificarlo.

Le funzioni high-level che iterano su serie del catalogo dovrebbero conservare anche l’identificativo usato per la chiamata, ad esempio in una colonna separata:

```text
catalogue_series_id
```

Questo evita join ambigui tra dati e catalogo serie, almeno finché la discrepanza non sarà eventualmente corretta lato API.

## Unità di misura e fattori di conversione

### Campi osservati

Nelle risposte degli endpoint `/series/{region}`, `/series/{station_id}` e `/parameters` sono presenti campi come:

```text
unit
conversion_factor_curr
conversion_unit
conversion_history
```

In `ropas` questi campi sono rinominati nei metadata come:

```text
parameter_unit
parameter_conv_curr
parameter_conv_unit
parameter_conv_history / conversion_history
```

### Chiarimento sviluppatori

Fonte: Chiarimento sviluppatori.

Gli sviluppatori OPAS hanno confermato questa interpretazione:

- `unit` = unità del valore restituito dagli endpoint dati;
- `conversion_factor_curr` = fattore attuale di conversione, cioè il fattore in uso al momento;
- `conversion_unit` = unità dopo conversione;
- valore convertito = `measure_value * conversion_factor_curr`.

Esempio osservato per O3:

```text
unit = "ppb"
conversion_factor_curr = 2
conversion_unit = "µg/m³"
```

### Comportamento degli endpoint dati

Gli endpoint dati come `/series-data` restituiscono `measure_value`, esposto in `ropas` come `value_raw`.

Osservazione importante:

- `/series-data` non restituisce direttamente `conversion_factor_curr` o `conversion_unit`.
- La conversione richiede quindi un join con il catalogo serie o parametri, oppure un fattore esplicito fornito dall’utente.

### Conversioni storiche

Fonte: Chiarimento sviluppatori.

`conversion_history` deve essere usata quando il periodo richiesto attraversa cambi di fattore di conversione.

Gli sviluppatori OPAS hanno confermato che:

- `date_from` e `date_to` sono estremi inclusivi;
- `-infinity` e `infinity` indicano intervalli aperti;
- `conversion_factor_curr` contiene il fattore attuale, cioè quello in uso al momento.

È stato inoltre citato uno specifico cambio dei fattori avvenuto il 1 aprile 2024 alle ore 00:00. Questo va interpretato come caso storico specifico, non come regola generale sulla periodicità o sulla data dei cambi di fattore.

I fattori storici devono quindi essere applicati usando esclusivamente gli intervalli indicati in `conversion_history`, senza assumere periodicità fisse o date convenzionali di cambio.

### Decisione `ropas`

Le funzioni low-level non applicano conversioni automatiche.

I dati restituiti da `opas_get_data()` contengono:

```text
value_raw
parameter_unit
```

La conversione sarà gestita da funzioni high-level, preservando il valore raw per tracciabilità.

Possibile output high-level:

```text
value_raw          # valore raw API
parameter_unit     # unità raw
parameter_conv_curr
parameter_conv_unit
value              # valore convertito
unit               # unità del valore convertito
```

## Codici di validità

### Campi osservati

Nei dati restituiti da `/series-data` sono presenti diversi campi di validità o controllo:

```text
post_validity_code
auto_validity_code
final_validity_code
measure_code
station_code
```

### Chiarimento sviluppatori

Fonte: Chiarimento sviluppatori.

Gli sviluppatori OPAS hanno chiarito che i principali campi di validità hanno questo significato operativo:

- `measure_code` = codici periferia;
- `auto_validity_code` = codici di autovalidazione;
- `post_validity_code` = codici di validazione utente;
- `final_validity_code` = codici finali.

È stato inoltre precisato che `final_validity_code` dipende da ogni agenzia e normalmente indica livelli di validazione giornaliera, mensile o annuale.

I codici di dettaglio sono consultabili sul portale OPAS, nella pagina di validazione o nella sezione analyser tramite icona informativa.

### Interpretazione operativa in `ropas`

Per filtri operativi generici, `ropas` usa `post_validity_code`, in quanto rappresenta la validazione utente.

Convenzione operativa adottata:

| `post_validity_code` | Interpretazione operativa |
|---:|---|
| `0` | dato valido |
| `1` | dato ricostruito |
| `< 0` | dato non valido / da scartare |

Filtro per dati utilizzabili:

```text
post_validity_code >= 0
```

Filtro per soli dati validi stretti:

```text
post_validity_code == 0
```

### Combinazioni osservate

In dati recenti O3 sono state osservate combinazioni come:

| `post_validity_code` | `auto_validity_code` | `final_validity_code` |
|---:|---:|---:|
| `0` | `0` | `1` |
| `0` | `0` | `0` |
| `-4` | `0` | `1` |
| `-4` | `0` | `0` |

Questo è coerente con il chiarimento ricevuto: `final_validity_code` non deve essere interpretato in modo uniforme come flag valido/non valido, perché la sua semantica può cambiare tra agenzie.

Non è stato identificato un campo unico e agenzia-indipendente che indichi in modo certo se un dato non ha ancora completato il processo di validazione finale.

## Timestamp e fusi orari

### Timestamp di misura

I timestamp di misura, ad esempio:

```text
measure_date_time
```

sono restituiti senza offset esplicito di fuso orario.

In `ropas` vengono interpretati come ora solare italiana, cioè UTC+1 fisso senza ora legale, usando:

```text
Etc/GMT-1
```

La colonna derivata in `ropas` si chiama:

```text
datetime
```

### Timestamp di inserimento e aggiornamento

Timestamp come:

```text
measure_insert_ts
measure_update_ts
log_insert_ts
log_update_ts
log_note_insert_ts
log_note_update_ts
```

sono trattati come timestamp di database e parsati in UTC quando presenti.

Quando possono contenere frazioni di secondo o offset espliciti, `ropas` tronca i primi 19 caratteri prima del parsing:

```text
YYYY-MM-DDTHH:MM:SS
```

### Decisione `ropas`

- timestamp di misura → `Etc/GMT-1`;
- timestamp di inserimento/aggiornamento DB → `UTC`;
- parsing sempre robusto: se una colonna opzionale manca, non viene generato errore.

## Note specifiche sugli endpoint

### `/series-data`

Osservazioni:

- restituisce valori raw in `measure_value`;
- in `ropas`, `measure_value` viene esposto come `value_raw`;
- non restituisce direttamente `conversion_factor_curr` o `conversion_unit`;
- il `series_id` nella risposta può essere diverso dall’identificativo usato nella chiamata.

Chiarimento sviluppatori:

- il comportamento è confermato nello stato attuale;
- sarebbe preferibile che `series_id` nella risposta dati coincidesse con l’identificativo usato nella chiamata;
- la discrepanza potrebbe essere corretta lato API in futuro.

### `/series-data-dd`

Osservazioni:

- endpoint per aggregati giornalieri;
- i record sono timestampati a mezzanotte del giorno di riferimento;
- stessa convenzione temporale dei dati orari: `Etc/GMT-1`.

### `/series-data-synchro`

Osservazioni:

- restituisce record inseriti o modificati dopo una certa data;
- include timestamp come `measure_insert_ts` e `measure_update_ts`;
- può includere `measure_update_obj` come oggetto/list-column;
- i metadati di conversione possono mancare;
- alcune risposte possono essere gzip-compressed senza header `Content-Encoding` utilizzabile.

Decisione `ropas`:

- fallback manuale per gzip non dichiarato;
- warning controllabile con `options(ropas.warn_unexpected_gzip = FALSE)`.

### `/campaigns/{station_id}`

Osservazioni:

- il campo top-level è `allocations`;
- se non ci sono allocazioni, l’API può restituire:

```text
allocations = null
```

invece di un array vuoto;

- in `ropas`, questo caso viene trattato come assenza di dati: warning + tibble vuoto.

È stata osservata almeno una stazione con risposta non vuota:

```text
station_id = 1135
```

Campi osservati nella risposta non vuota:

```text
station_id
station_name
station_override_id
station_external_id
site_id
site_name
network_names
site_locality
site_wgs84_lat
site_wgs84_lon
allocation_startup_date
allocation_dismiss_date
```

I campi `campaign_id` e `campaign_name`, pur presenti nello schema OpenAPI, possono essere assenti nelle risposte osservate.

### `/stations-log/{station_id}/{start}/{end}`

Osservazioni:

- usando timestamp Unix epoch nel path è stato ottenuto HTTP 404;
- usando timestamp ISO 8601 nel path l’endpoint funziona;
- il campo top-level restituito è `stations`.

Esempio di formato funzionante:

```text
/stations-log/1167/2026-01-01T00:00:00/2026-02-01T00:00:00
```

Campi osservati nella risposta:

```text
log_id
log_date
log_daily
station_id
station_name
lt_id
lt_name
log_creator_fullname
log_title
log_link
log_obj
log_note
log_note_creator_fullname
log_insert_ts
```

Altri campi temporali possono essere assenti, ad esempio:

```text
log_update_ts
log_note_insert_ts
log_note_update_ts
```

### `/sites`

Osservazioni:

- il campo top-level è `sites`;
- `id` e `name` sono rinominati in `ropas` come `site_id` e `site_name`;
- `network_names` è una list-column.

### `/stations-parameters/{station_id}/{parameter_id}`

Osservazioni:

- il campo top-level è `station`;
- la struttura è analoga a `/stations/{station_id}`;
- contiene un oggetto stazione e un array `parameters`;
- `parameters` può contenere più righe per la stessa combinazione osservata, che vengono preservate senza deduplicazione nel layer low-level.

## Decisioni implementative in `ropas`

### Layer low-level

Le funzioni low-level cercano di essere fedeli all’API:

- nessuna conversione automatica delle unità;
- nessun filtro automatico sui codici di validità;
- nessun join automatico con metadati esterni;
- parsing minimo ma robusto;
- oggetti annidati conservati come list-column.

### Naming in `ropas`

Alcuni campi API vengono rinominati per coerenza interna:

| Campo API | Nome in `ropas` | Note |
|---|---|---|
| `measure_value` | `value_raw` | valore raw, non convertito |
| `measure_date_time` | `datetime` | timestamp misura |
| `unit` | `parameter_unit` | unità raw |
| `conversion_factor_curr` | `parameter_conv_curr` | fattore attuale |
| `conversion_unit` | `parameter_conv_unit` | unità dopo conversione |
| `id` | prefisso semantico, es. `station_id`, `site_id`, `parameter_id` | dipende dall’endpoint |
| `name` | prefisso semantico, es. `station_name`, `site_name`, `parameter_name` | dipende dall’endpoint |

### Autenticazione

Sono supportati due workflow:

- workflow interattivo con stato interno (`opas_login()`);
- workflow esplicito con oggetto `auth` (`opas_auth()`), preferibile per processi paralleli o pipeline.

Le funzioni high-level non devono chiamare `opas_login()` internamente né modificare lo stato globale.

### High-level functions

Le funzioni high-level possono:

- eseguire join con cataloghi/metadati;
- aggiungere fattori di conversione;
- calcolare valori convertiti;
- applicare filtri di qualità opzionali;
- gestire errori parziali in loop su molte serie/stazioni.

Tuttavia devono preservare, dove possibile, i valori raw e gli identificativi originali restituiti dall’API.

In particolare, finché la discrepanza tra identificativo serie del catalogo e `series_id` restituito dai dati non sarà eventualmente corretta lato API, le funzioni high-level dovrebbero conservare esplicitamente anche l’identificativo usato nella chiamata, ad esempio come:

```text
catalogue_series_id
```

## Stato dei chiarimenti ricevuti

### Identificativi delle serie

Stato: risposta ricevuta.

Sintesi:

- l’identificativo restituito da `/series/{region}` è quello da usare per interrogare `/series-data/{id}/...`;
- `series_id` nella risposta dati può attualmente essere un identificativo interno diverso;
- sarebbe preferibile che i due identificativi coincidessero;
- la discrepanza potrebbe essere corretta lato API in futuro.

### Codici di validità

Stato: risposta ricevuta.

Sintesi:

- `measure_code` = codici periferia;
- `auto_validity_code` = codici di autovalidazione;
- `post_validity_code` = codici di validazione utente;
- `final_validity_code` = codici finali;
- `final_validity_code` dipende dall’agenzia e normalmente indica livelli di validazione giornaliera, mensile o annuale.

### Fattori di conversione

Stato: risposta ricevuta.

Sintesi:

- `unit` è l’unità del valore restituito dagli endpoint dati;
- `conversion_factor_curr` è il fattore attuale;
- `conversion_unit` è l’unità dopo conversione;
- valore convertito = `measure_value * conversion_factor_curr`;
- `conversion_history` va usata quando il periodo richiesto attraversa cambi di fattore;
- `date_from` e `date_to` sono inclusivi;
- `-infinity` e `infinity` indicano intervalli aperti.

## TODO

- Verificare la struttura reale di `conversion_history` per più parametri.
- Definire formalmente la semantica di `opas_convert()` e `opas_convert_historical()`.
- Decidere se `opas_get_year()` deve aggiungere sempre `catalogue_series_id`.
- Aggiornare README e documentazione utente quando saranno implementate le funzioni high-level.
- Valutare se aggiungere ulteriori contract test live per:
  - `opas_sync_station()`;
  - `opas_get_data()` con range custom orario;
  - `opas_get_data()` con range custom giornaliero;
  - `opas_campaigns()` con filtro `at`.
