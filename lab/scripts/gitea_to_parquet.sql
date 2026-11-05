-- gitea_to_parquet.sql — flatten the fetched Gitea commit JSON into one parquet.
-- Run with:  bin/duckdb -no-agent -init scripts/gitea_to_parquet.sql -c "select 1"

COPY (
    SELECT
        regexp_extract(filename, 'commits__(.+)\.json$', 1)      AS repo,   -- larry__repo
        c.sha,
        c.commit.author.name                                      AS author_name,
        c.commit.author.email                                     AS author_email,
        CAST(c.commit.author.date AS TIMESTAMPTZ)                 AS authored_at_utc,
        CAST(c.commit.committer.date AS TIMESTAMPTZ)              AS committed_at_utc,
        c.commit.message                                          AS message,
        c.author.login                                            AS gitea_login,
        now()                                                     AS _snapshot_utc
    FROM read_json_auto('data/raw/gitea/commits__*.json', union_by_name = true,
                        filename = true) AS c
) TO 'data/raw/gitea_commits.parquet' (FORMAT parquet, COMPRESSION zstd);
