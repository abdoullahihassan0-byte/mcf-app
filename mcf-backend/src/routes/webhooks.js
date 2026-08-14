const express = require('express');
const pool = require('../config/db');
const ledgerService = require('../services/ledgerService');

const router = express.Router();

/**
 * POST /webhooks/airtel/callback
 * Reçoit la confirmation Airtel pour un décaissement ou une collecte.
 *
 * IMPORTANT : la forme exacte du payload envoyé par Airtel (noms de
 * champs, structure) n'est pas vérifiée ici — à adapter une fois la
 * documentation officielle du callback consultée. Ne pas considérer
 * les noms de champs ci-dessous (transaction_id, status, reference)
 * comme garantis.
 *
 * IMPORTANT SÉCURITÉ : ce endpoint doit vérifier la signature/l'origine
 * de la requête (selon ce que fournit Airtel) avant de faire confiance
 * au payload. Squelette actuel : PAS de vérification — à ajouter avant
 * toute mise en production.
 */
router.post('/airtel/callback', express.json(), async (req, res) => {
  // TODO: vérifier la signature/l'authenticité du callback avant de continuer

  const { transaction_id: airtelTransactionId, status, reference } = req.body;

  const txResult = await pool.query(
    `SELECT * FROM airtel_transactions WHERE airtel_transaction_id = $1 OR reference = $2`,
    [airtelTransactionId, reference]
  );

  if (txResult.rows.length === 0) {
    // On répond 200 quand même pour éviter que Airtel ne re-tente indéfiniment
    // sur une transaction qu'on ne reconnaît pas ; à surveiller côté logs.
    console.warn('Callback Airtel reçu pour une transaction inconnue', req.body);
    return res.status(200).json({ received: true });
  }

  const tx = txResult.rows[0];

  // Callback déjà traité (idempotence) : on ne rejoue pas le ledger
  if (tx.status === 'success' || tx.status === 'failed') {
    return res.status(200).json({ received: true, note: 'already_processed' });
  }

  const newStatus = status === 'SUCCESS' ? 'success' : 'failed';

  await pool.query(
    `UPDATE airtel_transactions
     SET status = $1, callback_received_at = now(), raw_response = $2, updated_at = now()
     WHERE id = $3`,
    [newStatus, req.body, tx.id]
  );

  if (newStatus === 'success') {
    const direction = tx.transaction_type === 'collection' ? 'credit' : 'debit';
    const entryType = tx.transaction_type === 'collection' ? 'repayment' : 'disbursement';

    await ledgerService.addEntry({
      loanId: tx.loan_id,
      userId: tx.user_id,
      entryType,
      direction,
      amount: tx.amount,
      airtelTransactionId: tx.id,
    });

    if (tx.transaction_type === 'collection') {
      const balance = await ledgerService.getRemainingBalance(tx.loan_id);
      if (balance.remaining <= 0) {
        await pool.query(`UPDATE loans SET status = 'completed', updated_at = now() WHERE id = $1`, [tx.loan_id]);
      }
    } else {
      await pool.query(`UPDATE loans SET status = 'active', updated_at = now() WHERE id = $1`, [tx.loan_id]);
    }
  }

  res.status(200).json({ received: true });
});

module.exports = router;
