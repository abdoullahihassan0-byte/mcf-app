require('dotenv').config();
const express = require('express');
const helmet = require('helmet');

const authRouter = require('./routes/auth');
const loansRouter = require('./routes/loans');
const repaymentsRouter = require('./routes/repayments');
const webhooksRouter = require('./routes/webhooks');

const app = express();

app.use(helmet());
app.use(express.json());

app.use('/auth', authRouter);
app.use('/loans', loansRouter);
app.use('/repayments', repaymentsRouter);
app.use('/webhooks', webhooksRouter);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3000;
// '0.0.0.0' explicite : écoute sur toutes les interfaces réseau, pas
// seulement localhost — indispensable pour qu'un téléphone sur le même
// réseau Wi-Fi puisse atteindre ce serveur via l'IP locale du PC.
app.listen(PORT, '0.0.0.0', () => {
  console.log(`MCF backend démarré sur le port ${PORT} (accessible sur le réseau local)`);
});
