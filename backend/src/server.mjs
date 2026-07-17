//
// server.mjs — le relais HTTP. Trois responsabilités, rien d'autre :
//   1. démarrer l'autorisation Garmin (GET /v1/garmin/oauth/start)
//   2. encaisser le retour OAuth et rendre un connection_token à l'app
//      (GET /v1/garmin/oauth/callback → 302 lane04://garmin/oauth/callback)
//   3. pousser un protocole validé vers la Training API
//      (POST /v1/garmin/workouts, Bearer connection_token)
// + DELETE /v1/garmin/connection (déliaison) et GET /healthz.
//
// Vérité de transmission (éthos LANE 04) : si le workout est créé chez Garmin
// mais que la planification échoue, on répond quand même 201 (scheduled:false)
// — une erreur pousserait le client à réinjecter et créerait un doublon.
//

import { createServer } from 'node:http'
import { config } from './config.mjs'
import { Store } from './store.mjs'
import {
  GarminAPIError,
  authorizationURL,
  exchangeCode,
  garminAPI,
  hashToken,
  newCodeVerifier,
  newConnectionToken,
  newState,
  redirectURI,
  refreshTokens
} from './garmin.mjs'
import { PayloadError, toGarminWorkout } from './mapper.mjs'

const MAX_BODY_BYTES = 64 * 1024
const store = new Store(config.dataDir)

function sendJSON(res, status, body) {
  const data = JSON.stringify(body)
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(data)
  })
  res.end(data)
}

function readJSON(req) {
  return new Promise((resolve, reject) => {
    let size = 0
    const chunks = []
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        reject(new PayloadError('corps de requête trop volumineux'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')))
      } catch {
        reject(new PayloadError('JSON invalide'))
      }
    })
    req.on('error', reject)
  })
}

function bearerToken(req) {
  const match = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')
  return match ? match[1].trim() : null
}

// Récupère la connexion du Bearer token, en rafraîchissant l'access token
// Garmin s'il expire dans moins d'une minute. Un refresh refusé par Garmin
// (400/401/403) signifie un lien mort : la connexion est purgée.
async function authedConnection(req) {
  const token = bearerToken(req)
  if (!token) return null
  const key = hashToken(token)
  const connection = store.getConnection(key)
  if (!connection) return null
  if (connection.accessExpiresAt - Date.now() > 60_000) return { key, connection }
  if (connection.refreshExpiresAt <= Date.now()) {
    store.deleteConnection(key)
    return null
  }
  try {
    const fresh = await refreshTokens(connection.refreshToken)
    const merged = { ...connection, ...fresh }
    store.putConnection(key, merged)
    return { key, connection: merged }
  } catch (error) {
    if (error instanceof GarminAPIError && [400, 401, 403].includes(error.status)) {
      store.deleteConnection(key)
      return null
    }
    throw error
  }
}

function oauthStart(res) {
  const state = newState()
  const verifier = newCodeVerifier()
  store.putState(state, { verifier })
  sendJSON(res, 200, { authorizationURL: authorizationURL(state, verifier) })
}

async function oauthCallback(url, res) {
  const state = url.searchParams.get('state')
  const code = url.searchParams.get('code')
  const record = state ? store.takeState(state) : null
  if (!record || !code) return sendJSON(res, 400, { error: 'OAUTH STATE INVALID' })

  const tokens = await exchangeCode(code, record.verifier)
  let garminUserId = null
  try {
    garminUserId = (await garminAPI.userId(tokens.accessToken))?.userId ?? null
  } catch {
    // Non bloquant : l'identifiant sert au diagnostic, pas à l'autorisation.
  }

  const token = newConnectionToken()
  store.putConnection(hashToken(token), { ...tokens, garminUserId, createdAt: Date.now() })

  const target = new URL(config.appCallbackURL)
  target.searchParams.set('connection_token', token)
  res.writeHead(302, { Location: target.toString() })
  res.end()
}

async function createWorkout(req, res) {
  const auth = await authedConnection(req)
  if (!auth) return sendJSON(res, 401, { error: 'NOT CONNECTED' })

  const payload = await readJSON(req)
  const workout = toGarminWorkout(payload) // PayloadError → 422 (catch global)

  const created = await garminAPI.createWorkout(auth.connection.accessToken, workout)
  const workoutId = created?.workoutId ?? created?.id ?? null

  let scheduled = false
  if (workoutId !== null) {
    try {
      await garminAPI.scheduleWorkout(auth.connection.accessToken, workoutId, payload.scheduledDate)
      scheduled = true
    } catch (error) {
      // Le workout existe déjà côté Garmin : ne surtout pas échouer ici,
      // sinon le client retenterait l'envoi complet (doublon garanti).
      console.error(`[garmin] schedule en faute, workout ${workoutId} créé sans date : ${error.message}`)
    }
  }

  sendJSON(res, 201, { workoutId, scheduled })
}

async function deleteConnection(req, res) {
  const token = bearerToken(req)
  if (!token) return sendJSON(res, 401, { error: 'NOT CONNECTED' })
  const key = hashToken(token)
  const connection = store.getConnection(key)
  if (connection) {
    try {
      await garminAPI.deleteRegistration(connection.accessToken)
    } catch {
      // Best effort : un compte déjà délié côté Garmin ne bloque pas l'oubli local.
    }
    store.deleteConnection(key)
  }
  res.writeHead(204)
  res.end()
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`)
  res.on('finish', () => {
    console.log(`${new Date().toISOString()} ${req.method} ${url.pathname} → ${res.statusCode}`)
  })

  try {
    if (req.method === 'GET' && url.pathname === '/healthz') return sendJSON(res, 200, { ok: true })
    if (req.method === 'GET' && url.pathname === '/v1/garmin/oauth/start') return oauthStart(res)
    if (req.method === 'GET' && url.pathname === '/v1/garmin/oauth/callback') return await oauthCallback(url, res)
    if (req.method === 'POST' && url.pathname === '/v1/garmin/workouts') return await createWorkout(req, res)
    if (req.method === 'DELETE' && url.pathname === '/v1/garmin/connection') return await deleteConnection(req, res)
    sendJSON(res, 404, { error: 'NOT FOUND' })
  } catch (error) {
    if (error instanceof PayloadError) return sendJSON(res, 422, { error: error.message })
    if (error instanceof GarminAPIError) {
      // Jamais le corps de la réponse Garmin dans les logs standards :
      // il peut contenir des détails de compte.
      console.error(`[garmin] ${error.message}`)
      return sendJSON(res, 502, { error: 'GARMIN UPSTREAM FAULT' })
    }
    console.error(error)
    sendJSON(res, 500, { error: 'INTERNAL FAULT' })
  }
})

server.listen(config.port, () => {
  console.log(`LANE 04 — relais Garmin sur le port ${config.port}`)
  console.log(`redirect_uri à déclarer chez Garmin : ${redirectURI()}`)
})
