/**
 * Service SMS — interface volontairement minimale pour rester
 * indépendante du fournisseur.
 *
 * IMPORTANT : je n'ai pas de confirmation fiable qu'un fournisseur
 * particulier (Twilio, Africa's Talking, Infobip, etc.) couvre le
 * Tchad (+235) de façon fiable et à un coût raisonnable — à vérifier
 * toi-même avant de choisir. Piste à explorer aussi : si l'API Airtel
 * Money expose un canal SMS/notification pour ses propres abonnés,
 * ça pourrait éviter un fournisseur tiers pour les numéros Airtel au
 * moins — non vérifié, à checker dans leur doc développeur.
 *
 * En attendant un choix, sendOtpSms() logge simplement le code en
 * console (utile en développement uniquement — ne jamais laisser ça
 * tel quel en production, n'importe qui avec accès aux logs verrait
 * les codes).
 */

async function sendOtpSms(phoneNumber, code) {
  if (process.env.SMS_PROVIDER === 'console' || !process.env.SMS_PROVIDER) {
    console.log(`[DEV UNIQUEMENT] Code OTP pour ${phoneNumber} : ${code}`);
    return { provider: 'console', delivered: true };
  }

  // TODO: brancher ici le vrai fournisseur une fois choisi et vérifié
  // pour la couverture Tchad, ex:
  //
  // if (process.env.SMS_PROVIDER === 'twilio') {
  //   return sendViaTwilio(phoneNumber, code);
  // }

  throw new Error(`Fournisseur SMS "${process.env.SMS_PROVIDER}" non implémenté`);
}

module.exports = { sendOtpSms };
