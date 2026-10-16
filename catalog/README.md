# Public XTApp catalog

This directory is the public, sanitized catalog consumed by the Codex plugin. It must never be populated by copying private product state wholesale.

To refresh it, maintainers run the catalog exporter against a local source that is never committed here. Only explicitly approved public apps should be exported. User projects, editor internals, keys, and binary caches do not belong here.

The exported templates are the official store apps and are currently API 0.8 (each `index.json` item records its manifest `api`). They are reference only; new apps follow API 2.x. Exports contain text sources only (`lua`, `json`, `md`, `txt`, `tsv`): `assets/` and `raw/` directories and binary art are skipped, so assets must be imported in Studio after copying.
