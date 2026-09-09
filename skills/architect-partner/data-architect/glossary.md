# Glossary — data architecture terminology

One line per term, plain words. Extend when real work surfaces a missing term.

## Database fundamentals (start here)

- **transaction** — a group of operations applied all-or-nothing.
- **ACID** — the four transaction guarantees: atomicity, consistency, isolation, durability.
- **isolation levels** — how much concurrent transactions see of each other (read committed → serializable).
- **MVCC** — multi-version concurrency control: readers see snapshots, writers don't block readers (PostgreSQL's way).
- **WAL (write-ahead log)** — the journal written before data pages; crash recovery and replication feed from it.
- **B-tree index** — the default ordered index; O(log n) lookups, great for point/range queries on a key.
- **GiST / GIN** — PostgreSQL's pluggable index families (geometry/arrays/full-text).
- **BRIN** — block-range index: tiny, works only when column order correlates with physical order.
- **query planner / optimizer** — the component choosing HOW to execute your SQL; bad plans = slow queries.
- **EXPLAIN** — the command showing the chosen plan; the first debugging tool.
- **join (nested loop / hash / merge)** — the three physical ways to combine tables.
- **normalization / denormalization** — splitting data to kill redundancy vs joining it back for read speed.
- **buffer pool / page cache** — RAM where hot data pages live; most "fast DB" is "data was in RAM".
- **vacuum / bloat** — PostgreSQL's garbage collection and the table inflation when it lags.
- **replication** — copying data to another server (sync = safe, async = fast).
- **sharding** — splitting one logical dataset across servers by a key; the last resort of scaling writes.

## Fundamentals

- **OLTP** — databases for operations: many small queries, each touches a few rows (PostgreSQL, MySQL).
- **OLAP** - databases for analysis: few queries, each reads millions of rows and aggregates (ClickHouse, Greenplum, Druid).
- **append-only** - data that is only added, never updated or deleted (telemetry, logs).
- **moving objects** - the research domain of time + space + moving entities (trajectories).
- **row store** - stores a whole row together; reading one column costs reading them all.
- **column store** - stores each column separately; a query reads only the columns it needs.
- **hot / warm / cold data** - fresh data on fast storage, older on slower/cheaper tiers.

## Storage (ClickHouse-flavoured, concepts transfer)

- **part** - a physical chunk of a table on disk; every insert creates one.
- **merge** - background gluing of small parts into bigger ones; too many parts = meltdown.
- **partition** - a logical slice of a table (usually by day/month); the only cheap delete unit.
- **granule / mark** - a row-block (~8K rows) and its offset entry; the sparse index ClickHouse actually reads by.
- **ORDER BY key** - the table's sort order; the only "index" a MergeTree table has.
- **pruning** - skipping parts/granules whose ranges don't match the query, without reading them.
- **codec** — per-column pre-compression transform before LZ4/ZSTD; pick by data type: **DoubleDelta** for monotonic ints/timestamps, **Gorilla** for floats, **T64** for small integer ranges.
- **quantization** - storing scaled integers instead of floats (degrees × 1e7 in UInt32).
- **materialized view (MV)** - a precomputed aggregate updated on every insert; pay on write, save on read.
- **projection** - an alternative physical sort order stored inside the same table.
- **rollup** - replacing old detailed rows with their aggregates (hourly sums instead of points).
- **TTL** - a rule "after X, do Y to the data": delete, roll up, or move to cheaper storage.
- **tiering** - layered storage: SSD for fresh, S3/object storage for old.
- **cardinality** - number of distinct values in a column; drives index and codec choices.

## File formats

- **Parquet** - columnar file format, the de-facto lake standard; row groups + per-column encodings.
- **ORC** - Hive-era columnar format; legacy alternative to Parquet.
- **row group** - a horizontal batch of rows inside Parquet; the unit of pruning and I/O.
- **predicate pushdown** - applying filters while reading the file, before materializing rows.
- **Lance** - newer columnar container built for random access without row groups (LanceDB).
- **Vortex** - newer format betting on compressed execution (SpiralDB -> Linux Foundation).
- **Nimble** - Meta's wide-table format, pre-1.0.
- **Arrow** - in-memory columnar layout for zero-copy exchange between engines; not a storage format.
- **Protobuf / Cap'n Proto** - binary transport encodings; transport, not analytics storage.
- **Iceberg** - table-metadata layer over object storage: schema, snapshots, atomic commits for files.

