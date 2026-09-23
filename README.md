# Portfólio dbt — NYC Taxi Analytics

Pipeline de Analytics Engineering completo: dbt Core + Google BigQuery + orquestração via Apache Airflow (Astro CLI), construído sobre o dataset público de corridas de táxi de Nova York (2019).

Segundo projeto de portfólio na transição de carreira de Analista de Dados para Analytics Engineer — focado em fechar um gap específico: exposição a cloud data warehouse e orquestração, complementando um primeiro projeto (dbt + DuckDB + Olist) mais simples em infraestrutura.

## Contexto

Depois de quase 10 anos trabalhando com dados em ferramentas como Excel, VBA, Power BI e Salesforce, decidi migrar para Analytics Engineering — construindo prática real com o stack moderno de dados (dbt, cloud warehouse, orquestração). Este projeto documenta esse processo: decisões técnicas, investigações de qualidade de dado e os desafios reais encontrados no caminho.

## Dataset

`bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2019`, com join em `taxi_zone_geom` para nomes de zona/bairro. Total de **84.598.433 corridas** em 2019.

## Arquitetura

O projeto segue a estrutura de camadas padrão do dbt: **staging → intermediate → marts**, equivalente ao conceito de Bronze/Silver/Gold de arquiteturas de lakehouse.

![Gráfico de linhagem gerado pelo dbt docs](docs/lineage_graph.png)

O gráfico acima é gerado automaticamente por `dbt docs generate` e mostra as dependências de **compilação** entre models (via `ref()`/`source()`).

Um ponto que chama atenção: `dim_location` aparece como um ramo isolado, sem seta visível até `fct_trips`. Isso não é um erro — é reflexo de uma decisão de modelagem deliberada. Seguindo o padrão de star schema (Kimball), `fct_trips` armazena apenas as chaves estrangeiras (`pickup_location_id`, `dropoff_location_id`) como IDs simples, sem "achatar" atributos descritivos das dimensões (nome de zona, bairro, etc.) dentro da fato — o join acontece na ponta de consumo, quando necessário.

Como não há `JOIN` físico no SQL de `fct_trips` contra `dim_location`, o dbt não desenha essa dependência no gráfico de linhagem (que rastreia apenas relações de compilação). A integridade referencial entre as duas tabelas é garantida por um teste `relationships` dedicado (`models/marts/schema.yml`), não por uma dependência estrutural do model.

### Camadas

- **Staging** (`stg_taxi__trips`, `stg_taxi__zones`): espelho 1:1 da fonte, sem lógica de negócio, materializado como view.
- **Intermediate** (`int_taxi__trips`): primeiro modelo incremental do projeto, com estratégia `merge` e chave sintética composta (a fonte não possui ID de linha nativo).
- **Marts**: `dim_location`, `dim_vendor`, `dim_payment_type`, `dim_date` e `fct_trips`, seguindo star schema — a fato guarda métricas e FKs simples; quem consome decide os joins.

### Modelo dimensional (validado via checklist Kimball)

- **fct_trips**: grão = uma corrida de táxi, 84.598.433 linhas, 100% preservadas
- **dim_vendor**: fornecedor que operou a corrida
- **dim_payment_type**: forma de pagamento
- **dim_location**: zona de embarque/desembarque
- **dim_date**: calendário de 2019, 365 dias, sem lacunas

## Stack

`dbt Core 1.8.0` · `dbt-bigquery 1.8.0` · `Google BigQuery` · `Apache Airflow 3.x` (via `Astro CLI`) · `Docker` · `SQL` · `Git`

## Principais decisões técnicas e achados de qualidade de dado

Cada anomalia encontrada foi investigada até a causa raiz antes de qualquer decisão de tratamento. Os achados mais relevantes:

### Tarifas inválidas (`fare_amount`)

| Categoria | Corridas | % |
|---|---|---|
| Válido (> 0) | 84.393.312 | 99,76% |
| Zerado (= 0) | 35.066 | 0,04% |
| Negativo (< 0) | 170.055 | 0,20% |

**Decisão**: registros com fare inválido não são descartados — uma flag booleana (`is_valid_fare`) é criada já na staging, preservando o volume total para métricas de contagem e permitindo que análises financeiras filtrem quando necessário. Princípio aplicado ao projeto inteiro: dados brutos preservados até a camada de consumo, decisões de filtro tomadas com contexto, não impostas a priori.

### Zonas geograficamente fragmentadas

