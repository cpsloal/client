CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, salt TEXT, password TEXT, createdAt INTEGER, confirmedAt INTEGER, paymentStatus TEXT, language TEXT);
CREATE TABLE IF NOT EXISTS trees (id TEXT PRIMARY KEY, name TEXT, location TEXT, owner TEXT, collaborators TEXT, inviteUrl TEXT, createdAt INTEGER, updatedAt INTEGER, deletedAt INTEGER, migratedTo TEXT, publicUrl TEXT);
CREATE TABLE IF NOT EXISTS cards (id TEXT PRIMARY KEY, treeId TEXT, content TEXT, parentId TEXT, position FLOAT, updatedAt TEXT, deleted BOOLEAN);
CREATE INDEX IF NOT EXISTS cards_treeId ON cards (treeId);