## Write path

- **staging** - a landing area where raw data waits before loading into the warehouse.
- **batch** - a large group of rows written at once; column stores demand batches, not rows.
- **freshness** - delay from event creation to visibility in queries.
- **at-least-once** - delivery guarantee: no loss, but duplicates possible.
- **exactly-once** - delivery guarantee: no loss, no duplicates; expensive.
- **deduplication (dedup)** - removing duplicate rows after at-least-once delivery.
- **idempotency** - repeating an operation gives the same result; the safe way to retry loads.
- **DLQ (dead letter queue)** - quarantine for broken messages, handled separately.
- **WAP (write-audit-publish)** - pattern: write -> audit quality -> publish to consumers.
- **backfill** - re-loading a historical period after a failure or logic change.
- **compaction** - merging many small files/parts into fewer big ones.
- **small files problem** - thousands of tiny files murder both object storage and readers.
- **watermark** - the "processed up to here" timestamp that drives incremental pipelines.

## Streaming

- **Kafka topic** - a named durable log of messages.
- **Kafka partition** - a shard of a topic; ordering and parallelism unit.
- **offset** - a message's position in a partition; committing it = "processed".
- **consumer group** - cooperating readers splitting partitions between them.
- **rebalancing** - re-assigning partitions when consumers join/leave; a classic duplicate source.
- **Connect sink** - a ready-made Kafka->destination connector (the ClickHouse one has optional exactly-once).
- **Kafka engine** - ClickHouse reading Kafka by itself via a table engine.

## Geo

- **H3** - Uber's hexagonal grid: every point gets an integer cell id.
- **resolution (r0-r15)** - cell size level; each step down ≈ 7× smaller cells.
- **parent / child cell** - the same location at a coarser/finer resolution (h3ToParent).
- **polygon cover** - the set of cells approximating a polygon.
- **overlap + refinement** - coarse cell filter, then exact point-in-polygon on boundary candidates.
- **point-in-polygon** - exact geometric inclusion test.
- **geohash / S2** - alternative grid systems (strings / spherical cells); H3's cousins.
- **stay point** - a place where a device lingered (typical thresholds: >=20 min, <=200 m).

## Analytics

- **uniqExact / HLL** - exact distinct count vs HyperLogLog approximate sketch (memory vs precision).
- **bitmap / RoaringBitmap** - compressed sets of ids; fast intersections (Uber's exact-count trick).
- **sketch** - a probabilistic summary trading exactness for size.
- **top-K** - "the K biggest" query; heavy when grouped over a full scan.
- **co-presence** - "devices seen in A then in B"; the heaviest mobility query class.
- **p50 / p95 / p99** - latency percentiles; medians lie, tails tell the truth.
- **throughput vs latency** - rows per second vs seconds per query; improving one often costs the other.

## Orchestration & DWH layers

- **ETL** - extract-transform-load: transform before the warehouse.
- **ELT** - extract-load-transform: load raw first, transform inside the warehouse.
- **ODS (operational data store)** - the raw mirror layer of source messages.
- **DDS / detail layer** - cleaned, typed, deduplicated detail data.
- **data mart (витрина)** - a purpose-built table for one consumer class (a map, a report).
- **Airflow DAG** - a scheduled graph of tasks; the classic batch orchestrator.
- **idempotent rerun** - re-running a task for the same period must not duplicate data.

## Benchmarks

- **BerlinMOD** - the standard moving-objects benchmark (range, time-slice, NN queries).
- **SpatialBench** - Apache Sedona's geospatial benchmark (joins, distance, point-in-polygon).
- **TSBS** - time-series read/write benchmark suite (Timescale).
- **ClickBench** - ClickHouse's own analytics benchmark (web-analytics data).
- **TPC-H / TPC-DS** - classic generic OLAP benchmarks; not geospatial.
