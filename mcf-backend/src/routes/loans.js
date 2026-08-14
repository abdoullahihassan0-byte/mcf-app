const express = require('express');
const pool = require('../config/db');
const airtelService = require('../services/airtelService');
const ledgerService = require('../services/ledgerService');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// POST /loans - un emprunteur crée une demande de crédit
router.post('/', requireAuth, async (req, res) => {
  const { principalAmount, interestRate, durationDays } = req.body;

  if (!principalAmount || !interestRate || !durationDays) {
    return res.status(400).json({ error: 'principalAmount, interestRate et durationDays sont requis' });
  }

  const totalDue = Number(principalAmount) * (1 + Number(interestRate) / 100);

  const result = await pool.query(
    `INSERT INTO loans (user_id, principal_amount, interest_rate, duration_days, total_due, status)
     VALUES ($1, $2, $3, $4, $5, 'requested')
     RETURNING *`,
    [req.user.id, principalAmount, interestRate, durationDays, totalDue]
  );

  res.status(201).json(result.rows[0]);
});

// GET /loans - liste des prêts (les siens pour un emprunteur, tous pour un admin)
router.get('/', requireAuth, async (req, res) => {
  const isAdmin = req.user.role === 'admin';
  const result = await pool.query(
    isAdmin
      ? 'SELECT * FROM loans ORDER BY created_at DESC'
      : 'SELECT * FROM loans WHERE user_id = $1 ORDER BY created_at DESC',
    isAdmin ? [] : [req.user.id]
  );
  res.json(result.rows);
});

// GET /loans/:id - détail d'un prêt (avec solde calculé)
router.get('/:id', requireAuth, async (req, res) => {
  const loanResult = await pool.query('SELECT * FROM loans WHERE id = $1', [req.params.id]);
  if (loanResult.rows.length === 0) {
    return res.status(404).json({ error: 'Prêt introuvable' });
  }

  const loan = loanResult.rows[0];

  // un emprunteur ne peut voir que ses propres prêts
  if (req.user.role !== 'admin' && loan.user_id !== req.user.id) {
    return res.status(403).json({ error: 'Accès refusé' });
  }

  const balance = await ledgerService.getRemainingBalance(loan.id);
  res.json({ ...loan, balance });
});

// POST /loans/:id/approve - un admin valide une demande
router.post('/:id/approve', requireAuth, requireAdmin, async (req, res) => {
  const result = await pool.query(
    `UPDATE loans
     SET status = 'approved', approved_by = $1, approved_at = now(), updated_at = now()
     WHERE id = $2 AND status = 'requested'
     RETURNING *`,
    [req.user.id, req.params.id]
  );

  if (result.rows.length === 0) {
    return res.status(409).json({ error: 'Prêt introuvable ou déjà traité' });
  }

  await pool.query(
    `INSERT INTO admin_actions (admin_user_id, action_type, target_type, target_id)
     VALUES ($1, 'loan_approved', 'loan', $2)`,
    [req.user.id, req.params.id]
  );

  res.json(result.rows[0]);
});

// POST /loans/:id/reject - un admin rejette une demande (motif obligatoire)
router.post('/:id/reject', requireAuth, requireAdmin, async (req, res) => {
  const { reason } = req.body;

  if (!reason || !reason.trim()) {
    return res.status(400).json({ error: 'Le motif de rejet est obligatoire' });
  }

  const result = await pool.query(
    `UPDATE loans
     SET status = 'rejected', rejection_reason = $1, updated_at = now()
     WHERE id = $2 AND status = 'requested'
     RETURNING *`,
    [reason.trim(), req.params.id]
  );

  if (result.rows.length === 0) {
    return res.status(409).json({ error: 'Prêt introuvable ou déjà traité' });
  }

  await pool.query(
    `INSERT INTO admin_actions (admin_user_id, action_type, target_type, target_id, metadata)
     VALUES ($1, 'loan_rejected', 'loan', $2, $3)`,
    [req.user.id, req.params.id, { reason: reason.trim() }]
  );

  res.json(result.rows[0]);
});

// POST /loans/:id/disburse - déclenche le décaissement Airtel Money
router.post('/:id/disburse', requireAuth, requireAdmin, async (req, res) => {
  const loanResult = await pool.query(
    `SELECT l.*, u.phone_number FROM loans l
     JOIN users u ON u.id = l.user_id
     WHERE l.id = $1 AND l.status = 'approved'`,
    [req.params.id]
  );

  if (loanResult.rows.length === 0) {
    return res.status(409).json({ error: 'Prêt introuvable ou non approuvé' });
  }

  const loan = loanResult.rows[0];
  const reference = `mcf-disb-${loan.id}`;

  const txResult = await pool.query(
    `INSERT INTO airtel_transactions (loan_id, user_id, transaction_type, reference, amount, currency, status)
     VALUES ($1, $2, 'disbursement', $3, $4, $5, 'initiated')
     RETURNING *`,
    [loan.id, loan.user_id, reference, loan.principal_amount, process.env.AIRTEL_CURRENCY]
  );

  try {
    const airtelResponse = await airtelService.disburse({
      phoneNumber: loan.phone_number,
      amount: loan.principal_amount,
      reference,
    });

    await pool.query(
      `UPDATE airtel_transactions
       SET status = 'pending', airtel_transaction_id = $1, raw_response = $2, updated_at = now()
       WHERE id = $3`,
      [airtelResponse.transaction_id || null, airtelResponse, txResult.rows[0].id]
    );

    await pool.query(
      `UPDATE loans SET status = 'disbursed', disbursed_at = now(), updated_at = now() WHERE id = $1`,
      [loan.id]
    );

    res.json({ status: 'disbursement_initiated', reference });
  } catch (err) {
    await pool.query(
      `UPDATE airtel_transactions SET status = 'failed', raw_response = $1, updated_at = now() WHERE id = $2`,
      [{ error: err.message }, txResult.rows[0].id]
    );
    res.status(502).json({ error: 'Échec du décaissement Airtel Money', details: err.message });
  }
});

module.exports = router;
