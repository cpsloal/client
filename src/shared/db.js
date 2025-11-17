
import crypto from "crypto";
import { Buffer } from 'buffer';
import Database from 'better-sqlite3'
import _ from "lodash";
import * as uuid from "uuid";
import hlc from "@tpp/hybrid-logical-clock";
import Debug from "debug";
const debug = Debug('cards');

const db = new Database('data/data.sqlite');
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');
db.pragma('synchronous = NORMAL');

db.exec('CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, salt TEXT, password TEXT, createdAt INTEGER, confirmedAt INTEGER, paymentStatus TEXT, language TEXT)');
db.exec('CREATE TABLE IF NOT EXISTS trees (id TEXT PRIMARY KEY, name TEXT, location TEXT, owner TEXT, collaborators TEXT, inviteUrl TEXT, createdAt INTEGER, updatedAt INTEGER, deletedAt INTEGER, migratedTo TEXT, publicUrl TEXT)');
db.exec('CREATE TABLE IF NOT EXISTS cards (id TEXT PRIMARY KEY, treeId TEXT, content TEXT, parentId TEXT, position FLOAT, updatedAt TEXT, deleted BOOLEAN)');
db.exec('CREATE INDEX IF NOT EXISTS cards_treeId ON cards (treeId)');

const userByEmail = db.prepare('SELECT * FROM users WHERE id = ?');
const userByRowId = db.prepare('SELECT * FROM users WHERE rowid = ?');
const userSignup = db.prepare('INSERT INTO users (id, salt, password, createdAt, confirmedAt, paymentStatus, language) VALUES (?, ?, ?, ?, ?, ?, ?)');
const treesByOwner = db.prepare('SELECT * FROM trees WHERE owner = ?');
const treeById = db.prepare('SELECT * FROM trees WHERE id = ?');
const treeUpsert = db.prepare(`
INSERT INTO trees(id, name, location, owner, inviteUrl, publicUrl, createdAt, updatedAt, deletedAt)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  location = excluded.location,
  owner = excluded.owner,
  inviteUrl = excluded.inviteUrl,
  publicUrl = excluded.publicUrl,
  updatedAt = excluded.updatedAt,
  deletedAt = excluded.deletedAt;
`);
const cardsAllUndeleted = db.prepare('SELECT * FROM cards WHERE treeId = ? AND deleted = FALSE ORDER BY updatedAt ASC');
const cardById = db.prepare('SELECT * FROM cards WHERE id = ?');
const cardInsert = db.prepare('INSERT OR REPLACE INTO cards (updatedAt, id, treeId, content, parentId, position, deleted) VALUES (?, ?, ?, ?, ?, ?, ?)');
const cardUpdate = db.prepare('UPDATE cards SET updatedAt = ?, content = ? WHERE id = ?');
const cardMove = db.prepare('UPDATE cards SET updatedAt = ?, parentId = ?, position = ? WHERE id = ?');
const cardDelete = db.prepare('UPDATE cards SET updatedAt = ?, deleted = TRUE WHERE id = ?');
const cardUndelete = db.prepare('UPDATE cards SET deleted = FALSE WHERE id = ?');


const iterations = 10;
const keylen = 20;
const encoding = 'hex';
const digest = 'SHA1';

function signup(email, password) {
  const timestamp = Date.now();
  const confirmTime = timestamp;

  const salt = crypto.randomBytes(16).toString('hex');
  let hash = crypto.pbkdf2Sync(password, salt, iterations, keylen, digest).toString(encoding);
  try {
    let userInsertInfo = userSignup.run(email, salt, hash, timestamp, confirmTime, "active", "en");
    const user = userByRowId.get(userInsertInfo.lastInsertRowid);
    return user;
  } catch (e) {
    if (e.code && e.code === "SQLITE_CONSTRAINT_PRIMARYKEY") {
      console.error(e);
      return null;
    } else {
      console.error(e);
      return null;
    }
  }
}

function login(email, password) {
  let user = userByEmail.get(email);

  if (user !== undefined) {
    let hash = crypto.pbkdf2Sync(password, user.salt, iterations, keylen, digest).toString(encoding)
    if (hash === user.password) {
      return user;
    } else {
      return null;
    }
  } else {
    return null;
  }
}

function toHex(str) {
  return Buffer.from(str).toString('hex');
}

export {
  db,
  login,
  signup,
  userByEmail,
  treesByOwner,
  treeById,
  cardsAllUndeleted,
  cardById,
  cardInsert,
  cardUpdate,
  cardMove,
  cardDelete,
  cardUndelete,
  treeUpsert,
}
