//
// garmin.mjs — client Garmin : OAuth2 + PKCE (S256) et appels API signés.
// Le client secret ne quitte jamais ce processus ; l'app iOS ne voit que des
// connection_tokens opaques émis par le relais.
//

import { createHash, randomBytes } from 'node:crypto'
import { config } from './config.mjs'

const FETCH_TIMEOUT_MS = 15_000

function b64url(buffer) {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function newCodeVerifier() { return b64url(randomBytes(48)) } // 64 caractères ∈ [43;128]
export function codeChallenge(verifier) { return b64url(createHash('sha256').update(verifier).digest()) }
export function newState() { return randomBytes(24).toString('hex') }
export function newConnectionToken() { return randomBytes(32).toString('hex') }
export function hashToken(token) { return createHash('sha256').update(token).digest('hex') }

export function redirectURI() { return `${config.publicBaseURL}/v1/garmin/oauth/callback` }

export function authorizationURL(state, verifier) {
  const url = new URL(config.garmin.authorizeURL)
  url.searchParams.set('client_id', config.garmin.clientId)
  url.searchParams.set('response_type', 'code')
  url.searchParams.set('code_challenge', codeChallenge(verifier))
  url.searchParams.set('code_challenge_method', 'S256')
  url.searchParams.set('redirect_uri', redirectURI())
  url.searchParams.set('state', state)
  return url.toString()
}

export class GarminAPIError extends Error {
  constructor(endpoint, status, body) {
    super(`Garmin ${endpoint} → ${status}`)
    this.status = status
    this.body = body
  }
}

async function safeText(response) {
  try { return await response.text() } catch { return '' }
}

async function tokenRequest(params) {
  const body = new URLSearchParams({
    client_id: config.garmin.clientId,
    client_secret: config.garmin.clientSecret,
    ...params
  })
  const response = await fetch(config.garmin.tokenURL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS)
  })
  if (!response.ok) throw new GarminAPIError('token', response.status, await safeText(response))
  const json = await response.json()
  const now = Date.now()
  return {
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    accessExpiresAt: now + (json.expires_in ?? 0) * 1000,
    refreshExpiresAt: now + (json.refresh_token_expires_in ?? 0) * 1000
  }
}

export function exchangeCode(code, verifier) {
  return tokenRequest({
    grant_type: 'authorization_code',
    code,
    code_verifier: verifier,
    redirect_uri: redirectURI()
  })
}

export function refreshTokens(refreshToken) {
  return tokenRequest({ grant_type: 'refresh_token', refresh_token: refreshToken })
}

async function api(method, path, accessToken, payload) {
  const response = await fetch(config.garmin.apiBase + path, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(payload !== undefined && { 'Content-Type': 'application/json' })
    },
    body: payload !== undefined ? JSON.stringify(payload) : undefined,
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS)
  })
  if (!response.ok) throw new GarminAPIError(path, response.status, await safeText(response))
  const text = await response.text()
  if (!text) return null
  try { return JSON.parse(text) } catch { return text }
}

export const garminAPI = {
  userId: (token) => api('GET', config.garmin.userIdPath, token),
  createWorkout: (token, workout) => api('POST', config.garmin.workoutPath, token, workout),
  scheduleWorkout: (token, workoutId, date) => api('POST', config.garmin.schedulePath, token, { workoutId, date }),
  deleteRegistration: (token) => api('DELETE', config.garmin.deregistrationPath, token)
}
