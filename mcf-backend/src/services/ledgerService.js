const pool = require('../config/db');

/**
 * Ajoute une écriture au ledger. Jamais d'UPDATE : chaque mouvement
 * est une nouvelle ligne. Le solde se recalcule toujours à la lecture.
 */
async function addEntry({ loanId, userId, entryType, direction, amount, airtelTransactionId = null }) {
  const result = await pool.query(
    `INSERT INTO ledger_entries (loan_id, user_id, entry_type, direction, amount, airtel_transaction_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [loanId, userId, entryType, direction, amount, airtelTransactionId]
  );
  return result.rows[0];
}

/**
 * Calcule le solde restant dû pour un prêt à partir du ledger.
 */
async function getRemainingBalance(loanId) {
  const result = await pool.query(
    `SELECT
       l.total_due,
       COALESCE(SUM(CASE WHEN le.direction = 'credit' THEN le.amount ELSE 0 END), 0) AS total_paid
     FROM loans l
     LEFT JOIN ledger_entries le ON le.loan_id = l.id
     WHERE l.id = $1
     GROUP BY l.id, l.total_due`,
    [loanId]
  );

  if (result.rows.length === 0) {
    throw new Error('Prêt introuvable');
  }

  const { total_due, total_paid } = result.rows[0];
  return {
    totalDue: Number(total_due),
    totalPaid: Number(total_paid),
    remaining: Number(total_due) - Number(total_paid),
  };
}

module.exports = { addEntry, getRemainingBalance };
