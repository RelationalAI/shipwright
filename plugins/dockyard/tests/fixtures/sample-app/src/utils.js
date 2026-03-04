function formatUserName(first, last) {
  return `${first} ${last}`;
}

function validateEmail(email) {
  if (!email || typeof email !== 'string') return false;
  return email.includes('@') && email.includes('.');
}

module.exports = { formatUserName, validateEmail };
