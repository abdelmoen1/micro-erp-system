# MySQL for the Render private service (docs/deploy/mysql-migration.md).
# Pinned to the exact image that last wrote the production data on Railway (MySQL 9.7.2, built
# 2026-09-29), so the dump is restored into the same server version and checksums are comparable.
# Never replace the digest with a floating tag such as mysql:9.
FROM mysql@sha256:e2bde46db6563855d7177adb5f0b57b9dc663f5a20927a90f4259d3312068497

COPY hisbah.cnf /etc/mysql/conf.d/hisbah.cnf
