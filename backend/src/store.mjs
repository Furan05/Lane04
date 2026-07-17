//
// store.mjs — persistance fichier JSON, écriture atomique (tmp + rename).
// Zéro dépendance : suffisant pour un relais personnel auto-hébergé.
// Si le relais devait servir plusieurs athlètes, migrer vers SQLite/Postgres.
//
// Contenu : `connections` (hash SHA-256 du connection_token → jetons Garmin)
// et `states` (state OAuth → code_verifier PKCE, usage unique, TTL 10 min).
// Les connection_tokens ne sont jamais stockés en clair.
//

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const STATE_TTL_MS = 10 * 60 * 1000

export class Store {
  constructor(dataDir) {
    mkdirSync(dataDir, { recursive: true, mode: 0o700 })
    this.file = join(dataDir, 'store.json')
    this.data = existsSync(this.file)
      ? JSON.parse(readFileSync(this.file, 'utf8'))
      : { connections: {}, states: {} }
  }

  #flush() {
    const tmp = `${this.file}.tmp`
    writeFileSync(tmp, JSON.stringify(this.data, null, 2), { mode: 0o600 })
    renameSync(tmp, this.file)
  }

  #pruneStates() {
    const now = Date.now()
    for (const [state, record] of Object.entries(this.data.states)) {
      if (now - record.createdAt > STATE_TTL_MS) delete this.data.states[state]
    }
  }

  putState(state, record) {
    this.#pruneStates()
    this.data.states[state] = { ...record, createdAt: Date.now() }
    this.#flush()
  }

  /// Consomme le state : un code d'autorisation ne s'échange qu'une fois.
  takeState(state) {
    this.#pruneStates()
    const record = this.data.states[state] ?? null
    delete this.data.states[state]
    this.#flush()
    return record
  }

  putConnection(tokenHash, record) {
    this.data.connections[tokenHash] = record
    this.#flush()
  }

  getConnection(tokenHash) {
    return this.data.connections[tokenHash] ?? null
  }

  deleteConnection(tokenHash) {
    delete this.data.connections[tokenHash]
    this.#flush()
  }
}
