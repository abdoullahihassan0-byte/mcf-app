const axios = require('axios');

const BASE_URL = process.env.AIRTEL_ENV === 'production'
  ? process.env.AIRTEL_BASE_URL_PRODUCTION
  : process.env.AIRTEL_BASE_URL_STAGING;

let cachedToken = null;
let tokenExpiresAt = 0;

/**
 * Authentification OAuth2 Client Credentials.
 * Pattern vérifié (Airtel Africa developer portal), mais le chemin exact
 * de l'endpoint token doit être confirmé sur le portail développeur au
 * moment de l'implémentation réelle — je ne l'ai pas vérifié moi-même.
 */
async function getAccessToken() {
  if (cachedToken && Date.now() < tokenExpiresAt) {
    return cachedToken;
  }

  // TODO: confirmer le chemin exact, ex: `${BASE_URL}/auth/oauth2/token`
  const response = await axios.post(`${BASE_URL}/auth/oauth2/token`, {
    client_id: process.env.AIRTEL_CLIENT_ID,
    client_secret: process.env.AIRTEL_CLIENT_SECRET,
    grant_type: 'client_credentials',
  });

  cachedToken = response.data.access_token;
  // expires_in en secondes, on garde une marge de 60s
  tokenExpiresAt = Date.now() + (response.data.expires_in - 60) * 1000;

  return cachedToken;
}

/**
 * Décaissement vers le wallet Airtel Money d'un emprunteur.
 * SQUELETTE UNIQUEMENT — chemin d'endpoint, forme exacte du payload et
 * du header (ex: X-Country, X-Currency) à vérifier dans la documentation
 * officielle Airtel Africa avant utilisation. Ne pas déployer tel quel.
 */
async function disburse({ phoneNumber, amount, reference }) {
  const token = await getAccessToken();

  // TODO: confirmer le chemin exact (disbursement/payout) et les headers requis
  const response = await axios.post(
    `${BASE_URL}/standard/v1/disbursements/`, // placeholder à vérifier
    {
      payee: { msisdn: phoneNumber },
      reference,
      pin: undefined, // selon doc: peut nécessiter un PIN chiffré côté marchand
      transaction: {
        amount,
        id: reference,
      },
    },
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Country': process.env.AIRTEL_COUNTRY_CODE,
        'X-Currency': process.env.AIRTEL_CURRENCY,
      },
    }
  );

  return response.data;
}

/**
 * Demande de collecte (remboursement) via STK push / USSD.
 * SQUELETTE UNIQUEMENT — mêmes réserves que disburse().
 */
async function requestCollection({ phoneNumber, amount, reference }) {
  const token = await getAccessToken();

  // TODO: confirmer le chemin exact (collections)
  const response = await axios.post(
    `${BASE_URL}/merchant/v1/payments/`, // placeholder à vérifier
    {
      reference,
      subscriber: { msisdn: phoneNumber },
      transaction: {
        amount,
        id: reference,
      },
    },
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Country': process.env.AIRTEL_COUNTRY_CODE,
        'X-Currency': process.env.AIRTEL_CURRENCY,
      },
    }
  );

  return response.data;
}

module.exports = { getAccessToken, disburse, requestCollection };
