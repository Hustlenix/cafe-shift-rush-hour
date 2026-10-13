CREATE TABLE rooms (
 id TEXT PRIMARY KEY,
 pos_hash TEXT NOT NULL,
 kitchen_hash TEXT NOT NULL,
 expires_at INTEGER NOT NULL
);
--> statement-breakpoint
CREATE TABLE orders (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
 nonce TEXT NOT NULL,
 customer TEXT NOT NULL,
 table_name TEXT NOT NULL,
 items TEXT NOT NULL,
 total INTEGER NOT NULL,
 status TEXT NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW','PREPARING','DONE')),
 created_at TEXT NOT NULL,
 UNIQUE(room_id, nonce)
);
--> statement-breakpoint
CREATE INDEX orders_room ON orders(room_id, id);
