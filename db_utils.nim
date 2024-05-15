import db_connector/db_sqlite
import sugar

let db = open("updates.db", "", "", "")

when isMainModule:
    db.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS songUpdates (
                id INTEGER PRIMARY KEY ASC,
                songId TEXT NOT NULL,
                msg TEXT NOT NULL
            )
        """
    )
    db.close()
else:
    proc update*(songId: string, newUpdate: string) =
        db.exec(
            sql"""
                INSERT INTO songUpdates (songId, msg) VALUES (?, ?)
            """,
            songId,
            newUpdate,
        )

    proc resetUpdates*(songId: string) =
        db.exec(
            sql"""
                DELETE FROM songUpdates WHERE songId = ?
            """,
            songId,
        )

    proc getUpdates*(songId: string): seq[string] =
        let rows = db.getAllRows(
            sql"""
                SELECT msg FROM songUpdates WHERE songId=? ORDER BY id ASC
            """,
            songId,
        )

        result = collect(newSeq):
            for row in rows:
                row[0]
