const express = require('express');
const pool = require('../config/db');
const airtelService = require('../services/airtelService');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// POST /repayments - l'emprunteur déclenche un remboursement (STK push Airtel)
router.post('/', requireAuth, async (req, res) => {
  const { loanId, amount } = req.body;

  if (!loanId || !amount) {
    return res.status(400).json({ error: 'loanId et amount sont requis' });
  }

  const loanResult = await pool.query(
    `SELECT l.*, u.phone_number FROM loans l
     JOIN users u ON u.id = l.user_id
     WHERE l.id = $1 AND l.user_id = $2`,
    [loanId, req.user.id]
  );

  if (loanResult.rows.length === 0) {
    return res.status(404).json({ error: 'Prêt introuvable' });
  }

  const loan = loanResult.rows[0];
  const reference = `mcf-repay-${loan.id}-${Date.now()}`;

  const txResult = await pool.query(
    `INSERT INTO airtel_transactions (loan_id, user_id, transaction_type, reference, amount, currency, status)
     VALUES ($1, $2, 'collection', $3, $4, $5, 'initiated')
     RETURNING *`,
    [loan.id, req.user.id, reference, amount, process.env.AIRTEL_CURRENCY]
  );

  try {
    const airtelResponse = await airtelService.requestCollection({
      phoneNumber: loan.phone_number,
      amount,
      reference,
    });

    await pool.query(
      `UPDATE airtel_transactions
       SET status = 'pending', airtel_transaction_id = $1, raw_response = $2, updated_at = now()
       WHERE id = $3`,
      [airtelResponse.transaction_id || null, airtelResponse, txResult.rows[0].id]
    );

    // Le solde n'est mis à jour qu'à la réception du callback (voir routes/webhooks.js),
    // jamais de manière optimiste ici.
    res.json({ status: 'collection_requested', reference });
  } catch (err) {
    await pool.query(
      `UPDATE airtel_transactions SET status = 'failed', raw_response = $1, updated_at = now() WHERE id = $2`,
      [{ error: err.message }, txResult.rows[0].id]
    );
    res.status(502).json({ error: 'Échec de la demande de remboursement', details: err.message });
  }
});

module.exports = router;
