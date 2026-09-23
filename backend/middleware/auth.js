const jwt = require('jsonwebtoken');
require('dotenv').config();

const verifyToken = (req, res, next) => {
  const token = req.headers['authorization'];
  if (!token) return res.status(403).json({ error: 'No token provided' });

  // Token usually comes as 'Bearer <token>'
  const tokenString = token.split(' ')[1] || token;

  jwt.verify(tokenString, process.env.JWT_SECRET, (err, decoded) => {
    if (err) return res.status(401).json({ error: 'Unauthorized' });
    req.userId = decoded.id; // user id from JWT
    req.userEmail = decoded.email;
    next();
  });
};

module.exports = { verifyToken };
