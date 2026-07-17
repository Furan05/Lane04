//
// config.mjs — configuration du relais par variables d'environnement.
// Aucun secret dans le dépôt : GARMIN_CLIENT_ID / GARMIN_CLIENT_SECRET
// viennent de l'environnement (voir ../.env.example).
//

const env = process.env

function required(name) {
  const value = env[name]
  if (!value) throw new Error(`Variable d'environnement manquante : ${name}`)
  return value
}

const port = Number(env.PORT ?? 8080)

export const config = {
  port,
  // URL publique du relais telle que Garmin la voit (base du redirect_uri).
  // En production : impérativement https, déclarée dans le portail Garmin.
  publicBaseURL: (env.PUBLIC_BASE_URL ?? `http://127.0.0.1:${port}`).replace(/\/+$/, ''),
  dataDir: env.DATA_DIR ?? new URL('../data', import.meta.url).pathname,
  // Où renvoyer l'athlète une fois le compte lié : le scheme custom de l'app.
  appCallbackURL: env.APP_CALLBACK_URL ?? 'lane04://garmin/oauth/callback',
  garmin: {
    clientId: required('GARMIN_CLIENT_ID'),
    clientSecret: required('GARMIN_CLIENT_SECRET'),
    // ⚠️ Défauts issus du Garmin Connect Developer Program (OAuth2 + PKCE).
    // À confronter à la spec du portail développeur une fois l'accès Training
    // API approuvé — tout est surchargeable sans toucher au code.
    authorizeURL: env.GARMIN_AUTHORIZE_URL ?? 'https://connect.garmin.com/oauth2Confirm',
    tokenURL: env.GARMIN_TOKEN_URL ?? 'https://diauth.garmin.com/di-oauth2-service/oauth/token',
    apiBase: (env.GARMIN_API_BASE ?? 'https://apis.garmin.com').replace(/\/+$/, ''),
    workoutPath: env.GARMIN_WORKOUT_PATH ?? '/training-api/workout',
    schedulePath: env.GARMIN_SCHEDULE_PATH ?? '/training-api/schedule',
    userIdPath: env.GARMIN_USER_ID_PATH ?? '/wellness-api/rest/user/id',
    deregistrationPath: env.GARMIN_DEREGISTRATION_PATH ?? '/wellness-api/rest/user/registration'
  }
}
