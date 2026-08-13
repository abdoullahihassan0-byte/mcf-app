const crypto = require('crypto');
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const smsService = require('../services/smsService');

const router = express.Router();

const OTP_LENGTH = 6;
const OTP_TTL_MINUTES = 5;
const MAX_ATTEMPTS = 5;

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function generateCode() {
  // 6 chiffres, y compris les zéros en tête
  return crypto.randomInt(0, 10 ** OTP_LENGTH).toString().padStart(OTP_LENGTH, '0');
}

/**
 * POST /auth/otp/request
 * Génère un code, l'envoie par SMS, et indique si le numéro correspond
 * à un compte existant (pour que l'app sache si elle doit demander le
 * nom complet à l'étape suivante).
 */
router.post('/otp/request', async (req, res) => {
  const { phoneNumber } = req.body;

  if (!phoneNumber) {
    return res.status(400).json({ error: 'phoneNumber est requis' });
  }

  const code = generateCode();
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

  await pool.query(
    `INSERT INTO otp_codes (phone_number, code_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [phoneNumber, hashCode(code), expiresAt]
  );

  try {
    await smsService.sendOtpSms(phoneNumber, code);
  } catch (err) {
    return res.status(502).json({ error: 'Échec de l\'envoi du SMS', details: err.message });
  }

  const existing = await pool.query('SELECT id FROM users WHERE phone_number = $1', [phoneNumber]);

  res.json({
    message: 'Code envoyé',
    isNewUser: existing.rows.length === 0,
    expiresInMinutes: OTP_TTL_MINUTES,
  });
});

/**
 * POST /auth/otp/verify
 * Vérifie le code. Si le numéro n'a pas de compte, fullName est requis
 * pour créer le compte dans la foulée (inscription = première vérification).
 */
router.post('/otp/verify', async (req, res) => {
  const { phoneNumber, code, fullName } = req.body;

  if (!phoneNumber || !code) {
    return res.status(400).json({ error: 'phoneNumber et code sont requis' });
  }

  const otpResult = await pool.query(
    `SELECT * FROM otp_codes
     WHERE phone_number = $1 AND consumed_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC
     LIMIT 1`,
    [phoneNumber]
  );

  if (otpResult.rows.length === 0) {
    return res.status(400).json({ error: 'Aucun code valide — redemande un code' });
  }

  const otp = otpResult.rows[0];

  if (otp.attempts >= MAX_ATTEMPTS) {
    return res.status(429).json({ error: 'Trop de tentatives — redemande un code' });
  }

  if (otp.code_hash !== hashCode(code)) {
    await pool.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
    return res.status(400).json({ error: 'Code incorrect' });
  }

  await pool.query('UPDATE otp_codes SET consumed_at = now() WHERE id = $1', [otp.id]);

  let userResult = await pool.query(
    'SELECT id, phone_number, full_name, role, kyc_status FROM users WHERE phone_number = $1',
    [phoneNumber]
  );

  let user;
  if (userResult.rows.length === 0) {
    if (!fullName || !fullName.trim()) {
      return res.status(400).json({ error: 'fullName est requis pour créer un nouveau compte' });
    }
    const created = await pool.query(
      `INSERT INTO users (phone_number, full_name, role, kyc_status)
       VALUES ($1, $2, 'borrower', 'pending')
       RETURNING id, phone_number, full_name, role, kyc_status`,
      [phoneNumber, fullName.trim()]
    );
    user = created.rows[0];
  } else {
    user = userResult.rows[0];
  }

  const token = jwt.sign(
    { id: user.id, role: user.role, phone_number: user.phone_number },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );

  res.json({ user, token });
});

module.exports = router;