O teste `unique` em `zone_id` (fonte `taxi_zone_geom`) revelou duplicidade: a zona 103 (Governor's Island/Ellis Island/Liberty Island) aparece 3 vezes, a zona 56 (Corona) aparece 2 — cada linha representando um polígono geométrico distinto da mesma zona lógica (ilhas fisicamente separadas). `dim_location` resolve isso via `SELECT DISTINCT`, e o achado permanece documentado no teste (como aviso, não erro bloqueante).

### Zone_ids sem correspondência na fonte

5 `location_id` usados em corridas não têm match em `taxi_zone_geom`: 264 (787.156 corridas — código oficial "Unknown"), 265 (46.997 corridas — "Outside of NYC"), e 57/105/104 (412 corridas no total, baixo volume). Todos adicionados manualmente em `dim_location`, cada um com seu `zone_id` original preservado para rastreabilidade.

Essa correção foi identificada por testes `relationships` entre `fct_trips` e `dim_location`, que revelaram 412 (pickup) e 2.997 (dropoff) corridas órfãs — a decisão original de tratar 57/105/104 como "Unknown" tinha ficado documentada mas não implementada corretamente. O teste automatizado pegou a lacuna que uma checagem manual não pegou.

### Vendor_ids não documentados

`vendor_id` contém 4 valores: 1 e 2 são documentados oficialmente pelo TLC; 4 (267.080 corridas — volume não desprezível) e 5 (276 corridas) não constam em nenhuma versão da documentação pública consultada. Mapeados como "Unknown / Not documented" em `dim_vendor`, preservando o código original.

### Datas corrompidas (`pickup_datetime`)

Ao gerar `dim_date` com range dinâmico (MIN/MAX da fonte), o resultado inicial foi um intervalo de 2001 a 2090 — 1.442 corridas (0,0017% do total) com timestamp fora de 2019. Investigação espacial descartou a hipótese de origem concentrada (dado de teste): a distribuição segue o volume normal de corridas por zona, reforçando a hipótese de erro de relógio/GPS do equipamento de bordo, distribuído aleatoriamente entre veículos.

**Decisão**: `dim_date` restrita explicitamente a 2019 (dataset é histórico e fechado). Em `fct_trips`, essas 1.442 corridas são preservadas com uma flag `is_valid_date`, seguindo o mesmo padrão de `is_valid_fare`.

## Orquestração (Airflow)

A DAG `nyc_taxi_dbt_pipeline` dispara `dbt run` seguido de `dbt test` via `BashOperator`, rodando localmente através do Astro CLI (Docker). Como o dataset é histórico e fechado — sem chegada real de dado novo —, o schedule é `None`: a DAG existe pronta para operação automatizada, mas dispara apenas manualmente, refletindo a natureza real dos dados em vez de simular uma recorrência que não existe.

### Desafios técnicos resolvidos na configuração do ambiente

1. **Incompatibilidade de Python 3.14 com protobuf** — a imagem base do Astro Runtime trouxe Python 3.14 por padrão, incompatível com uma dependência interna do dbt (`TypeError: Metaclasses with custom tp_new are not supported`). Corrigido fixando a imagem em Python 3.12.
2. **Conflito de dependências dbt vs. Airflow** — instalar `dbt-core` no mesmo ambiente do Airflow gera conflito de versão (`importlib-metadata`). Resolvido instalando dbt em um `venv` isolado dentro do container, ativado explicitamente em cada `bash_command`.
3. **Erro de indentação em Python** — a DAG desapareceu silenciosamente da interface após um erro de indentação; o dag-processor não conseguia importar o módulo.
4. **Perfil dbt não encontrado** — o container não tinha acesso às credenciais do BigQuery; resolvido com um `profiles.yml` dedicado ao projeto (isolado dos outros perfis locais) e volumes Docker expondo a chave de service account.
5. **Cache de parsing incompatível entre sistemas** — a pasta `target/` gerada localmente no Windows, montada via volume, corrompia o parsing do dbt dentro do container Linux (`KeyError: 'dbt_bigquery://macros/adapters.sql'`). Resolvido removendo a pasta antes de execuções em ambiente novo.

Volumes Docker conectam o projeto dbt, a chave de service account (fora do controle de versão) e o profile dedicado ao container, sem misturar com outros projetos dbt locais.

## Testes de qualidade

12 testes automatizados (`not_null`, `unique`, `relationships`) cobrindo staging e marts. Dois deles rodam como `warn` intencional, não `error`: `date_day` (1.442 corridas com data inválida, já investigadas) e `zone_id` em staging (duplicidade geométrica conhecida, resolvida na camada de marts) — mantendo visibilidade do achado sem bloquear o pipeline por uma inconsistência já compreendida e documentada.

## Como rodar

```bash
# dbt
cd nyc_taxi_analytics
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt
dbt deps
dbt run
dbt test

# Airflow (requer Docker)
cd ../airflow
astro dev start
# Interface em http://localhost:8080
```

Requer uma chave de service account do GCP com permissões mínimas (BigQuery Data Editor + BigQuery Job User) e um `profiles.yml` configurado localmente — nenhuma credencial é versionada neste repositório.

## Próximos passos

- **Migração para `astronomer-cosmos`**: a orquestração atual usa `BashOperator`, disparando `dbt run` e `dbt test` como duas tarefas únicas. Uma evolução natural é adotar `cosmos`, que transforma cada model dbt em uma tarefa própria dentro do grafo do Airflow — permitindo, por exemplo, que a falha de um único model não interrompa a execução dos demais que não dependem dele, e dando visibilidade granular de qual model específico falhou.
- **Chave sintética mais robusta em `int_taxi__trips`**: a `unique_key` do modelo incremental combina 4 colunas (vendor, pickup/dropoff datetime e location) porque a fonte não fornece um identificador de linha nativo. Funcional, mas com risco residual de colisão em cenários extremos. `dbt_utils.generate_surrogate_key()`, que gera um hash a partir das mesmas colunas, seria uma evolução mais robusta.
- **Testes singulares**: além dos testes genéricos já implementados (`not_null`, `unique`, `relationships`), testes customizados — por exemplo, validar que `total_amount` bate com a soma de suas parcelas (`fare_amount + tip_amount + tolls_amount + ...`) — fechariam casos de qualidade de dado mais específicos do domínio de negócio.

## Autor

Wellington Rodrigues — [LinkedIn](https://www.linkedin.com/in/wellington-rodrigues-4984b353)